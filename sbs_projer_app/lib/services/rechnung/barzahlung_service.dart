import 'dart:convert';

import 'package:sbs_projer_app/core/util/anfrage_bloecke.dart';
import 'package:sbs_projer_app/core/util/chf_format.dart';
import 'package:sbs_projer_app/core/util/einzel_abschreibung.dart';
import 'package:sbs_projer_app/core/util/guthaben_verrechnung.dart';
import 'package:sbs_projer_app/core/util/rundung.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/services/buchhaltung/storno_logik.dart';
import 'package:sbs_projer_app/services/rechnung/zahlung_kern.dart';

/// Eine erfolgreich kassierte Rechnung (für Teilfehler-Meldungen).
typedef Kassiert = ({String nummer, double betrag});

class BarzahlungFehler implements Exception {
  /// «Rechnung N: Grund» bzw. ein allgemeiner Grund.
  final String meldung;

  /// Rechnungen, die VOR dem Fehler im selben Aufruf schon kassiert wurden
  /// (Review Teil 3, I-1). Seit Runde 3 (ZahlungKern, alles oder nichts)
  /// immer leer — Feld bleibt für [BarzahlungService.fehlerText].
  final List<Kassiert> kassiert;

  BarzahlungFehler(this.meldung, {this.kassiert = const []});

  @override
  String toString() => meldung;
}

/// Barzahlung vor Ort (Mahnwesen Teil 3, v0.136.0).
///
/// WARUM: Ein Betrieb mit gemahnten Rechnungen zahlt beim Service bar
/// (Entscheid Daniel 24.09.2026: kein TWINT, bar → Kasse 1000). Die App
/// bucht Soll 1000 / Haben 1100 je Rechnung und setzt sie bezahlt. Der
/// Mahn-Stand VOR der Zahlung steht in `notizen` der Buchung, damit
/// «Barzahlung rückgängig» die Rechnung wieder genau in ihre Mahnstufe
/// zurückversetzt statt pauschal auf «offen».
class BarzahlungService {
  static const kKasse = 1000;
  static const kDebitoren = 1100;

  /// Felder aus `MahnlaufService.vorherStand`, die beim Rückgängigmachen
  /// zurückgeschrieben werden dürfen — alles andere in der Notiz wird
  /// ignoriert.
  static const _vorherFelder = {
    'zahlungsstatus',
    'mahnung_stufe',
    'letzte_mahnung_am',
    'erinnerung_am',
    'mahnung_1_am',
    'mahnung_2_am',
    'mahn_frist_bis',
  };

  static String _datumStr(DateTime d) => d.toIso8601String().split('T').first;

  static String _nr(Rechnung r) => r.rechnungsnummer ?? r.id.substring(0, 8);

  /// Heute (bzw. [d]) als UTC-Tag — Datum der Buchung und des Zahlungseingangs.
  static DateTime kassierDatum([DateTime? d]) {
    final x = d ?? DateTime.now();
    return DateTime.utc(x.year, x.month, x.day);
  }

  /// Betrag der Barzahlung: Rechnungsbrutto auf 5 Rappen, wie der Bankweg
  /// (`ZahlungsdifferenzService`, Review Teil 3 Minor c).
  static double kassierBetrag(double brutto) => rundeAuf5Rappen(brutto);

  /// Bar kassiert wird «zu zahlen» — Brutto abzüglich verrechnetem
  /// Kundenguthaben (v0.137.0), auf 5 Rappen.
  static double kassierBetragFuer(Rechnung r) => kassierBetrag(r.zuZahlen);

  /// Rein: Verrechnung Soll 2030 / Haben 1100 neben der Barzahlung (0 =
  /// keine) — dieselbe Planfunktion wie der Bankweg.
  static double verrechnungFuer(Rechnung r) =>
      differenzPlan([r], kassierBetragFuer(r)).zeilen.single.verrechnung;

  /// Rein: Warum darf auf diese Rechnung NICHT bar kassiert werden — oder
  /// null, wenn sie frei ist. Unterscheidet «schon erledigt» vom halben
  /// Zustand «Zahlung gebucht, Status nicht nachgezogen» (Review I-2).
  static String? kassierSperre(Rechnung r, {required bool hatZahlung}) {
    if (r.zahlungsstatus == 'bezahlt' || r.zahlungsstatus == 'abgeschrieben') {
      return 'bereits bezahlt/abgeschrieben';
    }
    if (hatZahlung) {
      return 'Zahlung bereits gebucht (Rechnung noch nicht bezahlt) — '
          'im Rechnungsdetail prüfen';
    }
    if (r.zahlungEingegangenAm != null || (r.zahlungBetrag ?? 0) != 0) {
      return 'Zahlungseingang bereits vermerkt (Rechnung noch nicht bezahlt) — '
          'im Rechnungsdetail prüfen';
    }
    return null;
  }

  /// Rein: Darf auf diese Rechnung bar kassiert werden?
  static bool darfKassieren(Rechnung r, {required bool hatZahlung}) =>
      kassierSperre(r, hatZahlung: hatZahlung) == null;

  /// Rein: Meldung für die Oberfläche. Bei einem Teilfehler
  /// «X von Y kassiert (CHF …) — Rechnung N: Grund» (Review I-1).
  static String fehlerText(BarzahlungFehler f, {required int gesamt}) {
    if (f.kassiert.isEmpty) return f.meldung;
    final summe = f.kassiert.fold(0.0, (s, k) => s + k.betrag);
    return '${f.kassiert.length} von $gesamt kassiert (CHF ${chf(summe)}) — ${f.meldung}';
  }

  /// Rein: Fehlertext für eine Snackbar. Eigene Meldungen ungekürzt (sie
  /// sagen, was zu tun ist), alles andere über `kurzeFehlermeldung`.
  static String meldungFuer(Object e) =>
      e is BarzahlungFehler ? e.meldung : kurzeFehlermeldung(e);

  static bool _istBarzahlung(Buchung b) =>
      b.sollKonto == kKasse &&
      b.habenKonto == kDebitoren &&
      b.zahlungsweg == 'kasse' &&
      b.belegTyp == 'zahlung' &&
      zaehltFuerSaldo(istStorniert: b.istStorniert, stornoVonId: b.stornoVonId);

  /// Rein: Aktive Barzahlungs-Buchung (Soll 1000, Haben 1100, Zahlungsweg
  /// Kasse, nicht storniert, kein Storno) unter den Buchungen der Rechnung.
  static Buchung? barzahlungAus(Iterable<Buchung> buchungenDerRechnung) {
    for (final b in buchungenDerRechnung) {
      if (_istBarzahlung(b)) return b;
    }
    return null;
  }

  /// Rein: Warum darf die Barzahlung [bar] NICHT zurückgenommen werden —
  /// oder null. [buchungen] = alle Buchungen der Rechnung.
  /// - weitere aktive Zahlung (Minor a): sonst stünde die Rechnung offen,
  ///   obwohl Geld gebucht ist;
  /// - Vorjahr (Minor b): abgeschlossenes Jahr nie still verändern;
  /// - Rechnung nicht mehr bezahlt.
  static String? rueckgaengigSperre({
    required Buchung bar,
    required List<Buchung> buchungen,
    required String status,
    required DateTime heute,
  }) {
    if (status != 'bezahlt') {
      return 'Rechnung ist nicht mehr bezahlt — nichts geändert';
    }
    if (bar.geschaeftsjahr != heute.year) {
      return 'Barzahlung aus abgeschlossenem Jahr — Storno von Hand in der Buchhaltung';
    }
    // Die Guthaben-Verrechnung (2030/1100) gehört zur Barzahlung und wird
    // mit ihr zurückgenommen — sie ist keine «weitere Zahlung».
    if (zahlungGebucht(buchungen
        .where((b) => b.id != bar.id && !istGuthabenVerrechnung(b)))) {
      return 'Neben der Barzahlung ist eine weitere Zahlung gebucht — '
          'im Journal prüfen, nichts geändert';
    }
    return null;
  }

  /// Rein: Vorher-Stand aus der Buchungsnotiz lesen (robust gegen null/Unsinn).
  /// Nur bekannte Felder; ohne gültigen, nicht bezahlten Status → null.
  static Map<String, dynamic>? vorherAusNotiz(String? notizen) {
    if (notizen == null || notizen.trim().isEmpty) return null;
    Object? roh;
    try {
      roh = jsonDecode(notizen);
    } catch (_) {
      return null;
    }
    if (roh is! Map) return null;
    final status = roh['zahlungsstatus'];
    if (status is! String ||
        status.isEmpty ||
        status == 'bezahlt' ||
        status == 'abgeschrieben') {
      return null;
    }
    return {
      for (final e in roh.entries)
        if (e.key is String && _vorherFelder.contains(e.key)) e.key as String: e.value,
    };
  }

  /// Je Rechnung: frisch laden; abbrechen (nichts buchen), wenn eine nicht
  /// kassierbar ist ([kassierSperre]). Dann EIN Aufruf [ZahlungKern.erfassen]
  /// (Weg Kasse, Soll 1000 / Haben 1100): Buchungen und «bezahlt» aller
  /// Rechnungen atomar — alles oder nichts (Runde 3; vorher je Rechnung
  /// einzeln, mit Teilfehlern und eigenem Rückbau).
  ///
  /// Gibt die Ids der kassierten Rechnungen zurück. Lehnt die DB ab, wird
  /// [BarzahlungFehler] mit ihrem Text geworfen (nichts gebucht).
  static Future<List<String>> kassieren(List<Rechnung> rechnungen, {DateTime? datum}) async {
    if (rechnungen.isEmpty) return const [];
    final tag = kassierDatum(datum);

    // 1. Alles prüfen, bevor irgendetwas gebucht wird.
    final frische = <Rechnung>[];
    for (final r in rechnungen) {
      final f = await RechnungRepository.getById(r.id);
      if (f == null) throw BarzahlungFehler('Rechnung ${_nr(r)}: nicht gefunden');
      final buchungen = await BuchungRepository.getByBeleg(f.id);
      final sperre = kassierSperre(f, hatZahlung: zahlungGebucht(buchungen));
      if (sperre != null) {
        throw BarzahlungFehler('Rechnung ${_nr(f)}: $sperre — nichts gebucht');
      }
      frische.add(f);
    }

    // 2. Atomar buchen und bezahlt setzen (die DB prüft noch einmal unter
    //    Zeilensperre).
    final summe = rundeAufRappen(
        frische.fold<double>(0, (s, f) => s + kassierBetragFuer(f)));
    try {
      await ZahlungKern.erfassen(
        rechnungen: frische,
        betrag: summe,
        datum: tag,
        weg: ZahlungWeg.kasse,
      );
    } on ZahlungGesperrt catch (e) {
      throw BarzahlungFehler(e.text);
    }
    return [for (final f in frische) f.id];
  }

  /// Aktive Barzahlungs-Buchung der Rechnung oder null.
  static Future<Buchung?> barzahlungZu(String rechnungId) async =>
      barzahlungAus(await BuchungRepository.getByBeleg(rechnungId));

  /// Löscht die Barzahlungs-Buchung und setzt die Rechnung auf den in
  /// `notizen` gespeicherten Vorher-Stand zurück (Fallback: 'offen',
  /// Zahlungsfelder null). Nur wenn [rueckgaengigSperre] frei ist.
  static Future<void> rueckgaengig(Rechnung rechnung, {DateTime? heute}) async {
    final nr = _nr(rechnung);
    final frisch = await RechnungRepository.getById(rechnung.id);
    if (frisch == null) throw BarzahlungFehler('Rechnung $nr: nicht gefunden');
    final buchungen = await BuchungRepository.getByBeleg(rechnung.id);
    final buchung = barzahlungAus(buchungen);
    if (buchung == null) throw BarzahlungFehler('Keine Barzahlung zu Rechnung $nr gefunden');
    final sperre = rueckgaengigSperre(
      bar: buchung,
      buchungen: buchungen,
      status: frisch.zahlungsstatus,
      heute: heute ?? DateTime.now(),
    );
    if (sperre != null) throw BarzahlungFehler(sperre);

    final vorher = vorherAusNotiz(buchung.notizen) ?? {'zahlungsstatus': 'offen'};
    final gesetzt = await RechnungRepository.updateWennStatus(
      rechnung.id,
      {...vorher, 'zahlung_eingegangen_am': null, 'zahlung_betrag': null},
      erwarteterStatus: 'bezahlt',
    );
    if (!gesetzt) {
      throw BarzahlungFehler('Rechnung $nr ist nicht mehr bezahlt — nichts geändert');
    }
    try {
      await BuchungRepository.delete(buchung.id);
    } catch (e) {
      // Buchung steht noch → Rechnung wieder bezahlt, sonst stimmen Kasse
      // und Rechnungsstatus nicht mehr überein. Scheitert auch das, beide
      // Fehler nennen (Review Minor d).
      try {
        await RechnungRepository.updateWennStatus(
          rechnung.id,
          {
            // = 'bezahlt' (rueckgaengigSperre verlangt es); Rückbau des
            // Statuswechsels, keine neue Zahlung — Task 4 ersetzt den Weg.
            'zahlungsstatus': frisch.zahlungsstatus,
            'zahlung_eingegangen_am': _datumStr(buchung.datum),
            'zahlung_betrag': buchung.betragBrutto,
          },
          erwarteterStatus: vorher['zahlungsstatus'] as String,
        );
      } catch (e2) {
        throw BarzahlungFehler(
          'Buchung nicht gelöscht (${kurzeFehlermeldung(e)}) und Rechnung $nr '
          'nicht wieder auf bezahlt gesetzt (${kurzeFehlermeldung(e2)}) — '
          'Rechnung steht offen, Kassenbuchung besteht: im Rechnungsdetail prüfen',
        );
      }
      throw BarzahlungFehler(
          'Buchung nicht gelöscht (${kurzeFehlermeldung(e)}) — Rechnung bleibt bezahlt');
    }
    await _verrechnungEntfernen(buchungen, nr);
  }

  /// Guthaben-Verrechnung (2030/1100) der Rechnung löschen — sie entstand
  /// mit der Barzahlung und geht mit ihr (sonst wäre das Guthaben
  /// verbraucht, obwohl die Rechnung wieder offen ist).
  static Future<void> _verrechnungEntfernen(
      List<Buchung> buchungen, String nr) async {
    for (final v in buchungen.where(istGuthabenVerrechnung)) {
      try {
        await BuchungRepository.delete(v.id);
      } catch (e) {
        throw BarzahlungFehler(
            'Barzahlung zurückgenommen, aber Guthaben-Verrechnung zu Rechnung '
            '$nr nicht gelöscht (${kurzeFehlermeldung(e)}) — im Journal prüfen');
      }
    }
  }

  /// Halber Zustand (Review I-2): Kassenbuchung vorhanden, Rechnung aber
  /// NICHT bezahlt. Löscht nur diese Buchung, der Status bleibt.
  static Future<void> kassenbuchungEntfernen(Rechnung rechnung) async {
    final nr = _nr(rechnung);
    final frisch = await RechnungRepository.getById(rechnung.id);
    if (frisch == null) throw BarzahlungFehler('Rechnung $nr: nicht gefunden');
    if (frisch.zahlungsstatus == 'bezahlt') {
      throw BarzahlungFehler(
          'Rechnung $nr ist bezahlt — «Barzahlung rückgängig» verwenden');
    }
    final buchungen = await BuchungRepository.getByBeleg(rechnung.id);
    final buchung = barzahlungAus(buchungen);
    if (buchung == null) throw BarzahlungFehler('Keine Kassenbuchung zu Rechnung $nr gefunden');
    if (buchung.geschaeftsjahr != DateTime.now().year) {
      throw BarzahlungFehler(
          'Kassenbuchung aus abgeschlossenem Jahr — Storno von Hand in der Buchhaltung');
    }
    await BuchungRepository.delete(buchung.id);
    await _verrechnungEntfernen(buchungen, nr);
  }
}

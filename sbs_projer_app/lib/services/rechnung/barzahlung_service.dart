import 'dart:convert';

import 'package:sbs_projer_app/core/util/einzel_abschreibung.dart';
import 'package:sbs_projer_app/core/util/rundung.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/services/buchhaltung/storno_logik.dart';
import 'package:sbs_projer_app/services/rechnung/mahnlauf_service.dart';

class BarzahlungFehler implements Exception {
  final String meldung;
  BarzahlungFehler(this.meldung);
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

  /// Heute (bzw. [d]) als UTC-Tag — Datum der Buchung und des Zahlungseingangs.
  static DateTime kassierDatum([DateTime? d]) {
    final x = d ?? DateTime.now();
    return DateTime.utc(x.year, x.month, x.day);
  }

  /// Rein: Darf auf diese Rechnung bar kassiert werden?
  /// Nein bei bezahlt/abgeschrieben, gebuchter Zahlung oder bereits
  /// vermerktem Zahlungseingang.
  static bool darfKassieren(Rechnung r, {required bool hatZahlung}) =>
      r.zahlungsstatus != 'bezahlt' &&
      r.zahlungsstatus != 'abgeschrieben' &&
      !hatZahlung &&
      r.zahlungEingegangenAm == null &&
      (r.zahlungBetrag ?? 0) == 0;

  /// Rein: Aktive Barzahlungs-Buchung (Soll 1000, Haben 1100, Zahlungsweg
  /// Kasse, nicht storniert, kein Storno) unter den Buchungen der Rechnung.
  static Buchung? barzahlungAus(Iterable<Buchung> buchungenDerRechnung) {
    for (final b in buchungenDerRechnung) {
      if (b.sollKonto == kKasse &&
          b.habenKonto == kDebitoren &&
          b.zahlungsweg == 'kasse' &&
          b.belegTyp == 'zahlung' &&
          zaehltFuerSaldo(istStorniert: b.istStorniert, stornoVonId: b.stornoVonId)) {
        return b;
      }
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

  /// Je Rechnung: frisch laden; abbrechen (nichts buchen), wenn eine schon
  /// bezahlt/abgeschrieben ist oder eine Zahlung gebucht hat. Dann je
  /// Rechnung Buchung Soll 1000 / Haben 1100 und Rechnung bezahlt — gegen
  /// den geladenen Status. Ändert sich eine Rechnung zwischen Laden und
  /// Setzen, wird deren Buchung wieder gelöscht und [BarzahlungFehler]
  /// geworfen (vorher kassierte Rechnungen bleiben korrekt bezahlt).
  static Future<void> kassieren(List<Rechnung> rechnungen, {DateTime? datum}) async {
    if (rechnungen.isEmpty) return;
    final tag = kassierDatum(datum);
    final tagStr = _datumStr(tag);

    // 1. Alles prüfen, bevor irgendetwas gebucht wird.
    final frische = <Rechnung>[];
    for (final r in rechnungen) {
      final f = await RechnungRepository.getById(r.id);
      final nr = r.rechnungsnummer ?? r.id.substring(0, 8);
      if (f == null) throw BarzahlungFehler('Rechnung $nr nicht gefunden');
      final buchungen = await BuchungRepository.getByBeleg(f.id);
      if (!darfKassieren(f, hatZahlung: zahlungGebucht(buchungen))) {
        throw BarzahlungFehler(
          'Rechnung $nr ist bereits bezahlt oder abgeschrieben — nichts gebucht',
        );
      }
      frische.add(f);
    }

    // 2. Buchen und bezahlt setzen.
    for (final f in frische) {
      final nr = f.rechnungsnummer ?? f.id.substring(0, 8);
      final betrag = rundeAufRappen(f.betragBrutto);
      final buchung = await BuchungRepository.create({
        'datum': tagStr,
        'belegnummer': f.rechnungsnummer ?? '',
        'soll_konto': kKasse,
        'haben_konto': kDebitoren,
        'betrag_netto': betrag,
        'mwst_satz': 0,
        'mwst_betrag': 0,
        'betrag_brutto': betrag,
        'beschreibung': 'Barzahlung $nr (vor Ort)',
        'zahlungsweg': 'kasse',
        'beleg_typ': 'zahlung',
        'beleg_id': f.id,
        'geschaeftsjahr': tag.year,
        'notizen': jsonEncode(MahnlaufService.vorherStand(f)),
      });
      bool gesetzt;
      try {
        gesetzt = await RechnungRepository.updateWennStatus(
          f.id,
          {
            'zahlungsstatus': 'bezahlt',
            'zahlung_eingegangen_am': tagStr,
            'zahlung_betrag': betrag,
          },
          erwarteterStatus: f.zahlungsstatus,
          nurOhneZahlung: true,
        );
      } catch (_) {
        await BuchungRepository.delete(buchung.id);
        rethrow;
      }
      if (!gesetzt) {
        await BuchungRepository.delete(buchung.id);
        throw BarzahlungFehler('Rechnung $nr wurde inzwischen geändert — nicht kassiert');
      }
    }
  }

  /// Aktive Barzahlungs-Buchung der Rechnung oder null.
  static Future<Buchung?> barzahlungZu(String rechnungId) async =>
      barzahlungAus(await BuchungRepository.getByBeleg(rechnungId));

  /// Löscht die Barzahlungs-Buchung und setzt die Rechnung auf den in
  /// `notizen` gespeicherten Vorher-Stand zurück (Fallback: 'offen',
  /// Zahlungsfelder null). Nur wenn die Rechnung noch 'bezahlt' ist.
  static Future<void> rueckgaengig(Rechnung rechnung) async {
    final nr = rechnung.rechnungsnummer ?? rechnung.id.substring(0, 8);
    final buchung = await barzahlungZu(rechnung.id);
    if (buchung == null) throw BarzahlungFehler('Keine Barzahlung zu Rechnung $nr gefunden');
    final vorher = vorherAusNotiz(buchung.notizen) ?? {'zahlungsstatus': 'offen'};
    final felder = <String, dynamic>{
      ...vorher,
      'zahlung_eingegangen_am': null,
      'zahlung_betrag': null,
    };
    final gesetzt = await RechnungRepository.updateWennStatus(
      rechnung.id,
      felder,
      erwarteterStatus: 'bezahlt',
    );
    if (!gesetzt) {
      throw BarzahlungFehler('Rechnung $nr ist nicht mehr bezahlt — nichts geändert');
    }
    try {
      await BuchungRepository.delete(buchung.id);
    } catch (_) {
      // Buchung steht noch → Rechnung wieder bezahlt, sonst stimmen Kasse
      // und Rechnungsstatus nicht mehr überein.
      await RechnungRepository.updateWennStatus(
        rechnung.id,
        {
          'zahlungsstatus': 'bezahlt',
          'zahlung_eingegangen_am': _datumStr(buchung.datum),
          'zahlung_betrag': buchung.betragBrutto,
        },
        erwarteterStatus: vorher['zahlungsstatus'] as String,
      );
      rethrow;
    }
  }
}

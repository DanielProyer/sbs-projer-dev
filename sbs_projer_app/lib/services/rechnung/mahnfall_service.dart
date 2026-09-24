import 'package:flutter/foundation.dart';
import 'package:sbs_projer_app/core/config/mail_config.dart';
import 'package:sbs_projer_app/core/util/anfrage_bloecke.dart';
import 'package:sbs_projer_app/core/util/betrieb_anzeige.dart';
import 'package:sbs_projer_app/core/util/chf_format.dart';
import 'package:sbs_projer_app/core/util/mahnfall_regeln.dart';
import 'package:sbs_projer_app/core/util/mahnregeln.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/mappers/betrieb_rechnungsadresse_mapper.dart';
import 'package:sbs_projer_app/data/models/betrieb_rechnungsadresse.dart';
import 'package:sbs_projer_app/data/models/mahnfall.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_rechnungsadresse_repository.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/data/repositories/kontakt_repository.dart';
import 'package:sbs_projer_app/data/repositories/mahnfall_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/services/pdf/kontoauszug_pdf_service.dart';
import 'package:sbs_projer_app/services/pdf/rechnung_pdf_storage.dart';
import 'package:sbs_projer_app/services/rechnung/mahnwesen_service.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Fehler eines Mahnfall-Schritts. `toString()` liefert NUR [meldung] (wie
/// `MahnlaufFehler`) — die Meldung darf ohne Weiteres auf die Oberfläche.
/// [fallId] ist gesetzt, wenn der Fall beim Fehler schon angelegt ist (Mail
/// an Heineken gescheitert): Der Screen bietet dann «Mail erneut senden» an.
class MahnfallFehler implements Exception {
  final String meldung;
  final String? fallId;

  MahnfallFehler(this.meldung, {this.fallId});

  @override
  String toString() => meldung;
}

/// Alle schreibenden Schritte eines Mahnfalls (Mahnwesen Teil 2, Spec §5):
/// Fall eröffnen + Heineken-Mail, Ergebnis erfassen, Betreibung begleiten,
/// abschliessen.
///
/// «Heineken übernimmt» wird bewusst NUR erfasst (Plan-Kopf, Entscheid
/// Daniel 23.09.2026): keine Buchung, keine Position auf der
/// Heineken-Monatsrechnung — stattdessen die Markierung [kUebernahmeOffen]
/// in der Notiz, aus der die Glocke eine dringende Aufgabe macht.
class MahnfallService {
  /// Markierung in `notiz`: Übernahme durch Heineken noch nicht verbucht.
  static const kUebernahmeOffen = '[UEBERNAHME OFFEN]';

  static const _ergebnisse = {'vermittelt', 'uebernommen', 'konkurs', 'betreibung'};
  static const _erledigungen = {'bezahlt', 'abgeschrieben', 'zurueckgezogen'};

  /// Felder, die das Betreibungs-Datenblatt schreiben darf.
  static const _betreibungsFelder = {
    'schuldner_name',
    'schuldner_adresse',
    'rechtsform',
    'betreibungsamt',
    'eingereicht_am',
    'zahlungsbefehl_am',
    'rechtsvorschlag',
    'fortsetzung_am',
    'kosten_vorschuss',
    'notiz',
  };

  // ─── Fall eröffnen ───────────────────────────────────────────────────────

  /// Fall eröffnen + Heineken-Mail. Prüft vorher frisch aus der DB, dass jede
  /// Rechnung noch `mahnung_2` und im Mahnbereich ist, und dass keine der
  /// Rechnungen schon in einem offenen Fall steckt.
  ///
  /// Der Fall wird VOR der Mail angelegt (Protokoll, wie beim Mahnlauf):
  /// Scheitert die Mail, bleibt der Fall stehen und der Fehler trägt die
  /// [MahnfallFehler.fallId] — «Mail erneut senden» über [mailErneutSenden].
  static Future<Mahnfall> eroeffnen({
    required BetriebLocal betrieb,
    required List<Rechnung> rechnungen,
    DateTime? heute,
  }) async {
    final datum = heute ?? DateTime.now();
    final betriebId = betrieb.serverId;
    if (betriebId == null || betriebId.isEmpty) {
      throw MahnfallFehler('Betrieb ohne Server-Id — Fall kann nicht eröffnet werden');
    }
    if (rechnungen.isEmpty) {
      throw MahnfallFehler('Keine Rechnungen für den Mahnfall');
    }

    final List<Rechnung> frisch;
    final String kontaktEmail;
    try {
      // 1. Frischer Abgleich: Eine inzwischen bezahlte oder geänderte
      //    Rechnung darf nie bei Heineken landen.
      frisch = <Rechnung>[];
      for (final r in rechnungen) {
        final db = await RechnungRepository.getById(r.id);
        if (db == null || !imMahnbereich(db) || db.zahlungsstatus != 'mahnung_2') {
          throw MahnfallFehler(
            'Rechnung ${r.rechnungsnummer ?? r.id} wurde inzwischen geändert — '
            'kein Fall eröffnet',
          );
        }
        frisch.add(db);
      }
      final ids = {for (final r in frisch) r.id};
      final offene = await MahnfallRepository.getOffene();
      for (final f in offene) {
        final doppelt = f.rechnungIds.where(ids.contains);
        if (doppelt.isNotEmpty) {
          final nr = frisch.firstWhere((r) => r.id == doppelt.first).rechnungsnummer;
          throw MahnfallFehler(
            'Rechnung ${nr ?? doppelt.first} steckt schon in einem offenen '
            'Mahnfall — kein Fall eröffnet',
          );
        }
      }

      // 2. Heineken-Kontakt «Mahnwesen».
      final kontakt = await KontaktRepository.getHeinekenZuweisung('mahnwesen');
      final mail = kontakt?.email?.trim() ?? '';
      if (mail.isEmpty) {
        throw MahnfallFehler(
          'Kein Heineken-Kontakt «Mahnwesen» hinterlegt — unter Heineken → '
          'Zuweisungen erfassen',
        );
      }
      kontaktEmail = mail;
    } catch (e) {
      if (e is MahnfallFehler) rethrow;
      throw MahnfallFehler(kurzeFehlermeldung(e));
    }

    // 3. Testmodus: bis Daniel das Mahnwesen scharf stellt, geht alles an
    //    ihn, Papier mit MUSTER-Wasserzeichen.
    final muster = !MailConfig.istScharf('mahnwesen');

    // 4. Fall anlegen (user_id ohne DB-Default — immer mitgeben).
    final Mahnfall fall;
    try {
      fall = await MahnfallRepository.insert({
        'user_id': SupabaseService.dataUserId,
        'betrieb_id': betriebId,
        'rechnung_ids': frisch.map((r) => r.id).toList(),
        'eroeffnet_am': MahnfallRepository.dateStr(datum),
        'status': 'heineken',
        'test': muster,
        'heineken_kontakt_am': MahnfallRepository.dateStr(datum),
        'heineken_empfaenger': kontaktEmail,
      });
    } catch (e) {
      throw MahnfallFehler(kurzeFehlermeldung(e));
    }

    // 5./6. Kontoauszug + Mail. Fehler → Fall bleibt (Protokoll).
    try {
      await _heinekenMail(
        fall: fall,
        betrieb: betrieb,
        rechnungen: frisch,
        kontaktEmail: kontaktEmail,
        datum: datum,
        muster: muster,
      );
    } catch (e) {
      throw MahnfallFehler(
        'Fall angelegt, Mail an Heineken fehlgeschlagen: ${kurzeFehlermeldung(e)}',
        fallId: fall.id,
      );
    }
    return fall;
  }

  /// Heineken-Mail zu einem Fall erneut senden (nach gescheitertem Versand
  /// oder bei geändertem Kontakt). Nur solange Heineken noch kein Ergebnis
  /// gemeldet hat. Setzt Kontaktdatum und Empfänger neu.
  static Future<Mahnfall> mailErneutSenden(Mahnfall fall, {DateTime? heute}) async {
    if (fall.status != 'heineken' || fall.heinekenErgebnis != null) {
      throw MahnfallFehler('Heineken hat bereits ein Ergebnis — keine neue Mail', fallId: fall.id);
    }
    final datum = heute ?? DateTime.now();
    try {
      final betrieb = await BetriebRepository.getById(fall.betriebId);
      if (betrieb == null) {
        throw MahnfallFehler('Betrieb des Falls nicht gefunden', fallId: fall.id);
      }
      final kontakt = await KontaktRepository.getHeinekenZuweisung('mahnwesen');
      final mail = kontakt?.email?.trim() ?? '';
      if (mail.isEmpty) {
        throw MahnfallFehler(
          'Kein Heineken-Kontakt «Mahnwesen» hinterlegt — unter Heineken → '
          'Zuweisungen erfassen',
          fallId: fall.id,
        );
      }
      final rechnungen = await _laden(fall);
      await _heinekenMail(
        fall: fall,
        betrieb: betrieb,
        rechnungen: rechnungen,
        kontaktEmail: mail,
        datum: datum,
        muster: !MailConfig.istScharf('mahnwesen'),
      );
      return MahnfallRepository.update(fall.id, {
        'heineken_kontakt_am': MahnfallRepository.dateStr(datum),
        'heineken_empfaenger': mail,
      });
    } catch (e) {
      if (e is MahnfallFehler) rethrow;
      throw MahnfallFehler(kurzeFehlermeldung(e), fallId: fall.id);
    }
  }

  /// Kontoauszug des laufenden Jahres erzeugen, ablegen und die Mail an
  /// Heineken senden. KEIN `rechnungId`/`markiereVersandt` im Aufruf — der
  /// Versandvermerk der Rechnungen darf nicht überschrieben werden
  /// (`versandvermerk_waechter_test`).
  static Future<void> _heinekenMail({
    required Mahnfall fall,
    required BetriebLocal betrieb,
    required List<Rechnung> rechnungen,
    required String kontaktEmail,
    required DateTime datum,
    required bool muster,
  }) async {
    final betriebId = betrieb.serverId ?? fall.betriebId;
    final uid = SupabaseService.dataUserId;

    // Rechnungsadresse — dieselbe Quelle wie im Mahnlauf.
    BetriebRechnungsadresse? ra;
    final raLocal = await BetriebRechnungsadresseRepository.getByBetrieb(betriebId);
    if (raLocal != null) {
      ra = BetriebRechnungsadresseMapper.toDto(raLocal, betriebId: betriebId);
    }

    // Alle Kunden-/Jahresrechnungen des Betriebs im laufenden Jahr, frisch
    // geladen, INKLUSIVE bezahlter — ein Kontoauszug ohne Zahlungen wäre
    // keiner (wie `MahnBetrieb.rechnungenDesJahres`).
    final jahr = datum.year;
    final desJahres = (await RechnungRepository.getKundenrechnungenAb(
      DateTime.utc(jahr, 1, 1),
      betriebId: betriebId,
    ))
        .where((r) => r.rechnungsdatum.year == jahr)
        .toList();

    final kontoauszug = await KontoauszugPdfService.generate(
      betrieb: betrieb,
      rechnungen: desJahres,
      rechnungsadresse: ra,
      jahr: jahr,
      muster: muster,
      mitZahlteil: false,
    );
    await RechnungPdfStorage.uploadMahnfallPdf(fall.id, 'kontoauszug.pdf', kontoauszug);

    final empfaenger = MailConfig.empfaenger(kontaktEmail, bereich: 'mahnwesen');
    var subject = 'Offene Rechnungen ${betriebMitOrt(betrieb.name, betrieb.ort)} — '
        'Bitte um Unterstützung';
    if (muster) subject = 'TEST an: $kontaktEmail — $subject';

    final res = await SupabaseService.client.functions.invoke(
      'send-rechnung-mail',
      body: {
        'to': empfaenger,
        'subject': subject,
        'bodyText': heinekenMailText(
          betrieb: betriebMitOrt(betrieb.name, betrieb.ort),
          rechnungen: rechnungen,
        ),
        'userId': uid,
        'zusatzPdfs': [
          {
            'pfad': '$uid/mahnfaelle/${fall.id}/kontoauszug.pdf',
            'dateiname': 'Kontoauszug.pdf',
            'pflicht': true,
          },
          for (final r in rechnungen)
            {
              'pfad': '$uid/${r.id}/rechnung.pdf',
              'dateiname': 'Rechnung_${r.rechnungsnummer ?? ''}.pdf',
              'pflicht': false,
            },
        ],
      },
    );
    final data = res.data;
    if (data is Map && data['fehlendeAnhaenge'] is List) {
      final fehlend = List<String>.from(data['fehlendeAnhaenge']);
      if (fehlend.isNotEmpty) {
        debugPrint('[Mahnfall] fehlende Anhänge: ${fehlend.join(', ')}');
      }
    }
    debugPrint('[Mahnfall] Heineken-Mail an $empfaenger gesendet (Fall ${fall.id})');
  }

  // ─── Rückweg ─────────────────────────────────────────────────────────────

  /// Nur bei status 'heineken' ohne Ergebnis: Fall löschen (Testmodus-Rückweg).
  static Future<void> zuruecknehmen(Mahnfall fall) async {
    if (fall.status != 'heineken' || fall.heinekenErgebnis != null) {
      throw MahnfallFehler(
        'Nur ein Fall ohne Heineken-Ergebnis kann zurückgenommen werden',
        fallId: fall.id,
      );
    }
    try {
      await MahnfallRepository.delete(fall.id);
    } catch (e) {
      throw MahnfallFehler(kurzeFehlermeldung(e), fallId: fall.id);
    }
  }

  // ─── Ergebnis ────────────────────────────────────────────────────────────

  /// Ergebnis erfassen:
  /// - 'vermittelt'  → status heineken_frist, heineken_frist_bis = heute + 20
  /// - 'uebernommen' → status erledigt, erledigung uebernommen,
  ///                   notiz += '[UEBERNAHME OFFEN]' (keine Buchung, Plan-Kopf)
  /// - 'konkurs'     → je offene Rechnung MahnwesenService.abschreiben(r),
  ///                   status erledigt, erledigung abgeschrieben
  /// - 'betreibung'  → status betreibung, kosten_vorschuss vorbelegt mit
  ///                   betreibungsKostenvorschuss(summe offen), Schuldner
  ///                   vorbelegt aus der Rechnungsadresse (nur wenn leer)
  ///
  /// Erlaubt aus 'heineken' und — nach «vermittelt» ohne Zahlung — aus
  /// 'heineken_frist' (dort ist 'vermittelt' nicht nochmals möglich).
  static Future<Mahnfall> ergebnis(Mahnfall fall, String ergebnis, {DateTime? heute}) async {
    if (!_ergebnisse.contains(ergebnis)) {
      throw MahnfallFehler('Unbekanntes Ergebnis «$ergebnis»', fallId: fall.id);
    }
    final erlaubt = fall.status == 'heineken' ||
        (fall.status == 'heineken_frist' && ergebnis != 'vermittelt');
    if (!erlaubt) {
      throw MahnfallFehler(
        'Ergebnis «$ergebnis» passt nicht zum Stand des Falls',
        fallId: fall.id,
      );
    }
    final datum = heute ?? DateTime.now();
    final tag = MahnfallRepository.dateStr(datum);
    final basis = <String, dynamic>{
      'heineken_ergebnis': ergebnis,
      'heineken_ergebnis_am': tag,
    };

    try {
      switch (ergebnis) {
        case 'vermittelt':
          final bis = DateTime.utc(datum.year, datum.month, datum.day)
              .add(const Duration(days: kVermittlungsFristTage));
          return await MahnfallRepository.update(fall.id, {
            ...basis,
            'status': 'heineken_frist',
            'heineken_frist_bis': MahnfallRepository.dateStr(bis),
          });
        case 'uebernommen':
          return await MahnfallRepository.update(fall.id, {
            ...basis,
            'status': 'erledigt',
            'erledigung': 'uebernommen',
            'erledigt_am': tag,
            'notiz': notizMitUebernahme(fall.notiz),
          });
        case 'konkurs':
          await _offeneAbschreiben(fall, datum);
          return await MahnfallRepository.update(fall.id, {
            ...basis,
            'status': 'erledigt',
            'erledigung': 'abgeschrieben',
            'erledigt_am': tag,
          });
        default: // 'betreibung'
          final rechnungen = await _laden(fall);
          final offen = rechnungen
              .where((r) => r.zahlungsstatus != 'bezahlt' && r.zahlungsstatus != 'abgeschrieben')
              .fold<double>(0, (s, r) => s + r.betragBrutto);
          final felder = <String, dynamic>{
            ...basis,
            'status': 'betreibung',
            'kosten_vorschuss': betreibungsKostenvorschuss(offen),
          };
          if ((fall.schuldnerName ?? '').trim().isEmpty ||
              (fall.schuldnerAdresse ?? '').trim().isEmpty) {
            final s = await _schuldnerLaden(fall);
            if ((fall.schuldnerName ?? '').trim().isEmpty) felder['schuldner_name'] = s.name;
            if ((fall.schuldnerAdresse ?? '').trim().isEmpty && s.adresse != null) {
              felder['schuldner_adresse'] = s.adresse;
            }
          }
          return await MahnfallRepository.update(fall.id, felder);
      }
    } catch (e) {
      if (e is MahnfallFehler) rethrow;
      throw MahnfallFehler(kurzeFehlermeldung(e), fallId: fall.id);
    }
  }

  // ─── Betreibung ──────────────────────────────────────────────────────────

  /// Betreibungsfelder speichern (Datenblatt und Schritte). Nur im Status
  /// 'betreibung'; nur die Felder aus [betreibungsFelderBereinigen].
  static Future<Mahnfall> betreibungSpeichern(
    Mahnfall fall,
    Map<String, dynamic> felder,
  ) async {
    if (fall.status != 'betreibung') {
      throw MahnfallFehler('Der Fall ist nicht in Betreibung', fallId: fall.id);
    }
    final sauber = betreibungsFelderBereinigen(felder);
    if (sauber.isEmpty) return fall;
    try {
      return await MahnfallRepository.update(fall.id, sauber);
    } catch (e) {
      throw MahnfallFehler(kurzeFehlermeldung(e), fallId: fall.id);
    }
  }

  // ─── Abschluss ───────────────────────────────────────────────────────────

  /// Fall abschliessen: 'bezahlt' | 'abgeschrieben' | 'zurueckgezogen'.
  ///
  /// - 'bezahlt' nur, wenn alle Rechnungen des Falls tatsächlich bezahlt
  ///   (oder abgeschrieben) sind — frisch aus der DB ([alleBezahlt]). Sonst
  ///   stünde ein erledigter Fall neben offenen Rechnungen.
  /// - 'abgeschrieben' schreibt die noch offenen Rechnungen über
  ///   `MahnwesenService.abschreiben` ab (wie beim Konkurs) — mit Buchung.
  static Future<Mahnfall> erledigen(Mahnfall fall, String erledigung, {DateTime? heute}) async {
    if (!_erledigungen.contains(erledigung)) {
      throw MahnfallFehler('Unbekannte Erledigung «$erledigung»', fallId: fall.id);
    }
    if (!fall.offen) {
      throw MahnfallFehler('Der Fall ist bereits erledigt', fallId: fall.id);
    }
    final datum = heute ?? DateTime.now();
    try {
      if (erledigung == 'bezahlt') {
        final rechnungen = await _laden(fall);
        if (rechnungen.length != fall.rechnungIds.length ||
            !alleBezahlt(rechnungen.map((r) => r.zahlungsstatus).toList())) {
          throw MahnfallFehler(
            'Noch nicht alle Rechnungen des Falls sind bezahlt — zuerst den '
            'Zahlungseingang erfassen',
            fallId: fall.id,
          );
        }
      } else if (erledigung == 'abgeschrieben') {
        await _offeneAbschreiben(fall, datum);
      }
      return await MahnfallRepository.update(fall.id, {
        'status': 'erledigt',
        'erledigung': erledigung,
        'erledigt_am': MahnfallRepository.dateStr(datum),
      });
    } catch (e) {
      if (e is MahnfallFehler) rethrow;
      throw MahnfallFehler(kurzeFehlermeldung(e), fallId: fall.id);
    }
  }

  /// Markierung [kUebernahmeOffen] entfernen, sobald Daniel verbucht hat.
  static Future<Mahnfall> uebernahmeVerbucht(Mahnfall fall) async {
    try {
      return await MahnfallRepository.update(fall.id, {
        'notiz': notizOhneUebernahme(fall.notiz),
      });
    } catch (e) {
      throw MahnfallFehler(kurzeFehlermeldung(e), fallId: fall.id);
    }
  }

  // ─── Interne Helfer mit DB ───────────────────────────────────────────────

  /// Rechnungen des Falls frisch aus der DB (fehlende werden übersprungen).
  static Future<List<Rechnung>> _laden(Mahnfall fall) async {
    final out = <Rechnung>[];
    for (final id in fall.rechnungIds) {
      final r = await RechnungRepository.getById(id);
      if (r != null) out.add(r);
    }
    return out;
  }

  /// Frisch laden, nur noch offene (weder bezahlt noch abgeschrieben)
  /// abschreiben — eine inzwischen bezahlte Rechnung nie abschreiben.
  static Future<void> _offeneAbschreiben(Mahnfall fall, DateTime datum) async {
    for (final r in await _laden(fall)) {
      if (r.zahlungsstatus == 'bezahlt' || r.zahlungsstatus == 'abgeschrieben') continue;
      await MahnwesenService.abschreiben(r, heute: datum);
    }
  }

  /// Schuldner aus der Rechnungsadresse, sonst aus den Betriebsdaten.
  static Future<({String name, String? adresse})> _schuldnerLaden(Mahnfall fall) async {
    final betrieb = await BetriebRepository.getById(fall.betriebId);
    final raLocal = await BetriebRechnungsadresseRepository.getByBetrieb(fall.betriebId);
    final ra = raLocal == null
        ? null
        : BetriebRechnungsadresseMapper.toDto(raLocal, betriebId: fall.betriebId);
    final name = betrieb?.name ?? '';
    if (ra != null) {
      return schuldnerVorbelegung(
        betriebName: name,
        firma: ra.firma,
        strasse: ra.strasse,
        nr: ra.nr,
        plz: ra.plz,
        ort: ra.ort,
      );
    }
    return schuldnerVorbelegung(
      betriebName: name,
      strasse: betrieb?.strasse,
      nr: betrieb?.nr,
      plz: betrieb?.plz,
      ort: betrieb?.ort,
    );
  }

  // ─── Reine Hilfsfunktionen (TDD, `test/mahnfall_service_test.dart`) ──────

  static String _datum(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  /// Reiner Text der Heineken-Mail. Mahnverlauf direkt aus den
  /// Rechnungsfeldern `erinnerungAm`/`mahnung1Am`/`mahnung2Am` (statt der
  /// `mahnDaten`-Map der Plan-Vorlage). Kein Verzugszins, keine Gebühren.
  static String heinekenMailText({
    required String betrieb,
    required List<Rechnung> rechnungen,
  }) {
    final b = StringBuffer()
      ..writeln('Hallo')
      ..writeln()
      ..writeln('Beim Betrieb $betrieb sind trotz unserer Mahnungen '
          'folgende Rechnungen offen:')
      ..writeln();
    var total = 0.0;
    for (final r in rechnungen) {
      total += r.betragBrutto;
      b.writeln('- Rechnung ${r.rechnungsnummer ?? '(ohne Nummer)'} vom '
          '${_datum(r.rechnungsdatum)}: CHF ${chf(r.betragBrutto)}');
      final verlauf = [
        if (r.erinnerungAm != null) 'Erinnerung ${_datum(r.erinnerungAm!)}',
        if (r.mahnung1Am != null) '1. Mahnung ${_datum(r.mahnung1Am!)}',
        if (r.mahnung2Am != null) 'letzte Mahnung ${_datum(r.mahnung2Am!)}',
      ];
      if (verlauf.isNotEmpty) b.writeln('  gemahnt: ${verlauf.join(', ')}');
    }
    b
      ..writeln()
      ..writeln('Total offen: CHF ${chf(total)}')
      ..writeln()
      ..writeln('Könnt ihr mit dem Betrieb Kontakt aufnehmen? Im Anhang findet '
          'ihr den Kontoauszug des laufenden Jahres und die Rechnungskopien.')
      ..writeln()
      ..writeln('Besten Dank und Gruss')
      ..writeln('Daniel Projer, SBS Projer GmbH');
    return b.toString();
  }

  /// Schuldner für das Betreibungsbegehren: Firma der Rechnungsadresse, sonst
  /// der Betriebsname; Adresse «Strasse Nr, PLZ Ort» ohne leere Teile, `null`
  /// wenn gar nichts bekannt ist.
  static ({String name, String? adresse}) schuldnerVorbelegung({
    required String betriebName,
    String? firma,
    String? strasse,
    String? nr,
    String? plz,
    String? ort,
  }) {
    String join(List<String?> teile) =>
        teile.map((t) => t?.trim() ?? '').where((t) => t.isNotEmpty).join(' ');
    final f = firma?.trim() ?? '';
    final zeilen = [join([strasse, nr]), join([plz, ort])].where((z) => z.isNotEmpty);
    return (
      name: f.isEmpty ? betriebName : f,
      adresse: zeilen.isEmpty ? null : zeilen.join(', '),
    );
  }

  /// Notiz mit der Markierung [kUebernahmeOffen] (nicht doppelt).
  static String notizMitUebernahme(String? notiz) {
    final n = notiz?.trim() ?? '';
    if (n.contains(kUebernahmeOffen)) return n;
    return n.isEmpty ? kUebernahmeOffen : '$n\n$kUebernahmeOffen';
  }

  /// Notiz ohne die Markierung; leer → `null`.
  static String? notizOhneUebernahme(String? notiz) {
    final n = (notiz ?? '').replaceAll(kUebernahmeOffen, '').trim();
    return n.isEmpty ? null : n;
  }

  /// Nur erlaubte Betreibungsfelder; `DateTime` → 'YYYY-MM-DD', leere
  /// Texte → `null`. Unbekannte Schlüssel sind ein Programmierfehler.
  static Map<String, dynamic> betreibungsFelderBereinigen(Map<String, dynamic> felder) {
    final out = <String, dynamic>{};
    for (final e in felder.entries) {
      if (!_betreibungsFelder.contains(e.key)) {
        throw ArgumentError.value(e.key, 'felder', 'kein Betreibungsfeld');
      }
      final v = e.value;
      if (v is DateTime) {
        out[e.key] = MahnfallRepository.dateStr(v);
      } else if (v is String) {
        out[e.key] = v.trim().isEmpty ? null : v.trim();
      } else {
        out[e.key] = v;
      }
    }
    return out;
  }
}

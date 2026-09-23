import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:sbs_projer_app/core/config/mail_config.dart';
import 'package:sbs_projer_app/core/util/anfrage_bloecke.dart';
import 'package:sbs_projer_app/core/util/mahnregeln.dart';
import 'package:sbs_projer_app/core/util/scor_referenz.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/mappers/betrieb_rechnungsadresse_mapper.dart';
import 'package:sbs_projer_app/data/models/betrieb_rechnungsadresse.dart';
import 'package:sbs_projer_app/data/models/mahnschreiben.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_rechnungsadresse_repository.dart';
import 'package:sbs_projer_app/data/repositories/mahnschreiben_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/services/pdf/kontoauszug_pdf_service.dart';
import 'package:sbs_projer_app/services/pdf/mahnschreiben_pdf_service.dart';
import 'package:sbs_projer_app/services/pdf/rechnung_pdf_storage.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Fehler eines Mahnlaufs — mit der Protokoll-Id, WENN das Mahnschreiben
/// beim Auftreten des Fehlers bereits geschrieben ist: Der Screen kann dann
/// direkt «zurücknehmen» anbieten statt nur einen roten Text zu zeigen.
/// `toString()` liefert NUR [meldung] (keine "Instance of ..."-Verpackung) —
/// die Meldung ist bereits über `kurzeFehlermeldung` gekürzt und darf ohne
/// Weiteres auf der Oberfläche landen (Projektregel: kein roher
/// Exception-Text).
class MahnlaufFehler implements Exception {
  final String meldung;
  final String? mahnschreibenId;

  MahnlaufFehler(this.meldung, {this.mahnschreibenId});

  @override
  String toString() => meldung;
}

/// Ergebnis eines Mahnlaufs (`MahnlaufService.erstellen`) — für den
/// aufrufenden Screen: die Protokoll-Id (für ein sofortiges «zurücknehmen»),
/// der tatsächliche Mail-Empfänger (im Testmodus Daniel statt des Kunden) und
/// ein optionales Druck-PDF (Kanal `druck`/`mail_und_druck`).
class MahnlaufErgebnis {
  final String mahnschreibenId;
  final String? mailAn;
  final Uint8List? druckPdf;

  /// Anhänge, die `send-rechnung-mail` NICHT anhängen konnte, aber nicht
  /// PFLICHT waren (z. B. eine fehlende Rechnungskopie) — die Mail ging
  /// trotzdem raus. Der Screen zeigt das an; das Mahnschreiben selbst ist
  /// immer PFLICHT und würde bei Fehlen die Mail verhindern (siehe
  /// `zusatzPdfs`-Aufruf unten).
  final List<String> fehlendeAnhaenge;

  MahnlaufErgebnis({
    required this.mahnschreibenId,
    this.mailAn,
    this.druckPdf,
    this.fehlendeAnhaenge = const [],
  });
}

/// Ergebnis von `MahnlaufService.zuruecknehmen`: welche Rechnungen
/// tatsächlich zurückgesetzt wurden und welche NICHT — mit Grund. Eine
/// übersprungene Rechnung ist kein Fehler des Aufrufs, sondern ein Schutz
/// (siehe [MahnlaufService.darfZuruecksetzen]).
class MahnlaufZuruecknehmenErgebnis {
  final List<String> zurueckgesetzt;
  final List<({String rechnungId, String grund})> uebersprungen;

  MahnlaufZuruecknehmenErgebnis({
    required this.zurueckgesetzt,
    required this.uebersprungen,
  });
}

/// Ob eine Rechnung beim Zurücknehmen zurückgesetzt werden darf, plus Grund
/// bei Ablehnung.
typedef Zuruecksetzenpruefung = ({bool erlaubt, String? grund});

/// Erstellt und storniert Sammel-Mahnschreiben (v0.134.0, Spec
/// docs/superpowers/specs/2026-09-23-mahnwesen-design.md).
///
/// WARUM ein Protokoll VOR dem Mailversand geschrieben wird (Schritt 7 vor
/// Schritt 9): Bricht der Mailversand ab, nachdem die Rechnungen schon auf
/// die neue Stufe gesetzt sind, braucht der Screen eine Möglichkeit, das
/// rückgängig zu machen — ohne Protokoll wüsste [zuruecknehmen] nicht, was
/// der Zustand VORHER war.
///
/// WARUM zusätzlich ein NACHHER-Zustand protokolliert wird (Migration 202,
/// Review 23.09.2026): Ohne ihn könnte [zuruecknehmen] eine Rechnung, die der
/// Kunde inzwischen bezahlt hat oder die ein SPÄTERER Mahnlauf weitergestuft
/// hat, stillschweigend auf den ALTEN Stand zurückwerfen — eine bezahlte
/// Rechnung würde dadurch wieder als offen erscheinen. Oberstes Ziel des
/// Mahnwesens: NIE eine bezahlte Rechnung mahnen (Daniel 23.09.2026).
class MahnlaufService {
  static const _uuid = Uuid();

  /// Erstellt einen Sammel-Mahnlauf für [posten] eines Betriebs.
  ///
  /// [offeneDesBetriebs] entscheidet NUR, ob der Kontoauszug beigelegt wird
  /// (mehr als eine offene Rechnung). Der INHALT des Kontoauszugs kommt aus
  /// [rechnungenDesJahres] — alle Rechnungen des Betriebs mit Rechnungsdatum
  /// im laufenden Jahr, INKLUSIVE bereits bezahlter: Ein Kontoauszug ohne die
  /// Zahlungen wäre keiner, sondern nur eine zweite Mahnliste.
  static Future<MahnlaufErgebnis> erstellen({
    required BetriebLocal betrieb,
    required List<MahnPosten> posten,
    required List<Rechnung> offeneDesBetriebs,
    required List<Rechnung> rechnungenDesJahres,
    DateTime? heute,
  }) async {
    final betriebId = betrieb.serverId ?? '';
    final datum = heute ?? DateTime.now();
    final frist = mahnFrist(datum);
    final stufen = posten.map((p) => p.stufe).toList();
    final stufe = hoechsteStufe(stufen);
    // `mahnwesenScharf` bleibt bewusst false, bis Daniel den echten Versand
    // freigibt (CLAUDE.md) — bis dahin gehen alle Mails an ihn, das Papier
    // trägt das MUSTER-Wasserzeichen.
    final muster = !MailConfig.istScharf('mahnwesen');
    final mahnschreibenId = _uuid.v4();
    // Sobald das Protokoll steht, bekommt jeder Fehler danach die Id mit —
    // der Screen kann dann «zurücknehmen» anbieten statt nur zu scheitern.
    var protokolliert = false;

    try {
      // Fehlende QR-Referenz nachtragen (Review 23.09.2026): Ohne Referenz
      // kann der camt-Abgleich eine Zahlung nicht eindeutig einer gemahnten
      // Rechnung zuordnen. Nur mit Rechnungsnummer möglich; die Kollisions-
      // behandlung (qr_referenz ist UNIQUE) teilt sich mit
      // `RechnungRepository.create` (`mitQrReferenzRetry`).
      final korrigiert = await _qrReferenzenSicherstellen(posten);
      final postenKorrigiert = posten
          .map((p) => (
                rechnung: korrigiert[p.rechnung.id] ?? p.rechnung,
                stufe: p.stufe,
              ))
          .toList();
      final jahresKorrigiert = rechnungenDesJahres
          .map((r) => korrigiert[r.id] ?? r)
          .toList();

      // Rechnungsadresse des Betriebs — dieselbe Quelle wie beim bisherigen
      // `MahnwesenService.eskalieren`. Ein Override pro Rechnung
      // (`Rechnung.rechnungsadresse`) gibt es beim Sammelschreiben bewusst
      // nicht: Ein Brief geht an EINE Adresse für den ganzen Betrieb.
      BetriebRechnungsadresse? ra;
      final raLocal = await BetriebRechnungsadresseRepository.getByBetrieb(betriebId);
      if (raLocal != null) {
        ra = BetriebRechnungsadresseMapper.toDto(raLocal, betriebId: betriebId);
      }
      final raEmail = (ra?.email ?? '').trim();
      final betriebEmail = (betrieb.email ?? '').trim();
      final mailadresse = raEmail.isNotEmpty
          ? raEmail
          : (betriebEmail.isNotEmpty ? betriebEmail : null);

      final beilegen = offeneDesBetriebs.length > 1;
      final hatMail = mailadresse != null;
      // Letzte Mahnung wird IMMER zusätzlich gedruckt — Beweismittel für eine
      // allfällige Betreibung, unabhängig davon, ob die Mail rausging.
      final druckNoetig = !hatMail || stufe == MahnStufe.letzte;
      final kanal = hatMail ? (druckNoetig ? 'mail_und_druck' : 'mail') : 'druck';

      // Update- und Vorher-Stand je Rechnung EINMAL berechnen — dieselbe Map
      // geht ins Protokoll (`nachher`) UND in die tatsächlichen Updates;
      // beide dürfen niemals auseinanderlaufen, sonst würde [zuruecknehmen]
      // später gegen einen falschen Nachher-Stand prüfen.
      final updates = {
        for (final p in postenKorrigiert) p.rechnung.id: updateFuerStufe(p.stufe, datum),
      };
      final vorherMap = {
        for (final p in postenKorrigiert) p.rechnung.id: vorherStand(p.rechnung),
      };
      final rechnungIds = postenKorrigiert.map((p) => p.rechnung.id).toList();

      String? hauptdateiPfad;
      String? tatsaechlicherEmpfaenger;
      Uint8List? druckPdf;
      var fehlendeAnhaenge = const <String>[];

      if (hatMail) {
        // Mahnschreiben OHNE Kontoauszug-Seiten — der Auszug geht bei Bedarf
        // als eigener Anhang mit (kein zweiter, summierter Zahlteil neben
        // den Zahlteilen je Rechnung, siehe Doc-Kommentar an
        // `MahnschreibenPdfService.generate`).
        final schreibenBytes = await MahnschreibenPdfService.generate(
          betrieb: betrieb,
          rechnungsadresse: ra,
          posten: postenKorrigiert,
          datum: datum,
          frist: frist,
          muster: muster,
        );
        await RechnungPdfStorage.uploadMahnlaufPdf(
          mahnschreibenId,
          'mahnschreiben.pdf',
          schreibenBytes,
        );
        hauptdateiPfad =
            '${SupabaseService.dataUserId}/mahnungen/$mahnschreibenId/mahnschreiben.pdf';

        Uint8List? kontoauszugBytes;
        if (beilegen) {
          // muster/mitZahlteil durchgereicht (Review 23.09.2026, Punkt 3):
          // KEIN eigener Zahlteil in der Mail-Beilage — das Mahnschreiben hat
          // bereits einen Zahlteil PRO RECHNUNG (Doppelzahlungsgefahr sonst).
          kontoauszugBytes = await KontoauszugPdfService.generate(
            betrieb: betrieb,
            rechnungen: jahresKorrigiert,
            rechnungsadresse: ra,
            jahr: datum.year,
            muster: muster,
            mitZahlteil: false,
          );
          await RechnungPdfStorage.uploadMahnlaufPdf(
            mahnschreibenId,
            'kontoauszug.pdf',
            kontoauszugBytes,
          );
        }

        if (druckNoetig) {
          druckPdf = await MahnschreibenPdfService.generate(
            betrieb: betrieb,
            rechnungsadresse: ra,
            posten: postenKorrigiert,
            datum: datum,
            frist: frist,
            muster: muster,
            kontoauszugRechnungen: beilegen ? jahresKorrigiert : null,
            kontoauszugJahr: datum.year,
          );
          await RechnungPdfStorage.uploadMahnlaufPdf(
            mahnschreibenId,
            'druck.pdf',
            druckPdf,
          );
        }

        tatsaechlicherEmpfaenger = mailadresse;
        final userId = SupabaseService.dataUserId;
        final empfaenger = MailConfig.empfaenger(mailadresse, bereich: 'mahnwesen');
        var subject = '${stufe.titel} — ${betrieb.name}';
        if (muster) subject = 'TEST an: $mailadresse — $subject';

        // Protokoll VOR dem Mailversand — siehe Klassenkommentar.
        await MahnschreibenRepository.insert({
          'id': mahnschreibenId,
          'user_id': userId,
          'betrieb_id': betriebId,
          'stufe': stufe.wert,
          'rechnung_ids': rechnungIds,
          'kanal': kanal,
          'empfaenger': mailadresse,
          'test': muster,
          'frist_bis': _dateStr(frist),
          'pdf_pfad': hauptdateiPfad,
          'vorher': vorherMap,
          'nachher': updates,
        });
        protokolliert = true;

        for (final p in postenKorrigiert) {
          await RechnungRepository.update(p.rechnung.id, updates[p.rechnung.id]!);
        }

        final zusatzPdfs = <Map<String, dynamic>>[
          {
            'pfad': '$userId/mahnungen/$mahnschreibenId/mahnschreiben.pdf',
            'dateiname': 'Mahnschreiben.pdf',
            'pflicht': true,
          },
          if (kontoauszugBytes != null)
            {
              'pfad': '$userId/mahnungen/$mahnschreibenId/kontoauszug.pdf',
              'dateiname': 'Kontoauszug.pdf',
              'pflicht': false,
            },
          for (final p in postenKorrigiert)
            {
              'pfad': '$userId/${p.rechnung.id}/rechnung.pdf',
              'dateiname': 'Rechnung_${p.rechnung.rechnungsnummer ?? ''}.pdf',
              'pflicht': false,
            },
        ];

        final res = await SupabaseService.client.functions.invoke(
          'send-rechnung-mail',
          body: {
            'to': empfaenger,
            'subject': subject,
            'bodyText': _mailText(stufe, betrieb.name),
            'userId': userId,
            'zusatzPdfs': zusatzPdfs,
          },
        );
        final data = res.data;
        if (data is Map && data['fehlendeAnhaenge'] is List) {
          fehlendeAnhaenge = List<String>.from(data['fehlendeAnhaenge']);
        }
        debugPrint('[Mahnlauf] ${stufe.titel} Mail an $empfaenger gesendet');
      } else {
        // Reine Druck-Variante: keine Mailadresse bekannt.
        druckPdf = await MahnschreibenPdfService.generate(
          betrieb: betrieb,
          rechnungsadresse: ra,
          posten: postenKorrigiert,
          datum: datum,
          frist: frist,
          muster: muster,
          kontoauszugRechnungen: beilegen ? jahresKorrigiert : null,
          kontoauszugJahr: datum.year,
        );
        await RechnungPdfStorage.uploadMahnlaufPdf(mahnschreibenId, 'druck.pdf', druckPdf);
        hauptdateiPfad =
            '${SupabaseService.dataUserId}/mahnungen/$mahnschreibenId/druck.pdf';

        await MahnschreibenRepository.insert({
          'id': mahnschreibenId,
          'user_id': SupabaseService.dataUserId,
          'betrieb_id': betriebId,
          'stufe': stufe.wert,
          'rechnung_ids': rechnungIds,
          'kanal': kanal,
          'empfaenger': null,
          'test': muster,
          'frist_bis': _dateStr(frist),
          'pdf_pfad': hauptdateiPfad,
          'vorher': vorherMap,
          'nachher': updates,
        });
        protokolliert = true;

        for (final p in postenKorrigiert) {
          await RechnungRepository.update(p.rechnung.id, updates[p.rechnung.id]!);
        }
      }

      return MahnlaufErgebnis(
        mahnschreibenId: mahnschreibenId,
        mailAn: tatsaechlicherEmpfaenger,
        druckPdf: druckPdf,
        fehlendeAnhaenge: fehlendeAnhaenge,
      );
    } catch (e) {
      // Kein roher Exception-Text auf der Oberfläche (Projektregel
      // `kurzeFehlermeldung`). Steht das Protokoll schon, bekommt der Fehler
      // die Id mit — der Screen bietet dann «zurücknehmen» an, statt nur zu
      // scheitern (die Mahnstufen stehen in dem Fall bereits).
      throw MahnlaufFehler(
        protokolliert
            ? '${kurzeFehlermeldung(e)} — die Mahnung ist protokolliert und '
                'kann im Rechnungsdetail zurückgenommen werden.'
            : kurzeFehlermeldung(e),
        mahnschreibenId: protokolliert ? mahnschreibenId : null,
      );
    }
  }

  /// Macht ein Mahnschreiben rückgängig — aber NUR die Rechnungen, die sich
  /// seit dem Schreiben nicht weiterbewegt haben ([darfZuruecksetzen]). Wurde
  /// [m] bereits zurückgenommen, bricht der Aufruf sofort ab (kein zweites
  /// Zurücksetzen auf denselben Vorher-Stand).
  static Future<MahnlaufZuruecknehmenErgebnis> zuruecknehmen(Mahnschreiben m) async {
    if (m.zurueckgenommen) {
      throw MahnlaufFehler(
        'Dieses Mahnschreiben wurde bereits zurückgenommen.',
        mahnschreibenId: m.id,
      );
    }

    final zurueckgesetzt = <String>[];
    final uebersprungen = <({String rechnungId, String grund})>[];

    for (final id in m.rechnungIds) {
      // Frisch aus der DB laden — der Zustand in [m] ist der von der
      // ERSTELLUNG, nicht zwingend der aktuelle (der ganze Zweck der Prüfung).
      final aktuelleRechnung = await RechnungRepository.getById(id);
      if (aktuelleRechnung == null) {
        uebersprungen.add((rechnungId: id, grund: 'Rechnung nicht gefunden'));
        continue;
      }

      final nachherRoh = m.nachher[id];
      final pruefung = darfZuruecksetzen(
        _vergleichsStand(aktuelleRechnung),
        nachherRoh is Map ? Map<String, dynamic>.from(nachherRoh) : null,
      );
      if (!pruefung.erlaubt) {
        uebersprungen.add((rechnungId: id, grund: pruefung.grund ?? 'geändert'));
        continue;
      }

      final vorher = m.vorher[id];
      if (vorher is! Map) {
        uebersprungen.add((rechnungId: id, grund: 'kein gespeicherter Vorher-Zustand'));
        continue;
      }
      await RechnungRepository.update(id, Map<String, dynamic>.from(vorher));
      zurueckgesetzt.add(id);
    }

    await MahnschreibenRepository.markiereZurueckgenommen(m.id);
    return MahnlaufZuruecknehmenErgebnis(
      zurueckgesetzt: zurueckgesetzt,
      uebersprungen: uebersprungen,
    );
  }

  // ─── Reine Hilfsfunktionen (TDD, `test/mahnlauf_service_test.dart`) ───

  /// Felder einer Rechnung VOR dem Schreiben — Grundlage für [zuruecknehmen].
  /// Genau die sieben Felder, die [updateFuerStufe] je verändern kann.
  static Map<String, dynamic> vorherStand(Rechnung r) => {
        'zahlungsstatus': r.zahlungsstatus,
        'mahnung_stufe': r.mahnungStufe,
        'letzte_mahnung_am': _dateStrOrNull(r.letzteMahnungAm),
        'erinnerung_am': _dateStrOrNull(r.erinnerungAm),
        'mahnung_1_am': _dateStrOrNull(r.mahnung1Am),
        'mahnung_2_am': _dateStrOrNull(r.mahnung2Am),
        'mahn_frist_bis': _dateStrOrNull(r.mahnFristBis),
      };

  /// Update-Felder für eine Rechnung, die [stufe] am [datum] bekommt.
  /// Setzt NUR das zur Stufe gehörende Datumsfeld — die übrigen Datumsfelder
  /// bleiben unangetastet (kein Eintrag in der Map, kein Überschreiben mit
  /// null). Dieselbe Map wird sowohl für das Update als auch — unverändert —
  /// als `nachher`-Protokollzustand verwendet (siehe `erstellen`).
  static Map<String, dynamic> updateFuerStufe(MahnStufe stufe, DateTime datum) {
    final datumStr = _dateStr(datum);
    final map = <String, dynamic>{
      'zahlungsstatus': stufe.status,
      'mahnung_stufe': stufe.wert,
      'letzte_mahnung_am': datumStr,
      'mahn_frist_bis': _dateStr(mahnFrist(datum)),
    };
    switch (stufe) {
      case MahnStufe.erinnerung:
        map['erinnerung_am'] = datumStr;
      case MahnStufe.mahnung1:
        map['mahnung_1_am'] = datumStr;
      case MahnStufe.letzte:
        map['mahnung_2_am'] = datumStr;
    }
    return map;
  }

  /// Live-Stand einer Rechnung, reduziert auf die drei Felder, die
  /// [darfZuruecksetzen] mit dem protokollierten `nachher`-Zustand
  /// vergleicht — bewusst NICHT alle sieben Felder aus [vorherStand]: Ein
  /// abweichendes `mahn_frist_bis` allein (z. B. durch eine spätere manuelle
  /// Korrektur) ist kein Zahlungs- oder Stufenwechsel und soll das
  /// Zurücknehmen nicht blockieren.
  static Map<String, dynamic> _vergleichsStand(Rechnung r) => {
        'zahlungsstatus': r.zahlungsstatus,
        'mahnung_stufe': r.mahnungStufe,
        'letzte_mahnung_am': _dateStrOrNull(r.letzteMahnungAm),
      };

  /// Darf eine Rechnung beim Zurücknehmen auf ihren VORHER-Stand
  /// zurückgesetzt werden? [aktuell] ist der LIVE-Stand ([_vergleichsStand]),
  /// [nachher] der beim Erstellen protokollierte NACHHER-Stand
  /// ([updateFuerStufe], Migration 202) — `null` bei Schreiben von vor der
  /// Migration (kein Vergleichswert, also nie automatisch zurücksetzen).
  ///
  /// Nur bei EXAKTER Übereinstimmung von `zahlungsstatus`, `mahnung_stufe`
  /// und `letzte_mahnung_am` hat sich die Rechnung seit dem Schreiben nicht
  /// weiterbewegt — jede Abweichung heisst: seither ist etwas passiert
  /// (Zahlung, weitere Mahnung, manuelle Änderung), und das Zurücksetzen
  /// würde das überschreiben. Rein, ohne I/O — testbar ohne DB.
  static Zuruecksetzenpruefung darfZuruecksetzen(
    Map<String, dynamic> aktuell,
    Map<String, dynamic>? nachher,
  ) {
    if (nachher == null) {
      return (
        erlaubt: false,
        grund: 'kein Vergleichszustand (altes Mahnschreiben ohne Protokoll)',
      );
    }
    // Bezahlt/abgeschrieben geht IMMER vor — auch wenn zusätzlich die Stufe
    // abweicht (z. B. bezahlt NACH der letzten Mahnung): Das ist der Fall,
    // den es um jeden Preis zu vermeiden gilt.
    if (aktuell['zahlungsstatus'] == 'bezahlt' ||
        aktuell['zahlungsstatus'] == 'abgeschrieben') {
      return (erlaubt: false, grund: 'inzwischen bezahlt');
    }
    // Stufe vor dem generischen Status-Vergleich: Eine Eskalation ändert
    // BEIDES (z. B. 'erinnert' → 'mahnung_1'), soll aber als "weiter gemahnt"
    // erkannt werden, nicht als unspezifisches "geändert".
    if (aktuell['mahnung_stufe'] != nachher['mahnung_stufe']) {
      return (erlaubt: false, grund: 'seither weiter gemahnt');
    }
    if (aktuell['zahlungsstatus'] != nachher['zahlungsstatus'] ||
        aktuell['letzte_mahnung_am'] != nachher['letzte_mahnung_am']) {
      return (erlaubt: false, grund: 'geändert');
    }
    return (erlaubt: true, grund: null);
  }

  static String _dateStr(DateTime d) => d.toIso8601String().split('T').first;
  static String? _dateStrOrNull(DateTime? d) => d == null ? null : _dateStr(d);

  static String _mailText(MahnStufe stufe, String betriebName) =>
      'Guten Tag\n\n'
      'Im Anhang erhalten Sie unser Schreiben «${stufe.titel}» betreffend '
      '$betriebName sowie die zugehörigen Rechnungskopien.\n\n'
      'Freundliche Grüsse\nSBS Projer GmbH';

  /// Trägt für Posten ohne `qrReferenz` eine SCOR-Referenz aus der
  /// Rechnungsnummer nach (DB + Rückgabe) — sonst kann der camt-Abgleich die
  /// Zahlung nicht eindeutig zuordnen. Nur möglich, wenn eine Rechnungsnummer
  /// vorliegt; sonst bleibt die Rechnung ohne Referenz (unverändert).
  ///
  /// Kollisionsbehandlung (`qr_referenz` ist UNIQUE, Migration 104) über
  /// [mitQrReferenzRetry] — dieselbe Logik wie beim Anlegen einer Rechnung
  /// (`RechnungRepository.create`), nicht zweimal geschrieben.
  static Future<Map<String, Rechnung>> _qrReferenzenSicherstellen(
    List<MahnPosten> posten,
  ) async {
    final korrigiert = <String, Rechnung>{};
    for (final p in posten) {
      final r = p.rechnung;
      if (r.qrReferenz != null && r.qrReferenz!.isNotEmpty) continue;
      if (qrReferenzAusNummer(r.rechnungstyp, r.rechnungsnummer) == null) {
        continue; // kein Kundentyp oder keine Rechnungsnummer
      }
      final ref = await mitQrReferenzRetry<String?>(
        rechnungstyp: r.rechnungstyp,
        rechnungsnummer: r.rechnungsnummer,
        aktion: (kandidat) async {
          await RechnungRepository.update(r.id, {'qr_referenz': kandidat});
          return kandidat;
        },
      );
      if (ref != null) korrigiert[r.id] = _mitQrReferenz(r, ref);
    }
    return korrigiert;
  }

  static Rechnung _mitQrReferenz(Rechnung r, String ref) => Rechnung(
        id: r.id,
        userId: r.userId,
        rechnungsnummer: r.rechnungsnummer,
        rechnungstyp: r.rechnungstyp,
        betriebId: r.betriebId,
        heinekenPoNummer: r.heinekenPoNummer,
        heinekenMonat: r.heinekenMonat,
        rechnungsdatum: r.rechnungsdatum,
        faelligkeitsdatum: r.faelligkeitsdatum,
        betragNetto: r.betragNetto,
        mwstBetrag: r.mwstBetrag,
        betragBrutto: r.betragBrutto,
        zahlungsstatus: r.zahlungsstatus,
        versandart: r.versandart,
        versendetAm: r.versendetAm,
        uebergebenAm: r.uebergebenAm,
        zahlungEingegangenAm: r.zahlungEingegangenAm,
        zahlungBetrag: r.zahlungBetrag,
        mahnungStufe: r.mahnungStufe,
        letzteMahnungAm: r.letzteMahnungAm,
        erinnerungAm: r.erinnerungAm,
        mahnung1Am: r.mahnung1Am,
        mahnung2Am: r.mahnung2Am,
        mahnFristBis: r.mahnFristBis,
        pdfUrl: r.pdfUrl,
        qrReferenz: ref,
        rechnungsadresse: r.rechnungsadresse,
        notizen: r.notizen,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      );
}

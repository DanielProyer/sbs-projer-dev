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

/// Erstellt und storniert Sammel-Mahnschreiben (v0.134.0, Spec
/// docs/superpowers/specs/2026-09-23-mahnwesen-design.md).
///
/// WARUM ein Protokoll VOR dem Mailversand geschrieben wird (Schritt 7 vor
/// Schritt 9): Bricht der Mailversand ab, nachdem die Rechnungen schon auf
/// die neue Stufe gesetzt sind, braucht der Screen eine Möglichkeit, das
/// rückgängig zu machen — ohne Protokoll wüsste [zuruecknehmen] nicht, was
/// der Zustand VORHER war.
class MahnlaufService {
  static const _uuid = Uuid();

  /// Erstellt einen Sammel-Mahnlauf für [posten] eines Betriebs.
  ///
  /// [offeneDesBetriebs] dient zweifach: Ist mehr als eine Rechnung offen,
  /// wird der Kontoauszug beigelegt — und genau diese Liste (nicht nur
  /// [posten]) füllt ihn, damit er den vollständigen Kontostand zeigt statt
  /// nur der gerade gemahnten Posten.
  static Future<MahnlaufErgebnis> erstellen({
    required BetriebLocal betrieb,
    required List<MahnPosten> posten,
    required List<Rechnung> offeneDesBetriebs,
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

    // Fehlende QR-Referenz nachtragen (Vorgabe Review 23.09.2026): Ohne
    // Referenz kann der camt-Abgleich eine Zahlung nicht eindeutig einer
    // gemahnten Rechnung zuordnen. Nur mit Rechnungsnummer möglich — sonst
    // bleibt der Zahlteil ohne Referenz (bestehendes Verhalten).
    final korrigiert = await _qrReferenzenSicherstellen(posten);
    final postenKorrigiert = posten
        .map((p) => (
              rechnung: korrigiert[p.rechnung.id] ?? p.rechnung,
              stufe: p.stufe,
            ))
        .toList();
    final offeneKorrigiert = offeneDesBetriebs
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
    final mahnschreibenId = _uuid.v4();
    final hatMail = mailadresse != null;
    // Letzte Mahnung wird IMMER zusätzlich gedruckt — Beweismittel für eine
    // allfällige Betreibung, unabhängig davon, ob die Mail rausging.
    final druckNoetig = !hatMail || stufe == MahnStufe.letzte;
    final kanal = hatMail
        ? (druckNoetig ? 'mail_und_druck' : 'mail')
        : 'druck';

    String? hauptdateiPfad;
    String? tatsaechlicherEmpfaenger;
    Uint8List? druckPdf;
    var fehlendeAnhaenge = const <String>[];

    if (hatMail) {
      // Mahnschreiben OHNE Kontoauszug-Seiten — der Auszug geht bei Bedarf
      // als eigener Anhang mit (kein zweiter, summierter Zahlteil neben den
      // Zahlteilen je Rechnung, siehe Doc-Kommentar an
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
        kontoauszugBytes = await KontoauszugPdfService.generate(
          betrieb: betrieb,
          rechnungen: offeneKorrigiert,
          rechnungsadresse: ra,
          jahr: datum.year,
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
          kontoauszugRechnungen: beilegen ? offeneKorrigiert : null,
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
        'rechnung_ids': postenKorrigiert.map((p) => p.rechnung.id).toList(),
        'kanal': kanal,
        'empfaenger': mailadresse,
        'test': muster,
        'frist_bis': _dateStr(frist),
        'pdf_pfad': hauptdateiPfad,
        'vorher': {
          for (final p in postenKorrigiert) p.rechnung.id: vorherStand(p.rechnung),
        },
      });

      for (final p in postenKorrigiert) {
        await RechnungRepository.update(p.rechnung.id, updateFuerStufe(p.stufe, datum));
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

      try {
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
      } catch (e) {
        // Die Stufen stehen bereits (Schritt 8 lief schon durch) — der
        // Screen bietet «zurücknehmen» an. Kein roher Exception-Text auf der
        // Oberfläche (Projektregel `kurzeFehlermeldung`).
        throw Exception(
          'Mahn-Mail fehlgeschlagen (${kurzeFehlermeldung(e)}) — die '
          'Mahnstufen sind bereits gesetzt, das Schreiben kann '
          'zurückgenommen werden.',
        );
      }
    } else {
      // Reine Druck-Variante: keine Mailadresse bekannt.
      druckPdf = await MahnschreibenPdfService.generate(
        betrieb: betrieb,
        rechnungsadresse: ra,
        posten: postenKorrigiert,
        datum: datum,
        frist: frist,
        muster: muster,
        kontoauszugRechnungen: beilegen ? offeneKorrigiert : null,
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
        'rechnung_ids': postenKorrigiert.map((p) => p.rechnung.id).toList(),
        'kanal': kanal,
        'empfaenger': null,
        'test': muster,
        'frist_bis': _dateStr(frist),
        'pdf_pfad': hauptdateiPfad,
        'vorher': {
          for (final p in postenKorrigiert) p.rechnung.id: vorherStand(p.rechnung),
        },
      });

      for (final p in postenKorrigiert) {
        await RechnungRepository.update(p.rechnung.id, updateFuerStufe(p.stufe, datum));
      }
    }

    return MahnlaufErgebnis(
      mahnschreibenId: mahnschreibenId,
      mailAn: tatsaechlicherEmpfaenger,
      druckPdf: druckPdf,
      fehlendeAnhaenge: fehlendeAnhaenge,
    );
  }

  /// Macht ein Mahnschreiben rückgängig: jede betroffene Rechnung bekommt
  /// ihren Zustand VOR dem Schreiben zurück ([vorherStand], im Protokoll
  /// gespeichert). Die PDFs im Storage bleiben liegen — sie sind Belege, kein
  /// aktueller Zustand.
  static Future<void> zuruecknehmen(Mahnschreiben m) async {
    for (final id in m.rechnungIds) {
      final vorher = m.vorher[id];
      if (vorher is Map) {
        await RechnungRepository.update(id, Map<String, dynamic>.from(vorher));
      }
    }
    await MahnschreibenRepository.markiereZurueckgenommen(m.id);
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
  /// null).
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
  static Future<Map<String, Rechnung>> _qrReferenzenSicherstellen(
    List<MahnPosten> posten,
  ) async {
    final korrigiert = <String, Rechnung>{};
    for (final p in posten) {
      final r = p.rechnung;
      if (r.qrReferenz != null && r.qrReferenz!.isNotEmpty) continue;
      final ref = qrReferenzAusNummer(r.rechnungstyp, r.rechnungsnummer);
      if (ref == null) continue;
      await RechnungRepository.update(r.id, {'qr_referenz': ref});
      korrigiert[r.id] = _mitQrReferenz(r, ref);
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

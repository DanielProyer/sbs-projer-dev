import 'package:flutter/foundation.dart';
import 'package:sbs_projer_app/core/config/mail_config.dart';
import 'package:sbs_projer_app/data/models/betrieb_rechnungsadresse.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_rechnungsadresse_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/services/buchhaltung/abschreibung_service.dart';
import 'package:sbs_projer_app/services/pdf/mahnung_pdf_service.dart';
import 'package:sbs_projer_app/services/pdf/rechnung_pdf_storage.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class MahnwesenService {
  static String statusFuerStufe(int stufe) {
    switch (stufe) {
      case 0:
        return 'erinnert';
      case 1:
        return 'mahnung_1';
      case 2:
        return 'mahnung_2';
      default:
        return 'abgeschrieben';
    }
  }

  static String titelFuerStufe(int stufe) {
    switch (stufe) {
      case 0:
        return 'Zahlungserinnerung';
      case 1:
        return '1. Mahnung';
      case 2:
        return '2. Mahnung';
      default:
        return 'Mahnung';
    }
  }

  static Future<void> eskalieren({
    required Rechnung rechnung,
    required int mahnStufe,
    bool mailSenden = false,
  }) async {
    final betrieb = await BetriebRepository.getByServerId(
        rechnung.betriebId ?? '');
    if (betrieb == null) throw Exception('Betrieb nicht gefunden');

    BetriebRechnungsadresse? ra;
    final raLocal = await BetriebRechnungsadresseRepository.getByBetrieb(
        rechnung.betriebId ?? '');
    if (raLocal != null) {
      ra = BetriebRechnungsadresse(
        id: raLocal.serverId ?? '',
        userId: raLocal.userId,
        betriebId: rechnung.betriebId ?? '',
        firma: raLocal.firma,
        vorname: raLocal.vorname,
        nachname: raLocal.nachname,
        strasse: raLocal.strasse,
        nr: raLocal.nr,
        plz: raLocal.plz,
        ort: raLocal.ort,
        email: raLocal.email,
        notizen: raLocal.notizen,
      );
    }

    // 1. PDF generieren
    final pdfBytes = await MahnungPdfService.generate(
      rechnung: rechnung,
      betrieb: betrieb,
      rechnungsadresse: ra,
      mahnStufe: mahnStufe,
    );

    // 2. PDF hochladen
    await RechnungPdfStorage.uploadMahnungPdf(rechnung.id, mahnStufe, pdfBytes);

    // 3. DB-Update
    final datumStr = DateTime.now().toIso8601String().split('T').first;
    final updates = <String, dynamic>{
      'zahlungsstatus': statusFuerStufe(mahnStufe),
      'mahnung_stufe': mahnStufe,
      'letzte_mahnung_am': datumStr,
    };
    switch (mahnStufe) {
      case 0:
        updates['erinnerung_am'] = datumStr;
      case 1:
        updates['mahnung_1_am'] = datumStr;
      case 2:
        updates['mahnung_2_am'] = datumStr;
    }
    await RechnungRepository.update(rechnung.id, updates);

    // 4. Optional: Mail senden
    if (mailSenden) {
      final email = ra?.email;
      final empfaenger = MailConfig.empfaenger(email, bereich: 'mahnwesen');
      final titel = titelFuerStufe(mahnStufe);
      final rgNr = rechnung.rechnungsnummer ?? '';

      final subject = '$titel - Rechnung $rgNr';
      final bodyText = _mailText(mahnStufe, rgNr);

      await SupabaseService.client.functions.invoke('send-rechnung-mail',
          body: {
            'to': empfaenger,
            'subject': subject,
            'bodyText': bodyText,
            'rechnungId': rechnung.id,
            'pdfPath': 'mahnung_$mahnStufe.pdf',
            'userId': SupabaseService.dataUserId,
          });

      debugPrint('[Mahnwesen] $titel Mail an $empfaenger gesendet');
    }

    debugPrint('[Mahnwesen] ${titelFuerStufe(mahnStufe)} für ${rechnung.rechnungsnummer} erstellt');
  }

  /// Rechnung abschreiben + Debitorenverlust korrekt buchen (netto + MWST-Rückholung).
  static Future<void> abschreiben(Rechnung rechnung) async {
    await RechnungRepository.update(rechnung.id, {'zahlungsstatus': 'abgeschrieben'});
    await AbschreibungService.abschreiben(
      brutto: (rechnung.betragBrutto * 20).roundToDouble() / 20,
      datum: rechnung.rechnungsdatum,
      beschreibung:
          'Debitorenverlust ${rechnung.rechnungsnummer ?? rechnung.id.substring(0, 8)} (abgeschrieben)',
      belegnummer: rechnung.rechnungsnummer,
      belegId: rechnung.id,
    );
    debugPrint('[Mahnwesen] Rechnung ${rechnung.rechnungsnummer} abgeschrieben (mit MWST-Rückholung)');
  }

  static String _mailText(int stufe, String rgNr) {
    switch (stufe) {
      case 0:
        return 'Guten Tag\n\n'
            'Bei der Überprüfung unserer Buchhaltung haben wir festgestellt, '
            'dass die Rechnung $rgNr noch nicht beglichen wurde.\n\n'
            'Möglicherweise haben Sie die Zahlung bereits veranlasst - '
            'in diesem Fall betrachten Sie dieses Schreiben bitte als gegenstandslos.\n\n'
            'Wir bitten Sie, den offenen Betrag innert 20 Tagen zu überweisen.\n\n'
            'Freundliche Grüsse\nSBS Projer GmbH';
      case 1:
        return 'Guten Tag\n\n'
            'Trotz unserer Zahlungserinnerung ist der Betrag der Rechnung $rgNr '
            'bisher nicht auf unserem Konto eingegangen.\n\n'
            'Wir fordern Sie hiermit auf, die ausstehende Zahlung '
            'innert 20 Tagen vorzunehmen.\n\n'
            'Freundliche Grüsse\nSBS Projer GmbH';
      default:
        return 'Guten Tag\n\n'
            'Wir haben Sie bereits mehrfach an die ausstehende Zahlung '
            'der Rechnung $rgNr erinnert. Leider ist der Betrag bis heute nicht eingegangen.\n\n'
            'Wir fordern Sie letztmalig auf, den offenen Betrag innert 30 Tagen zu begleichen. '
            'Andernfalls behalten wir uns weitere Schritte vor.\n\n'
            'Freundliche Grüsse\nSBS Projer GmbH';
    }
  }
}

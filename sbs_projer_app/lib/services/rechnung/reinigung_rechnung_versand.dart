import 'package:flutter/foundation.dart';
import 'package:sbs_projer_app/core/config/mail_config.dart';
import 'package:sbs_projer_app/core/util/rechnung_nachhol_plan.dart';
import 'package:sbs_projer_app/core/util/zahlungsart.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnungs_position_repository.dart';
import 'package:sbs_projer_app/services/pdf/rechnung_pdf_storage.dart';
import 'package:sbs_projer_app/services/rechnung/rechnung_service.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Ergebnis eines Rechnungs-/Mailversands zu einer Reinigung.
class ReinigungVersandErgebnis {
  /// Ob eine Rechnung erstellt wurde (false = war bereits vorhanden oder
  /// es wird für diese Reinigung keine erstellt).
  final bool rechnungErstellt;

  /// Ob war bereits eine Rechnung vorhanden (dann wurde nur neu versendet).
  final bool warVorhanden;

  /// Ob eine Mail versendet wurde.
  final bool mailGesendet;

  /// Tatsächlicher Empfänger der Mail (null wenn keine Mail).
  final String? empfaenger;

  /// Nur bei rechnung_mail: es war keine echte Kundenadresse gepflegt, die
  /// Rechnung ging intern an den Testempfänger.
  final bool keineKundenadresse;

  /// Menschenlesbare Erfolgsmeldung.
  final String meldung;

  /// Das Rechnungs-PDF liegt NICHT im Storage. Der Geschäftsvorfall ist
  /// trotzdem erfasst — aber der Beleg fehlt und muss nachgezogen werden.
  final bool pdfFehlt;

  const ReinigungVersandErgebnis({
    required this.rechnungErstellt,
    required this.warVorhanden,
    required this.mailGesendet,
    required this.empfaenger,
    required this.keineKundenadresse,
    required this.meldung,
    this.pdfFehlt = false,
  });

  /// Dasselbe Ergebnis, aber mit dem Hinweis auf das fehlende PDF in der
  /// Meldung. Eine Erfolgsmeldung darf nicht verschweigen, was fehlt.
  ReinigungVersandErgebnis mitPdfHinweis() => ReinigungVersandErgebnis(
        rechnungErstellt: rechnungErstellt,
        warVorhanden: warVorhanden,
        mailGesendet: mailGesendet,
        empfaenger: empfaenger,
        keineKundenadresse: keineKundenadresse,
        meldung: RechnungNachholPlan.pdfFehltMeldung(meldung),
        pdfFehlt: true,
      );
}

/// Erstellt (falls nötig) die Kundenrechnung zu einer abgeschlossenen Reinigung
/// und versendet sie je nach Rechnungsstellung:
/// - `rechnung_mail`: Rechnung + Lieferschein an die Kundenadresse
/// - `rechnung_post`: Rechnung + Lieferschein an Daniel (zum Ausdrucken/Postversand)
///
/// Wirft bei Fehlern (Rechnungserstellung, Mailversand) — der Aufrufer MUSS die
/// Exception abfangen und dem Nutzer sichtbar melden. Es wird bewusst NICHT
/// still verschluckt.
class ReinigungRechnungVersand {
  /// Hängt den Hinweis auf ein fehlendes PDF an, sonst unverändert.
  static ReinigungVersandErgebnis _mitPdfStand(
    ReinigungVersandErgebnis e,
    bool pdfFehlt,
  ) =>
      pdfFehlt ? e.mitPdfHinweis() : e;

  /// Erstellt die Rechnung falls noch keine existiert und versendet sie.
  static Future<ReinigungVersandErgebnis> erstelleUndSende(
    ReinigungLocal r,
    BetriebLocal betrieb,
  ) async {
    // 1. Bereits vorhandene Rechnung zur Reinigung suchen (kein Doppel)
    Rechnung? rechnung;
    final serviceId = r.serverId;
    if (serviceId != null) {
      final vorhandeneId =
          await RechnungsPositionRepository.getRechnungIdByServiceId(serviceId);
      if (vorhandeneId != null) {
        rechnung = await RechnungRepository.getById(vorhandeneId);
      }
    }
    final warVorhanden = rechnung != null;

    // 2. Fehlendes ergänzen. «Vorhanden» heisst NICHT «vollständig»: Am
    //    01.09.2026 stand die Rechnung, aber das PDF fehlte, weil der Upload
    //    abgebrochen war — und weil dieser Weg die Erstellung übersprang,
    //    wurde das PDF nie nachgezogen. Gemeldet wurde trotzdem Erfolg.
    //    Deshalb wird die Ablage gefragt, nicht die Datenbank.
    final plan = RechnungNachholPlan.fuer(
      rechnungVorhanden: warVorhanden,
      pdfVorhanden:
          warVorhanden && await RechnungPdfStorage.existiert(rechnung.id),
    );

    if (plan.rechnungErstellen) {
      rechnung = await RechnungService.createFromReinigung(r, betrieb);
    }
    if (rechnung == null) {
      return const ReinigungVersandErgebnis(
        rechnungErstellt: false,
        warVorhanden: false,
        mailGesendet: false,
        empfaenger: null,
        keineKundenadresse: false,
        meldung:
            'Für diese Reinigung wird keine Rechnung erstellt (Kulanz/Heineken '
            'oder keine Rechnungs-Verrechnungsart).',
      );
    }

    // 2b. PDF sicherstellen. Auch beim Erstellen kann die Ablage scheitern —
    //     `pdfErzeugenUndAblegen` wirft bewusst nicht, damit ein abgebrochener
    //     Upload weder Buchung noch Übergabevermerk verhindert.
    var pdfFehlt = false;
    if (plan.rechnungErstellen) {
      pdfFehlt = !await RechnungPdfStorage.existiert(rechnung.id);
    } else if (plan.pdfNachziehen) {
      pdfFehlt =
          !await RechnungService.pdfErzeugenUndAblegen(rechnung, betrieb);
    }

    // 3. Versand je nach Rechnungsstellung
    final rs = resolveZahlungsart(r.zahlungsart, betrieb.rechnungsstellung);
    final datumStr =
        '${r.datum.day}. ${_monatName(r.datum.month)} ${r.datum.year}';
    final betriebLabel = betrieb.ort != null && betrieb.ort!.isNotEmpty
        ? '${betrieb.name} ${betrieb.ort}'
        : betrieb.name;

    if (rs == 'rechnung_mail') {
      final kundenEmail = await _kundenEmail(betrieb);
      final keineKundenadresse = kundenEmail == null;
      final empfaenger = MailConfig.empfaenger(
        kundenEmail,
        bereich: 'reinigung',
      );
      final betragRounded = (rechnung.betragBrutto * 20).roundToDouble() / 20;
      final betragStr = betragRounded.toStringAsFixed(2);

      await SupabaseService.client.functions.invoke(
        'send-rechnung-mail',
        body: {
          'to': empfaenger,
          'subject':
              'Rechnung Service Offenausschankanlage $betriebLabel vom $datumStr',
          'bodyText':
              'Guten Tag\n\n'
              'Im Anhang sende ich Ihnen die Rechnung für die Bierleitungsreinigung im $betriebLabel vom $datumStr, '
              'die Details entnehmen Sie bitte der Rechnung und dem Lieferschein im Anhang.\n\n'
              'Ich bitte Sie den offenen Betrag von CHF $betragStr innerhalb von 30 Tagen '
              'mit dem beiliegenden Einzahlungsschein zu begleichen.\n\n'
              'Mit freundlichen Grüssen\n\n'
              'Daniel Projer\n\n'
              'SBS Projer GmbH\nVia Rezia 8\n7013 Domat/Ems\n076 / 566 58 06',
          'rechnungId': rechnung.id,
          'userId': SupabaseService.dataUserId,
          // Der Versandvermerk wird seit v15 SERVERSEITIG gesetzt, direkt nach
          // dem Gmail-Aufruf. Vorher hing er allein am `update` unten — ging
          // die Antwort dieses `invoke` verloren (Timeout, Verbindungsabbruch),
          // war die Mail beim Kunden, der Vermerk fehlte, und ein zweiter
          // Klick hätte sie erneut verschickt. Vorfall Hugos Davos 27.08.2026.
          'markiereVersandt': MailConfig.istScharf('reinigung'),
          if (r.protokollFotoPfad != null)
            'protokollFotoPfad': r.protokollFotoPfad,
        },
      );

      // Status/versendet_am NUR bei scharfem Versand setzen (im Testmodus ging
      // die Mail an den Testempfänger, nicht an den Kunden).
      //
      // Bleibt als Rückfall neben dem serverseitigen Vermerk: Beide Wege sind
      // idempotent (der Server hebt `offen` → `gesendet`, hier passiert bei
      // gleichem Ergebnis nichts Neues). Kommt die Antwort an, ist der Status
      // ohnehin schon gesetzt; kommt sie nicht an, hat der Server ihn.
      if (MailConfig.istScharf('reinigung')) {
        await RechnungRepository.update(rechnung.id, {
          'zahlungsstatus': 'gesendet',
          'versendet_am': DateTime.now().toIso8601String().split('T').first,
        });
      }

      return _mitPdfStand(
        ReinigungVersandErgebnis(
          rechnungErstellt: !warVorhanden,
          warVorhanden: warVorhanden,
          mailGesendet: true,
          empfaenger: empfaenger,
          keineKundenadresse: keineKundenadresse,
          meldung: keineKundenadresse
              ? 'Keine Kundenadresse gepflegt — Rechnung ging an $empfaenger (intern). '
                    'Bitte Rechnungsadresse für ${betrieb.name} ergänzen.'
              : 'Rechnung per Mail versendet an $empfaenger',
        ),
        pdfFehlt,
      );
    }

    if (rs == 'rechnung_post') {
      // Rechnung per Mail an Daniel selbst (zum Ausdrucken + Postversand).
      await SupabaseService.client.functions.invoke(
        'send-rechnung-mail',
        body: {
          'to': MailConfig.testEmpfaenger, // dani.proyer@gmail.com (intern)
          'subject':
              'Post-Rechnung zum Ausdrucken: $betriebLabel vom $datumStr',
          'bodyText':
              'Rechnung für die Bierleitungsreinigung im $betriebLabel vom $datumStr '
              'zum Ausdrucken und Versand per Post (Anhang: Rechnung + Lieferschein).',
          'rechnungId': rechnung.id,
          'userId': SupabaseService.dataUserId,
          if (r.protokollFotoPfad != null)
            'protokollFotoPfad': r.protokollFotoPfad,
        },
      );

      // Versand gilt mit dem Abschluss als erfolgt (Postversand zeitnah).
      await RechnungRepository.update(rechnung.id, {
        'zahlungsstatus': 'gesendet',
        'versendet_am': DateTime.now().toIso8601String().split('T').first,
      });

      return _mitPdfStand(
        ReinigungVersandErgebnis(
          rechnungErstellt: !warVorhanden,
          warVorhanden: warVorhanden,
          mailGesendet: true,
          empfaenger: MailConfig.testEmpfaenger,
          keineKundenadresse: false,
          meldung:
              'Rechnung zum Postversand an ${MailConfig.testEmpfaenger} gemailt',
        ),
        pdfFehlt,
      );
    }

    if (rs == 'rechnung_tresen') {
      // Persönliche Übergabe am Tresen — kein Mailversand. Das Datum gehört
      // in uebergeben_am, NICHT in versendet_am (das bleibt echtem Mail-/
      // Postversand vorbehalten, sonst geht der Übergabezeitpunkt bei einem
      // späteren Mailversand verloren).
      await RechnungRepository.update(rechnung.id, {
        'uebergeben_am': DateTime.now().toIso8601String().split('T').first,
      });
      return _mitPdfStand(
        ReinigungVersandErgebnis(
          rechnungErstellt: !warVorhanden,
          warVorhanden: warVorhanden,
          mailGesendet: false,
          empfaenger: null,
          keineKundenadresse: false,
          meldung: 'Rechnung erstellt — Übergabe am Tresen.',
        ),
        pdfFehlt,
      );
    }

    // Andere Verrechnungsarten: Rechnung erstellt, aber kein automatischer
    // Mailversand.
    return _mitPdfStand(
      ReinigungVersandErgebnis(
        rechnungErstellt: !warVorhanden,
        warVorhanden: warVorhanden,
        mailGesendet: false,
        empfaenger: null,
        keineKundenadresse: false,
        meldung: 'Rechnung erstellt (Verrechnungsart „$rs" — kein Mailversand).',
      ),
      pdfFehlt,
    );
  }

  /// Versand IMMER via betrieb_rechnungsadressen.email — betriebe.email ist
  /// reine Info (Entscheid Daniel 16.07.2026).
  static Future<String?> _kundenEmail(BetriebLocal betrieb) async {
    try {
      final adrRows = await SupabaseService.client
          .from('betrieb_rechnungsadressen')
          .select('email')
          .eq('betrieb_id', betrieb.serverId!)
          .limit(1);
      if (adrRows.isNotEmpty) {
        final mail = (adrRows.first as Map)['email'];
        if (mail is String && mail.isNotEmpty) return mail;
      }
    } catch (e) {
      debugPrint(
        '[ReinigungVersand] Rechnungsadresse-Query fehlgeschlagen: $e',
      );
    }
    return null;
  }

  static String _monatName(int monat) {
    const namen = [
      '',
      'Januar',
      'Februar',
      'März',
      'April',
      'Mai',
      'Juni',
      'Juli',
      'August',
      'September',
      'Oktober',
      'November',
      'Dezember',
    ];
    return namen[monat];
  }
}

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';

/// Erstellt Buchhaltungs-Buchungen für den Heineken-Rechnungsworkflow.
/// - Freigabe → Debitoren-Buchung (Soll 1100 / Haben 3400) + MwSt
/// - Bezahlt → Zahlungseingang (Soll 1020 / Haben 1100)
class HeinekenBuchungService {
  static double _round5Rappen(double v) => (v * 20).roundToDouble() / 20;

  /// Erstellt Buchung wenn Heineken-Rechnung freigegeben wird.
  /// Soll 1100 (Debitoren) / Haben 3400 (Dienstleistungsertrag)
  /// + MwSt-Buchung: Soll 3400 / Haben 2200 (Geschuldete MwSt)
  static Future<Buchung?> createFromRechnung(Rechnung rechnung) async {
    // Guard: nur für heineken_monat
    if (rechnung.rechnungstyp != 'heineken_monat') return null;

    // Duplikat-Check via beleg_id
    final existing = await BuchungRepository.getByBeleg(rechnung.id);
    // Bereits eine Hauptbuchung (nicht Zahlung, nicht MwSt) vorhanden?
    final hatHauptbuchung = existing.any((b) =>
        b.belegTyp == 'rechnung' && !b.istStorniert);
    if (hatHauptbuchung) {
      debugPrint('[HeiBuch] Buchung existiert bereits für ${rechnung.id}');
      return null;
    }

    // Beträge aus Rechnung (bereits 5-Rappen-gerundet)
    final netto = rechnung.betragNetto;
    final mwstBetrag = rechnung.mwstBetrag;
    final brutto = _round5Rappen(rechnung.betragBrutto);
    final mwstSatz = netto > 0 ? (mwstBetrag / netto * 100) : 8.1;

    final monatLabel = rechnung.heinekenMonat != null
        ? DateFormat('MM/yyyy').format(rechnung.heinekenMonat!)
        : '?';
    final datumStr =
        rechnung.rechnungsdatum.toIso8601String().split('T').first;

    try {
      // 1. Hauptbuchung: Soll 1100 (Debitoren) / Haben 3400 (Erlöse) → Brutto
      final buchung = await BuchungRepository.create({
        'datum': datumStr,
        'belegnummer': rechnung.rechnungsnummer,
        'soll_konto': 1100, // Debitoren
        'haben_konto': 3400, // Dienstleistungsertrag
        'mwst_konto': 2200, // Geschuldete MwSt
        'betrag_netto': netto,
        'mwst_satz': mwstSatz,
        'mwst_betrag': mwstBetrag,
        'betrag_brutto': brutto,
        'beschreibung': 'Heineken Monatsrechnung $monatLabel',
        'zahlungsweg': 'rechnung',
        'beleg_typ': 'rechnung',
        'beleg_id': rechnung.id,
        'geschaeftsjahr': rechnung.rechnungsdatum.year,
      });

      // 2. MwSt-Buchung: Soll 3400 / Haben 2200 (Bruttomethode)
      if (mwstBetrag > 0) {
        await BuchungRepository.create({
          'datum': datumStr,
          'soll_konto': 3400,
          'haben_konto': 2200,
          'betrag_netto': mwstBetrag,
          'mwst_satz': 0,
          'mwst_betrag': 0,
          'betrag_brutto': mwstBetrag,
          'beschreibung': 'MwSt Heineken $monatLabel',
          'beleg_typ': 'mwst',
          'beleg_id': rechnung.id,
          'geschaeftsjahr': rechnung.rechnungsdatum.year,
        });
      }

      debugPrint(
          '[HeiBuch] Freigabe: Netto $netto, MwSt $mwstBetrag, Brutto $brutto');
      return buchung;
    } catch (e) {
      debugPrint('[HeiBuch] Freigabe-Buchung fehlgeschlagen: $e');
      rethrow;
    }
  }

  /// Erstellt Zahlungseingang-Buchung wenn bezahlt markiert.
  /// Soll 1020 (Bank) / Haben 1100 (Debitoren)
  static Future<Buchung?> createZahlungseingang(Rechnung rechnung) async {
    // Duplikat-Check: schon Zahlungseingang gebucht?
    final existing = await BuchungRepository.getByBeleg(rechnung.id);
    final hatZahlung =
        existing.any((b) => b.belegTyp == 'zahlung' && !b.istStorniert);
    if (hatZahlung) {
      debugPrint('[HeiBuch] Zahlungseingang existiert bereits für ${rechnung.id}');
      return null;
    }

    final monatLabel = rechnung.heinekenMonat != null
        ? DateFormat('MM/yyyy').format(rechnung.heinekenMonat!)
        : '?';
    final datumStr = DateTime.now().toIso8601String().split('T').first;

    try {
      final buchung = await BuchungRepository.create({
        'datum': datumStr,
        'belegnummer': rechnung.rechnungsnummer,
        'soll_konto': 1020, // Bank
        'haben_konto': 1100, // Debitoren
        'betrag_netto': rechnung.betragBrutto,
        'mwst_satz': 0,
        'mwst_betrag': 0,
        'betrag_brutto': rechnung.betragBrutto,
        'beschreibung': 'Zahlungseingang Heineken $monatLabel',
        'zahlungsweg': 'bank',
        'beleg_typ': 'zahlung',
        'beleg_id': rechnung.id,
        'geschaeftsjahr': DateTime.now().year,
      });

      debugPrint('[HeiBuch] Zahlungseingang: ${rechnung.betragBrutto} CHF');
      return buchung;
    } catch (e) {
      debugPrint('[HeiBuch] Zahlungseingang-Buchung fehlgeschlagen: $e');
      rethrow;
    }
  }
}

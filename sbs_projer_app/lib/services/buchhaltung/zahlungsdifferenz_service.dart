import 'package:flutter/foundation.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';

/// Erstellt Zahlungseingang-Buchungen für Kunden-Rechnungen (nicht Heineken).
/// Handhabt auch Zahlungsdifferenzen:
/// - Unterzahlung → Debitorenverlust (3805)
/// - Überzahlung → Ausserordentlicher Ertrag (8000)
class ZahlungsdifferenzService {
  static double _round5Rappen(double v) => (v * 20).roundToDouble() / 20;

  /// Erstellt Zahlungseingang + ggf. Differenz-Buchung.
  /// [zahlungBetrag] = effektiv eingegangener Betrag vom Kunden.
  /// [rechnung] = die zu bezahlende Rechnung.
  /// Gibt Liste der erstellten Buchungen zurück.
  static Future<List<Buchung>> verbuchen({
    required Rechnung rechnung,
    required double zahlungBetrag,
  }) async {
    final rechnungBrutto = _round5Rappen(rechnung.betragBrutto);
    final zahlung = _round5Rappen(zahlungBetrag);
    final differenz = _round5Rappen(zahlung - rechnungBrutto);
    final datumStr = DateTime.now().toIso8601String().split('T').first;
    final rgNr = rechnung.rechnungsnummer ?? '';
    final erstellteBuchungen = <Buchung>[];

    // Duplikat-Check: schon Zahlungseingang gebucht?
    final existing = await BuchungRepository.getByBeleg(rechnung.id);
    final hatZahlung =
        existing.any((b) => b.belegTyp == 'zahlung' && !b.istStorniert);
    if (hatZahlung) {
      debugPrint('[ZahlDiff] Zahlungseingang existiert bereits für ${rechnung.id}');
      return [];
    }

    try {
      if (differenz.abs() < 0.01) {
        // ── Exakte Zahlung ──
        // Soll 1020 (Bank) / Haben 1100 (Debitoren) = Brutto
        final buchung = await BuchungRepository.create({
          'datum': datumStr,
          'belegnummer': rgNr,
          'soll_konto': 1020,
          'haben_konto': 1100,
          'betrag_netto': rechnungBrutto,
          'mwst_satz': 0,
          'mwst_betrag': 0,
          'betrag_brutto': rechnungBrutto,
          'beschreibung': 'Zahlungseingang $rgNr',
          'zahlungsweg': 'bank',
          'beleg_typ': 'zahlung',
          'beleg_id': rechnung.id,
          'geschaeftsjahr': DateTime.now().year,
        });
        erstellteBuchungen.add(buchung);
        debugPrint('[ZahlDiff] Exakte Zahlung: $rechnungBrutto CHF');
      } else if (differenz < 0) {
        // ── Unterzahlung (Kunde zahlt zu wenig) ──
        // 1. Zahlungseingang: Soll 1020 / Haben 1100 = tatsächlicher Betrag
        final buchung1 = await BuchungRepository.create({
          'datum': datumStr,
          'belegnummer': rgNr,
          'soll_konto': 1020,
          'haben_konto': 1100,
          'betrag_netto': zahlung,
          'mwst_satz': 0,
          'mwst_betrag': 0,
          'betrag_brutto': zahlung,
          'beschreibung': 'Zahlungseingang $rgNr',
          'zahlungsweg': 'bank',
          'beleg_typ': 'zahlung',
          'beleg_id': rechnung.id,
          'geschaeftsjahr': DateTime.now().year,
        });
        erstellteBuchungen.add(buchung1);

        // 2. Debitorenverlust: Soll 3805 / Haben 1100 = Differenz
        final verlust = _round5Rappen(differenz.abs());
        final buchung2 = await BuchungRepository.create({
          'datum': datumStr,
          'belegnummer': rgNr,
          'soll_konto': 3805,
          'haben_konto': 1100,
          'betrag_netto': verlust,
          'mwst_satz': 0,
          'mwst_betrag': 0,
          'betrag_brutto': verlust,
          'beschreibung': 'Debitorenverlust $rgNr (Differenz erlassen)',
          'zahlungsweg': 'intern',
          'beleg_typ': 'zahlung',
          'beleg_id': rechnung.id,
          'geschaeftsjahr': DateTime.now().year,
        });
        erstellteBuchungen.add(buchung2);
        debugPrint(
            '[ZahlDiff] Unterzahlung: $zahlung CHF bezahlt, $verlust CHF erlassen');
      } else {
        // ── Überzahlung (Kunde zahlt zu viel) ──
        // 1. Zahlungseingang Rechnungsbetrag: Soll 1020 / Haben 1100
        final buchung1 = await BuchungRepository.create({
          'datum': datumStr,
          'belegnummer': rgNr,
          'soll_konto': 1020,
          'haben_konto': 1100,
          'betrag_netto': rechnungBrutto,
          'mwst_satz': 0,
          'mwst_betrag': 0,
          'betrag_brutto': rechnungBrutto,
          'beschreibung': 'Zahlungseingang $rgNr',
          'zahlungsweg': 'bank',
          'beleg_typ': 'zahlung',
          'beleg_id': rechnung.id,
          'geschaeftsjahr': DateTime.now().year,
        });
        erstellteBuchungen.add(buchung1);

        // 2. Überschuss: Soll 1020 / Haben 8000 (Ausserordentlicher Ertrag)
        final ueberschuss = _round5Rappen(differenz);
        final buchung2 = await BuchungRepository.create({
          'datum': datumStr,
          'belegnummer': rgNr,
          'soll_konto': 1020,
          'haben_konto': 8000,
          'betrag_netto': ueberschuss,
          'mwst_satz': 0,
          'mwst_betrag': 0,
          'betrag_brutto': ueberschuss,
          'beschreibung': 'Mehrzahlung $rgNr (Trinkgeld/Rundung)',
          'zahlungsweg': 'bank',
          'beleg_typ': 'zahlung',
          'beleg_id': rechnung.id,
          'geschaeftsjahr': DateTime.now().year,
        });
        erstellteBuchungen.add(buchung2);
        debugPrint(
            '[ZahlDiff] Überzahlung: $zahlung CHF bezahlt, $ueberschuss CHF Mehrzahlung');
      }

      return erstellteBuchungen;
    } catch (e) {
      debugPrint('[ZahlDiff] Buchung fehlgeschlagen: $e');
      rethrow;
    }
  }
}

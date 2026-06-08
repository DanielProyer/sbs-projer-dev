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

  /// Verbucht eine Sammelzahlung über mehrere Rechnungen.
  /// Jede Rechnung bekommt eine eigene Buchung (Soll 1020 / Haben 1100).
  /// Eine Differenz zum [zahlungBetrag] wird einmal am Ende gebucht.
  static Future<List<Buchung>> verbuchenSammel({
    required List<Rechnung> rechnungen,
    required double zahlungBetrag,
    DateTime? datum,
  }) async {
    final erstellteBuchungen = <Buchung>[];
    final datumStr = (datum ?? DateTime.now()).toIso8601String().split('T').first;

    double gesamtBrutto = 0;
    for (final r in rechnungen) {
      gesamtBrutto += _round5Rappen(r.betragBrutto);
    }
    gesamtBrutto = _round5Rappen(gesamtBrutto);

    for (final rechnung in rechnungen) {
      final rechnungBrutto = _round5Rappen(rechnung.betragBrutto);
      final rgNr = rechnung.rechnungsnummer ?? '';

      final existing = await BuchungRepository.getByBeleg(rechnung.id);
      final hatZahlung =
          existing.any((b) => b.belegTyp == 'zahlung' && !b.istStorniert);
      if (hatZahlung) {
        debugPrint('[ZahlDiff] Überspringe ${rechnung.id} – bereits bezahlt');
        continue;
      }

      final buchung = await BuchungRepository.create({
        'datum': datumStr,
        'belegnummer': rgNr,
        'soll_konto': 1020,
        'haben_konto': 1100,
        'betrag_netto': rechnungBrutto,
        'mwst_satz': 0,
        'mwst_betrag': 0,
        'betrag_brutto': rechnungBrutto,
        'beschreibung': 'Zahlungseingang $rgNr (Sammelzahlung)',
        'zahlungsweg': 'bank',
        'beleg_typ': 'zahlung',
        'beleg_id': rechnung.id,
        'geschaeftsjahr': (datum ?? DateTime.now()).year,
      });
      erstellteBuchungen.add(buchung);
    }

    final differenz = _round5Rappen(_round5Rappen(zahlungBetrag) - gesamtBrutto);
    if (differenz.abs() >= 0.01) {
      final letzte = rechnungen.last;
      final rgNr = letzte.rechnungsnummer ?? '';
      if (differenz < 0) {
        final buchung = await BuchungRepository.create({
          'datum': datumStr,
          'belegnummer': rgNr,
          'soll_konto': 3805,
          'haben_konto': 1100,
          'betrag_netto': _round5Rappen(differenz.abs()),
          'mwst_satz': 0,
          'mwst_betrag': 0,
          'betrag_brutto': _round5Rappen(differenz.abs()),
          'beschreibung': 'Debitorenverlust Sammelzahlung (Differenz erlassen)',
          'zahlungsweg': 'intern',
          'beleg_typ': 'zahlung',
          'beleg_id': letzte.id,
          'geschaeftsjahr': (datum ?? DateTime.now()).year,
        });
        erstellteBuchungen.add(buchung);
      } else {
        final buchung = await BuchungRepository.create({
          'datum': datumStr,
          'belegnummer': rgNr,
          'soll_konto': 1020,
          'haben_konto': 8000,
          'betrag_netto': _round5Rappen(differenz),
          'mwst_satz': 0,
          'mwst_betrag': 0,
          'betrag_brutto': _round5Rappen(differenz),
          'beschreibung': 'Mehrzahlung Sammelzahlung (Trinkgeld/Rundung)',
          'zahlungsweg': 'bank',
          'beleg_typ': 'zahlung',
          'beleg_id': letzte.id,
          'geschaeftsjahr': (datum ?? DateTime.now()).year,
        });
        erstellteBuchungen.add(buchung);
      }
    }

    debugPrint('[ZahlDiff] Sammelzahlung: ${rechnungen.length} Rechnungen, '
        '$zahlungBetrag CHF bezahlt, Differenz: $differenz CHF');
    return erstellteBuchungen;
  }

  /// Erstellt Zahlungseingang + ggf. Differenz-Buchung.
  /// [zahlungBetrag] = effektiv eingegangener Betrag vom Kunden.
  /// [rechnung] = die zu bezahlende Rechnung.
  /// Gibt Liste der erstellten Buchungen zurück.
  static Future<List<Buchung>> verbuchen({
    required Rechnung rechnung,
    required double zahlungBetrag,
    DateTime? datum,
  }) async {
    final rechnungBrutto = _round5Rappen(rechnung.betragBrutto);
    final zahlung = _round5Rappen(zahlungBetrag);
    final differenz = _round5Rappen(zahlung - rechnungBrutto);
    final datumStr = (datum ?? DateTime.now()).toIso8601String().split('T').first;
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
          'geschaeftsjahr': (datum ?? DateTime.now()).year,
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
          'geschaeftsjahr': (datum ?? DateTime.now()).year,
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
          'geschaeftsjahr': (datum ?? DateTime.now()).year,
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
          'geschaeftsjahr': (datum ?? DateTime.now()).year,
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
          'geschaeftsjahr': (datum ?? DateTime.now()).year,
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

import 'package:flutter/foundation.dart';
import 'package:sbs_projer_app/core/util/guthaben.dart';
import 'package:sbs_projer_app/core/util/guthaben_verrechnung.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';

/// Erstellt Zahlungseingang-Buchungen für Kunden-Rechnungen (nicht Heineken).
/// Handhabt auch Zahlungsdifferenzen:
/// - Unterzahlung → Debitorenverlust (3805)
/// - Überzahlung → Ausserordentlicher Ertrag (8000)
/// - verrechnetes Kundenguthaben → Soll 2030 / Haben 1100 (v0.137.0)
///
/// Was gebucht wird, plant die reine Funktion [differenzPlan]; hier steht
/// nur noch das Schreiben.
class ZahlungsdifferenzService {
  static String _alsText(DateTime d) => d.toIso8601String().split('T').first;

  static bool _hatZahlung(List<Buchung> existing) => existing.any((b) =>
      b.belegTyp == 'zahlung' && !b.istStorniert && b.stornoVonId == null);

  /// Verrechnungsbuchung Soll 2030 / Haben 1100 über das Guthaben der Rechnung
  /// (auch vom Anlegen einer ganz gedeckten Rechnung und vom Abschreiben).
  static Future<Buchung> verrechnungBuchen(
      Rechnung rechnung, double betrag, DateTime datum) {
    final rgNr = rechnung.rechnungsnummer ?? '';
    return BuchungRepository.create({
      'datum': _alsText(datum),
      'belegnummer': rgNr,
      'soll_konto': kKontoKundenguthaben,
      'haben_konto': 1100,
      'betrag_netto': betrag,
      'mwst_satz': 0,
      'mwst_betrag': 0,
      'betrag_brutto': betrag,
      'beschreibung': 'Verrechnung Kundenguthaben $rgNr',
      'zahlungsweg': 'intern',
      'beleg_typ': 'sonstiges',
      'beleg_id': rechnung.id,
      'geschaeftsjahr': datum.year,
    });
  }

  /// Zahlung deckte trotz Guthaben den vollen Betrag: Das Guthaben wird auf
  /// dieser Rechnung NICHT verrechnet und bleibt auf 2030 stehen.
  static Future<void> _guthabenZuruecksetzen(List<Rechnung> rechnungen) async {
    for (final r in rechnungen) {
      if (r.guthabenVerrechnet <= 0) continue;
      await RechnungRepository.update(r.id, {'guthaben_verrechnet': 0});
    }
  }

  /// Verbucht eine Sammelzahlung über mehrere Rechnungen.
  /// Jede Rechnung bekommt eine eigene Buchung (Soll 1020 / Haben 1100) über
  /// «zu zahlen», bei verrechnetem Guthaben zusätzlich Soll 2030 / Haben 1100.
  /// Eine Differenz zum [zahlungBetrag] wird einmal am Ende gebucht.
  ///
  /// [datumProRechnung] setzt je Rechnung (Schlüssel = Rechnungs-Id) ein
  /// eigenes Buchungsdatum — nötig, wenn mehrere Zahlungseingänge von
  /// verschiedenen Tagen zugeordnet werden. Ohne Eintrag gilt [datum].
  static Future<List<Buchung>> verbuchenSammel({
    required List<Rechnung> rechnungen,
    required double zahlungBetrag,
    DateTime? datum,
    Map<String, DateTime>? datumProRechnung,
  }) async {
    final erstellteBuchungen = <Buchung>[];
    final standard = datum ?? DateTime.now();
    DateTime datumFuer(Rechnung r) => datumProRechnung?[r.id] ?? standard;

    // Erlassene Minderzahlung: Die Bank erhält nur den Zahlbetrag — die
    // Hauptzeilen werden von hinten um den Verlust gekürzt (der
    // Debitor gleicht über die 3805-Verlustzeile trotzdem exakt aus).
    // Vorher buchte jede Hauptzeile das volle Rechnungsbrutto auf 1020 →
    // Bank überschoss um den erlassenen Betrag (Befund Nachhol-Import
    // 07.08.2026: 12.20 über dem E-Banking-Saldo). Steckt in [differenzPlan].
    final plan = differenzPlan(rechnungen, zahlungBetrag);
    final differenz = plan.differenz;
    if (plan.hinweis != null) debugPrint('[ZahlDiff] ${plan.hinweis}');

    final gebuchteRechnungen = <Rechnung>[];
    for (final zeile in plan.zeilen) {
      final rechnung = zeile.rechnung;
      final rgNr = rechnung.rechnungsnummer ?? '';

      final existing = await BuchungRepository.getByBeleg(rechnung.id);
      if (_hatZahlung(existing)) {
        debugPrint('[ZahlDiff] Überspringe ${rechnung.id} – bereits bezahlt');
        continue;
      }
      gebuchteRechnungen.add(rechnung);

      final rechnungDatum = datumFuer(rechnung);
      if (zeile.bank >= 0.005) {
        final buchung = await BuchungRepository.create({
          'datum': _alsText(rechnungDatum),
          'belegnummer': rgNr,
          'soll_konto': 1020,
          'haben_konto': 1100,
          'betrag_netto': zeile.bank,
          'mwst_satz': 0,
          'mwst_betrag': 0,
          'betrag_brutto': zeile.bank,
          'beschreibung': 'Zahlungseingang $rgNr (Sammelzahlung)',
          'zahlungsweg': 'bank',
          'beleg_typ': 'zahlung',
          'beleg_id': rechnung.id,
          'geschaeftsjahr': rechnungDatum.year,
          // Guthaben nicht verrechnet → alten Stand sichern (Review I5).
          if (zeile.guthabenVorher > 0)
            'notizen': guthabenNotiz(zeile.guthabenVorher),
        });
        erstellteBuchungen.add(buchung);
      }
      if (zeile.verrechnung >= 0.005) {
        erstellteBuchungen.add(
            await verrechnungBuchen(rechnung, zeile.verrechnung, rechnungDatum));
      }
    }
    if (plan.guthabenZuruecksetzen) {
      await _guthabenZuruecksetzen(gebuchteRechnungen);
    }

    if (differenz.abs() >= 0.01 && rechnungen.isNotEmpty) {
      final letzte = rechnungen.last;
      final rgNr = letzte.rechnungsnummer ?? '';
      final letztesDatum = datumFuer(letzte);
      final datumStr = _alsText(letztesDatum);
      if (differenz < 0) {
        final buchung = await BuchungRepository.create({
          'datum': datumStr,
          'belegnummer': rgNr,
          'soll_konto': 3805,
          'haben_konto': 1100,
          'betrag_netto': differenz.abs(),
          'mwst_satz': 0,
          'mwst_betrag': 0,
          'betrag_brutto': differenz.abs(),
          'beschreibung': 'Debitorenverlust Sammelzahlung (Differenz erlassen)',
          'zahlungsweg': 'intern',
          'beleg_typ': 'zahlung',
          'beleg_id': letzte.id,
          'geschaeftsjahr': letztesDatum.year,
        });
        erstellteBuchungen.add(buchung);
      } else {
        final buchung = await BuchungRepository.create({
          'datum': datumStr,
          'belegnummer': rgNr,
          'soll_konto': 1020,
          'haben_konto': 8000,
          'betrag_netto': differenz,
          'mwst_satz': 0,
          'mwst_betrag': 0,
          'betrag_brutto': differenz,
          'beschreibung': 'Mehrzahlung Sammelzahlung (Trinkgeld/Rundung)',
          'zahlungsweg': 'bank',
          'beleg_typ': 'zahlung',
          'beleg_id': letzte.id,
          'geschaeftsjahr': letztesDatum.year,
        });
        erstellteBuchungen.add(buchung);
      }
    }

    debugPrint('[ZahlDiff] Sammelzahlung: ${rechnungen.length} Rechnungen, '
        '$zahlungBetrag CHF bezahlt, Differenz: $differenz CHF, '
        'Guthaben verrechnet: ${plan.summeVerrechnung} CHF');
    return erstellteBuchungen;
  }

  /// Erstellt Zahlungseingang + ggf. Differenz- und Verrechnungsbuchung.
  /// [zahlungBetrag] = effektiv eingegangener Betrag vom Kunden.
  /// [rechnung] = die zu bezahlende Rechnung.
  /// Gibt Liste der erstellten Buchungen zurück.
  static Future<List<Buchung>> verbuchen({
    required Rechnung rechnung,
    required double zahlungBetrag,
    DateTime? datum,
  }) async {
    final tag = datum ?? DateTime.now();
    final datumStr = _alsText(tag);
    final rgNr = rechnung.rechnungsnummer ?? '';
    final erstellteBuchungen = <Buchung>[];

    // Duplikat-Check: schon Zahlungseingang gebucht?
    final existing = await BuchungRepository.getByBeleg(rechnung.id);
    if (_hatZahlung(existing)) {
      debugPrint('[ZahlDiff] Zahlungseingang existiert bereits für ${rechnung.id}');
      return [];
    }

    final plan = differenzPlan([rechnung], zahlungBetrag);
    final zeile = plan.zeilen.single;
    final differenz = plan.differenz;
    if (plan.hinweis != null) debugPrint('[ZahlDiff] ${plan.hinweis}');

    try {
      // Zahlungseingang: Soll 1020 (Bank) / Haben 1100 (Debitoren)
      if (zeile.bank >= 0.005) {
        erstellteBuchungen.add(await BuchungRepository.create({
          'datum': datumStr,
          'belegnummer': rgNr,
          'soll_konto': 1020,
          'haben_konto': 1100,
          'betrag_netto': zeile.bank,
          'mwst_satz': 0,
          'mwst_betrag': 0,
          'betrag_brutto': zeile.bank,
          'beschreibung': 'Zahlungseingang $rgNr',
          'zahlungsweg': 'bank',
          'beleg_typ': 'zahlung',
          'beleg_id': rechnung.id,
          'geschaeftsjahr': tag.year,
          if (zeile.guthabenVorher > 0)
            'notizen': guthabenNotiz(zeile.guthabenVorher),
        }));
      }
      if (zeile.verrechnung >= 0.005) {
        erstellteBuchungen
            .add(await verrechnungBuchen(rechnung, zeile.verrechnung, tag));
      }
      if (plan.guthabenZuruecksetzen) {
        await _guthabenZuruecksetzen([rechnung]);
      }

      if (differenz < -0.005) {
        // Unterzahlung: Debitorenverlust Soll 3805 / Haben 1100 = Differenz
        erstellteBuchungen.add(await BuchungRepository.create({
          'datum': datumStr,
          'belegnummer': rgNr,
          'soll_konto': 3805,
          'haben_konto': 1100,
          'betrag_netto': differenz.abs(),
          'mwst_satz': 0,
          'mwst_betrag': 0,
          'betrag_brutto': differenz.abs(),
          'beschreibung': 'Debitorenverlust $rgNr (Differenz erlassen)',
          'zahlungsweg': 'intern',
          'beleg_typ': 'zahlung',
          'beleg_id': rechnung.id,
          'geschaeftsjahr': tag.year,
        }));
        debugPrint('[ZahlDiff] Unterzahlung: ${differenz.abs()} CHF erlassen');
      } else if (differenz > 0.005) {
        // Überzahlung: Soll 1020 / Haben 8000 (Ausserordentlicher Ertrag)
        erstellteBuchungen.add(await BuchungRepository.create({
          'datum': datumStr,
          'belegnummer': rgNr,
          'soll_konto': 1020,
          'haben_konto': 8000,
          'betrag_netto': differenz,
          'mwst_satz': 0,
          'mwst_betrag': 0,
          'betrag_brutto': differenz,
          'beschreibung': 'Mehrzahlung $rgNr (Trinkgeld/Rundung)',
          'zahlungsweg': 'bank',
          'beleg_typ': 'zahlung',
          'beleg_id': rechnung.id,
          'geschaeftsjahr': tag.year,
        }));
        debugPrint('[ZahlDiff] Überzahlung: $differenz CHF Mehrzahlung');
      }

      return erstellteBuchungen;
    } catch (e) {
      debugPrint('[ZahlDiff] Buchung fehlgeschlagen: $e');
      rethrow;
    }
  }
}

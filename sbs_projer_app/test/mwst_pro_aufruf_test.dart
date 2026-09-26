import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/mwst_satz.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/services/buchhaltung/reinigung_buchung_service.dart';
import 'package:sbs_projer_app/services/rechnung/jahresrechnung_service.dart';
import 'package:sbs_projer_app/services/rechnung/rechnung_service.dart';

/// Der MwSt-Satz wird pro Aufruf ermittelt und durchgereicht (Runde 4,
/// Task 8). Vorher hielten vier Services ihn in einem statischen Feld — eine
/// Reinigung von 2023 konnte so mit dem 8.1 %-Satz einer vorher
/// verarbeiteten Reinigung von 2024 abgerechnet werden (und umgekehrt).
void main() {
  const satz2023 = MwstAngabe(prozent: 7.7, faktor: 0.077);
  const satz2024 = MwstAngabe(prozent: 8.1, faktor: 0.081);

  ReinigungLocal reinigung(DateTime datum) => ReinigungLocal()
    ..serverId = 'r-${datum.year}'
    ..userId = 'u'
    ..anlageId = 'a1'
    ..betriebId = 'b1'
    ..datum = datum
    ..status = 'abgeschlossen'
    ..serviceTyp = 'reinigung_bier'
    ..preisGrundtarif = 120
    ..anzahlHaehneEigen = 1; // + 18 → Netto 138

  ReinigungLocal ocrReinigung(DateTime datum) => ReinigungLocal()
    ..serverId = 'ocr-${datum.year}'
    ..userId = 'u'
    ..anlageId = 'a1'
    ..betriebId = 'b1'
    ..datum = datum
    ..status = 'abgeschlossen'
    ..preisBrutto = 162.15;

  final alt = reinigung(DateTime(2023, 6, 1));
  final neu = reinigung(DateTime(2024, 6, 1));

  test('Kundenrechnung: jede Reinigung mit dem Satz ihres Datums', () {
    // Abwechselnd im selben Lauf — kein Satz darf in den nächsten Aufruf
    // hinüberwirken.
    final a1 = RechnungService.bruttoAusReinigung(alt, satz2023);
    final b = RechnungService.bruttoAusReinigung(neu, satz2024);
    final a2 = RechnungService.bruttoAusReinigung(alt, satz2023);

    expect(a1, 148.65); // 138 × 1.077 = 148.626 → 5 Rappen
    expect(b, 149.20); // 138 × 1.081 = 149.178 → 5 Rappen
    expect(a2, a1);
  });

  test('Positionen tragen Satz und MwSt-Betrag des übergebenen Satzes', () {
    final p23 = RechnungService.buildPositionen(alt, satz2023);
    final p24 = RechnungService.buildPositionen(neu, satz2024);

    expect(p23.map((p) => p['mwst_satz']), everyElement(7.7));
    expect(p24.map((p) => p['mwst_satz']), everyElement(8.1));
    expect(p23.first['mwst_betrag'], 9.24); // 120 × 0.077
    expect(p24.first['mwst_betrag'], 9.72); // 120 × 0.081
  });

  test('OCR-Reinigung: Netto-Rückrechnung mit dem Satz des Datums', () {
    final ocr23 = ocrReinigung(DateTime(2023, 6, 1));
    final ocr24 = ocrReinigung(DateTime(2024, 6, 1));

    expect(ReinigungBuchungService.netto(ocr23, satz2023.faktor), 150.56);
    expect(ReinigungBuchungService.netto(ocr24, satz2024.faktor), 150.00);
    expect(JahresrechnungService.calcNetto(ocr23, satz2023.faktor), 150.56);
    expect(JahresrechnungService.calcNetto(ocr24, satz2024.faktor), 150.00);
    // Die Rechnung aus dem Protokoll-Brutto trifft das Brutto bei jedem Satz.
    expect(RechnungService.bruttoAusReinigung(ocr23, satz2023), 162.15);
    expect(RechnungService.bruttoAusReinigung(ocr24, satz2024), 162.15);
  });

  test('Jahresrechnung: Totale beim übergebenen Satz', () {
    final j23 = JahresrechnungService.berechnePositionen(
        [alt, ocrReinigung(DateTime(2023, 6, 1))], satz2023);
    final j24 = JahresrechnungService.berechnePositionen(
        [neu, ocrReinigung(DateTime(2024, 6, 1))], satz2024);

    expect(j23.netto, closeTo(288.56, 1e-9));
    expect(j23.brutto, 310.80);
    expect(j23.mwst, 22.24);
    expect(j23.positionen.map((p) => p['mwst_satz']), everyElement(7.7));

    expect(j24.netto, closeTo(288.00, 1e-9));
    expect(j24.brutto, 311.35);
    expect(j24.mwst, 23.35);
  });

  test('Rückfall ist 8.1 % und steht nur an einer Stelle', () {
    expect(MwstAngabe.fallback.faktor, 0.081);
    expect(MwstAngabe.fallback.prozent, 8.1);
    expect(MwstAngabe.fallback.label, '8.1%');
    expect(mwstProzentAusBetraegen(100, 7.7), '7.7');
    expect(mwstProzentAusBetraegen(0, 0), '8.1');

    final treffer = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('.g.dart')) continue;
      final pfad = f.path.replaceAll(r'\', '/');
      if (pfad.endsWith('core/util/mwst_satz.dart')) continue;
      final zeilen = f.readAsLinesSync();
      for (var i = 0; i < zeilen.length; i++) {
        final z = zeilen[i];
        if (z.trimLeft().startsWith('//')) continue;
        if (RegExp(r'\b0\.081\b').hasMatch(z) ||
            RegExp(r'static\s+(double|String)\s+_mwst').hasMatch(z)) {
          treffer.add('$pfad:${i + 1}: ${z.trim()}');
        }
      }
    }
    expect(treffer, isEmpty,
        reason: 'MwSt-Satz nie hart und nie in statischen Feldern — '
            'mwstAusPreisliste(datum) bzw. kMwstFaktorFallback nutzen');
  });
}

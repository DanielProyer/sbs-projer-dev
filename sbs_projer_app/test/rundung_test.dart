import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/rundung.dart';

void main() {
  group('rundeAuf5Rappen', () {
    test('rundet auf das nächste 5-Rappen-Vielfache', () {
      expect(rundeAuf5Rappen(74.59), 74.60);
      expect(rundeAuf5Rappen(113.51), 113.50);
      expect(rundeAuf5Rappen(138.37), 138.35);
      expect(rundeAuf5Rappen(107.02), 107.00);
      expect(rundeAuf5Rappen(177.28), 177.30);
    });

    test('lässt bereits saubere Beträge unverändert', () {
      for (final v in [74.60, 113.50, 118.90, 0.05, 0.0]) {
        expect(rundeAuf5Rappen(v), v);
      }
    });

    test('rundet an der Hälfte auf', () {
      expect(rundeAuf5Rappen(0.025), 0.05);
      expect(rundeAuf5Rappen(74.625), 74.65);
    });

    test('negative Beträge (Gutschrift/Korrektur)', () {
      expect(rundeAuf5Rappen(-74.59), -74.60);
      expect(rundeAuf5Rappen(-0.02), 0.0);
    });
  });

  group('bruttoKundenrechnung', () {
    test('die 38 nachgetragenen Fälle ergeben 5-Rappen-Beträge', () {
      // Netto-Werte aus den real betroffenen Reinigungen, MwSt 8.1%.
      for (final netto in [69.0, 105.0, 110.0, 99.0, 128.0, 117.0]) {
        final brutto = bruttoKundenrechnung(netto, 0.081);
        expect(istAuf5Rappen(brutto), isTrue,
            reason: 'netto $netto -> $brutto ist nicht auf 5 Rappen');
      }
    });

    test('Alpenblick Arosa: 128.00 netto + 8.1% -> 138.35, nicht 138.37', () {
      // Der konkrete Fall, an dem der Fehler auffiel. Alte Rechnung:
      // _round2(128 * 1.081) = 138.37. Richtig ist 138.35.
      expect(bruttoKundenrechnung(128.0, 0.081), 138.35);
    });

    test('MwSt ergibt sich aus dem gerundeten Brutto minus Netto', () {
      final netto = 128.0;
      final brutto = bruttoKundenrechnung(netto, 0.081);
      final mwst = rundeAufRappen(brutto - netto);
      expect(rundeAufRappen(netto + mwst), brutto,
          reason: 'Netto + MwSt muss exakt das Brutto ergeben');
    });

    test('mwstFaktor 0 (befreit) -> Brutto = Netto, auf 5 Rappen', () {
      expect(bruttoKundenrechnung(74.60, 0), 74.60);
    });
  });

  group('istAuf5Rappen', () {
    test('erkennt krumme Beträge', () {
      expect(istAuf5Rappen(74.60), isTrue);
      expect(istAuf5Rappen(74.59), isFalse);
      expect(istAuf5Rappen(138.37), isFalse);
    });
  });
}

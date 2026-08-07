import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/heineken_buchung_betraege.dart';

void main() {
  group('heinekenBuchungsBetraege', () {
    test('übernimmt das Rechnungsbrutto exakt — KEINE 5-Rappen-Rundung', () {
      // April 2026: Rechnung 5817.40 netto / 6288.62 brutto.
      // Der alte Fehler machte daraus 6288.60 (5 Rappen) → Invariante verletzt.
      final b = heinekenBuchungsBetraege(netto: 5817.40, brutto: 6288.62);
      expect(b.brutto, 6288.62);
      expect(b.netto, 5817.40);
      expect(b.mwst, closeTo(471.22, 0.001));
    });

    test('Invariante brutto = netto + mwst gilt konstruktiv', () {
      // Mai 2026 und Juni 2026 (die beiden anderen Schadensfälle).
      for (final fall in [
        (netto: 5733.80, brutto: 6198.24, mwst: 464.44),
        (netto: 6100.80, brutto: 6594.96, mwst: 494.16),
      ]) {
        final b = heinekenBuchungsBetraege(netto: fall.netto, brutto: fall.brutto);
        expect(b.mwst, closeTo(fall.mwst, 0.001));
        expect(b.netto + b.mwst, closeTo(b.brutto, 0.004),
            reason: 'SaldoExpansion-Assert verlangt |brutto − netto − mwst| < 0.005');
      }
    });

    test('rundet krumme Eingaben auf Rappen', () {
      final b = heinekenBuchungsBetraege(netto: 100.004, brutto: 108.106);
      expect(b.netto, 100.00);
      expect(b.brutto, 108.11);
      expect(b.mwst, closeTo(8.11, 0.001));
    });
  });
}

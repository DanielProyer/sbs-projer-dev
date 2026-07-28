import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/beleg_korrektur.dart';

void main() {
  group('runde5Rappen', () {
    test('rundet kaufmännisch auf 5 Rappen', () {
      expect(runde5Rappen(89.68), 89.70);
      expect(runde5Rappen(6.72), 6.70);
      expect(runde5Rappen(10.13), 10.15);
      expect(runde5Rappen(0.02), 0.0);
    });
  });

  group('verteileBarRundung (Regel Daniel 28.07.: nur Total runden)', () {
    test('Einzelbeträge bleiben, Differenz geht an die grösste Position', () {
      // Coop Pronto: 89.68 + 6.75 + 10.10 = 106.53 -> Total 106.55
      final r = verteileBarRundung([89.68, 6.75, 10.10]);
      expect(r, [89.70, 6.75, 10.10]);
      expect(r.reduce((a, b) => a + b), closeTo(106.55, 0.001));
    });

    test('Summe der Positionen entspricht IMMER dem gerundeten Total', () {
      for (final fall in [
        [12.31, 4.44],
        [0.02, 5.55, 100.01],
        [7.77],
        [1.11, 2.22, 3.33, 4.44],
      ]) {
        final r = verteileBarRundung(fall);
        final summe = r.reduce((a, b) => a + b);
        final total = runde5Rappen(fall.reduce((a, b) => a + b));
        expect(summe, closeTo(total, 0.001), reason: '$fall');
      }
    });

    test('bereits gerundetes Total bleibt unverändert', () {
      expect(verteileBarRundung([10.00, 5.05]), [10.00, 5.05]);
    });

    test('einzelne Position: nur diese wird gerundet', () {
      expect(verteileBarRundung([89.68]), [89.70]);
    });

    test('leere Liste -> leere Liste', () {
      expect(verteileBarRundung([]), isEmpty);
    });

    test('grösste Position wird auch bei Abrundung getroffen', () {
      // 3.33 + 3.33 = 6.66 -> 6.65, Differenz -0.01 auf die erste 3.33
      final r = verteileBarRundung([3.33, 3.33]);
      expect(r.reduce((a, b) => a + b), closeTo(6.65, 0.001));
    });
  });

  group('differenzZumTotal', () {
    test('stimmt überein -> null', () {
      expect(differenzZumTotal([5.50, 4.50], 10.00), isNull);
      // Rundungsrauschen unter einem Rappen zählt nicht als Abweichung
      expect(differenzZumTotal([5.504], 5.50), isNull);
    });
    test('Positionen zu tief -> positive Differenz', () {
      expect(differenzZumTotal([5.00], 10.00), closeTo(5.00, 0.001));
    });
    test('Positionen zu hoch -> negative Differenz', () {
      expect(differenzZumTotal([15.00], 10.00), closeTo(-5.00, 0.001));
    });
  });

  group('dublettenTreffer', () {
    final kandidaten = [
      DublettenKandidat(
          beschreibung: 'Coop Pronto - Diesel (42.91 L)', brutto: 89.68),
      DublettenKandidat(beschreibung: 'Coop Pronto - Non-Food', brutto: 10.10),
      DublettenKandidat(beschreibung: 'BAUHAUS Mels', brutto: 168.80),
    ];

    test('gleiches Geschäft und gleiche Summe -> Treffer', () {
      expect(dublettenTreffer(kandidaten, 'Coop Pronto', 99.78), isTrue);
    });
    test('Gross-/Kleinschreibung egal', () {
      expect(dublettenTreffer(kandidaten, 'bauhaus mels', 168.80), isTrue);
    });
    test('gleiches Geschäft, andere Summe -> kein Treffer', () {
      expect(dublettenTreffer(kandidaten, 'Coop Pronto', 55.00), isFalse);
    });
    test('anderes Geschäft -> kein Treffer', () {
      expect(dublettenTreffer(kandidaten, 'Migros', 89.68), isFalse);
    });
    test('Rappen-Toleranz (5-Rappen-Rundung bar)', () {
      expect(dublettenTreffer(kandidaten, 'BAUHAUS', 168.82), isTrue);
    });
    test('keine Kandidaten -> kein Treffer', () {
      expect(dublettenTreffer([], 'Coop Pronto', 99.78), isFalse);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/heineken_positionen_pruefung.dart';

/// Wächter vor der Freigabe einer Heineken-Monatsrechnung.
///
/// WARUM so gründlich getestet: Die Prüfung ist die letzte Stelle vor der
/// Debitoren- und Ertragsbuchung. Schlägt sie fälschlich nicht an, wandert ein
/// falscher Betrag in die Bücher und fällt erst beim Zahlungseingang auf —
/// genau der Fall vom August 2026 (250.00 zu viel).
void main() {
  group('Abweichungen finden', () {
    test('alles gleich: kein Befund', () {
      final r = positionsAbweichungen(
        gespeichert: const {'Störungen': 3184.60, 'Montagen': 8600.00},
        berechnet: const {'Störungen': 3184.60, 'Montagen': 8600.00},
      );
      expect(r, isEmpty);
    });

    test('der August-Fall wird erkannt', () {
      // Gespeichert 3'434.60, Quelldaten 3'184.60 — die 250.00, die im PDF
      // nie standen.
      final r = positionsAbweichungen(
        gespeichert: const {'Störungen': 3434.60},
        berechnet: const {'Störungen': 3184.60},
      );
      expect(r, hasLength(1));
      expect(r.single.kategorie, 'Störungen');
      expect(r.single.differenz, closeTo(250.00, 0.001));
    });

    test('Rappen-Rauschen schlägt nicht an', () {
      final r = positionsAbweichungen(
        gespeichert: const {'Pikett': 80.00},
        berechnet: const {'Pikett': 80.004},
      );
      expect(r, isEmpty);
    });

    test('ein ganzer Rappen schlägt an', () {
      final r = positionsAbweichungen(
        gespeichert: const {'Pikett': 80.00},
        berechnet: const {'Pikett': 80.01},
      );
      expect(r, hasLength(1));
    });

    test('fehlende Position zählt als 0, nicht als «egal»', () {
      // Sonst fiele eine ganz verlorene Kategorie durch die Prüfung.
      final r = positionsAbweichungen(
        gespeichert: const {'Störungen': 100.00},
        berechnet: const {'Störungen': 100.00, 'Montagen': 8600.00},
      );
      expect(r, hasLength(1));
      expect(r.single.kategorie, 'Montagen');
      expect(r.single.aufRechnung, 0);
      expect(r.single.differenz, closeTo(-8600.00, 0.001));
    });

    test('zusätzliche Position auf der Rechnung fällt ebenso auf', () {
      final r = positionsAbweichungen(
        gespeichert: const {'Störungen': 100.00, 'Diverses': 500.00},
        berechnet: const {'Störungen': 100.00},
      );
      expect(r.single.kategorie, 'Diverses');
      expect(r.single.differenz, closeTo(500.00, 0.001));
    });

    test('grösste Abweichung steht oben', () {
      final r = positionsAbweichungen(
        gespeichert: const {'A': 110.00, 'B': 1000.00, 'C': 55.00},
        berechnet: const {'A': 100.00, 'B': 0.00, 'C': 0.00},
      );
      expect(r.map((e) => e.kategorie).toList(), ['B', 'C', 'A']);
    });
  });

  group('Kopfsumme', () {
    test('Kopf gleich Summe der Positionen: keine Abweichung', () {
      expect(
        kopfAbweichung(
          kopfNetto: 12919.60,
          gespeichert: const {'Störungen': 3184.60, 'Rest': 9735.00},
        ),
        closeTo(0, 0.001),
      );
    });

    test('Kopf zu hoch wird als positive Differenz gemeldet', () {
      expect(
        kopfAbweichung(
          kopfNetto: 13169.60,
          gespeichert: const {'Störungen': 3184.60, 'Rest': 9735.00},
        ),
        closeTo(250.00, 0.001),
      );
    });
  });

  group('Text für den Dialog', () {
    test('nennt Kategorie, beide Beträge und das Vorzeichen', () {
      final text = abweichungsText(
        positionsAbweichungen(
          gespeichert: const {'Störungen': 3434.60},
          berechnet: const {'Störungen': 3184.60},
        ),
        0,
      );
      expect(text, contains('Störungen'));
      expect(text, contains('3434.60'));
      expect(text, contains('3184.60'));
      expect(text, contains('+250.00'));
    });

    test('negative Differenz ohne Pluszeichen', () {
      // Der bekannte Fall: Die Störung 438 wurde nach dem Versand auf zwei
      // Bereiche korrigiert, die Rechnung blieb bewusst auf dem PDF-Wert.
      final text = abweichungsText(
        positionsAbweichungen(
          gespeichert: const {'Störungen': 3184.60},
          berechnet: const {'Störungen': 3239.60},
        ),
        0,
      );
      expect(text, contains('-55.00'));
      expect(text, isNot(contains('+')));
    });

    test('Kopfabweichung bekommt eine eigene Zeile', () {
      final text = abweichungsText(const [], 250.00);
      expect(text, contains('Kopfsumme'));
      expect(text, contains('250.00'));
    });

    test('alles sauber ergibt leeren Text', () {
      expect(abweichungsText(const [], 0), isEmpty);
    });
  });
}

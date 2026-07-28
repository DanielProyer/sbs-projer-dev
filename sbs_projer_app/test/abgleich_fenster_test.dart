import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/abgleich_fenster.dart';

void main() {
  final heute = DateTime(2026, 7, 28);

  group('istImAbgleichsfenster (Regel Daniel 28.07.2026)', () {
    test('heutige Rechnung ist drin', () {
      expect(istImAbgleichsfenster(DateTime(2026, 7, 28), heute), isTrue);
    });

    test('genau ein Jahr alt zählt noch dazu', () {
      expect(istImAbgleichsfenster(DateTime(2025, 7, 28), heute), isTrue);
    });

    test('einen Tag älter fällt raus', () {
      expect(istImAbgleichsfenster(DateTime(2025, 7, 27), heute), isFalse);
    });

    test('Altforderung von 2019 fällt raus', () {
      expect(istImAbgleichsfenster(DateTime(2019, 5, 6), heute), isFalse);
    });

    test('Rechnung aus der Zukunft bleibt sichtbar', () {
      expect(istImAbgleichsfenster(DateTime(2026, 12, 31), heute), isTrue);
    });

    test('Uhrzeit spielt keine Rolle', () {
      expect(istImAbgleichsfenster(DateTime(2025, 7, 28, 23, 59), heute), isTrue);
      expect(
          istImAbgleichsfenster(DateTime(2025, 7, 27, 23, 59), heute), isFalse);
    });

    test('Schaltjahr: 29.02. als Stichtag', () {
      final schalttag = DateTime(2024, 2, 29);
      expect(istImAbgleichsfenster(DateTime(2023, 3, 1), schalttag), isTrue);
      expect(istImAbgleichsfenster(DateTime(2023, 2, 27), schalttag), isFalse);
    });

    test('Fenster ist einstellbar', () {
      expect(istImAbgleichsfenster(DateTime(2024, 8, 1), heute, jahre: 2),
          isTrue);
      expect(istImAbgleichsfenster(DateTime(2024, 7, 1), heute, jahre: 2),
          isFalse);
    });
  });
}

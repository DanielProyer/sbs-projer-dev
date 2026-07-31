import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/war_geschlossen.dart';

void main() {
  group('istHeuteOderVergangenerTag', () {
    final heute = DateTime(2026, 7, 31, 14, 30);

    test('heute (auch mit anderer Uhrzeit) -> true', () {
      expect(
        istHeuteOderVergangenerTag(DateTime(2026, 7, 31), jetzt: heute),
        isTrue,
      );
    });

    test('gestern -> true', () {
      expect(
        istHeuteOderVergangenerTag(DateTime(2026, 7, 30), jetzt: heute),
        isTrue,
      );
    });

    test('lange vergangen -> true', () {
      expect(
        istHeuteOderVergangenerTag(DateTime(2020, 1, 1), jetzt: heute),
        isTrue,
      );
    });

    test('morgen -> false', () {
      expect(
        istHeuteOderVergangenerTag(DateTime(2026, 8, 1), jetzt: heute),
        isFalse,
      );
    });

    test('kuenftig -> false', () {
      expect(
        istHeuteOderVergangenerTag(DateTime(2027, 1, 1), jetzt: heute),
        isFalse,
      );
    });
  });

  group('heutigesWochentagKuerzel', () {
    test('Montag', () {
      // 27.07.2026 ist ein Montag.
      expect(heutigesWochentagKuerzel(jetzt: DateTime(2026, 7, 27)), 'Mo');
    });

    test('Freitag', () {
      // 31.07.2026 ist ein Freitag.
      expect(heutigesWochentagKuerzel(jetzt: DateTime(2026, 7, 31)), 'Fr');
    });

    test('Sonntag', () {
      // 02.08.2026 ist ein Sonntag.
      expect(heutigesWochentagKuerzel(jetzt: DateTime(2026, 8, 2)), 'So');
    });
  });

  group('ruhetageErgaenzt', () {
    test('leere Liste -> Tag wird hinzugefuegt', () {
      expect(ruhetageErgaenzt([], 'Mo'), ['Mo']);
    });

    test('Tag bereits vorhanden -> keine Aenderung (idempotent)', () {
      expect(ruhetageErgaenzt(['Mo', 'Di'], 'Mo'), ['Mo', 'Di']);
    });

    test('anderer Tag bereits vorhanden -> wird ergaenzt', () {
      expect(ruhetageErgaenzt(['Mo'], 'Di'), ['Mo', 'Di']);
    });

    test('Sentinel "keine" wird durch den neuen Tag ersetzt', () {
      expect(ruhetageErgaenzt(['keine'], 'Mi'), ['Mi']);
    });
  });

  group('standardFerienfenster', () {
    test('heute bis heute + 14 Tage', () {
      final f = standardFerienfenster(jetzt: DateTime(2026, 7, 31, 9, 15));
      expect(f.von, DateTime(2026, 7, 31));
      expect(f.bis, DateTime(2026, 8, 14));
    });
  });
}

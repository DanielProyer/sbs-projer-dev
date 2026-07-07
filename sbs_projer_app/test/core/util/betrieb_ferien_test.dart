import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/betrieb_ferien.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';

BetriebLocal _betrieb() => BetriebLocal()
  ..userId = 'test'
  ..name = 'Test';

void main() {
  group('ferienSlots', () {
    test('ohne Ferien: 5 leere Slots', () {
      final slots = ferienSlots(_betrieb());
      expect(slots.length, 5);
      expect(slots.every((s) => s.start == null && s.ende == null), isTrue);
    });

    test('liefert alle 5 Slots in Reihenfolge', () {
      final b = _betrieb()
        ..ferienStart = DateTime(2026, 1, 1)
        ..ferien4Start = DateTime(2026, 4, 1)
        ..ferien5Ende = DateTime(2026, 5, 31);
      final slots = ferienSlots(b);
      expect(slots[0].start, DateTime(2026, 1, 1));
      expect(slots[3].start, DateTime(2026, 4, 1));
      expect(slots[4].ende, DateTime(2026, 5, 31));
    });
  });

  group('ferienStarts / ferienEnden', () {
    test('nur belegte Werte, auch aus Slot 4+5', () {
      final b = _betrieb()
        ..ferien2Start = DateTime(2026, 2, 1)
        ..ferien5Start = DateTime(2026, 5, 1)
        ..ferien3Ende = DateTime(2026, 3, 15);
      expect(ferienStarts(b),
          [DateTime(2026, 2, 1), DateTime(2026, 5, 1)]);
      expect(ferienEnden(b), [DateTime(2026, 3, 15)]);
    });
  });

  group('istInFerien', () {
    test('innerhalb Ferien 2 -> true (Bugfix: bisher nur Ferien 1 geprueft)', () {
      final b = _betrieb()
        ..ferien2Start = DateTime(2026, 7, 10)
        ..ferien2Ende = DateTime(2026, 7, 20);
      expect(istInFerien(b, DateTime(2026, 7, 15)), isTrue);
    });

    test('Randtage inklusive', () {
      final b = _betrieb()
        ..ferien4Start = DateTime(2026, 8, 1)
        ..ferien4Ende = DateTime(2026, 8, 14);
      expect(istInFerien(b, DateTime(2026, 8, 1)), isTrue);
      expect(istInFerien(b, DateTime(2026, 8, 14)), isTrue);
      expect(istInFerien(b, DateTime(2026, 7, 31)), isFalse);
      expect(istInFerien(b, DateTime(2026, 8, 15)), isFalse);
    });

    test('unvollstaendiger Slot (nur Start) zaehlt nicht', () {
      final b = _betrieb()..ferien3Start = DateTime(2026, 9, 1);
      expect(istInFerien(b, DateTime(2026, 9, 5)), isFalse);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/event_aufwand_slots.dart';

void main() {
  group('montageSlotsAusAufwand', () {
    test('leere Liste -> keine Slots', () {
      expect(montageSlotsAusAufwand([]), isEmpty);
    });

    test('ein Tag -> ein Slot mit Summe und Datums-Label', () {
      final slots = montageSlotsAusAufwand([
        (datum: DateTime(2026, 7, 25), stunden: 4),
        (datum: DateTime(2026, 7, 25), stunden: 12),
      ]);
      expect(slots.length, 1);
      expect(slots.first.stunden, 16);
      expect(slots.first.text, 'Sa 25.7.'); // 25.7.2026 ist ein Samstag
    });

    test('mehrere Tage nach Datum sortiert', () {
      final slots = montageSlotsAusAufwand([
        (datum: DateTime(2026, 7, 26), stunden: 5),
        (datum: DateTime(2026, 7, 24), stunden: 3),
        (datum: DateTime(2026, 7, 25), stunden: 8),
      ]);
      expect(slots.map((s) => s.stunden).toList(), [3, 8, 5]);
      expect(slots.first.text, 'Fr 24.7.');
    });

    test('mehr als 5 Tage -> 5 Slots, Rest in "Weitere Tage", Summe erhalten', () {
      final zeilen = [
        for (var d = 1; d <= 6; d++)
          (datum: DateTime(2026, 8, d), stunden: 2.0),
      ];
      final slots = montageSlotsAusAufwand(zeilen);
      expect(slots.length, 5);
      expect(slots.last.text, 'Weitere Tage');
      expect(slots.last.stunden, 4);
      final total = slots.fold<double>(0, (s, e) => s + e.stunden);
      expect(total, 12);
    });
  });
}

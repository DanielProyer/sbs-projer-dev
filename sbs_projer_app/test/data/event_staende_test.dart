import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/local/event_stand_local_export.dart';
import 'package:sbs_projer_app/data/models/event_stand.dart';
import 'package:sbs_projer_app/data/repositories/event_stand_repository.dart';

EventStandLocal _s(String name) => EventStandLocal()
  ..userId = 't'
  ..eventId = 'e'
  ..name = name;

void main() {
  group('fehlendeStaende', () {
    test('leeres Ziel: alle', () {
      expect(EventStandRepository.fehlendeStaende([_s('VIP'), _s('Kiosk')], []).length, 2);
    });
    test('gleicher Name (case-insensitive, getrimmt) uebersprungen', () {
      final neu = EventStandRepository.fehlendeStaende(
          [_s('VIP'), _s('Kiosk')], [_s(' vip ')]);
      expect(neu.length, 1);
      expect(neu.first.name, 'Kiosk');
    });
  });

  group('EventStand.anlagenText', () {
    test('Aggregation nach Typ', () {
      final text = EventStand.anlagenText([
        (typ: 'oberthekengeraet', anzahl: 1),
        (typ: 'oberthekengeraet', anzahl: 1),
        (typ: 'hollandbuffet', anzahl: 1),
      ]);
      expect(text, '2× OT · 1× Hollandbuffet');
    });
    test('leere Liste', () {
      expect(EventStand.anlagenText([]), 'Keine Anlagen');
    });
  });
}

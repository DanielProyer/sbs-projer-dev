import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/event_aufwand.dart';

void main() {
  test('fromJson/toJson roundtrip', () {
    final json = {
      'id': 'a1',
      'user_id': 'u1',
      'event_id': 'e1',
      'datum': '2026-07-25',
      'kategorie': 'pikett',
      'notiz': '10:00-02:00',
      'stunden': 16,
    };
    final dto = EventAufwand.fromJson(json);
    expect(dto.eventId, 'e1');
    expect(dto.datum, DateTime(2026, 7, 25));
    expect(dto.kategorie, 'pikett');
    expect(dto.stunden, 16.0);

    final out = dto.toJson();
    expect(out['event_id'], 'e1');
    expect(out['datum'], '2026-07-25');
    expect(out['kategorie'], 'pikett');
    expect(out['stunden'], 16.0);
    expect(out['id'], 'a1');
  });
}

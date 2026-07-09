import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/event_status.dart';

void main() {
  final heute = DateTime(2026, 7, 15);

  group('eventStatus', () {
    test('ohne Termin: offen', () {
      expect(eventStatus(null, null, heute), EventStatus.offen);
    });
    test('vor Beginn: kommend', () {
      expect(eventStatus(DateTime(2026, 7, 20), DateTime(2026, 7, 22), heute),
          EventStatus.kommend);
    });
    test('waehrend (Randtage inklusive): laufend', () {
      expect(eventStatus(DateTime(2026, 7, 15), DateTime(2026, 7, 17), heute),
          EventStatus.laufend);
      expect(eventStatus(DateTime(2026, 7, 13), DateTime(2026, 7, 15), heute),
          EventStatus.laufend);
    });
    test('nach Ende: vorbei', () {
      expect(eventStatus(DateTime(2026, 7, 1), DateTime(2026, 7, 3), heute),
          EventStatus.vorbei);
    });
    test('nur von gesetzt: von zaehlt als ganzer Event-Tag', () {
      expect(eventStatus(DateTime(2026, 7, 15), null, heute), EventStatus.laufend);
      expect(eventStatus(DateTime(2026, 7, 10), null, heute), EventStatus.vorbei);
      expect(eventStatus(DateTime(2026, 7, 20), null, heute), EventStatus.kommend);
    });
  });
}

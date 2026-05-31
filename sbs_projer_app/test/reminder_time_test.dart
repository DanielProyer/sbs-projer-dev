import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/notification/reminder_time.dart';

void main() {
  group('berechneErinnerungszeitpunkt', () {
    test('mit Uhrzeit: Datum+Uhrzeit minus Vorlauf', () {
      final r = berechneErinnerungszeitpunkt(
        datum: DateTime(2026, 6, 10),
        uhrzeitVon: '14:30',
        vorlaufMinuten: 60,
      );
      expect(r, DateTime(2026, 6, 10, 13, 30));
    });

    test('ohne Uhrzeit: 08:00 als Bezug minus Vorlauf', () {
      final r = berechneErinnerungszeitpunkt(
        datum: DateTime(2026, 6, 10),
        uhrzeitVon: null,
        vorlaufMinuten: 1440,
      );
      expect(r, DateTime(2026, 6, 9, 8, 0));
    });

    test('Vorlauf 0: exakt zum Termin', () {
      final r = berechneErinnerungszeitpunkt(
        datum: DateTime(2026, 6, 10),
        uhrzeitVon: '09:15',
        vorlaufMinuten: 0,
      );
      expect(r, DateTime(2026, 6, 10, 9, 15));
    });

    test('ungueltige Uhrzeit faellt auf 08:00 zurueck', () {
      final r = berechneErinnerungszeitpunkt(
        datum: DateTime(2026, 6, 10),
        uhrzeitVon: 'abc',
        vorlaufMinuten: 0,
      );
      expect(r, DateTime(2026, 6, 10, 8, 0));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/stand_position.dart';

void main() {
  group('positionsAbgleich', () {
    test('noch keine Position: GPS wird ohne Rückfrage übernommen', () {
      final a = positionsAbgleich(
        bisherLat: null,
        bisherLng: null,
        bisherQuelle: null,
        neuLat: 46.85,
        neuLng: 9.53,
      );
      expect(a.brauchtRueckfrage, isFalse);
      expect(a.distanzMeter, isNull);
    });

    test('geplante Position vorhanden: Rückfrage mit Distanz', () {
      final a = positionsAbgleich(
        bisherLat: 46.85000,
        bisherLng: 9.53000,
        bisherQuelle: 'karte',
        neuLat: 46.85010,
        neuLng: 9.53000,
      );
      expect(a.brauchtRueckfrage, isTrue);
      // 0.0001° Breite ≈ 11 m
      expect(a.distanzMeter, closeTo(11, 1.5));
      expect(a.bisherWarGeplant, isTrue);
    });

    test('bereits gemessene Position: Rückfrage ebenfalls — nie stilles '
        'Überschreiben', () {
      final a = positionsAbgleich(
        bisherLat: 46.85,
        bisherLng: 9.53,
        bisherQuelle: 'gps',
        neuLat: 46.86,
        neuLng: 9.54,
      );
      expect(a.brauchtRueckfrage, isTrue);
      expect(a.bisherWarGeplant, isFalse);
    });

    test('halbe Position (nur lat) zählt als keine', () {
      final a = positionsAbgleich(
        bisherLat: 46.85,
        bisherLng: null,
        bisherQuelle: 'karte',
        neuLat: 46.85,
        neuLng: 9.53,
      );
      expect(a.brauchtRueckfrage, isFalse);
    });

    test('identische Position: Distanz 0, Rückfrage trotzdem', () {
      final a = positionsAbgleich(
        bisherLat: 46.85,
        bisherLng: 9.53,
        bisherQuelle: 'karte',
        neuLat: 46.85,
        neuLng: 9.53,
      );
      expect(a.distanzMeter, closeTo(0, 0.01));
      expect(a.brauchtRueckfrage, isTrue);
    });
  });

  group('distanzText', () {
    test('unter 1000 m in ganzen Metern', () {
      expect(distanzText(0), '0 m');
      expect(distanzText(11.4), '11 m');
      expect(distanzText(999.6), '1000 m');
    });

    test('ab 1000 m in Kilometern mit einer Nachkommastelle', () {
      expect(distanzText(1000), '1.0 km');
      expect(distanzText(2540), '2.5 km');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/koordinaten_parser.dart';

void main() {
  group('koordinatenAus — Google-Maps-Formate', () {
    test('Standardformat aus «Koordinaten kopieren»', () {
      final k = koordinatenAus('46.849994916702336, 9.532274794958706');
      expect(k, isNotNull);
      expect(k!.lat, closeTo(46.849994916702336, 1e-12));
      expect(k.lng, closeTo(9.532274794958706, 1e-12));
    });

    test('ohne Leerzeichen', () {
      expect(koordinatenAus('46.85,9.53')!.lat, 46.85);
    });

    test('mit Semikolon getrennt', () {
      expect(koordinatenAus('46.85; 9.53')!.lng, 9.53);
    });

    test('mit umschliessenden Leerzeichen und Zeilenumbruch', () {
      expect(koordinatenAus('  46.85 , 9.53 \n')!.lat, 46.85);
    });

    test('Google-Maps-URL mit @lat,lng,zoom', () {
      final k = koordinatenAus(
          'https://www.google.com/maps/@46.849994,9.532274,19z');
      expect(k!.lat, closeTo(46.849994, 1e-9));
      expect(k.lng, closeTo(9.532274, 1e-9));
    });

    test('Google-Maps-URL mit ?q=', () {
      final k = koordinatenAus('https://maps.google.com/?q=46.849994,9.532274');
      expect(k!.lat, closeTo(46.849994, 1e-9));
    });

    test('negative Werte (Südhalbkugel / westliche Länge)', () {
      final k = koordinatenAus('-33.8688, 151.2093');
      expect(k!.lat, closeTo(-33.8688, 1e-9));
      expect(k.lng, closeTo(151.2093, 1e-9));
    });
  });

  group('koordinatenAus — Ungültiges', () {
    test('leer', () {
      expect(koordinatenAus(''), isNull);
      expect(koordinatenAus('   '), isNull);
    });

    test('nur eine Zahl', () {
      expect(koordinatenAus('46.85'), isNull);
    });

    test('Text ohne Zahlen', () {
      expect(koordinatenAus('Standplatz beim Brunnen'), isNull);
    });

    test('Breite ausserhalb -90..90', () {
      expect(koordinatenAus('96.5, 9.5'), isNull);
    });

    test('Länge ausserhalb -180..180', () {
      expect(koordinatenAus('46.85, 190.2'), isNull);
    });
  });

  group('istInDerSchweiz — Plausibilitätswarnung', () {
    test('Chur liegt drin', () {
      expect(istInDerSchweiz(46.8499, 9.5322), isTrue);
    });

    test('Sydney nicht', () {
      expect(istInDerSchweiz(-33.8688, 151.2093), isFalse);
    });

    test('vertauschte Koordinaten fallen auf', () {
      // 9.53 / 46.85 wäre Nigeria — genau der Tippfehler, den die Warnung
      // abfangen soll.
      expect(istInDerSchweiz(9.5322, 46.8499), isFalse);
    });
  });
}

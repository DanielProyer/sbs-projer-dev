import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/fahrzeit.dart';

void main() {
  group('haversineKm', () {
    test('Chur -> Davos ~ 24 km Luftlinie', () {
      final km = haversineKm(46.8508, 9.5320, 46.8027, 9.8360);
      expect(km, closeTo(23.7, 1.5)); // echte Luftlinie Chur-Davos ~23-24 km
    });
    test('identischer Punkt = 0', () {
      expect(haversineKm(47.0, 9.0, 47.0, 9.0), 0);
    });
  });

  group('heuristikMinuten', () {
    test('45 km/h Schnitt x Faktor 1.6', () {
      // 30 km Luftlinie -> 48 km Strasse -> 64 min
      expect(heuristikMinuten(luftlinieKm: 30, faktor: 1.6), 64);
    });
    test('Minimum 3 min fuer Nachbarn', () {
      expect(heuristikMinuten(luftlinieKm: 0.3, faktor: 1.6), 3);
    });
    test('Standard-Faktor ist kalibriert (2.2, Stand 29.07.2026)', () {
      // 30 km Luftlinie x 2.2 / 45 km/h = 88 min effektive Uebergangszeit
      // (inkl. Parkieren/Umladen — so wurde gegen die Beobachtungen geeicht).
      expect(kFahrzeitFaktor, 2.2);
      expect(heuristikMinuten(luftlinieKm: 30), 88);
    });
  });

  group('waehleFahrzeit', () {
    test('beobachtet schlaegt route schlaegt heuristik', () {
      expect(waehleFahrzeit(beobachtet: 12, route: 20, heuristik: 30), (12, FahrzeitQuelle.beobachtet));
      expect(waehleFahrzeit(beobachtet: null, route: 20, heuristik: 30), (20, FahrzeitQuelle.route));
      expect(waehleFahrzeit(beobachtet: null, route: null, heuristik: 30), (30, FahrzeitQuelle.heuristik));
    });
  });

  group('fahrtLueckeMinuten (Beobachtungs-Nachfuehrung)', () {
    test('normale Luecke: Minutendifferenz', () {
      expect(fahrtLueckeMinuten('10:00', '10:15'), 15);
    });
    test('negative Luecke (Ende nach neuem Start): null', () {
      expect(fahrtLueckeMinuten('10:20', '10:15'), isNull);
    });
    test('Luecke ueber 120 min: null', () {
      expect(fahrtLueckeMinuten('08:00', '11:00'), isNull);
    });
    test('Grenzwert exakt 3 min: gueltig', () {
      expect(fahrtLueckeMinuten('10:00', '10:03'), 3);
    });
    test('Grenzwert exakt 120 min: gueltig', () {
      expect(fahrtLueckeMinuten('08:00', '10:00'), 120);
    });
    test('Grenzwert 121 min: null', () {
      expect(fahrtLueckeMinuten('08:00', '10:01'), isNull);
    });
    test('Grenzwert 2 min: null', () {
      expect(fahrtLueckeMinuten('10:00', '10:02'), isNull);
    });
  });
}

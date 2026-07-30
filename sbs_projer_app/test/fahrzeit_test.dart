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

  group('heuristikMinuten (kalibriert 31.07.2026 an 804 echten Routen)', () {
    test('Untergrenze 3 min bei reiner Fahrzeit', () {
      expect(heuristikMinuten(luftlinieKm: 0.3, mitRuestzeit: false), 3);
    });

    test('Nachbarbetrieb: kurze Fahrt, aber Ruestzeit zaehlt', () {
      // 300 m Luftlinie ist fahrtechnisch nichts — Parkieren und Umladen
      // brauchen trotzdem ihre Minuten.
      expect(heuristikMinuten(luftlinieKm: 0.3), kRuestzuschlagMin + 1);
    });

    test('Ruestzuschlag nur zwischen Besuchen', () {
      final mit = heuristikMinuten(luftlinieKm: 20);
      final ohne = heuristikMinuten(luftlinieKm: 20, mitRuestzeit: false);
      expect(mit - ohne, kRuestzuschlagMin);
    });

    test('Fernstrecke realistisch — Fall Sonne Seehotel Eich', () {
      // Domat/Ems -> Eich: 104 km Luftlinie, echte Route 117 min.
      // Das alte Modell (x2.5 / 45 km/h) lieferte hier 346 min.
      final min = heuristikMinuten(luftlinieKm: 103.7, mitRuestzeit: false);
      expect(min, closeTo(117, 12));
    });

    test('Nahbereich bleibt im Bergtempo', () {
      // 8 km im Bündner Tal: real gut 15 min inkl. Ortsdurchfahrten.
      final min = heuristikMinuten(luftlinieKm: 8, mitRuestzeit: false);
      expect(min, inInclusiveRange(12, 22));
    });

    test('monoton steigend', () {
      var vorher = 0;
      for (final km in [1.0, 5.0, 12.0, 30.0, 60.0, 120.0, 200.0]) {
        final min = heuristikMinuten(luftlinieKm: km);
        expect(min, greaterThan(vorher));
        vorher = min;
      }
    });

    test('Schnitt bleibt in plausiblen Grenzen', () {
      for (final km in [2.0, 10.0, 50.0, 150.0]) {
        final stunden = reineFahrzeitMinuten(km) / 60;
        final effektivKmh = km / stunden; // Luftlinien-Tempo
        expect(effektivKmh, greaterThan(10));
        expect(effektivKmh, lessThan(60));
      }
    });
  });

  group('lueckePlausibel (Störungs-/Pausen-Filter, 30.07.2026)', () {
    test('ohne Referenz wird nicht gefiltert', () {
      expect(
        lueckePlausibel(lueckeMinuten: 137, referenzMinuten: null),
        isTrue,
      );
    });

    test('normale Fahrt mit etwas Parkieren: plausibel', () {
      // Route 15 min, real 22 min — Parkieren, Umladen, eine rote Welle.
      expect(lueckePlausibel(lueckeMinuten: 22, referenzMinuten: 15), isTrue);
    });

    test('Störung dazwischen: verworfen', () {
      // Fall Migros Golfpark -> Restaurant Linden am 30.07.: Route ~15 min,
      // gemessen 137 min (Störung + 25 min Pause).
      expect(lueckePlausibel(lueckeMinuten: 137, referenzMinuten: 15), isFalse);
    });

    test('Terminwartezeit: verworfen', () {
      // Türmli -> Schlagerbar: Route ~10 min, aber Termin erst um 16:00.
      expect(lueckePlausibel(lueckeMinuten: 55, referenzMinuten: 10), isFalse);
    });

    test('kurze Strecke: Toleranz greift', () {
      // Route 4 min, real 9 min — ohne Toleranz wäre 2x4=8 zu streng.
      expect(lueckePlausibel(lueckeMinuten: 9, referenzMinuten: 4), isTrue);
      // 30 min bei 4 min Route ist auch mit Toleranz nicht mehr plausibel.
      expect(lueckePlausibel(lueckeMinuten: 30, referenzMinuten: 4), isFalse);
    });

    test('unrealistisch schnell: verworfen', () {
      // Halb so lang wie die Route — da stimmt eine der Uhrzeiten nicht.
      expect(lueckePlausibel(lueckeMinuten: 8, referenzMinuten: 40), isFalse);
    });

    test('exakt an den Grenzen', () {
      expect(lueckePlausibel(lueckeMinuten: 10, referenzMinuten: 20), isTrue);
      expect(lueckePlausibel(lueckeMinuten: 9, referenzMinuten: 20), isFalse);
      expect(lueckePlausibel(lueckeMinuten: 50, referenzMinuten: 20), isTrue);
      expect(lueckePlausibel(lueckeMinuten: 51, referenzMinuten: 20), isFalse);
    });
  });

  group('waehleFahrzeit', () {
    test('beobachtet schlaegt route schlaegt heuristik', () {
      expect(waehleFahrzeit(beobachtet: 12, route: 20, heuristik: 30), (
        12,
        FahrzeitQuelle.beobachtet,
      ));
      expect(waehleFahrzeit(beobachtet: null, route: 20, heuristik: 30), (
        20,
        FahrzeitQuelle.route,
      ));
      expect(waehleFahrzeit(beobachtet: null, route: null, heuristik: 30), (
        30,
        FahrzeitQuelle.heuristik,
      ));
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

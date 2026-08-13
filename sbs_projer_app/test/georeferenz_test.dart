import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/georeferenz.dart';

void main() {
  // Testgelände: Gampel (Rhonetal), ~46.31 N / 7.74 E.
  const lat0 = 46.31;
  const lng0 = 7.74;

  /// Baut Passpunkte für einen Plan, der [rotationGrad] gegen Nord verdreht
  /// ist und [meterProPixel] Auflösung hat. Bild-Pixel (px, py nach unten)
  /// → Weltpunkt. So lässt sich die erwartete Abbildung exakt konstruieren.
  ({double lat, double lng}) weltpunkt(
      double px, double py, double rotationGrad, double meterProPixel) {
    final phi = rotationGrad * pi / 180;
    // Bild-y zeigt nach unten → Nordanteil negativ.
    final ost = (px * cos(phi) - (-py) * sin(phi)) * meterProPixel;
    final nord = (px * sin(phi) + (-py) * cos(phi)) * meterProPixel;
    const mProGradLat = 111319.49;
    final mProGradLng = mProGradLat * cos(lat0 * pi / 180);
    return (lat: lat0 + nord / mProGradLat, lng: lng0 + ost / mProGradLng);
  }

  // Die Implementierung rechnet ihren Meter-Massstab am Schwerpunkt der
  // Kartenpunkte, die Testkonstruktion bei lat0 — die cos-Differenz erzeugt
  // Zentimeter-Effekte über das Testgelände. 1e-6° (~10 cm) ist die ehrliche
  // Toleranz; fürs Auflegen eines «groben Lageplans» ohnehin um Grössen-
  // ordnungen besser als nötig.
  const tol = 1e-6;

  group('Georeferenz.berechne — 2 Punkte (Ähnlichkeit)', () {
    test('genordeter Plan: dritter Punkt wird korrekt abgebildet', () {
      final p1 = weltpunkt(100, 100, 0, 0.5);
      final p2 = weltpunkt(1500, 900, 0, 0.5);
      final g = Georeferenz.berechne([
        (px: 100, py: 100, lat: p1.lat, lng: p1.lng),
        (px: 1500, py: 900, lat: p2.lat, lng: p2.lng),
      ]);
      expect(g, isNotNull);
      final soll = weltpunkt(800, 500, 0, 0.5);
      final ist = g!.bildZuKarte(800, 500);
      expect(ist.lat, closeTo(soll.lat, tol)); // ~1 cm
      expect(ist.lng, closeTo(soll.lng, tol));
      expect(g.rmsMeter, closeTo(0, 0.01));
    });

    test('um 30° verdrehter Plan wird richtig gedreht', () {
      final p1 = weltpunkt(0, 0, 30, 0.4);
      final p2 = weltpunkt(1600, 1131, 30, 0.4);
      final g = Georeferenz.berechne([
        (px: 0, py: 0, lat: p1.lat, lng: p1.lng),
        (px: 1600, py: 1131, lat: p2.lat, lng: p2.lng),
      ]);
      final soll = weltpunkt(1600, 0, 30, 0.4);
      final ist = g!.bildZuKarte(1600, 0);
      expect(ist.lat, closeTo(soll.lat, tol));
      expect(ist.lng, closeTo(soll.lng, tol));
    });

    test('identische Punkte → null (degeneriert)', () {
      expect(
        Georeferenz.berechne([
          (px: 10, py: 10, lat: lat0, lng: lng0),
          (px: 10, py: 10, lat: lat0, lng: lng0),
        ]),
        isNull,
      );
    });

    test('weniger als 2 Punkte → null', () {
      expect(Georeferenz.berechne([]), isNull);
      expect(
        Georeferenz.berechne([(px: 1, py: 1, lat: lat0, lng: lng0)]),
        isNull,
      );
    });
  });

  group('Georeferenz.berechne — ab 3 Punkten (affin)', () {
    test('3 Punkte exakt, 4. Punkt stimmt', () {
      ({double px, double py, double lat, double lng}) paar(
          double px, double py) {
        final w = weltpunkt(px, py, 12, 0.35);
        return (px: px, py: py, lat: w.lat, lng: w.lng);
      }

      final g = Georeferenz.berechne(
          [paar(50, 60), paar(1550, 80), paar(700, 1100)]);
      final soll = weltpunkt(400, 400, 12, 0.35);
      final ist = g!.bildZuKarte(400, 400);
      expect(ist.lat, closeTo(soll.lat, tol));
      expect(ist.lng, closeTo(soll.lng, tol));
      expect(g.rmsMeter, closeTo(0, 0.01));
    });

    test('4 Punkte mit einem Ausreisser: Residuum zeigt auf den Ausreisser',
        () {
      ({double px, double py, double lat, double lng}) paar(
          double px, double py) {
        final w = weltpunkt(px, py, 0, 0.5);
        return (px: px, py: py, lat: w.lat, lng: w.lng);
      }

      // Vierter Punkt bewusst ~28 m daneben (0.00025° Breite).
      final schief = weltpunkt(1400, 1000, 0, 0.5);
      final g = Georeferenz.berechne([
        paar(100, 100),
        paar(1500, 100),
        paar(100, 1000),
        (px: 1400, py: 1000, lat: schief.lat + 0.00025, lng: schief.lng),
      ]);
      expect(g, isNotNull);
      // Ausreisser trägt das grösste Residuum, RMS deutlich über 0.
      final r = g!.residuenMeter;
      expect(r.length, 4);
      expect(r[3], greaterThan(r[0]));
      expect(r[3], greaterThan(r[1]));
      expect(r[3], greaterThan(r[2]));
      expect(g.rmsMeter, greaterThan(5));
    });

    test('3 kollineare Punkte → null (Ebene nicht bestimmbar)', () {
      ({double px, double py, double lat, double lng}) paar(
          double px, double py) {
        final w = weltpunkt(px, py, 0, 0.5);
        return (px: px, py: py, lat: w.lat, lng: w.lng);
      }

      expect(
        Georeferenz.berechne([paar(0, 0), paar(500, 500), paar(1000, 1000)]),
        isNull,
      );
    });
  });

  group('ecken — Overlay-Eckpunkte', () {
    test('genordeter Plan: topLeft nördlich von bottomLeft, links von '
        'bottomRight', () {
      final p1 = weltpunkt(0, 0, 0, 0.5);
      final p2 = weltpunkt(1600, 1131, 0, 0.5);
      final g = Georeferenz.berechne([
        (px: 0, py: 0, lat: p1.lat, lng: p1.lng),
        (px: 1600, py: 1131, lat: p2.lat, lng: p2.lng),
      ])!;
      final e = g.ecken(1600, 1131);
      expect(e.topLeft.lat, greaterThan(e.bottomLeft.lat));
      expect(e.bottomRight.lng, greaterThan(e.bottomLeft.lng));
      expect(e.topLeft.lng, closeTo(e.bottomLeft.lng, tol));
    });
  });
}

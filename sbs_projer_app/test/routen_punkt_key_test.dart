import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/fahrten_aus_kette.dart';
import 'package:sbs_projer_app/core/util/routen_punkt_key.dart';

/// Schlüssel der Routen-Enden im Cache `routen_punkte` (Migration 213).
///
/// Dieselben drei Beispiele stehen in
/// `supabase/functions/fahrzeit-route/keys_test.ts`: App und Edge Function
/// müssen für denselben Punkt denselben Schlüssel rechnen — sonst findet die
/// App die gecachte Strecke nie und fragt sie immer wieder an.
void main() {
  group('punktKey — gleich wie keys.ts', () {
    test('Domat/Ems auf vier Nachkommastellen', () {
      expect(punktKey(46.8328452, 9.4529918), 'p:46.8328,9.4530');
    });

    test('Aufrunden an der vierten Stelle', () {
      expect(punktKey(46.86396925, 9.5278708), 'p:46.8640,9.5279');
    });

    // JS toFixed und Dart toStringAsFixed behalten beide das Minus
    // (geprüft 29.09.2026) — deshalb keine eigene Normalisierung.
    test('kleine Werte um null', () {
      expect(punktKey(-0.00004, 0.00005), 'p:-0.0000,0.0001');
    });
  });

  test('betriebKey: Präfix b:', () {
    expect(betriebKey('betrieb-a'), 'b:betrieb-a');
  });

  group('haltKey', () {
    test('Betrieb → betriebKey, auch wenn er Koordinaten hat', () {
      const h = Halt(
        typ: HaltTyp.betrieb,
        id: 'betrieb-a',
        name: 'Peppino',
        lat: 46.85,
        lng: 9.53,
        quelle: 'reinigung',
      );
      expect(haltKey(h), 'b:betrieb-a');
    });

    test('Startort → Punkt', () {
      const h = Halt(
        typ: HaltTyp.startort,
        id: 'domat_ems',
        name: 'Domat/Ems',
        lat: 46.8328452,
        lng: 9.4529918,
        quelle: 'arbeitsbeginn',
      );
      expect(haltKey(h), 'p:46.8328,9.4530');
    });

    test('GPS-Position → Punkt', () {
      const h = Halt(
        typ: HaltTyp.startort,
        id: kGpsStartId,
        name: 'Arbeitsbeginn unterwegs',
        lat: 47.37,
        lng: 8.54,
        quelle: 'arbeitsbeginn',
      );
      expect(haltKey(h), 'p:47.3700,8.5400');
    });

    test('ohne Koordinaten → null (auch ein Betrieb)', () {
      const betrieb = Halt(
        typ: HaltTyp.betrieb,
        id: 'betrieb-x',
        name: 'Ohne Koordinaten',
        quelle: 'reinigung',
      );
      const startort = Halt(
        typ: HaltTyp.startort,
        id: 'domat_ems',
        name: 'Domat/Ems',
        lat: 46.83,
        quelle: 'feierabend',
      );
      expect(haltKey(betrieb), isNull);
      expect(haltKey(startort), isNull);
    });
  });
}

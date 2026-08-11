import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/tagesrand_position.dart';

void main() {
  const gps = (lat: 46.85, lng: 9.53);
  const zuhause = (lat: 46.8328452, lng: 9.4529918); // Via Rezia 8, Domat/Ems

  group('tagesrandPosition', () {
    test('GPS hat immer Vorrang vor dem Startort', () {
      final w = tagesrandPosition(
          gps: gps, startort: zuhause, startortErlaubt: true);
      expect(w.position, gps);
      expect(w.quelle, PositionsQuelle.gps);
    });

    test('Feierabend ohne GPS: Startort greift (Fall PC ohne Standortdienst)',
        () {
      final w = tagesrandPosition(
          gps: null, startort: zuhause, startortErlaubt: true);
      expect(w.position, zuhause);
      expect(w.quelle, PositionsQuelle.startort);
    });

    test('Arbeitsbeginn ohne GPS: KEIN Startort — Start ist oft nicht zuhause',
        () {
      final w = tagesrandPosition(
          gps: null, startort: zuhause, startortErlaubt: false);
      expect(w.position, isNull);
      expect(w.quelle, PositionsQuelle.keine);
    });

    test('Arbeitsbeginn mit GPS bleibt unberührt', () {
      final w = tagesrandPosition(
          gps: gps, startort: zuhause, startortErlaubt: false);
      expect(w.position, gps);
      expect(w.quelle, PositionsQuelle.gps);
    });

    test('kein GPS und kein erfasster Startort → nichts', () {
      final w =
          tagesrandPosition(gps: null, startort: null, startortErlaubt: true);
      expect(w.position, isNull);
      expect(w.quelle, PositionsQuelle.keine);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/config/router.dart';

void main() {
  group('anlageIdsAusQuery', () {
    test('mehrere IDs kommagetrennt', () {
      expect(anlageIdsAusQuery({'anlageIds': 'a1,a2,a3'}), ['a1', 'a2', 'a3']);
    });

    test('einzelnes anlageId bleibt gültig', () {
      expect(anlageIdsAusQuery({'anlageId': 'a1'}), ['a1']);
    });

    test('anlageIds hat Vorrang vor anlageId', () {
      expect(anlageIdsAusQuery({'anlageId': 'a1', 'anlageIds': 'a1,a2'}), ['a1', 'a2']);
    });

    test('ohne Angabe leer', () {
      expect(anlageIdsAusQuery({}), isEmpty);
    });

    test('leere Segmente fallen weg', () {
      expect(anlageIdsAusQuery({'anlageIds': 'a1,,a2,'}), ['a1', 'a2']);
    });
  });
}

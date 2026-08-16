import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/uuid_check.dart';

void main() {
  group('istUuid', () {
    test('valide UUID → true', () {
      expect(istUuid('82a3e6c2-0ee8-4760-815c-8e024d0d9b84'), isTrue);
      expect(istUuid('82A3E6C2-0EE8-4760-815C-8E024D0D9B84'), isTrue);
    });
    test('Anlass-Freitext → false (Migration-175-Fall)', () {
      expect(
        istUuid('Do 13.8. — Inbetriebnahme 1h (Vorbereitung Stände)'),
        isFalse,
      );
    });
    test('leer, fast-UUID, Unsinn → false', () {
      expect(istUuid(''), isFalse);
      expect(istUuid('82a3e6c2-0ee8-4760-815c'), isFalse);
      expect(istUuid('82a3e6c2-0ee8-4760-815c-8e024d0d9b84x'), isFalse);
    });
  });
}

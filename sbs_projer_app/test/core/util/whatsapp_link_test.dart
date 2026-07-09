import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/whatsapp_link.dart';

void main() {
  group('whatsappNummer', () {
    test('CH-Nummer mit fuehrender 0 -> 41…', () {
      expect(whatsappNummer('079 123 45 67'), '41791234567');
    });
    test('bereits international mit +', () {
      expect(whatsappNummer('+41 79 123 45 67'), '41791234567');
    });
    test('00-Praefix', () {
      expect(whatsappNummer('0049 171 1234567'), '491711234567');
    });
    test('Sonderzeichen werden entfernt', () {
      expect(whatsappNummer('079/123-45-67'), '41791234567');
    });
    test('null oder zu kurz -> null', () {
      expect(whatsappNummer(null), isNull);
      expect(whatsappNummer('123'), isNull);
    });
  });

  group('whatsappUri', () {
    test('baut wa.me-Link', () {
      expect(whatsappUri('079 123 45 67').toString(), 'https://wa.me/41791234567');
    });
  });
}

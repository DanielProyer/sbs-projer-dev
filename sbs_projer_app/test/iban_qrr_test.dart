import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/iban_qrr.dart';

void main() {
  group('istQrIban', () {
    test('QR-IBAN (IID 30000–31999) wird erkannt', () {
      // CH44 3199 9123 0008 8901 2 — IID 31999 = QR-IBAN
      expect(istQrIban('CH4431999123000889012'), isTrue);
    });

    test('normale IBAN ist keine QR-IBAN', () {
      // GKB CH66 0077 4010 3765 5060 1 — IID 00774
      expect(istQrIban('CH6600774010376550601'), isFalse);
    });

    test('Leerzeichen werden ignoriert', () {
      expect(istQrIban('CH44 3199 9123 0008 8901 2'), isTrue);
    });

    test('zu kurze oder nicht-numerische IID liefert false', () {
      expect(istQrIban('CH44'), isFalse);
      // Stellen 5–9 sind nicht numerisch → keine parsebare IID.
      expect(istQrIban('CH44ABCDE123000889012'), isFalse);
    });
  });

  group('qrrPruefzifferOk', () {
    test('gültige 27-stellige QRR wird akzeptiert', () {
      expect(qrrPruefzifferOk('210000000003139471430009017'), isTrue);
    });

    test('Leerzeichen werden ignoriert', () {
      expect(qrrPruefzifferOk('21 00000 00003 13947 14300 09017'), isTrue);
    });

    test('falsche Prüfziffer wird abgelehnt', () {
      expect(qrrPruefzifferOk('210000000003139471430009018'), isFalse);
    });

    test('falsche Länge wird abgelehnt', () {
      expect(qrrPruefzifferOk('1234567890'), isFalse);
    });

    test('nicht-numerisch wird abgelehnt', () {
      expect(qrrPruefzifferOk('21000000000313947143000901X'), isFalse);
    });
  });
}

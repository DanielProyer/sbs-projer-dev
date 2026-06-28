import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/eingangsrechnung/swiss_qr_data.dart';

void main() {
  // Gültiger Swiss-QR-Payload (QRType SPC v0200), Felder an Standardpositionen.
  const payloadLines = [
    'SPC', '0200', '1',
    'CH4431999123000889012', // 3: IBAN
    'S', 'Heineken Switzerland AG', 'Industriestrasse', '12', '8005', 'Zürich',
    'CH', // 4-10: Creditor (7)
    '', '', '', '', '', '', '', // 11-17: UltimateCreditor (7)
    '3772.70', 'CHF', // 18-19: Amount, Currency
    'S', 'SBS Projer GmbH', 'Teststrasse', '1', '7000', 'Chur',
    'CH', // 20-26: UltimateDebtor (7)
    'QRR', // 27: ReferenceType
    '210000000003139471430009017', // 28: Reference
    'Rechnung 12345', // 29: Unstructured
    'EPD', // 30: Trailer
  ];

  test('parseSwissQrPayload extrahiert IBAN/Referenz/Betrag/Währung', () {
    final qr = parseSwissQrPayload(payloadLines.join('\n'));
    expect(qr, isNotNull);
    expect(qr!.iban, 'CH4431999123000889012');
    expect(qr.referenzTyp, 'QRR');
    expect(qr.referenz, '210000000003139471430009017');
    expect(qr.betrag, 3772.70);
    expect(qr.waehrung, 'CHF');
    expect(qr.cdtrName, 'Heineken Switzerland AG');
  });

  test('parseSwissQrPayload: kein SPC-Header -> null', () {
    expect(parseSwissQrPayload('FOO\n0200\n1\nCH4431999123000889012'), isNull);
  });

  test('qrAbweichungen erkennt IBAN-Differenz, ignoriert Leerzeichen in Ref',
      () {
    final abw = qrAbweichungen(
      qrIban: 'CH4431999123000889012',
      kiIban: 'CH44 3199 9123 0008 8901 3', // letzte Ziffer falsch
      qrRef: '210000000003139471430009017',
      kiRef: '21 0000 0000 0313 9471 4300 09017', // identisch bis auf Spaces
      qrBetrag: 3772.70,
      kiBetrag: 3772.70,
    );
    expect(abw, isNotNull);
    expect(abw!.contains('IBAN'), isTrue);
    expect(abw.contains('Referenz'), isFalse);
    expect(abw.contains('Betrag'), isFalse);
  });

  test('qrAbweichungen: alles gleich -> null', () {
    final abw = qrAbweichungen(
      qrIban: 'CH4431999123000889012',
      kiIban: 'CH4431999123000889012',
      qrRef: '21',
      kiRef: '21',
      qrBetrag: 10.0,
      kiBetrag: 10.0,
    );
    expect(abw, isNull);
  });

  test('qrAbweichungen erkennt Betrags-Differenz', () {
    final abw = qrAbweichungen(qrBetrag: 100.00, kiBetrag: 90.00);
    expect(abw, isNotNull);
    expect(abw!.contains('Betrag'), isTrue);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/eingangsrechnung/swiss_qr_data.dart';

/// Baut einen gültigen Swiss-QR-Payload (SPC / Version 0200) zusammen.
/// Feldreihenfolge (0-basiert):
///   0 SPC · 1 Version · 2 Coding · 3 IBAN ·
///   4 Cdtr-AdrTp · 5 Cdtr-Name · 6 Strt/Addr1 · 7 Bldg/Addr2 · 8 PLZ ·
///   9 Ort · 10 Land · 11–17 UltimateCreditor(7) · 18 Amount · 19 Currency ·
///   20–26 UltimateDebtor(7) · 27 ReferenceType · 28 Reference ·
///   29 Unstructured · 30 Trailer "EPD".
String _buildPayload({
  required String adrTp,
  required String name,
  required String addr1,
  required String addr2,
  required String plz,
  required String ort,
  required String land,
}) {
  final lines = <String>[
    'SPC', // 0
    '0200', // 1
    '1', // 2
    'CH4431999123000889012', // 3 IBAN
    adrTp, // 4 Cdtr AdrTp (S/K)
    name, // 5 Cdtr Name
    addr1, // 6 Cdtr Strt / Addr1
    addr2, // 7 Cdtr Bldg / Addr2
    plz, // 8 Cdtr PLZ
    ort, // 9 Cdtr Ort
    land, // 10 Cdtr Land
    '', // 11 UltmtCdtr AdrTp
    '', // 12 UltmtCdtr Name
    '', // 13 UltmtCdtr Strt
    '', // 14 UltmtCdtr Bldg
    '', // 15 UltmtCdtr PLZ
    '', // 16 UltmtCdtr Ort
    '', // 17 UltmtCdtr Land
    '199.95', // 18 Amount
    'CHF', // 19 Currency
    '', // 20 UltmtDbtr AdrTp
    '', // 21 UltmtDbtr Name
    '', // 22 UltmtDbtr Strt
    '', // 23 UltmtDbtr Bldg
    '', // 24 UltmtDbtr PLZ
    '', // 25 UltmtDbtr Ort
    '', // 26 UltmtDbtr Land
    'QRR', // 27 ReferenceType
    '210000000003139471430009017', // 28 Reference
    '', // 29 Unstructured
    'EPD', // 30 Trailer
  ];
  return lines.join('\n');
}

void main() {
  group('parseSwissQrPayload — Cdtr-Adresse', () {
    test('strukturierte Adresse (AdrTp S) wird vollständig geparst', () {
      final payload = _buildPayload(
        adrTp: 'S',
        name: 'Heineken Switzerland AG',
        addr1: 'Industriestrasse',
        addr2: '12',
        plz: '8005',
        ort: 'Zürich',
        land: 'CH',
      );

      final qr = parseSwissQrPayload(payload);

      expect(qr, isNotNull);
      expect(qr!.cdtrName, 'Heineken Switzerland AG');
      expect(qr.cdtrStrasse, 'Industriestrasse');
      expect(qr.cdtrHausnr, '12');
      expect(qr.cdtrPlz, '8005');
      expect(qr.cdtrOrt, 'Zürich');
      expect(qr.cdtrLand, 'CH');
    });

    test('kombinierte Adresse (AdrTp K) — Strasse + Ort, kein Hausnr/PLZ', () {
      final payload = _buildPayload(
        adrTp: 'K',
        name: 'Beispiel GmbH',
        addr1: 'Musterweg 5',
        addr2: '3000 Bern',
        plz: '',
        ort: '',
        land: 'CH',
      );

      final qr = parseSwissQrPayload(payload);

      expect(qr, isNotNull);
      expect(qr!.cdtrStrasse, 'Musterweg 5');
      expect(qr.cdtrHausnr, isNull);
      expect(qr.cdtrPlz, isNull);
      expect(qr.cdtrOrt, '3000 Bern');
      expect(qr.cdtrLand, 'CH');
    });
  });
}

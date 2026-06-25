import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/rechnung_scan_result.dart';

void main() {
  test('fromJson mappt parse-rechnung Felder (robustes Parsing)', () {
    final r = RechnungScanResult.fromJson({
      'ist_rechnung': true, 'dok_typ': 'rechnung', 'ist_nur_info': false,
      'aussteller_name': 'Heineken Switzerland AG', 'empfaenger_iban': 'CH3408686001085747001',
      'referenz': '210000000003139471430009017', 'referenz_typ': 'QRR',
      'betrag_zahlbar': '3772.70', 'mwst_satz': '8.1', 'mwst_pflichtig': true,
      'rechnungsdatum': '2026-06-01', 'faelligkeit': '2026-07-01', 'konfidenz': 0.93,
    });
    expect(r.ausstellerName, 'Heineken Switzerland AG');
    expect(r.empfaengerIban, 'CH3408686001085747001');
    expect(r.betragZahlbar, 3772.70);
    expect(r.referenzTyp, 'QRR');
    expect(r.istNurInfo, false);
    expect(r.mwstPflichtig, true);
  });
}

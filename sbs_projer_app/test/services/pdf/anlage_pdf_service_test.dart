import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/local/anlage_local_export.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/services/pdf/anlage_pdf_service.dart';

void main() {
  test('steckbrief baut ein PDF ohne Fotos', () async {
    final a = AnlageLocal()
      ..bezeichnung = 'Warm 1'
      ..typAnlage = 'Warmanstich'
      ..anzahlHaehne = 4;
    final b = BetriebLocal()
      ..name = 'Restaurant Sonne'
      ..ort = 'Chur';
    final bytes = await AnlagePdfService.steckbrief(anlage: a, betrieb: b);
    expect(bytes.lengthInBytes, greaterThan(1000));
  });
}

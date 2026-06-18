import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/buchhaltung/mwst_satz_service.dart';

void main() {
  final saetze = [
    MwstSatz(DateTime(2010, 1, 1), 7.7, 2.5),
    MwstSatz(DateTime(2024, 1, 1), 8.1, 2.6),
  ];

  test('Normalsatz datumsabhängig (unverändert)', () {
    expect(MwstSatzService.satzFuer(DateTime(2023, 6, 1), saetze), 7.7);
    expect(MwstSatzService.satzFuer(DateTime(2024, 1, 1), saetze), 8.1);
  });

  test('reduzierter Satz datumsabhängig; vor erstem Eintrag 0', () {
    expect(MwstSatzService.reduzierterSatzFuer(DateTime(2023, 12, 31), saetze), 2.5);
    expect(MwstSatzService.reduzierterSatzFuer(DateTime(2024, 6, 1), saetze), 2.6);
    expect(MwstSatzService.reduzierterSatzFuer(DateTime(2009, 1, 1), saetze), 0.0);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/buchhaltung/mwst_satz_service.dart';

void main() {
  final saetze = [
    MwstSatz(DateTime(2010, 1, 1), 7.7),
    MwstSatz(DateTime(2024, 1, 1), 8.1),
  ];

  test('Datum 2023 → 7.7', () {
    expect(MwstSatzService.satzFuer(DateTime(2023, 6, 1), saetze), 7.7);
  });
  test('Datum 2024 → 8.1', () {
    expect(MwstSatzService.satzFuer(DateTime(2024, 1, 1), saetze), 8.1);
  });
  test('Datum 2026 → 8.1 (jüngster gültiger)', () {
    expect(MwstSatzService.satzFuer(DateTime(2026, 6, 9), saetze), 8.1);
  });
  test('Datum vor erstem Eintrag → 0.0', () {
    expect(MwstSatzService.satzFuer(DateTime(2000, 1, 1), saetze), 0.0);
  });
}

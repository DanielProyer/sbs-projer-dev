import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/auswertung/auswertung_mwst.dart';

void main() {
  test('mwstFaktor: 7.7% bis 2023, 8.1% ab 2024', () {
    expect(mwstFaktor(2019), 1.077);
    expect(mwstFaktor(2023), 1.077);
    expect(mwstFaktor(2024), 1.081);
    expect(mwstFaktor(2026), 1.081);
  });
}

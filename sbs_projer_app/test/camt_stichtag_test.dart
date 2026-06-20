import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/camt/camt_stichtag.dart';

void main() {
  test('Stichtag ist 11.03.2026, davor nicht automatisierbar', () {
    expect(CamtStichtag.stichtag, DateTime(2026, 3, 11));
    expect(CamtStichtag.istAutomatisierbar(DateTime(2026, 3, 10)), isFalse);
    expect(CamtStichtag.istAutomatisierbar(DateTime(2026, 3, 11)), isTrue);
  });
}

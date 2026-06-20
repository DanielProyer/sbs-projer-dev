import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/camt/camt_stichtag.dart';

void main() {
  test('Stichtag ist 20.06.2026, davor nicht automatisierbar', () {
    expect(CamtStichtag.stichtag, DateTime(2026, 6, 20));
    expect(CamtStichtag.istAutomatisierbar(DateTime(2026, 6, 19)), isFalse);
    expect(CamtStichtag.istAutomatisierbar(DateTime(2026, 6, 20)), isTrue);
  });
}

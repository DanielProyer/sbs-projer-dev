import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/camt/sammelzahler.dart';

void main() {
  test('bekannte Sammelzahler werden erkannt (Angaben Daniel 07.08.2026)', () {
    expect(istSammelzahler('Davos Klosters Bergbahnen AG'), isTrue);
    expect(istSammelzahler('Weisse Arena Hospitality AG'), isTrue);
    expect(istSammelzahler('Goodfast Hotels AG'), isTrue);
  });

  test('normale Zahler sind keine Sammelzahler', () {
    expect(istSammelzahler('Hotel Alpina AG'), isFalse);
    expect(istSammelzahler(null), isFalse);
  });
}

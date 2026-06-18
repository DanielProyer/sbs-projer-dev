import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/chf_format.dart';

void main() {
  test('formatiert mit Tausender-Apostroph und 2 Dezimalstellen', () {
    expect(chf(1234.5), "1'234.50");
    expect(chf(-1234.55), "-1'234.55");
    expect(chf(0), "0.00");
    expect(chf(1000000), "1'000'000.00");
    expect(chf(12.1), "12.10");
  });
}

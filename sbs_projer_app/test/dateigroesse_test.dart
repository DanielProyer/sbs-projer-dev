import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/dateigroesse.dart';

void main() {
  group('formatiereGroesse', () {
    test('Bytes bleiben Bytes', () {
      expect(formatiereGroesse(0), '0 B');
      expect(formatiereGroesse(999), '999 B');
    });
    test('kleine KB mit einer Nachkommastelle, grosse ohne', () {
      expect(formatiereGroesse(1024), '1.0 KB');
      expect(formatiereGroesse(1024 * 500), '500 KB');
    });
    test('MB mit einer Nachkommastelle', () {
      expect(formatiereGroesse(1024 * 1024), '1.0 MB');
      expect(formatiereGroesse((1024 * 1024 * 77.7).round()), '77.7 MB');
    });
    test('GB ab 1024 MB', () {
      expect(formatiereGroesse(1024 * 1024 * 1024 * 3), '3.00 GB');
    });
    test('negative Werte -> 0 B (defensiv)', () {
      expect(formatiereGroesse(-5), '0 B');
    });
  });
}

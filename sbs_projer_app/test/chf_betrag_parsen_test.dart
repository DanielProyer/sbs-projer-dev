import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/chf_betrag.dart';

void main() {
  group('chfBetragParsen', () {
    test('Apostroph als Tausendertrenner', () {
      expect(chfBetragParsen("1'234.50"), 1234.5);
    });

    test('typografischer Apostroph U+2019 als Tausendertrenner', () {
      expect(chfBetragParsen('1’234.50'), 1234.5);
    });

    test('Komma als Dezimaltrenner', () {
      expect(chfBetragParsen('1234,50'), 1234.5);
    });

    test('negativer Betrag (Guthaben)', () {
      expect(chfBetragParsen('-45.00'), -45);
    });

    test('unlesbare Eingabe ergibt null', () {
      expect(chfBetragParsen('abc'), isNull);
    });

    test('leere Eingabe ergibt null', () {
      expect(chfBetragParsen(''), isNull);
    });

    test('Leerzeichen werden entfernt', () {
      expect(chfBetragParsen(' 1 234.50 '), 1234.5);
      expect(chfBetragParsen('   '), isNull);
    });
  });
}

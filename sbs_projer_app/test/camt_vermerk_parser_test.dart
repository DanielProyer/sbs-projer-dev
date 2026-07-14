import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/camt/vermerk_parser.dart';

void main() {
  group('parseVermerk', () {
    test('leerer / null Vermerk → istLeer', () {
      expect(parseVermerk(null).istLeer, isTrue);
      expect(parseVermerk('').istLeer, isTrue);
      expect(parseVermerk('   ').istLeer, isTrue);
    });

    test('kein Datum, keine Nummer → istLeer', () {
      expect(parseVermerk('Zahlung Rechnung ABC').istLeer, isTrue);
    });

    test('strukturiert Nummer_yyyy_MM_dd (Davos Klosters Bergbahnen)', () {
      final h = parseVermerk('0151_2026_04_04');
      expect(h.betriebNummer, '0151');
      expect(h.datum, DateTime(2026, 4, 4));
    });

    test('strukturiert mit Text drumherum + gemischten Trennern', () {
      final h = parseVermerk('Sammelzahlung 0151 2026-04-04 April');
      expect(h.betriebNummer, '0151');
      expect(h.datum, DateTime(2026, 4, 4));
    });

    test('reines ISO-Datum ohne Nummer → nur Datum', () {
      final h = parseVermerk('2026_04_04');
      expect(h.betriebNummer, isNull);
      expect(h.datum, DateTime(2026, 4, 4));
    });

    test('Schweizer Datum dd.MM.yyyy im Freitext (HAPIMAG)', () {
      final h = parseVermerk('Reinigung vom 04.04.2026');
      expect(h.betriebNummer, isNull);
      expect(h.datum, DateTime(2026, 4, 4));
    });

    test('Schweizer Datum mit 2-stelligem Jahr → 20xx', () {
      expect(parseVermerk('04.04.26').datum, DateTime(2026, 4, 4));
    });

    test('einstellige Tage/Monate', () {
      expect(parseVermerk('Reinigung 4.4.2026').datum, DateTime(2026, 4, 4));
    });

    test('ungültiges Datum wird verworfen', () {
      expect(parseVermerk('99.99.2026').istLeer, isTrue);
      expect(parseVermerk('0151_2026_13_40').istLeer, isTrue);
    });

    test('31.02. (nicht existent) → verworfen', () {
      expect(parseVermerk('31.02.2026').istLeer, isTrue);
    });
  });
}

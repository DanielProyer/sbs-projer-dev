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

    test('Betriebnummer-Format 0151_2026_04_04 (führende Zahl = Betriebnummer)', () {
      // 0151 ist die (Heineken-)Betriebnummer, KEINE Rechnungssequenz.
      final h = parseVermerk('0151_2026_04_04');
      expect(h.betriebNummer, '0151');
      expect(h.datum, DateTime(2026, 4, 4));
      expect(h.rechnungsnummer, isNull);
    });

    test('Davos Klosters real: „04.04.2026 0151_2026_04_04" → Betriebnummer+Datum', () {
      final h = parseVermerk('04.04.2026 0151_2026_04_04');
      expect(h.betriebNummer, '0151');
      expect(h.datum, DateTime(2026, 4, 4));
      expect(h.rechnungsnummer, isNull);
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

    test('Rechnungsnummer YYYY-MM-NNNN wird erkannt (Davos Klosters real)', () {
      // Bemerkung: „01.05.2026 2026-04-0505" — Datum + Rechnungsnummer.
      final h = parseVermerk('01.05.2026 2026-04-0505');
      expect(h.rechnungsnummer, '2026-04-0505');
      expect(h.datum, DateTime(2026, 5, 1)); // 01.05. NICHT aus der Rg-Nr geparst
      expect(h.betriebNummer, isNull);
    });

    test('nur Rechnungsnummer → kein Datum aus deren Ziffern', () {
      final h = parseVermerk('Zahlung 2026-04-0505');
      expect(h.rechnungsnummer, '2026-04-0505');
      expect(h.datum, isNull);
    });

    test('3-stellige Rechnungsnummer-Sequenz', () {
      expect(parseVermerk('2025-12-007').rechnungsnummer, '2025-12-007');
    });
  });
}

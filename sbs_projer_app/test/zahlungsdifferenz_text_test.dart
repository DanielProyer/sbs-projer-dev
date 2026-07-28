import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/zahlungsdifferenz_text.dart';

void main() {
  group('bewerteDifferenz — Fall Sartons (Daniel 28.07.2026)', () {
    test('74.30 auf 74.60 ist eine Minderzahlung, keine Mehrzahlung', () {
      final d = bewerteDifferenz(74.30, 74.60);
      expect(d.art, DifferenzArt.minder);
      expect(d.betrag, closeTo(0.30, 0.001));
      expect(d.istBagatelle, isTrue);
      expect(d.text, contains('Minderzahlung CHF 0.30'));
      expect(d.text, contains('keine Nachforderung'));
      expect(d.text, contains('3805'));
    });

    test('ohne zugeordnete Forderung KEINE Differenz', () {
      // Vorher erschien die volle Zahlung als gruene Mehrzahlung.
      expect(bewerteDifferenz(74.30, 0).art, DifferenzArt.keine);
      expect(bewerteDifferenz(74.30, 0).text, isEmpty);
    });
  });

  group('bewerteDifferenz', () {
    test('exakte Zahlung -> keine Differenz', () {
      expect(bewerteDifferenz(74.60, 74.60).art, DifferenzArt.keine);
    });
    test('Rappen-Rundung unter 1 Rappen zaehlt nicht', () {
      expect(bewerteDifferenz(74.604, 74.60).art, DifferenzArt.keine);
    });
    test('Mehrzahlung -> a.o. Ertrag, nie Bagatelle', () {
      final d = bewerteDifferenz(80.00, 74.60);
      expect(d.art, DifferenzArt.mehr);
      expect(d.betrag, closeTo(5.40, 0.001));
      expect(d.istBagatelle, isFalse);
      expect(d.text, contains('8000'));
    });
    test('Minderzahlung ueber der Bagatellgrenze -> ohne Zusatz', () {
      final d = bewerteDifferenz(60.00, 74.60);
      expect(d.art, DifferenzArt.minder);
      expect(d.istBagatelle, isFalse);
      expect(d.text, isNot(contains('keine Nachforderung')));
    });
    test('genau an der Grenze (1.00) ist noch Bagatelle', () {
      expect(bewerteDifferenz(73.60, 74.60).istBagatelle, isTrue);
      expect(bewerteDifferenz(73.55, 74.60).istBagatelle, isFalse);
    });
    test('Zahlung 0 -> keine Differenz', () {
      expect(bewerteDifferenz(0, 74.60).art, DifferenzArt.keine);
    });
  });
}

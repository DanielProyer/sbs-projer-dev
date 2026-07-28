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

  group('rechnungenNachZahlung — Fall Marsöl (Daniel 28.07.2026)', () {
    test('Rechnung vom 12.05. auf Zahlung vom 25.03. wird gemeldet', () {
      final treffer = rechnungenNachZahlung(DateTime(2026, 3, 25), [
        (bezeichnung: '2026-05-0618', rechnungsdatum: DateTime(2026, 5, 12)),
      ]);
      expect(treffer, ['2026-05-0618']);
    });

    test('ältere offene Rechnungen sind plausibel', () {
      final treffer = rechnungenNachZahlung(DateTime(2026, 3, 25), [
        (bezeichnung: '2026-04-0273', rechnungsdatum: DateTime(2026, 1, 20)),
        (bezeichnung: '2026-04-0173', rechnungsdatum: DateTime(2025, 12, 17)),
      ]);
      expect(treffer, isEmpty);
    });

    test('nur die problematischen werden zurückgegeben', () {
      final treffer = rechnungenNachZahlung(DateTime(2026, 3, 25), [
        (bezeichnung: 'alt', rechnungsdatum: DateTime(2026, 1, 20)),
        (bezeichnung: 'zu jung', rechnungsdatum: DateTime(2026, 6, 1)),
      ]);
      expect(treffer, ['zu jung']);
    });

    test('gleicher Tag ist in Ordnung (Barzahlung bei Übergabe)', () {
      expect(
          rechnungenNachZahlung(DateTime(2026, 3, 25), [
            (bezeichnung: 'x', rechnungsdatum: DateTime(2026, 3, 25)),
          ]),
          isEmpty);
    });

    test('ein Tag Toleranz für Buchungs-/Valutadatum', () {
      expect(
          rechnungenNachZahlung(DateTime(2026, 3, 25), [
            (bezeichnung: 'x', rechnungsdatum: DateTime(2026, 3, 26)),
          ]),
          isEmpty);
      expect(
          rechnungenNachZahlung(DateTime(2026, 3, 25), [
            (bezeichnung: 'x', rechnungsdatum: DateTime(2026, 3, 27)),
          ]),
          ['x']);
    });

    test('leere Auswahl -> keine Meldung', () {
      expect(rechnungenNachZahlung(DateTime(2026, 3, 25), []), isEmpty);
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

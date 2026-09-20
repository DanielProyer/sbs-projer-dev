import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/chf_format.dart';

/// Das Betragsformat der ganzen App.
///
/// WARUM der Test um die negative Null: Am 20.09.2026 zeigte die
/// MwSt-Abrechnung für das leere Q4/2026 in jeder Zeile «-0.00 CHF». Die
/// Beträge entstehen dort durch Vorzeichenumkehr eines Saldos
/// (`-(saldi[3400] ?? 0)`); aus `0.0` wird so `-0.0`, und `NumberFormat`
/// schreibt das Minus mit. Fachlich ist es null, auf dem Bildschirm sah es
/// nach einem Rechenfehler aus.
void main() {
  group('chf', () {
    test('Tausender mit Apostroph, immer zwei Dezimalstellen', () {
      expect(chf(1234.5), "1'234.50");
      expect(chf(1234567.89), "1'234'567.89");
      expect(chf(7.7), '7.70');
    });

    test('echte negative Beträge behalten ihr Minus', () {
      expect(chf(-1234.55), "-1'234.55");
      expect(chf(-0.05), '-0.05');
    });

    test('negative Null wird als 0.00 geschrieben, nicht als -0.00', () {
      expect(chf(-0.0), '0.00');
      expect(chf(0.0), '0.00');
      expect(chf(-(0.0)), '0.00');
      // so entsteht sie produktiv: Saldo eines leeren Kontos umgedreht
      const Map<int, double> saldi = {};
      expect(chf(-(saldi[3400] ?? 0)), '0.00');
    });

    test('rundet auf zwei Stellen', () {
      expect(chf(0.005), '0.01');
      expect(
        chf(-0.004),
        '0.00',
        reason: 'Restbetrag unter einem halben Rappen',
      );
    });
  });
}

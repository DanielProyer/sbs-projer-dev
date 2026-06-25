import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/scor_referenz.dart';

void main() {
  test('kanonischer ISO-11649-Vektor', () {
    expect(scorReferenz('539007547034'), 'RF18539007547034');
  });

  test('erzeugte Referenz ist mod-97-gültig (RF…00-Regel)', () {
    final ref = scorReferenz('202606250001');
    expect(ref.startsWith('RF'), isTrue);
    expect(istGueltigeScor(ref), isTrue);
  });

  test('scorRefNorm: Leerzeichen weg, Uppercase', () {
    expect(scorRefNorm('rf18 5390 0754 7034'), 'RF18539007547034');
    expect(scorRefNorm(' RF18539007547034 '), 'RF18539007547034');
  });

  test('qrReferenzAusNummer: nur Kundentypen, Ziffern aus Nummer', () {
    expect(qrReferenzAusNummer('kundenrechnung', '2026-06-25-0001'),
        scorReferenz('202606250001'));
    expect(qrReferenzAusNummer('jahresrechnung', '2026-0042'),
        scorReferenz('20260042'));
    expect(qrReferenzAusNummer('heineken_monat', '2026-06-25-0001'), isNull);
    expect(qrReferenzAusNummer('kundenrechnung', null), isNull);
  });

  test('Suffix erzeugt eine andere, gültige Referenz (Kollisions-Auflösung)', () {
    final basis = qrReferenzAusNummer('kundenrechnung', '2026-06-25-0001')!;
    final s1 = qrReferenzAusNummer('kundenrechnung', '2026-06-25-0001', suffix: 1)!;
    final s2 = qrReferenzAusNummer('kundenrechnung', '2026-06-25-0001', suffix: 2)!;
    expect(qrReferenzAusNummer('kundenrechnung', '2026-06-25-0001', suffix: 0), basis);
    expect(s1, isNot(basis));
    expect(s2, isNot(s1));
    expect(istGueltigeScor(s1), isTrue);
    expect(istGueltigeScor(s2), isTrue);
  });
}

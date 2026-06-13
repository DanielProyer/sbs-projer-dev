import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/buchhaltung/saldo_expansion.dart';

void main() {
  test('ohne MWST: brutto auf Soll und Haben', () {
    final s = <int, double>{};
    SaldoExpansion.apply(s,
        sollKonto: 6200, habenKonto: 1020, mwstKonto: null,
        betragNetto: 100, mwstBetrag: 0, betragBrutto: 100);
    expect(s[6200], 100);
    expect(s[1020], -100);
  });

  test('Vorsteuer (mwstKonto 1171): Aufwand=netto, Vorsteuer=+mwst, Bank=-brutto', () {
    final s = <int, double>{};
    SaldoExpansion.apply(s,
        sollKonto: 6200, habenKonto: 1020, mwstKonto: 1171,
        betragNetto: 100, mwstBetrag: 8.1, betragBrutto: 108.1);
    expect(s[6200], 100);
    expect(s[1171], 8.1);
    expect(s[1020], -108.1);
  });

  test('Umsatzsteuer (mwstKonto 2200): Debitor=+brutto, USt=-mwst, Erlös=-netto', () {
    final s = <int, double>{};
    SaldoExpansion.apply(s,
        sollKonto: 1100, habenKonto: 3400, mwstKonto: 2200,
        betragNetto: 87, mwstBetrag: 7.05, betragBrutto: 94.05);
    expect(s[1100], 94.05);
    expect(s[2200], -7.05);
    expect(s[3400], -87);
  });

  test('akkumuliert in vorhandene Map', () {
    final s = <int, double>{1020: -50};
    SaldoExpansion.apply(s,
        sollKonto: 6200, habenKonto: 1020, mwstKonto: null,
        betragNetto: 30, mwstBetrag: 0, betragBrutto: 30);
    expect(s[1020], -80);
  });
}

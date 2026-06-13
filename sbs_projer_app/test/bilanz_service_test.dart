import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/buchhaltung/bilanz_service.dart';

BuchungSaldo _b(int soll, int haben, double betrag, String datum,
        {bool storniert = false}) =>
    BuchungSaldo(
      sollKonto: soll,
      habenKonto: haben,
      betrag: betrag,
      datum: DateTime.parse(datum),
      storniert: storniert,
    );

KontoInfo _k(int nr, String kat) =>
    KontoInfo(kontonummer: nr, bezeichnung: 'K$nr', kategorie: kat);

void main() {
  test('Saldo per Stichtag ignoriert spätere + stornierte Buchungen', () {
    final saldi = BilanzService.saldiPerStichtag(
      [
        _b(1020, 3400, 100, '2025-01-10'),
        _b(1020, 3400, 50, '2025-06-01'),
        _b(1020, 3400, 99, '2025-01-15', storniert: true),
      ],
      DateTime.parse('2025-03-31'),
    );
    expect(saldi[1020], 100);
  });

  test('Aktiven positiv bei Soll-Überhang, Passiven positiv bei Haben-Überhang',
      () {
    final saldi = BilanzService.saldiPerStichtag(
      [
        _b(1020, 2000, 200, '2025-01-10'),
      ],
      DateTime.parse('2025-12-31'),
    );
    final bilanz = BilanzService.gruppiere(saldi, [
      _k(1020, 'Umlaufvermögen'),
      _k(2000, 'Kurzfristiges Fremdkapital'),
    ]);
    expect(bilanz.aktiven.single.summe, 200);
    expect(bilanz.passiven.single.summe, 200);
    expect(bilanz.totalAktiven, 200);
    expect(bilanz.totalPassiven, 200);
    expect(bilanz.differenz, 0);
  });

  test('Sozialversicherungen zählen zum kurzfristigen Fremdkapital', () {
    final saldi = BilanzService.saldiPerStichtag(
      [_b(5700, 2271, 80, '2025-02-01')],
      DateTime.parse('2025-12-31'),
    );
    final bilanz = BilanzService.gruppiere(saldi, [
      _k(2271, 'Sozialversicherungen'),
    ]);
    final kfk = bilanz.passiven
        .firstWhere((g) => g.titel == 'Kurzfristiges Fremdkapital');
    expect(kfk.summe, 80);
  });

  test('Passiv-Gruppen erscheinen in fester Reihenfolge', () {
    final saldi = BilanzService.saldiPerStichtag(
      [
        _b(1020, 2800, 100, '2025-01-01'), // Eigenkapital
        _b(1020, 2000, 50, '2025-01-02'), // Kurzfristiges Fremdkapital
      ],
      DateTime.parse('2025-12-31'),
    );
    final bilanz = BilanzService.gruppiere(saldi, [
      _k(2800, 'Eigenkapital'),
      _k(2000, 'Kurzfristiges Fremdkapital'),
    ]);
    expect(bilanz.passiven.map((g) => g.titel).toList(),
        ['Kurzfristiges Fremdkapital', 'Eigenkapital']);
  });

  test('Konten mit Saldo 0 werden nicht gelistet', () {
    final saldi = BilanzService.saldiPerStichtag(
      [_b(1020, 1000, 0, '2025-01-01')],
      DateTime.parse('2025-12-31'),
    );
    final bilanz = BilanzService.gruppiere(
        saldi, [_k(1020, 'Umlaufvermögen'), _k(1000, 'Umlaufvermögen')]);
    expect(bilanz.aktiven, isEmpty);
  });
}

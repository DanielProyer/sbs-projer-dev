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

  test('Einnahme mit MWST: Debitor=brutto (Aktiv), Umsatzsteuer 2200=mwst (Passiv)', () {
    final saldi = BilanzService.saldiPerStichtag(
      [
        BuchungSaldo(
          sollKonto: 1100,
          habenKonto: 3400,
          betrag: 94.05,
          datum: DateTime.parse('2025-02-01'),
          storniert: false,
          mwstKonto: 2200,
          betragNetto: 87.0,
          mwstBetrag: 7.05,
        ),
      ],
      DateTime.parse('2025-12-31'),
    );
    expect(saldi[1100], 94.05);
    expect(saldi[2200], -7.05);
    expect(saldi[3400], -87.0);

    final bilanz = BilanzService.gruppiere(saldi, [
      KontoInfo(kontonummer: 1100, bezeichnung: 'Debitoren', kategorie: 'Umlaufvermögen'),
      KontoInfo(kontonummer: 2200, bezeichnung: 'Umsatzsteuer', kategorie: 'Kurzfristiges Fremdkapital'),
    ]);
    expect(bilanz.aktiven.single.summe, 94.05);
    expect(bilanz.passiven.single.summe, 7.05);
  });

  test('kumuliertesErgebnis: Ertrag (Kl.3) minus Aufwand (Kl.4-8) = Gewinn', () {
    final saldi = {3400: -1000.0, 5000: 300.0, 8900: 20.0, 1020: 680.0};
    expect(BilanzService.kumuliertesErgebnis(saldi), 680.0); // -(-1000+300+20)
  });

  test('kumuliertesErgebnis ignoriert Klasse 1/2/9', () {
    final saldi = {1020: 500.0, 2000: -200.0, 9000: 999.0};
    expect(BilanzService.kumuliertesErgebnis(saldi), 0.0);
  });

  test('gruppiere mit Vortrag+Jahresergebnis hängt EK-Posten an und balanciert', () {
    final saldi = {1020: 83118.0, 2800: -20000.0};
    final bilanz = BilanzService.gruppiere(
      saldi,
      [
        KontoInfo(kontonummer: 1020, bezeichnung: 'Bank', kategorie: 'Umlaufvermögen'),
        KontoInfo(kontonummer: 2800, bezeichnung: 'Eigenkapital', kategorie: 'Eigenkapital'),
      ],
      gewinnvortrag: 35319.11,
      jahresergebnis: 27798.89,
    );
    final ek = bilanz.passiven.firstWhere((g) => g.titel == 'Eigenkapital');
    expect(
        ek.posten.any((p) =>
            p.bezeichnung == 'Gewinn-/Verlustvortrag' && p.summe == 35319.11),
        isTrue);
    expect(
        ek.posten.any(
            (p) => p.bezeichnung == 'Jahresergebnis' && p.summe == 27798.89),
        isTrue);
    expect(bilanz.totalAktiven, 83118.0);
    expect(bilanz.totalPassiven, 83118.0);
    expect(bilanz.differenz.abs() < 0.005, isTrue);
  });

  test('gruppiere ohne Split (Default 0) erzeugt keine Ergebnis-Posten', () {
    final saldi = {1020: 100.0, 2800: -100.0};
    final bilanz = BilanzService.gruppiere(saldi, [
      KontoInfo(kontonummer: 1020, bezeichnung: 'Bank', kategorie: 'Umlaufvermögen'),
      KontoInfo(kontonummer: 2800, bezeichnung: 'EK', kategorie: 'Eigenkapital'),
    ]);
    final ek = bilanz.passiven.firstWhere((g) => g.titel == 'Eigenkapital');
    expect(ek.posten.length, 1);
  });
}

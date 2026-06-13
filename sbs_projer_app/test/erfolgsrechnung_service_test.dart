import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/buchhaltung/bilanz_service.dart'
    show BuchungSaldo;
import 'package:sbs_projer_app/services/buchhaltung/erfolgsrechnung_service.dart';

BuchungSaldo _b(int soll, int haben, double betrag, String datum) =>
    BuchungSaldo(
        sollKonto: soll,
        habenKonto: haben,
        betrag: betrag,
        datum: DateTime.parse(datum),
        storniert: false);

void main() {
  final buchungen = [
    _b(1100, 3400, 1000, '2025-02-01'),
    _b(4004, 2000, 100, '2025-02-02'),
    _b(5000, 1020, 300, '2025-02-03'),
    _b(6200, 1020, 50, '2025-02-04'),
    _b(6940, 1020, 10, '2025-02-05'),
    _b(8900, 2208, 20, '2025-02-06'),
  ];

  test('Stufengliederung rechnet korrekt durch', () {
    final er = ErfolgsrechnungService.berechne(
      buchungen,
      von: DateTime.parse('2025-01-01'),
      bis: DateTime.parse('2025-12-31'),
    );
    expect(er.nettoerloes, 1000);
    expect(er.materialaufwand, 100);
    expect(er.bruttoergebnis1, 900);
    expect(er.personalaufwand, 300);
    expect(er.bruttoergebnis2, 600);
    expect(er.uebrigerAufwand, 50);
    expect(er.ebitda, 550);
    expect(er.abschreibungen, 0);
    expect(er.ebit, 550);
    expect(er.finanzerfolg, -10);
    expect(er.ebt, 540);
    expect(er.steuern, 20);
    expect(er.jahresergebnis, 520);
  });

  test('Periodenfilter: Buchung ausserhalb von–bis zählt nicht', () {
    final er = ErfolgsrechnungService.berechne(
      [_b(1100, 3400, 999, '2024-12-31')],
      von: DateTime.parse('2025-01-01'),
      bis: DateTime.parse('2025-12-31'),
    );
    expect(er.nettoerloes, 0);
  });

  test('Nebenerfolg: Klasse-7-Ertrag minus betriebsfremder Aufwand (8000–8899)',
      () {
    final er = ErfolgsrechnungService.berechne(
      [
        _b(1020, 7000, 200, '2025-03-01'), // Nebenertrag +200 (Haben)
        _b(8000, 1020, 30, '2025-03-02'), // betriebsfremder Aufwand 30 (Soll)
      ],
      von: DateTime.parse('2025-01-01'),
      bis: DateTime.parse('2025-12-31'),
    );
    expect(er.nebenerfolg, 170); // 200 − 30
    expect(er.steuern, 0); // 8900er nicht betroffen
    expect(er.jahresergebnis, 170);
  });
}

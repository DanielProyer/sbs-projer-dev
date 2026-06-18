import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/buchhaltung/bilanz_service.dart';

BuchungSaldo b(int soll, int haben, double betrag, DateTime d) =>
    BuchungSaldo(sollKonto: soll, habenKonto: haben, betrag: betrag, datum: d, storniert: false);

void main() {
  final konten = [
    const KontoInfo(kontonummer: 1020, bezeichnung: 'Bank', kategorie: 'Umlaufvermögen'),
    const KontoInfo(kontonummer: 2800, bezeichnung: 'Eigenkapital', kategorie: 'Eigenkapital'),
  ];

  test('Mitte-Jahr-Stichtag: EK-Split Vortrag + laufendes Ergebnis, Bilanz ausgeglichen', () {
    final buchungen = [
      b(1020, 3400, 1000, DateTime(2025, 6, 1)),
      b(1020, 3400, 400, DateTime(2026, 3, 1)),
      b(1020, 3400, 999, DateTime(2026, 9, 1)),
    ];
    final daten = BilanzService.erstelle(buchungen, konten, DateTime(2026, 6, 30));

    expect(daten.totalAktiven, closeTo(1400, 0.001));
    expect(daten.differenz.abs() < 0.005, isTrue);
    final ek = daten.passiven.firstWhere((g) => g.titel == 'Eigenkapital');
    final vortrag = ek.posten.firstWhere((p) => p.kontonummer == 2970).summe;
    final jahr = ek.posten.firstWhere((p) => p.kontonummer == 2980).summe;
    expect(vortrag, closeTo(1000, 0.001));
    expect(jahr, closeTo(400, 0.001));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/buchhaltung/bilanz_service.dart' show BuchungSaldo;
import 'package:sbs_projer_app/services/buchhaltung/erfolgsrechnung_service.dart';

BuchungSaldo b(int soll, int haben, double betrag, DateTime d) =>
    BuchungSaldo(sollKonto: soll, habenKonto: haben, betrag: betrag, datum: d, storniert: false);

void main() {
  final von = DateTime(2026, 1, 1);
  final bis = DateTime(2026, 12, 31);

  test('Ertragskonto 3400 erscheint positiv in Klasse 3', () {
    final a = ErfolgsrechnungService.kontenAufstellung(
        [b(1020, 3400, 1000, DateTime(2026, 3, 1))], von: von, bis: bis);
    final k3 = a.klassen.firstWhere((k) => k.klasse == 3);
    expect(k3.konten.single.nr, 3400);
    expect(k3.konten.single.summe, 1000);
    expect(k3.summe, 1000);
    expect(a.nettoerloes, 1000);
  });

  test('Aufwandkonto 4000 erscheint positiv in Klasse 4', () {
    final a = ErfolgsrechnungService.kontenAufstellung(
        [b(4000, 1020, 500, DateTime(2026, 4, 1))], von: von, bis: bis);
    final k4 = a.klassen.firstWhere((k) => k.klasse == 4);
    expect(k4.konten.single.nr, 4000);
    expect(k4.konten.single.summe, 500);
  });

  test('Konten mit Summe 0 und Buchungen ausserhalb des Zeitraums fehlen', () {
    final a = ErfolgsrechnungService.kontenAufstellung([
      b(4000, 1020, 500, DateTime(2025, 12, 31)),
    ], von: von, bis: bis);
    expect(a.klassen, isEmpty);
  });

  test('Klassen und Konten aufsteigend sortiert', () {
    final a = ErfolgsrechnungService.kontenAufstellung([
      b(5000, 1020, 100, DateTime(2026, 2, 1)),
      b(4000, 1020, 100, DateTime(2026, 2, 1)),
      b(4200, 1020, 100, DateTime(2026, 2, 1)),
    ], von: von, bis: bis);
    expect(a.klassen.map((k) => k.klasse).toList(), [4, 5]);
    expect(a.klassen.first.konten.map((k) => k.nr).toList(), [4000, 4200]);
  });
}

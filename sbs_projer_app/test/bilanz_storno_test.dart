import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/buchhaltung/bilanz_service.dart';

void main() {
  test('Storno-Paar nettet auf 0 (Original + Gegenbuchung beide übersprungen)',
      () {
    final orig = BuchungSaldo(
      sollKonto: 2000,
      habenKonto: 1020,
      betrag: 100,
      datum: DateTime(2026, 6, 1),
      storniert: true,
    );
    final gegen = BuchungSaldo(
      sollKonto: 1020,
      habenKonto: 2000,
      betrag: 100,
      datum: DateTime(2026, 6, 2),
      storniert: false,
      istGegenbuchung: true,
    );
    final saldi =
        BilanzService.saldiPerStichtag([orig, gegen], DateTime(2026, 12, 31));
    // Vor dem Fix: 2000 = -100 (nur Gegenbuchung gezählt). Nach Fix: 0.
    expect(saldi[2000] ?? 0, 0);
    expect(saldi[1020] ?? 0, 0);
  });

  test('aktive Buchung wird weiterhin gezählt', () {
    final aktiv = BuchungSaldo(
      sollKonto: 6000,
      habenKonto: 1020,
      betrag: 50,
      datum: DateTime(2026, 6, 3),
      storniert: false,
    );
    final saldi =
        BilanzService.saldiPerStichtag([aktiv], DateTime(2026, 12, 31));
    expect((saldi[6000] ?? 0) != 0, isTrue);
  });
}

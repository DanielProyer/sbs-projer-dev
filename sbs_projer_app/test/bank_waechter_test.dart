import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/bank_waechter.dart';

void main() {
  group('Anschluss-Prüfung (OPBD gegen Journal)', () {
    test('stimmt der Anfangssaldo, ist der Anschluss lückenlos', () {
      final c = BankWaechter.pruefeAnschluss(
          opbd: 15816.07, journalVortag: 15816.07);
      expect(c.ok, isTrue);
      expect(c.text, contains('15816.07'));
    });

    test('weicht der Anfangssaldo ab, wird die Differenz benannt', () {
      final c = BankWaechter.pruefeAnschluss(
          opbd: 15816.07, journalVortag: 15716.07);
      expect(c.ok, isFalse);
      expect(c.text, contains('100.00'));
    });

    test('Rundungsrauschen unter einem Rappen gilt als ok', () {
      final c = BankWaechter.pruefeAnschluss(
          opbd: 100.004, journalVortag: 100.001);
      expect(c.ok, isTrue);
    });
  });

  group('Schluss-Prüfung (CLBD gegen Journal)', () {
    test('grün wenn identisch', () {
      final c =
          BankWaechter.pruefeSchluss(clbd: 23351.23, journal: 23351.23);
      expect(c.ok, isTrue);
    });
    test('rot mit Differenz wenn abweichend', () {
      final c =
          BankWaechter.pruefeSchluss(clbd: 23351.23, journal: 23000.00);
      expect(c.ok, isFalse);
      expect(c.text, contains('351.23'));
    });
  });

  group('Lücken-Prüfung (Zeitraum-Anschluss)', () {
    test('nahtloser Anschluss: keine Warnung', () {
      expect(
          BankWaechter.luecke(
              letztesBis: DateTime(2026, 8, 31), neuesVon: DateTime(2026, 9, 1)),
          isNull);
    });
    test('Überlappung: keine Warnung (Import ist idempotent)', () {
      expect(
          BankWaechter.luecke(
              letztesBis: DateTime(2026, 8, 31), neuesVon: DateTime(2026, 8, 20)),
          isNull);
    });
    test('Lücke von zwei Tagen wird benannt', () {
      final w = BankWaechter.luecke(
          letztesBis: DateTime(2026, 8, 31), neuesVon: DateTime(2026, 9, 3));
      expect(w, contains('01.09.2026'));
      expect(w, contains('02.09.2026'));
    });
    test('erster Import überhaupt: keine Warnung', () {
      expect(
          BankWaechter.luecke(letztesBis: null, neuesVon: DateTime(2026, 9, 1)),
          isNull);
    });
  });

  group('Verbindlichkeits-Wächter (Tilgung ohne Aufbau)', () {
    test('Soll-Überhang auf 2002 wird mit Kontoname und Betrag gemeldet', () {
      final w = BankWaechter.verbindlichkeitsWarnungen({2002: -3500.0});
      expect(w, hasLength(1));
      expect(w.first, contains('2002'));
      expect(w.first, contains('Lohn'));
      expect(w.first, contains('3500.00'));
    });

    test('gesunde Salden (Kredit oder 0) lösen nichts aus', () {
      expect(
          BankWaechter.verbindlichkeitsWarnungen(
              {2000: 96.95, 2002: 0.0, 2202: 7234.63}),
          isEmpty);
    });

    test('mehrere betroffene Konten ergeben mehrere Warnungen', () {
      final w = BankWaechter.verbindlichkeitsWarnungen(
          {2000: -3675.75, 2002: -3500.0, 1020: -99999.0});
      expect(w, hasLength(2)); // 1020 ist kein Verbindlichkeitskonto
    });
  });
}

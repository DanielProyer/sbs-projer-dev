import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Migration 214: mehrere Abschreibungsläufe je Geschäftsjahr.
///
/// WARUM: Der Abschluss 2025 trug schon den 2019er-Lauf (per SQL, Rücknahme
/// nur von Hand). Entscheid Daniel 29.09.2026: Jahrgang 2020 ebenfalls per
/// 31.12.2025 — der Wächter «ein Lauf je Jahr» aus 194 hätte den App-Schritt
/// am 01.10.2026 mit einer Fehlermeldung enden lassen. Doppelbuchungen
/// verhindert seit 214 die Prüfung je Rechnung (Position in einem gebuchten
/// Lauf), nicht mehr das Jahr.
void main() {
  final sql = File(
    '../Datenbank/migrations/214_abschreibung_lauf_pro_jahrgang.sql',
  ).readAsStringSync();

  test('214 definiert abschreibung_jahrgang_buchen neu', () {
    expect(
      sql,
      contains(
        'CREATE OR REPLACE FUNCTION abschreibung_jahrgang_buchen'
        '(p_geschaeftsjahr INTEGER, p_rechnung_ids UUID[])',
      ),
    );
  });

  test('kein Wächter «ein Lauf je Jahr» mehr, dafür «keine Rechnung doppelt»',
      () {
    // Der Kommentar darf den alten Wächter zitieren — nur die RAISE-Zeile
    // darf nicht mehr stehen.
    expect(
      sql,
      isNot(contains("RAISE EXCEPTION 'Für % gibt es schon einen gebuchten")),
    );
    expect(sql, contains("RAISE EXCEPTION 'Schon in einem gebuchten Lauf"));
    expect(sql, contains('p.rechnung_id = ANY (p_rechnung_ids)'));
  });

  test('Kern unverändert: 31.12., netto auf 3805, MWST 2200 an 1100, Q4', () {
    expect(sql, contains('make_date(p_geschaeftsjahr, 12, 31)'));
    expect(sql, contains('3805, 1100, r.betrag_netto'));
    expect(sql, contains('2200, 1100, r.mwst_betrag'));
    expect(sql, contains('p_geschaeftsjahr, 4,'));
    expect(sql, contains("rg.zahlungsstatus IN ('bezahlt', 'abgeschrieben')"));
  });
}

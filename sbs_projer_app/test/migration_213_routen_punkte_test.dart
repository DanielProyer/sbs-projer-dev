import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Migration 213 (`routen_punkte`, 29.09.2026): Die App darf nur LESEN.
///
/// WARUM: Die Zeilen schreibt ausschliesslich die Edge Function
/// `fahrzeit-route` mit der Service-Role. Eine Schreib-Policy für den
/// eingeloggten User liesse beliebige km unter beliebigen Schlüsseln zu, und
/// die Fahrten-Auswertung übernähme sie ungeprüft als geroutete Strecke.
void main() {
  final sql = File(
    '../Datenbank/migrations/213_routen_punkte.sql',
  ).readAsStringSync();
  // Nur der Code, ohne SQL-Kommentare (die erklären das Verbotene).
  final code = sql
      .split('\n')
      .map((z) => z.contains('--') ? z.substring(0, z.indexOf('--')) : z)
      .join('\n')
      .toLowerCase();

  test('RLS an, genau eine Policy — nur select', () {
    expect(code, contains('enable row level security'));
    final policies = RegExp(r'create policy').allMatches(code).length;
    expect(policies, 1);
    expect(code, contains('for select using (user_id = auth.uid())'));
    expect(code, isNot(contains('for all')));
    expect(code, isNot(contains('for insert')));
    expect(code, isNot(contains('for update')));
    expect(code, isNot(contains('for delete')));
  });

  test('kein doppelter Index auf user_id (Unique-Index deckt ihn ab)', () {
    expect(code, contains('unique (user_id, von_key, nach_key)'));
    expect(code, isNot(contains('create index')));
  });
}

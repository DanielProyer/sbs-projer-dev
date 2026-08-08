import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Wächter gegen stille Datenverluste beim seitenweisen Laden.
///
/// Befund 08.08.2026 (Bilanz zeigte Bank 15'057.97 statt 15'816.07): Wer mit
/// `.range()` paginiert und dabei nur nach einer NICHT eindeutigen Spalte
/// sortiert (z. B. `datum` — 1'874 Tage tragen mehrere Buchungen), bekommt von
/// Postgres zwischen zwei Seiten keine stabile Reihenfolge. Zeilen erscheinen
/// doppelt oder fallen ganz durch; die Salden sind dann zufällig falsch und
/// ändern sich bei jedem Neuladen.
///
/// Abhilfe: IMMER `.order('id')` als letzten Sortierschlüssel setzen.
void main() {
  test('jede paginierte Query sortiert zuletzt nach der eindeutigen id', () {
    final verstoesse = <String>[];

    for (final datei in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final inhalt = datei.readAsStringSync();
      if (!inhalt.contains('.range(')) continue;

      // Jede .range()-Stelle mit ihrem vorangehenden Query-Aufbau prüfen.
      for (final treffer in RegExp(r'\.range\(').allMatches(inhalt)) {
        final start = treffer.start - 600 < 0 ? 0 : treffer.start - 600;
        final block = inhalt.substring(start, treffer.start);
        // Nur Supabase-Queries betrachten (nicht String/Liste-Ranges).
        if (!block.contains('SupabaseService.client') &&
            !block.contains('.from(')) {
          continue;
        }
        if (!block.contains(".order('id')")) {
          final zeile = '\n'.allMatches(inhalt.substring(0, treffer.start)).length + 1;
          verstoesse.add('${datei.path}:$zeile');
        }
      }
    }

    expect(
      verstoesse,
      isEmpty,
      reason: 'Diese paginierten Abfragen haben keinen eindeutigen '
          "Sortierschlüssel — zwischen den Seiten können Zeilen doppelt "
          'erscheinen oder verloren gehen (falsche Salden!). Bitte '
          "`.order('id')` als letzten order-Aufruf ergänzen:\n"
          '${verstoesse.join('\n')}',
    );
  });
}

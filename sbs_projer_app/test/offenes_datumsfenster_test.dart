import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Wächter gegen den stillen 1000-Zeilen-Deckel bei offenen Zeiträumen.
///
/// Befund 04.09.2026: `BuchungNachholService.finde()` und
/// `ReinigungenOhneRechnung.finde()` luden «alle abgeschlossenen Reinigungen
/// ab 01.12.2025» mit einem einzigen `select()`. PostgREST liefert höchstens
/// 1000 Zeilen und sagt das nicht — bei 1022 passenden Reinigungen fielen die
/// 22 ältesten heraus. Für die wäre die Abschlussprüfung dauerhaft blind grün
/// gewesen, und der Abstand wächst mit jeder neuen Reinigung.
///
/// Die Regel trifft nur **offene** Fenster (`gte('datum')` ohne obere
/// Grenze): ein Monats- oder Jahresfenster ist von Natur aus begrenzt und
/// braucht keine Seiten. Wer ein offenes Fenster liest, muss `.range()`
/// (seitenweise) oder `.limit()` (bewusst gedeckelt) setzen.
void main() {
  test('offene Datumsfenster werden seitenweise geladen', () {
    final verstoesse = <String>[];
    final tabellen = RegExp(
      r"\.from\('(reinigungen|buchungen|rechnungen|stoerungen|montagen)'\)",
    );

    for (final datei in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final inhalt = datei.readAsStringSync();
      for (final treffer in tabellen.allMatches(inhalt)) {
        // Query-Block bis zum abschliessenden Semikolon betrachten.
        final rest = inhalt.substring(treffer.start);
        final ende = rest.indexOf(';');
        final block = ende > 0 ? rest.substring(0, ende) : rest;

        if (!block.contains(".gte('datum'")) continue; // kein Zeitraum
        if (block.contains(".lt('datum'") || block.contains(".lte('datum'")) {
          continue; // begrenztes Fenster
        }
        if (block.contains('.update(') || block.contains('.delete(')) {
          continue; // kein Leseergebnis, kein Zeilendeckel
        }
        if (block.contains('.range(') || block.contains('.limit(')) continue;

        final zeile =
            '\n'.allMatches(inhalt.substring(0, treffer.start)).length + 1;
        verstoesse.add('${datei.path}:$zeile');
      }
    }

    expect(
      verstoesse,
      isEmpty,
      reason:
          'Offenes Datumsfenster ohne .range()/.limit() — PostgREST schneidet '
          'stumm bei 1000 Zeilen ab:\n${verstoesse.join('\n')}',
    );
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `neq()` auf einer Spalte, die NULL sein kann, filtert alles weg.
///
/// Vorfall 10.09.2026: Beide Frühwarnungen für abgeschlossene Reinigungen —
/// die fehlende Ertragsbuchung und die fehlende Rechnung — enthielten
/// `.neq('quelle', 'excel_import')`. Gemeint war «Excel-Altfälle
/// überspringen». Tatsächlich lieferten beide Suchen **immer** eine leere
/// Liste: `quelle` ist bei jeder in der App erfassten Reinigung NULL, und in
/// SQL ergibt `NULL <> 'excel_import'` nicht «wahr», sondern «unbekannt».
///
/// Die Folge war doppelt unsichtbar: Der automatische Nachlauf fand nie
/// etwas, und die Warnung, die den Fall hätte melden sollen, blieb ebenfalls
/// stumm. Die Ertragsbuchungen von Signina (07.09.) und Mountain Plaza
/// (09.09.) lagen deshalb tagelang, ohne dass ein Hinweis erschien.
///
/// Solche Filter gehören in den Dart-Code, wo `null` sichtbar ist — dort
/// steht `if (row['quelle'] == 'excel_import') continue;`.
void main() {
  test('kein neq() auf nullbaren Spalten in lib/', () {
    // Spalten, die in dieser Datenbank NULL enthalten. Kommt eine dazu,
    // gehört sie hierher — der Test kann die DB nicht selbst befragen.
    const nullbar = ['quelle'];

    final verstoesse = <String>[];
    final dateien = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    for (final f in dateien) {
      final zeilen = f.readAsLinesSync();
      for (var i = 0; i < zeilen.length; i++) {
        // Kommentare ausblenden: Genau dort steht die Erklärung, warum der
        // Ausdruck verboten ist — sie darf den Test nicht auslösen. (Derselbe
        // Fehler wie in offenes_datumsfenster_test.dart, beide am 10.09.2026.)
        final kommentar = zeilen[i].indexOf('//');
        final code =
            kommentar == -1 ? zeilen[i] : zeilen[i].substring(0, kommentar);
        for (final spalte in nullbar) {
          if (code.contains(".neq('$spalte'")) {
            verstoesse.add('${f.path}:${i + 1} — .neq(\'$spalte\', …)');
          }
        }
      }
    }

    expect(verstoesse, isEmpty,
        reason: 'neq() auf einer nullbaren Spalte filtert JEDE Zeile weg, in '
            'der sie NULL ist — hier also alle. Im Dart-Code aussortieren:\n'
            '${verstoesse.join('\n')}');
  });
}

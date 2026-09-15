import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Das Diktat darf bei einer Reinigung nichts speichern.
///
/// WARUM: Alle anderen Diktat-Arten legen einen Datensatz an — Störung,
/// Montage, Termin, Aufgabe. Bei der Reinigung ist das anders und muss anders
/// bleiben: Eine abgeschlossene Reinigung zieht Rechnung, Ertragsbuchung und
/// **Mail an den Kunden** nach sich. Eine verhörte Spracherkennung würde
/// damit eine falsche Rechnung verschicken, und zurückholen lässt sich die
/// nicht (Entscheid Daniel, 15.09.2026: das Diktat öffnet nur das Formular).
///
/// Dass dort einmal ein `…Repository.` hineinrutscht, ist die naheliegende
/// Nachlässigkeit — schliesslich sieht jeder andere Zweig genau so aus.
void main() {
  test('der Reinigungs-Zweig im Diktat schreibt nichts', () {
    final datei = File('lib/presentation/widgets/diktat_sheet.dart');
    expect(datei.existsSync(), isTrue,
        reason: 'diktat_sheet.dart fehlt — Pfad im Waechter anpassen');

    final zeilen = datei.readAsLinesSync();
    final start = zeilen.indexWhere(
      (z) => z.contains("if (_art == 'reinigung')"),
    );
    expect(start, isNot(-1),
        reason:
            'Der Reinigungs-Zweig fehlt. Wurde A4 zurueckgebaut, gehoert '
            'auch dieser Waechter weg — dann aber bewusst.');

    // Bis zur schliessenden Klammer auf gleicher Einrückungstiefe lesen.
    final einrueckung = zeilen[start].indexOf('if');
    final block = <String>[];
    for (var i = start + 1; i < zeilen.length; i++) {
      final z = zeilen[i];
      if (z.trimRight() == '${' ' * einrueckung}}') break;
      // Kommentare ausblenden: Dort steht erklaert, WARUM hier nichts
      // gespeichert wird — das darf den Waechter nicht ausloesen (derselbe
      // Fehler wie am 10.09.2026 in zwei anderen Waechter-Tests).
      final k = z.indexOf('//');
      block.add(k == -1 ? z : z.substring(0, k));
    }

    final code = block.join('\n');
    for (final verboten in ['Repository.', 'await ']) {
      expect(
        code.contains(verboten),
        isFalse,
        reason:
            'Der Reinigungs-Zweig enthaelt «$verboten». Hier darf nichts '
            'gespeichert und nichts abgewartet werden — das Diktat oeffnet '
            'nur das Formular, den Abschluss macht Daniel von Hand. Sonst '
            'verschickt eine verhoerte Spracherkennung eine Rechnung.',
      );
    }

    expect(
      code.contains("router.push('/reinigungen/neu"),
      isTrue,
      reason:
          'Der Zweig soll das Reinigungsformular mit vorausgewaehltem '
          'Betrieb oeffnen — sonst tut er gar nichts.',
    );
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// B6: Fünf Oberflächen, eine Quelle. Glocke, Startkarte, Kachel, Sheet und
/// Screen lesen `aufgabenListeProvider`/`aufgabenJetztProvider`/
/// `aufgabenBadgeProvider` — und rechnen nichts selbst aus den Einsatz-
/// Providern zusammen. Vorher zeigte die Kachel andere Zahlen als die Glocke
/// (Befund 4 der App-Analyse 09/2026). Kommentare werden ausgeblendet.
void main() {
  const dateien = [
    'lib/presentation/widgets/aufgaben_glocke.dart',
    'lib/presentation/widgets/aufgaben_sheet.dart',
    'lib/presentation/screens/aufgaben/aufgaben_screen.dart',
    'lib/presentation/screens/home_screen.dart',
  ];
  const verboten = [
    'offeneEigeneAufgabenProvider',
    'AufgabenStand',
    'stoerungOffen(',
    'montageOffen(',
    'aufgabenProvider)',
    'aufgabenProvider.',
  ];
  final erlaubt = RegExp(r'aufgaben(Liste|Jetzt|Badge)Provider');

  for (final pfad in dateien) {
    test('$pfad liest die eine Aufgabenliste', () {
      final code = File(pfad)
          .readAsLinesSync()
          .map((z) {
            final k = z.indexOf('//');
            return k == -1 ? z : z.substring(0, k);
          })
          .join('\n');
      for (final v in verboten) {
        expect(code.contains(v), isFalse, reason: '$pfad enthaelt noch "$v"');
      }
      expect(erlaubt.hasMatch(code), isTrue, reason: '$pfad liest keinen der neuen Provider');
    });
  }
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Verbietet die nachweislich CanvasKit-tote Widget-Kombination.
///
/// Vorfall 13.08.2026 (dritter seiner Art): Ein `ExpansionTile` mit
/// `dense: true` renderte auf Daniels CanvasKit weder title noch subtitle —
/// die Stand-Übersicht zeigte drei Deploy-Runden lang nur das gestreckte
/// Nummern-Badge, und jede Nachbesserung landete im unsichtbaren Bereich.
/// Vorher schon: FilledButton/OutlinedButton, die nicht rendern oder nicht
/// reagieren (20.06.2026 camt-Bestätigen, 13.08.2026 Lageplan-Speichern).
///
/// Für kritische Interaktion/Anzeige gilt: GestureDetector + Container +
/// Row/Column statt Material-Komfort-Widgets (siehe CLAUDE.md).
void main() {
  test('kein ExpansionTile mit dense: true in lib/', () {
    final verstoesse = <String>[];
    final dateien = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    for (final f in dateien) {
      final text = f.readAsStringSync();
      var start = text.indexOf('ExpansionTile(');
      while (start != -1) {
        // Argumentblock grob abgrenzen: bis zur schliessenden Klammer auf
        // gleicher Tiefe reicht hier ein Fenster von 600 Zeichen — die
        // dense-Angabe steht als benannter Parameter immer weit vorne.
        final fenster =
            text.substring(start, (start + 600).clamp(0, text.length));
        if (RegExp(r'dense:\s*true').hasMatch(fenster)) {
          verstoesse.add(f.path);
          break;
        }
        start = text.indexOf('ExpansionTile(', start + 1);
      }
    }

    expect(
      verstoesse,
      isEmpty,
      reason:
          'ExpansionTile mit dense: true rendert auf CanvasKit title/subtitle '
          'nicht (Vorfall 13.08.2026, Stand-Übersicht). Eigenen Kopf aus '
          'InkWell + Row/Column bauen — Vorbild: _StandCard in '
          'event_detail_screen.dart.',
    );
  });
}

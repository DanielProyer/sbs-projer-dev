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

  // Vorfall 10.09.2026: Ein Wächter dieser Art schlug auf sein eigenes
  // Zitat im `reason`-Text an — die verbotenen Namen stehen ja auch in
  // dieser Test-Datei. Deshalb liest dieser Test ausschliesslich
  // `lib/presentation/widgets/heute_liste.dart`, nie seine eigene Datei
  // (`text` unten kommt von `datei.readAsStringSync()`, nicht von
  // `File(Platform.script...)` o.ä.). In `heute_liste.dart` selbst kommt
  // "ListTile" nur unparenthesiert in einem Kommentar vor (Begründung fürs
  // InkWell-Muster) — die geprüften Strings tragen bewusst die öffnende
  // Klammer/den Wortstamm, damit ein Prosa-Erwähnen des Namens keinen
  // Treffer auslöst.
  test('Heute-Liste ohne CanvasKit-tote Widgets', () {
    final datei = File('lib/presentation/widgets/heute_liste.dart');
    expect(datei.existsSync(), isTrue,
        reason: 'heute_liste.dart fehlt — Pfad im Waechter anpassen');
    final text = datei.readAsStringSync();

    for (final verboten in ['ListTile(', 'FilledButton', 'OutlinedButton', 'ExpansionTile(']) {
      expect(
        text.contains(verboten),
        isFalse,
        reason:
            '$verboten in der Heute-Liste. Die Liste steht auf der '
            'meistgenutzten Seite der App; rendert der Start-Pfeil auf '
            'CanvasKit nicht, merkt es niemand bis zum naechsten '
            'Arbeitstag. GestureDetector + Container + Row verwenden '
            '(CLAUDE.md, drei bestaetigte Vorfaelle).',
      );
    }
  });
}

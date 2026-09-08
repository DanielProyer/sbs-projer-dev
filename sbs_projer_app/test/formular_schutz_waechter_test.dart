import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Jedes Formular muss vor Datenverlust beim Verlassen schützen.
///
/// Befund 6 der App-Analyse vom 08.09.2026: Von 19 Formular-Screens hatte
/// keines einen Schutz — ein Wischer am Rand des Pixel 9, und eine ganze
/// Reinigung mit Fotos und Positionen war weg. Dieser Test hält den Zustand
/// fest, damit ein neues Formular ihn nicht still wieder einführt.
///
/// Drei Dinge gehören zusammen, und jedes fehlt in der Praxis gern einzeln:
/// der Wächter um das Scaffold, das Markieren bei jeder Änderung und das
/// Zurücksetzen vor dem Verlassen nach dem Speichern (sonst fragt der
/// Schutz auch nach einem erfolgreichen Speichern nach).
void main() {
  test('jedes *_form_screen.dart nutzt UngespeichertSchutz vollständig', () {
    final formulare = Directory('lib/presentation/screens')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('_form_screen.dart'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    expect(formulare, isNotEmpty);

    final verstoesse = <String>[];
    for (final f in formulare) {
      final text = f.readAsStringSync();
      final fehlt = <String>[
        if (!text.contains('UngespeichertSchutz(')) 'Wächter',
        if (!text.contains('onChanged: markiereGeaendert')) 'Form.onChanged',
        if (!text.contains('geaendertZuruecksetzen()')) 'Zurücksetzen',
      ];
      if (fehlt.isNotEmpty) {
        verstoesse.add('${f.path}: ${fehlt.join(', ')} fehlt');
      }
    }

    expect(verstoesse, isEmpty,
        reason: 'Formulare ohne vollständigen Schutz vor Datenverlust:\n'
            '${verstoesse.join('\n')}');
  });
}

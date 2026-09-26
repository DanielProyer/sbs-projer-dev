import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Eine 5-Rappen-Rundung: `rundeAuf5Rappen` aus `core/util/rundung.dart`.
///
/// Bis Runde 4 (26.09.2026) gab es neben ihr `runde5Rappen` und zehn private
/// Kopien in Screens und PDF-Services — jede eine Stelle, an der die
/// Rundungsregel still auseinanderlaufen kann.
void main() {
  test('Die 5-Rappen-Formel steht in lib/ nur in rundung.dart', () {
    final formel = RegExp(r'\*\s*20\s*\)\s*\.round(ToDouble)?\(\)\s*/\s*20');
    final treffer = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final pfad = f.path.replaceAll(r'\', '/');
      if (pfad.endsWith('core/util/rundung.dart')) continue;
      final zeilen = f.readAsLinesSync();
      for (var i = 0; i < zeilen.length; i++) {
        if (formel.hasMatch(zeilen[i])) {
          treffer.add('$pfad:${i + 1}: ${zeilen[i].trim()}');
        }
      }
    }
    expect(treffer, isEmpty,
        reason: 'rundeAuf5Rappen() aus core/util/rundung.dart benutzen');
  });
}

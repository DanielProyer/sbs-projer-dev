import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Jede Datumsauswahl läuft über `zeigeDatumsauswahl` (Analyse-Runde 4,
/// «eine Datumsauswahl»). Muster: `test/zeitauswahl_waechter_test.dart`.
///
/// WARUM als Wächter: Vor diesem Refactoring standen 29 direkte
/// `showDatePicker(`-Aufrufe mit uneinheitlichen Grenzen in 27 Dateien.
/// Ohne den Wächter schleicht sich der direkte Aufruf beim nächsten
/// Datumsfeld wieder ein.
void main() {
  const erlaubt = 'lib/presentation/widgets/datum_auswahl.dart';

  test('kein showDatePicker ausserhalb von datum_auswahl.dart', () {
    final verstoesse = <String>[];
    final dateien = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final f in dateien) {
      final pfad = f.path.replaceAll('\\', '/');
      if (pfad.endsWith(erlaubt)) continue;
      // Kommentare ausblenden: Eine Erklärung, warum hier KEIN
      // showDatePicker steht, darf den Wächter nicht auslösen.
      final code = f
          .readAsLinesSync()
          .map((z) {
            final k = z.indexOf('//');
            return k == -1 ? z : z.substring(0, k);
          })
          .join('\n');
      if (code.contains('showDatePicker(')) verstoesse.add(pfad);
    }
    expect(
      verstoesse,
      isEmpty,
      reason:
          'Diese Dateien rufen showDatePicker direkt auf. Stattdessen '
          'zeigeDatumsauswahl(context, initial: …) aus $erlaubt verwenden:\n'
          '${verstoesse.join('\n')}',
    );
  });
}

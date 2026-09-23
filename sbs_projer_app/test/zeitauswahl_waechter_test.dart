import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Jede Zeitauswahl läuft über `zeigeZeitauswahl` (24 Stunden, ohne AM/PM).
///
/// WARUM als Wächter: Die Regel steht seit 29.07.2026 («wie die Servicezeit
/// am Betrieb, überall»), trotzdem rief die Saison-Abmachung (v0.125.0) den
/// Flutter-Dialog direkt auf — beim Termin für Eröffnungs- und
/// Endreinigungen erschien wieder AM/PM (Daniel 23.09.2026). Ein direkter
/// `showTimePicker` richtet sich nach dem Gebietsschema des Geräts; das
/// fällt erst auf, wenn man die Zeit eingibt.
void main() {
  const erlaubt = 'lib/presentation/widgets/zeit_auswahl.dart';

  test('kein showTimePicker ausserhalb von zeit_auswahl.dart', () {
    final verstoesse = <String>[];
    final dateien = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final f in dateien) {
      final pfad = f.path.replaceAll('\\', '/');
      if (pfad.endsWith(erlaubt)) continue;
      // Kommentare ausblenden: Eine Erklärung, warum hier KEIN
      // showTimePicker steht, darf den Wächter nicht auslösen.
      final code = f
          .readAsLinesSync()
          .map((z) {
            final k = z.indexOf('//');
            return k == -1 ? z : z.substring(0, k);
          })
          .join('\n');
      if (code.contains('showTimePicker(')) verstoesse.add(pfad);
    }
    expect(
      verstoesse,
      isEmpty,
      reason:
          'Diese Dateien rufen showTimePicker direkt auf und zeigen je nach '
          'Gerät AM/PM. Stattdessen zeigeZeitauswahl(context, initial: …) '
          'aus $erlaubt verwenden:\n${verstoesse.join('\n')}',
    );
  });

  test('zeit_auswahl.dart erzwingt weiterhin 24 Stunden', () {
    final code = File(erlaubt).readAsStringSync();
    expect(code.contains('alwaysUse24HourFormat: true'), isTrue);
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ratsche: Die verstreuten Statusvergleiche duerfen nur weniger werden.
///
/// WARUM: Sechs Einsatztypen tragen vier Status-Vokabulare. Seit B2 gibt es
/// eine Ableitung (`einsatz_lage.dart`), aber rund 37 Stellen vergleichen
/// noch direkt (`status == 'behoben'`). Sie alle auf einmal umzubauen waere
/// eine Grossaktion mit Risiko; sie einfach zu lassen hiesse, dass neue
/// dazukommen. Diese Ratsche schreibt den Stand fest — jeder, der eine
/// dieser Dateien anfasst, senkt die Zahl, und `anlage_detail_screen.dart:878`
/// (Stoerung == 'abgeschlossen', ein Wert, den Stoerungen nie tragen)
/// verschwindet, sobald jemand dort vorbeikommt.
///
/// Zaehlt nur Vergleiche der Einsatz-Vokabulare; `zahlungsstatus` der
/// Rechnungen und andere Statusfelder sind ausgenommen (kein Identifikator-
/// zeichen direkt vor `status`).
void main() {
  test('Statusvergleiche werden nicht mehr', () {
    // Startwert 23 nach Umsetzung von B2 (15.09.2026). Nur senken.
    // 15.09.2026: 23 -> 20, drei Vergleiche lagen in den alten Listen (B6).
    const erlaubt = 20;

    final muster = RegExp(
      r"(?<![A-Za-z_])status\s*==\s*'(offen|geplant|in_bearbeitung|behoben|"
      r"abgeschlossen|abgerechnet|storniert|nicht_behebbar|abgebrochen|"
      r"nachbearbeitung_noetig|erledigt|vorgeschlagen|abgesagt)'",
    );
    const ausgenommen = {
      'lib/core/util/einsatz_lage.dart',
      // Alt: `einsatzStatusNachSpeichern` (Fall Sartons, v0.76.0) — bleibt,
      // bis die Formulare auf die Lage umgestellt sind.
      'lib/core/util/einsatz_status.dart',
      'lib/core/util/tour_filter.dart',
    };

    final treffer = <String>[];
    final dateien = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'));
    for (final f in dateien) {
      final pfad = f.path.replaceAll('\\', '/');
      if (ausgenommen.any(pfad.endsWith)) continue;
      final zeilen = f.readAsLinesSync();
      for (var i = 0; i < zeilen.length; i++) {
        final k = zeilen[i].indexOf('//');
        final code = k == -1 ? zeilen[i] : zeilen[i].substring(0, k);
        if (muster.hasMatch(code)) treffer.add('$pfad:${i + 1}');
      }
    }

    expect(
      treffer.length,
      lessThanOrEqualTo(erlaubt),
      reason:
          'Es gibt ${treffer.length} direkte Statusvergleiche, erlaubt sind '
          '$erlaubt. Neue Vergleiche gehoeren nicht in den Code — die Stufe '
          'liefert einsatz_lage.dart. Wer eine Datei anfasst, stellt deren '
          'Vergleiche um und senkt den Wert hier.\n${treffer.join('\n')}',
    );
  });
}

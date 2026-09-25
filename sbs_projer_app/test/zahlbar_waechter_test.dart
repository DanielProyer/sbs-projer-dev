import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Wächter: Der Bankabgleich fragt `istZahlbar()`, nie eigene Statuslisten.
///
/// WARUM (Analyse 25.09.2026, R2): Import-Tab und Zuordnen-Dialog filterten
/// je von Hand auf `zahlungsstatus == 'offen' || == 'gesendet'` und
/// `rechnungstyp == 'kundenrechnung'`. Gemahnte Rechnungen und
/// Jahresrechnungen fielen dadurch aus dem Abgleich — ihre Zahlungen wären
/// als «unbekannte Gutschrift» liegen geblieben. Die Regel steht jetzt in
/// `lib/core/util/rechnung_status.dart`; neue Handfilter in den camt-Pfaden
/// würden sie still wieder aushebeln.
void main() {
  test('camt-Pfade filtern Zahlungskandidaten nur über istZahlbar', () {
    final muster = RegExp(
      r"zahlungsstatus\s*==\s*'(offen|gesendet|erinnert|mahnung_1|mahnung_2)'"
      r"|rechnungstyp\s*==\s*'(kundenrechnung|jahresrechnung)'",
    );
    const ordner = [
      'lib/presentation/screens/buchhaltung/camt',
      'lib/services/camt',
    ];
    const einzeldateien = [
      'lib/presentation/screens/buchhaltung/widgets/abgleich_vorschau.dart',
    ];

    final dateien = <File>[
      for (final o in ordner)
        ...Directory(o)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart')),
      for (final d in einzeldateien) File(d),
    ];
    expect(dateien, isNotEmpty);

    final treffer = <String>[];
    for (final f in dateien) {
      final pfad = f.path.replaceAll('\\', '/');
      final zeilen = f.readAsLinesSync();
      for (var i = 0; i < zeilen.length; i++) {
        final k = zeilen[i].indexOf('//');
        final code = k == -1 ? zeilen[i] : zeilen[i].substring(0, k);
        if (muster.hasMatch(code)) treffer.add('$pfad:${i + 1}');
      }
    }

    expect(
      treffer,
      isEmpty,
      reason:
          'Zahlungskandidaten gehören über `istZahlbar()` '
          '(core/util/rechnung_status.dart) gefiltert, nicht über eigene '
          'Status-/Typvergleiche:\n${treffer.join('\n')}',
    );
  });
}

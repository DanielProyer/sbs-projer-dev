import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Wächter: Nach einem Versand wird `gesendet` nie pauschal geschrieben.
///
/// WARUM (Analyse 25.09.2026, R4): Vier Stellen setzten nach dem Mailversand
/// `'zahlungsstatus': 'gesendet'` ohne Rücksicht auf den aktuellen Stand. Ein
/// Neuversand aus dem Reinigungsdetail hätte eine bezahlte oder gemahnte
/// Rechnung zurückgedreht. Der Weg führt jetzt über
/// `ReinigungRechnungVersand.vermerkeVersand` / `hebeStatusNachVersand`
/// (nur `offen` → `gesendet`, abgesichert per `.eq('zahlungsstatus','offen')`).
///
/// Ausgenommen: die Heineken-Monatsrechnung (eigener Workflow
/// offen → gesendet → freigegeben → bezahlt).
void main() {
  test('kein pauschales zahlungsstatus: gesendet ausserhalb Heineken', () {
    final muster = RegExp(r"'zahlungsstatus'\s*:\s*'gesendet'");
    final treffer = <String>[];
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final pfad = f.path.replaceAll('\\', '/');
      if (pfad.contains('/screens/heineken/')) continue;
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
          'Versandstatus über ReinigungRechnungVersand.vermerkeVersand setzen '
          '(nur offen → gesendet):\n${treffer.join('\n')}',
    );
  });
}

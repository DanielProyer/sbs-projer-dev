import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Wächter: Ein Versand schreibt keinen Status.
///
/// WARUM (Analyse 25.09.2026, R4): Vier Stellen setzten nach dem Mailversand
/// `'zahlungsstatus': 'gesendet'` ohne Rücksicht auf den aktuellen Stand. Ein
/// Neuversand aus dem Reinigungsdetail hätte eine bezahlte oder gemahnte
/// Rechnung zurückgedreht. Bis Migration 211 führte der Weg deshalb über
/// `hebeStatusNachVersand` (nur `offen` → `gesendet`).
///
/// Seit Migration 211 (27.09.2026) gibt es `gesendet` nicht mehr: Die
/// Zustellung IST `versendet_am`, `ReinigungRechnungVersand.vermerkeVersand`
/// schreibt nur noch das Datum. Auch die Heineken-Monatsrechnung (B3) —
/// ihre Freigabe steht in `freigegeben_am`, ein Versand kann sie nicht
/// zurückdrehen.
void main() {
  test('kein zahlungsstatus: gesendet — auch nicht Heineken', () {
    final muster = RegExp(r"'zahlungsstatus'\s*:\s*'gesendet'");
    final treffer = <String>[];
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
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
          'Den Versand hält versendet_am fest (ReinigungRechnungVersand.'
          'vermerkeVersand), keinen Status:\n${treffer.join('\n')}',
    );
  });

  test('vermerkeVersand schreibt nur versendet_am, hebeStatus ist weg', () {
    final code = File(
      'lib/services/rechnung/reinigung_rechnung_versand.dart',
    ).readAsStringSync();
    final start = code.indexOf('static Future<void> vermerkeVersand(');
    expect(start, isNot(-1));
    final ende = code.indexOf('\n  }', start);
    final rumpf = code.substring(start, ende);
    expect(rumpf, contains("'versendet_am'"));
    expect(rumpf, isNot(contains('zahlungsstatus')));
    expect(code, isNot(contains('hebeStatusNachVersand')));
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Kein Menüeintrag zeigt auf eine Route, die es nicht gibt.
///
/// WARUM: Am 17.09.2026 schickten zwei Fehlermeldungen Daniel «ins
/// Reinigungs-Detail nachbuchen» — dort gibt es kein Nachbuchen. Ein
/// Wegweiser, der ins Leere zeigt, kostet eine Suche und am Ende das
/// Vertrauen. Für Meldungstexte kann das kein Test prüfen, für Navigations-
/// ziele schon: Der Router weiss, welche Pfade existieren.
///
/// Geprüft werden nur **literale** Pfade (ohne Interpolation) — genau die
/// Menü- und Kachel-Ziele, um die es geht.
void main() {
  final routen = _routenPfade();

  test('der Router liefert ueberhaupt Pfade', () {
    expect(routen.length, greaterThan(50), reason: 'Scanner kaputt?');
    expect(routen, contains('/'));
    expect(routen, contains('/buchhaltung'));
  });

  test('jedes literale Navigationsziel existiert', () {
    final tote = <String>[];
    for (final f in Directory(
      'lib/presentation',
    ).listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final pfad = f.path.replaceAll(r'\', '/');
      final quelle = f.readAsStringSync();
      for (final m in RegExp(
        r"""context\.(?:push|go|pushReplacement)\(\s*'(/[^'$]*)'""",
      ).allMatches(quelle)) {
        final ziel = m.group(1)!.split('?').first;
        if (!_kennt(routen, ziel)) {
          final zeile =
              '\n'.allMatches(quelle.substring(0, m.start)).length + 1;
          tote.add('$pfad:$zeile → $ziel');
        }
      }
    }
    expect(
      tote,
      isEmpty,
      reason: 'Navigationsziele ohne Route im Router:\n${tote.join('\n')}',
    );
  });
}

/// Alle im Router deklarierten Pfade.
Set<String> _routenPfade() {
  final quelle = File('lib/core/config/router.dart').readAsStringSync();
  return RegExp(
    r"path:\s*'([^']+)'",
  ).allMatches(quelle).map((m) => m.group(1)!).toSet();
}

/// Passt [ziel] auf eine Route? Router-Segmente mit `:` nehmen jedes Segment.
bool _kennt(Set<String> routen, String ziel) {
  if (routen.contains(ziel)) return true;
  final zielTeile = ziel.split('/');
  for (final route in routen) {
    final teile = route.split('/');
    if (teile.length != zielTeile.length) continue;
    var passt = true;
    for (var i = 0; i < teile.length; i++) {
      if (teile[i].startsWith(':')) continue;
      if (teile[i] != zielTeile[i]) {
        passt = false;
        break;
      }
    }
    if (passt) return true;
  }
  return false;
}

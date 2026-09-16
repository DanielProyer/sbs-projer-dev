import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/navigation_ziele.dart';

/// Kein Formular trägt die Navigationsleiste (B1).
///
/// WARUM als Wächter: `zeigtNavigation` erkennt Formulare an der Endung
/// `/neu` bzw. `/bearbeiten` und an einer Liste von Ausnahmen. Beides ist
/// von Hand gepflegt — ein neues Formular mit eigenem Pfad bekäme sonst
/// eine Leiste, und ein Fehltipp darauf kostet die Eingabe. Dieser Test
/// liest die Routen und hält die Liste ehrlich.
void main() {
  final quelle = File('lib/core/config/router.dart').readAsStringSync();

  /// Routen-Blöcke: An `GoRoute(` geteilt, beginnt jeder Abschnitt mit dem
  /// `path` seiner Route und enthält deren `builder`.
  List<(String pfad, String block)> routen() {
    final ergebnis = <(String, String)>[];
    for (final block in quelle.split('GoRoute(').skip(1)) {
      final treffer = RegExp(r"path:\s*'([^']+)'").firstMatch(block);
      if (treffer != null) ergebnis.add((treffer.group(1)!, block));
    }
    return ergebnis;
  }

  /// `/betriebe/:id/bearbeiten` → `/betriebe/x1/bearbeiten`
  String echterPfad(String muster) =>
      muster.split('/').map((s) => s.startsWith(':') ? 'x1' : s).join('/');

  test('router.dart wird gefunden und enthaelt Routen', () {
    expect(routen().length, greaterThan(50));
  });

  test('jede *FormScreen-Route zeigt keine Leiste', () {
    final verstoesse = <String>[];
    for (final (pfad, block) in routen()) {
      if (!block.contains('FormScreen(')) continue;
      if (zeigtNavigation(echterPfad(pfad))) verstoesse.add(pfad);
    }
    expect(
      verstoesse,
      isEmpty,
      reason:
          'Diese Formular-Routen bekaemen eine Navigationsleiste. Entweder '
          'endet der Pfad auf /neu bzw. /bearbeiten, oder er gehoert in '
          '`kFormularPfade` in lib/core/util/navigation_ziele.dart:\n'
          '${verstoesse.join('\n')}',
    );
  });

  test('kein Eintrag in kFormularPfade ist eine Karteileiche', () {
    final alle = routen().map((r) => r.$1).toList();
    final tot = <String>[];
    for (final eintrag in kFormularPfade) {
      if (eintrag == '/login') continue; // existiert, wird unten geprueft
      final basis = eintrag.endsWith('/')
          ? eintrag.substring(0, eintrag.length - 1)
          : eintrag;
      final gibtEs = alle.any((p) => p == basis || p.startsWith('$basis/'));
      if (!gibtEs) tot.add(eintrag);
    }
    expect(alle, contains('/login'));
    expect(
      tot,
      isEmpty,
      reason:
          'Eintraege ohne passende Route (Pfad umbenannt oder Screen '
          'entfernt?):\n${tot.join('\n')}',
    );
  });
}

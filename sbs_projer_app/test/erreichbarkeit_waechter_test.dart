import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/config/bereiche.dart';
import 'package:sbs_projer_app/core/util/navigation_ziele.dart';
import 'package:sbs_projer_app/presentation/widgets/bereich_reiter.dart';

/// Jeder Listen-Screen ist über die Navigation erreichbar (v0.131.0).
///
/// WARUM: Die Bestellungen-Liste war bis v0.47.0 unauffindbar, und mit dem
/// Wegfall der «Weitere»-Liste auf Heute könnte das jedem Eintrag passieren,
/// den niemand umhängt. Erreichbar heisst: Leisten-Ziel, Eintrag in
/// `bereiche.dart`, Reiter — oder eine Unterseite, deren Link in der
/// genannten Datei wirklich steht.
void main() {
  final router = File('lib/core/config/router.dart').readAsStringSync();
  final pfade = RegExp(r"path:\s*'([^']+)'")
      .allMatches(router)
      .map((m) => m.group(1)!)
      .toSet();

  /// Reine Weiterleitungen (Route mit `redirect:`, ohne eigenen `builder:`)
  /// sind Aliase für alte Links — sie brauchen keinen eigenen Weg, ihr Ziel
  /// wird selbst geprüft. Am 22.09.2026 standen vier davon irrtümlich als
  /// «ohne Link» in einer Ausnahmeliste (etwa `/buchhaltung/bilanz` →
  /// `/buchhaltung/berichte`).
  final aliase = <String>{};
  for (final block in router.split('GoRoute(').skip(1)) {
    if (!block.contains('redirect:') || block.contains('builder:')) continue;
    final pfad = RegExp(r"path:\s*'([^']+)'").firstMatch(block)?.group(1);
    if (pfad != null) aliase.add(pfad);
  }

  bool detailOderFormular(String p) =>
      p.contains('/:') ||
      p.endsWith('/neu') ||
      p.endsWith('/bearbeiten') ||
      !zeigtNavigation(p);

  final direkt = <String>{
    for (final z in NavZiel.values) navPfad(z),
    for (final b in kAlleBereiche) ...b.alleEintraege.map((e) => e.ziel),
    ...kReiterBetriebe.map((r) => r.pfad),
    ...kReiterRechnungen.map((r) => r.pfad),
  };

  /// Unterseiten: Route → Datei, in der der Weg dorthin steht.
  const unterseiten = <String, String>{
    '/betriebe/servicezeiten':
        'lib/presentation/screens/betriebe/betriebe_list_screen.dart',
    '/betriebe/saisondaten':
        'lib/presentation/screens/touren/tourenplanung_screen.dart',
    '/betriebe/vorschlaege': 'lib/core/util/aufgabe.dart',
    '/anlagen': 'lib/presentation/screens/einstellungen/stammdaten_screen.dart',
    '/heineken/zuweisungen':
        'lib/presentation/screens/einstellungen/stammdaten_screen.dart',
    '/heineken/raster':
        'lib/presentation/screens/heineken/heineken_rechnungen_list_screen.dart',
    '/bergkundenpauschalen':
        'lib/presentation/screens/heineken/heineken_rechnungen_list_screen.dart',
    '/buchhaltung/abschreibung':
        'lib/services/buchhaltung/abschluss_regeln.dart',
    '/buchhaltung/camt-pruefliste': 'lib/core/util/aufgaben_regeln.dart',
    '/buchhaltung/eingangsrechnungen/regeln':
        'lib/presentation/screens/eingangsrechnungen/eingangsrechnung_liste_screen.dart',
    '/buchhaltung/eingangsrechnungen/zahlungsfile':
        'lib/presentation/screens/eingangsrechnungen/eingangsrechnung_liste_screen.dart',
    '/buchhaltung/lohn/einstellungen':
        'lib/presentation/screens/einstellungen/stammdaten_screen.dart',
    '/materialien/bestellungen':
        'lib/presentation/screens/materialien/materialien_list_screen.dart',
    '/einstellungen/biersorten':
        'lib/presentation/screens/einstellungen/stammdaten_screen.dart',
    '/einstellungen/regionen':
        'lib/presentation/screens/einstellungen/stammdaten_screen.dart',
    '/google-termine':
        'lib/presentation/screens/einstellungen/einstellungen_screen.dart',
  };

  test('router.dart wird gelesen', () {
    expect(pfade.length, greaterThan(50));
  });

  test('Alias-Erkennung greift (sonst wuerde sie still alles durchwinken)', () {
    expect(
      aliase,
      containsAll([
        '/buchhaltung/bilanz',
        '/buchhaltung/debitoren',
        '/buchhaltung/camt-regeln',
        '/buchhaltung/camt-dateien',
      ]),
    );
    // Screens mit bedingter Weiterleitung sind KEINE Aliase.
    expect(aliase.intersection(direkt), isEmpty);
  });

  test('jede Listen-Route ist erreichbar', () {
    final fehlt = <String>[];
    for (final p in pfade) {
      if (p == '/login' || detailOderFormular(p)) continue;
      if (direkt.contains(p) || aliase.contains(p)) continue;
      final datei = unterseiten[p];
      if (datei != null && File(datei).readAsStringSync().contains("'$p")) {
        continue;
      }
      fehlt.add(p);
    }
    expect(
      fehlt,
      isEmpty,
      reason:
          'Nicht erreichbar: ${fehlt.join(', ')}. In bereiche.dart eintragen '
          'oder als Unterseite mit der verlinkenden Datei in diesen Test.',
    );
  });

  test('Unterseiten-Liste ohne Karteileichen', () {
    for (final p in unterseiten.keys) {
      expect(pfade.contains(p), isTrue, reason: '$p gibt es nicht mehr');
    }
    for (final e in unterseiten.entries) {
      expect(
        File(e.value).readAsStringSync().contains("'${e.key}"),
        isTrue,
        reason: '${e.value} verlinkt ${e.key} nicht mehr',
      );
    }
  });

  test('jedes Bereichs-Ziel gibt es als Route', () {
    for (final z in direkt) {
      expect(pfade.contains(z), isTrue, reason: z);
    }
  });
}

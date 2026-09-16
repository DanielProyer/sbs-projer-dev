# Untere Navigationsleiste (B1) — Umsetzungsplan

> **Für agentische Arbeiter:** ERFORDERLICHE SUB-SKILL: `superpowers:subagent-driven-development` (empfohlen) oder `superpowers:executing-plans`, um diesen Plan Aufgabe für Aufgabe umzusetzen. Die Schritte nutzen Checkbox-Syntax (`- [ ]`).

**Ziel:** Eine untere Leiste mit vier Zielen — Heute · Einsätze · Betriebe · Tour — ist von jedem Screen aus erreichbar, ausser in Formularen.

**Architektur:** Zwei reine Funktionen entscheiden alles (`aktivesZiel`, `zeigtNavigation`); die Leiste ist ein darstellendes Widget ohne Router-Wissen; ein angebundener Rahmen beobachtet `router.routeInformationProvider` und hängt im `MaterialApp.builder` als `Column`-Geschwister unter dem Inhalt. Zum Schluss fallen die sieben Kacheln, die dieselben Ziele doppeln.

**Tech-Stack:** Flutter · GoRouter 14 · Riverpod · `flutter_test`

**Spec:** `docs/superpowers/specs/2026-09-16-navigationsleiste-b1-design.md`

**Modellwahl:** 1, 2, 4, 5 mechanisch (Sonnet). 3 greift in `app.dart` ein (Sonnet, Review durch Koordinator). 6 Koordinator.

---

## Dateistruktur

| Datei | Zuständigkeit | Neu/Ändern |
|---|---|---|
| `lib/core/util/navigation_ziele.dart` | `NavZiel`, `navPfad`, `navLabel`, `navIcon`, `aktivesZiel`, `zeigtNavigation`, `kFormularPfade`, `kNavigationHoehe` | **Neu** |
| `lib/presentation/widgets/haupt_navigation.dart` | `HauptNavigation` (rein) und `HauptNavigationLeiste` (angebunden) | **Neu** |
| `lib/app.dart:159-161` | Leiste in den `builder` einhängen | Ändern |
| `lib/presentation/widgets/aufgaben_glocke.dart:28` | Glocke von `bottom: 96` auf `152` | Ändern |
| `lib/presentation/screens/home_screen.dart` | sieben Kacheln und ihre Zähler entfernen | Ändern |
| `lib/presentation/providers/kachel_zaehler_providers.dart` | nicht mehr gelesene Zähler entfernen | Ändern |
| `test/navigation_ziele_test.dart` | die beiden Regeln | **Neu** |
| `test/haupt_navigation_test.dart` | Leiste auf 360 px, Roboto | **Neu** |
| `test/formular_ohne_navigation_waechter_test.dart` | jedes `*FormScreen` ohne Leiste | **Neu** |
| `test/canvaskit_sichere_widgets_test.dart` | `haupt_navigation.dart` in die Dateiliste | Ändern |
| `test/kachel_zaehler_test.dart`, `test/kachel_text_test.dart` | auf die drei verbleibenden Kacheln | Ändern |

**Version:** v0.107.0 (`pubspec.yaml` Zeile 4 `0.107.0+752`, `kAppVersion`).

**Gilt für alle Aufgaben:** Arbeitsverzeichnis `sbs_projer_app`; in Bash `export PATH="$PATH:/c/flutter/bin"`; `flutter analyze` hat 56 vorbestehende Infos — keine neuen (weniger ist gut, dann die Zahl melden); Kommentare auf Deutsch (Schweiz: «ss» statt «ß»), sie erklären das WARUM; Commit-Nachrichten ohne Umlaute; nie `git stash`; Layout-Tests laden Roboto (Muster `test/kachel_text_test.dart:28-35`); **CanvasKit-Regel:** Navigation und Listenzeilen aus `InkWell`/`GestureDetector` + `Container` + `Row`, **kein `NavigationBar`, `BottomNavigationBar`, `FilledButton`, `OutlinedButton`, `ListTile`** — auf dem produktiven CanvasKit-Web dreimal bestätigt nicht gerendert oder nicht reagiert.

---

### Task 1: Ziele und Regeln

**Files:**
- Create: `lib/core/util/navigation_ziele.dart`
- Test: `test/navigation_ziele_test.dart`

Hintergrund: Zwei Entscheidungen bestimmen die ganze Leiste — welches Ziel hervorgehoben ist und ob die Leiste überhaupt erscheint. Beide als reine Funktion mit einem `String` als Eingabe, damit sie ohne Router und ohne Widget prüfbar sind.

Die Formularliste ist am Code belegt (16.09.2026): `*FormScreen`-Routen enden fast alle auf `/neu` oder `/bearbeiten`; die zwei Ausnahmen sind `/betriebe/:id/rechnungsadresse` (`BetriebRechnungsadresseFormScreen`) und `/einstellungen/preise/:id` (`PreisVersionFormScreen`). Dazu kommen vier mehrstufige Vorgänge ohne `FormScreen` im Namen und das Lageplan-Werkzeug.

- [ ] **Step 1: Den fehlschlagenden Test schreiben** — `test/navigation_ziele_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/navigation_ziele.dart';

void main() {
  group('navPfad und navLabel', () {
    test('vier Ziele mit Pfad und Beschriftung', () {
      expect(NavZiel.values, [
        NavZiel.heute,
        NavZiel.einsaetze,
        NavZiel.betriebe,
        NavZiel.tour,
      ]);
      expect(navPfad(NavZiel.heute), '/');
      expect(navPfad(NavZiel.einsaetze), '/einsaetze');
      expect(navPfad(NavZiel.betriebe), '/betriebe');
      expect(navPfad(NavZiel.tour), '/touren');
      expect(navLabel(NavZiel.heute), 'Heute');
      expect(navLabel(NavZiel.einsaetze), 'Einsätze');
      expect(navLabel(NavZiel.betriebe), 'Betriebe');
      expect(navLabel(NavZiel.tour), 'Tour');
    });
  });

  group('aktivesZiel', () {
    test('die vier Ziele selbst', () {
      expect(aktivesZiel('/'), NavZiel.heute);
      expect(aktivesZiel('/einsaetze'), NavZiel.einsaetze);
      expect(aktivesZiel('/betriebe'), NavZiel.betriebe);
      expect(aktivesZiel('/touren'), NavZiel.tour);
    });

    test('Unterseiten zaehlen zum Ziel', () {
      expect(aktivesZiel('/betriebe/abc-123'), NavZiel.betriebe);
      expect(aktivesZiel('/betriebe/abc-123/rechnungsadresse'), NavZiel.betriebe);
      expect(aktivesZiel('/einsaetze?typ=stoerung'.split('?').first), NavZiel.einsaetze);
    });

    test('Detailseiten der Einsatztypen zeigen auf Einsaetze', () {
      for (final p in [
        '/reinigungen/abc',
        '/stoerungen/abc',
        '/montagen/abc',
        '/eigenauftraege/abc',
        '/eroeffnungsreinigungen/abc',
        '/pikett/abc',
      ]) {
        expect(aktivesZiel(p), NavZiel.einsaetze, reason: p);
      }
    });

    test('Fremdes hebt nichts hervor — die Leiste bleibt trotzdem', () {
      expect(aktivesZiel('/buchhaltung'), isNull);
      expect(aktivesZiel('/rechnungen/abc'), isNull);
      expect(aktivesZiel('/aufgaben'), isNull);
      expect(zeigtNavigation('/buchhaltung'), isTrue);
    });

    test('ein Praefix darf keinen anderen Namen kapern', () {
      // '/betriebe-alt' faengt mit '/betriebe' an, ist aber etwas anderes.
      expect(aktivesZiel('/betriebe-alt'), isNull);
    });
  });

  group('zeigtNavigation', () {
    test('die vier Ziele und normale Seiten zeigen sie', () {
      for (final p in ['/', '/einsaetze', '/betriebe', '/touren', '/aufgaben',
          '/buchhaltung', '/betriebe/abc', '/reinigungen/abc', '/dokumente']) {
        expect(zeigtNavigation(p), isTrue, reason: p);
      }
    });

    test('Formulare nicht — Endung neu und bearbeiten', () {
      for (final p in [
        '/reinigungen/neu',
        '/stoerungen/neu',
        '/betriebe/neu',
        '/betriebe/abc/bearbeiten',
        '/anlagen/abc/bierleitungen/neu',
        '/buchhaltung/buchungen/neu',
      ]) {
        expect(zeigtNavigation(p), isFalse, reason: p);
      }
    });

    test('Formulare ohne solche Endung', () {
      for (final p in [
        '/login',
        '/spesen',
        '/betriebe/abc-123/rechnungsadresse',
        '/einstellungen/preise/abc-123',
        '/buchhaltung/camt-import',
        '/buchhaltung/eingangsrechnungen/upload',
        '/materialien/bestellen',
        '/events/abc/lageplan',
      ]) {
        expect(zeigtNavigation(p), isFalse, reason: p);
      }
    });

    test('aehnliche Pfade bleiben verschont', () {
      // Die Liste darf nicht ueber das Ziel hinausschiessen.
      expect(zeigtNavigation('/materialien'), isTrue);
      expect(zeigtNavigation('/materialien/bestellungen'), isTrue);
      expect(zeigtNavigation('/einstellungen'), isTrue);
      expect(zeigtNavigation('/buchhaltung/eingangsrechnungen'), isTrue);
      expect(zeigtNavigation('/events/abc'), isTrue);
    });

    test('abschliessender Schraegstrich aendert nichts', () {
      expect(zeigtNavigation('/reinigungen/neu/'), isFalse);
      expect(zeigtNavigation('/betriebe/'), isTrue);
      expect(zeigtNavigation('/'), isTrue);
    });
  });
}
```

Achtung bei `/materialien/bestellungen`: Die Bestell**ungen**-Liste zeigt die Leiste, das Bestell**en**-Formular nicht. Ein blosses `startsWith('/materialien/bestellen')` würde beide treffen — deshalb steht der Pfad in der Liste als exakter Eintrag, nicht als Präfix.

- [ ] **Step 2: Test laufen lassen, Fehlschlag prüfen**

Run: `flutter test test/navigation_ziele_test.dart`
Erwartet: FEHLER — `Target of URI doesn't exist: navigation_ziele.dart`

- [ ] **Step 3: Umsetzung** — `lib/core/util/navigation_ziele.dart`:

```dart
import 'package:flutter/material.dart';

/// Die vier Ziele der unteren Navigationsleiste (B1).
///
/// WARUM diese vier: Die App hat 97 Routen und hatte keine globale
/// Navigation — aus einer Eingangsrechnung zurück zur Startseite waren es
/// drei Mal «zurück». Die Analyse schlug «Heute · Betriebe · Einsätze ·
/// Büro» vor; die Nutzungsmessung (`route_nutzung`, 09.–16.09.2026) zeigte
/// aber, dass Büro auf dem Handy **nie** geöffnet wird (20 Aufrufe von
/// Buchhaltung und Rechnungen, alle vom PC), während der Tourenplan
/// neunmal unterwegs dran war. Also Tour statt Büro; Buchhaltung bleibt
/// über «Weitere» auf der Startseite erreichbar.
///
/// Beide Entscheidungen — welches Ziel leuchtet und ob die Leiste
/// überhaupt erscheint — sind reine Funktionen über dem Pfad, damit sie
/// ohne Router und ohne Widget prüfbar bleiben.
library;

enum NavZiel { heute, einsaetze, betriebe, tour }

/// Höhe der Leiste ohne den `SafeArea`-Unterrand.
const double kNavigationHoehe = 56;

String navPfad(NavZiel z) => switch (z) {
  NavZiel.heute => '/',
  NavZiel.einsaetze => '/einsaetze',
  NavZiel.betriebe => '/betriebe',
  NavZiel.tour => '/touren',
};

String navLabel(NavZiel z) => switch (z) {
  NavZiel.heute => 'Heute',
  NavZiel.einsaetze => 'Einsätze',
  NavZiel.betriebe => 'Betriebe',
  NavZiel.tour => 'Tour',
};

IconData navIcon(NavZiel z) => switch (z) {
  NavZiel.heute => Icons.today,
  NavZiel.einsaetze => Icons.assignment,
  NavZiel.betriebe => Icons.store,
  NavZiel.tour => Icons.route,
};

/// Die Einsatztypen haben eigene Detailrouten (aus der Zeit vor B2). Sie
/// gehören zum Ziel «Einsätze», damit das Leuchten nicht verschwindet,
/// sobald man eine Störung öffnet.
const _einsatzPraefixe = [
  '/reinigungen',
  '/stoerungen',
  '/montagen',
  '/eigenauftraege',
  '/eroeffnungsreinigungen',
  '/pikett',
];

String _ohneSchraegstrich(String pfad) =>
    pfad.length > 1 && pfad.endsWith('/')
        ? pfad.substring(0, pfad.length - 1)
        : pfad;

/// Gehört [pfad] zu [basis] — als die Seite selbst oder als Unterseite?
/// `/betriebe-alt` gehört NICHT zu `/betriebe`, deshalb reicht
/// `startsWith` allein nicht.
bool _unter(String pfad, String basis) =>
    pfad == basis || pfad.startsWith('$basis/');

/// Welches Ziel ist hervorgehoben? `null` heisst: keines — die Leiste
/// bleibt trotzdem stehen (etwa in der Buchhaltung).
NavZiel? aktivesZiel(String pfad) {
  final p = _ohneSchraegstrich(pfad);
  if (p == '/') return NavZiel.heute;
  for (final z in [NavZiel.einsaetze, NavZiel.betriebe, NavZiel.tour]) {
    if (_unter(p, navPfad(z))) return z;
  }
  for (final e in _einsatzPraefixe) {
    if (_unter(p, e)) return NavZiel.einsaetze;
  }
  return null;
}

/// Pfad-Endungen, die ein Formular kennzeichnen. Fast alle
/// `*FormScreen`-Routen enden so.
const _formularEndungen = [
  '/neu',
  '/bearbeiten',
  // Zwei `*FormScreen` mit eigener Endung:
  '/rechnungsadresse',
  // Vollflächen-Werkzeug mit Karte — eine Leiste am Rand wäre dort im Weg.
  '/lageplan',
];

/// Formulare und mehrstufige Vorgänge ohne solche Endung. Ein Eintrag mit
/// abschliessendem `/` gilt als Präfix, alles andere als genauer Pfad —
/// `/materialien/bestellen` ist ein Formular, `/materialien/bestellungen`
/// eine Liste.
const kFormularPfade = [
  '/login',
  // Der Spesen-Scanner ist mehrstufig und trägt eine eigene
  // `bottomNavigationBar`; zwei Leisten übereinander will niemand.
  '/spesen',
  '/einstellungen/preise/', // PreisVersionFormScreen
  '/buchhaltung/camt-import',
  '/buchhaltung/eingangsrechnungen/upload',
  '/materialien/bestellen',
];

/// Zeigt dieser Pfad die Leiste? In Formularen nicht: Ein Fehltipp auf
/// «Tour» mitten in einer Reinigung soll gar nicht erst möglich sein.
bool zeigtNavigation(String pfad) {
  final p = _ohneSchraegstrich(pfad);
  for (final e in _formularEndungen) {
    if (p.endsWith(e)) return false;
  }
  for (final f in kFormularPfade) {
    if (f.endsWith('/') ? p.startsWith(f) : p == f) return false;
  }
  return true;
}
```

- [ ] **Step 4: Tests laufen lassen**

Run: `flutter test test/navigation_ziele_test.dart`
Erwartet: BESTANDEN, 10 Tests.

Run: `flutter analyze lib/core/util/navigation_ziele.dart test/navigation_ziele_test.dart`
Erwartet: keine Befunde. Dann `dart format` auf beide Dateien.

- [ ] **Step 5: Commit**

```bash
git add lib/core/util/navigation_ziele.dart test/navigation_ziele_test.dart
git commit -m "feat: vier Navigationsziele und die Regel, wo die Leiste erscheint (B1)"
```

---

### Task 2: Die Leiste

**Files:**
- Create: `lib/presentation/widgets/haupt_navigation.dart` (nur `HauptNavigation`, der angebundene Teil folgt in Task 3)
- Test: `test/haupt_navigation_test.dart`
- Modify: `test/canvaskit_sichere_widgets_test.dart`

Vorbild für die Bauart: `lib/presentation/widgets/einsatz_zeile.dart` (B2). Farben: `AppColors.primary` (Heineken-Grün `#008200`), `AppColors.textSecondary`, `AppColors.surface` aus `lib/core/theme/app_theme.dart`.

- [ ] **Step 1: Den fehlschlagenden Test schreiben** — `test/haupt_navigation_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/navigation_ziele.dart';
import 'package:sbs_projer_app/presentation/widgets/haupt_navigation.dart';

Widget rahmen(Widget kind) => MaterialApp(
  home: Scaffold(body: Column(children: [const Spacer(), kind])),
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final daten = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    await (FontLoader('Roboto')..addFont(Future.value(daten))).load();
  });

  testWidgets('zeigt alle vier Ziele', (tester) async {
    await tester.pumpWidget(rahmen(
      HauptNavigation(aktiv: NavZiel.heute, onZiel: (_) {}),
    ));
    for (final t in ['Heute', 'Einsätze', 'Betriebe', 'Tour']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
  });

  testWidgets('das aktive Ziel ist gruen, die uebrigen grau', (tester) async {
    await tester.pumpWidget(rahmen(
      HauptNavigation(aktiv: NavZiel.betriebe, onZiel: (_) {}),
    ));
    final aktiv = tester.widget<Text>(find.text('Betriebe'));
    final andere = tester.widget<Text>(find.text('Heute'));
    expect(aktiv.style?.color, AppColors.primary);
    expect(andere.style?.color, AppColors.textSecondary);
  });

  testWidgets('ohne aktives Ziel ist nichts hervorgehoben', (tester) async {
    await tester.pumpWidget(rahmen(
      const HauptNavigation(aktiv: null, onZiel: _nichts),
    ));
    for (final t in ['Heute', 'Einsätze', 'Betriebe', 'Tour']) {
      expect(tester.widget<Text>(find.text(t)).style?.color,
          AppColors.textSecondary, reason: t);
    }
  });

  testWidgets('Tippen meldet das Ziel', (tester) async {
    NavZiel? gewaehlt;
    await tester.pumpWidget(rahmen(
      HauptNavigation(aktiv: NavZiel.heute, onZiel: (z) => gewaehlt = z),
    ));
    await tester.tap(find.text('Tour'));
    expect(gewaehlt, NavZiel.tour);
    await tester.tap(find.text('Einsätze'));
    expect(gewaehlt, NavZiel.einsaetze);
  });

  testWidgets('passt auf 360 px, keine Beschriftung wird gekuerzt', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(rahmen(
      HauptNavigation(aktiv: NavZiel.einsaetze, onZiel: (_) {}),
    ));

    expect(tester.takeException(), isNull);
    for (final t in ['Heute', 'Einsätze', 'Betriebe', 'Tour']) {
      final absatz = tester.renderObject<RenderParagraph>(find.text(t));
      expect(absatz.didExceedMaxLines, isFalse, reason: t);
    }
  });

  testWidgets('kein NavigationBar, kein BottomNavigationBar', (tester) async {
    await tester.pumpWidget(rahmen(
      HauptNavigation(aktiv: NavZiel.heute, onZiel: (_) {}),
    ));
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(BottomNavigationBar), findsNothing);
    expect(find.byType(ListTile), findsNothing);
  });
}

void _nichts(NavZiel _) {}
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag prüfen**

Run: `flutter test test/haupt_navigation_test.dart`
Erwartet: FEHLER — `haupt_navigation.dart` fehlt.

- [ ] **Step 3: Umsetzung** — `lib/presentation/widgets/haupt_navigation.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/navigation_ziele.dart';

/// Die untere Navigationsleiste (B1) — reine Darstellung, ohne
/// Router-Wissen.
///
/// CanvasKit: `InkWell` + `Container` + `Row`, **kein** `NavigationBar`.
/// Auf dem produktiv genutzten CanvasKit-Web haben Material-Komfort-Widgets
/// dreimal nicht gerendert oder nicht reagiert (CLAUDE.md) — bei der
/// globalen Navigation wäre das der grösste denkbare Ausfall.
class HauptNavigation extends StatelessWidget {
  final NavZiel? aktiv;
  final ValueChanged<NavZiel> onZiel;

  const HauptNavigation({super.key, required this.aktiv, required this.onZiel});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Color(0x1F000000))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: kNavigationHoehe,
          child: Row(
            children: [
              for (final z in NavZiel.values)
                Expanded(
                  child: InkWell(
                    onTap: () => onZiel(z),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          navIcon(z),
                          size: 22,
                          color: z == aktiv
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          navLabel(z),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                z == aktiv ? FontWeight.w600 : FontWeight.w400,
                            color: z == aktiv
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Tests laufen lassen**

Run: `flutter test test/haupt_navigation_test.dart`
Erwartet: BESTANDEN, 6 Tests. Läuft die Zeile auf 360 px über (`didExceedMaxLines` oder eine Overflow-Ausnahme), die Icon-Grösse auf 20 und den Abstand auf 1 senken — **nicht** die Schrift unter 11 px.

- [ ] **Step 5: CanvasKit-Wächter erweitern**

In `test/canvaskit_sichere_widgets_test.dart` im Test «Listenzeilen ohne CanvasKit-tote Widgets» die Dateiliste um `'lib/presentation/widgets/haupt_navigation.dart'` ergänzen.

Run: `flutter test test/canvaskit_sichere_widgets_test.dart`
Erwartet: BESTANDEN.

Gegenprobe: Vorübergehend `final x = ListTile();` (unkommentiert) in `haupt_navigation.dart` einfügen — der Wächter muss FEHLSCHLAGEN und die Datei nennen. Zeile wieder entfernen, `git diff` prüfen.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/widgets/haupt_navigation.dart test/haupt_navigation_test.dart test/canvaskit_sichere_widgets_test.dart
git commit -m "feat: HauptNavigation - vier Ziele, CanvasKit-sicher (B1)"
```

---

### Task 3: Anbinden und einhängen

**Files:**
- Modify: `lib/presentation/widgets/haupt_navigation.dart` (`HauptNavigationLeiste` ergänzen)
- Modify: `lib/app.dart:159-161`
- Modify: `lib/presentation/widgets/aufgaben_glocke.dart:28`

Kein eigener Unit-Test: Der angebundene Teil spricht mit dem globalen Router; geprüft wird er in Task 6 im Browser. Die Regeln dahinter sind in Task 1 getestet, die Darstellung in Task 2.

`router` ist eine globale Variable in `lib/core/config/router.dart:110`. Im `MaterialApp.builder` gibt es **kein** `GoRouterState.of(context)` — der builder-Kontext liegt über dem Router (deshalb greift auch die Glocke auf `router.routerDelegate.navigatorKey.currentContext` zu, `aufgaben_glocke.dart:36`).

- [ ] **Step 1: `HauptNavigationLeiste` ergänzen** — ans Ende von `lib/presentation/widgets/haupt_navigation.dart`, Import `package:sbs_projer_app/core/config/router.dart` dazu:

```dart
/// Angebunden: beobachtet den Router, entscheidet über Sichtbarkeit und
/// aktives Ziel und navigiert.
///
/// `router.routeInformationProvider` ist ein `Listenable` und meldet jeden
/// Routenwechsel — `GoRouterState.of(context)` gibt es hier oben nicht.
/// `go` statt `push`: Der Stapel wird ersetzt, damit die Browser-Zurück-
/// Geste eine Seite zurückführt statt durch einen wachsenden Stapel.
class HauptNavigationLeiste extends StatelessWidget {
  const HauptNavigationLeiste({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: router.routeInformationProvider,
      builder: (context, _) {
        final pfad = router.routeInformationProvider.value.uri.path;
        if (!zeigtNavigation(pfad)) return const SizedBox.shrink();
        return HauptNavigation(
          aktiv: aktivesZiel(pfad),
          onZiel: (z) => router.go(navPfad(z)),
        );
      },
    );
  }
}
```

Meldet der Analyzer, dass `routeInformationProvider` kein `Listenable` ist, prüfe den Typ mit `grep -n "routeInformationProvider" ~/.pub-cache/hosted/pub.dev/go_router-*/lib/src/router.dart` und nutze ersatzweise `router.routerDelegate` als `animation` (auch ein `ChangeNotifier`) mit `router.routerDelegate.currentConfiguration.uri.path` als Pfad. Melde, welchen Weg du genommen hast.

- [ ] **Step 2: In `app.dart` einhängen** — den `builder` (Zeilen 159–161) ersetzen:

```dart
      // Reihenfolge: Die Glocke liegt AUSSERHALB der Breitenbegrenzung, damit
      // sie am PC in der Fensterecke bleibt und nicht an der Spaltenkante
      // klebt. Die Navigationsleiste dagegen gehört INNERHALB — sie ist Teil
      // der App-Spalte und läge am PC sonst über die ganze Fensterbreite.
      //
      // `Column` statt `Stack`: Der Inhalt bekommt dadurch von vornherein
      // weniger Höhe, und alles darin — auch schwebende Aktionsknöpfe —
      // sitzt von selbst über der Leiste (B1).
      builder: (context, child) => AufgabenGlocke(
        child: InhaltsBreite(
          child: Column(
            children: [
              Expanded(child: child ?? const SizedBox.shrink()),
              const HauptNavigationLeiste(),
            ],
          ),
        ),
      ),
```

Import in `app.dart` ergänzen: `import 'package:sbs_projer_app/presentation/widgets/haupt_navigation.dart';` — an der Stelle, wo die anderen `presentation/widgets`-Importe stehen.

- [ ] **Step 3: Glocke höher** — in `lib/presentation/widgets/aufgaben_glocke.dart` den Wert `bottom: 96` auf `bottom: 152` ändern und den Kommentar darüber ergänzen:

```dart
            // Hoch genug, damit die Glocke keine unteren Aktionsleisten
            // überdeckt (Vorfall 26.07.2026: sie lag über dem Buchen-Knopf
            // im Spesen-Scanner) — und seit B1 (v0.107.0) zusätzlich über
            // der Navigationsleiste, die 56 px plus SafeArea belegt.
            bottom: 152,
```

- [ ] **Step 4: Prüfen**

Run: `flutter analyze`
Erwartet: 56 Befunde, keine neuen.

Run: `flutter test`
Erwartet: alles grün. Schlägt ein Widget-Test fehl, der die ganze App aufbaut (`app.dart`), weil der Router im Test nicht initialisiert ist: melde den Testnamen und die Meldung, **bevor** du den Test änderst.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/widgets/haupt_navigation.dart lib/app.dart lib/presentation/widgets/aufgaben_glocke.dart
git commit -m "feat: Navigationsleiste global eingehaengt, Glocke rueckt hoch (B1)"
```

---

### Task 4: Der Formular-Wächter

**Files:**
- Create: `test/formular_ohne_navigation_waechter_test.dart`

Die Formularliste in `navigation_ziele.dart` ist von Hand gepflegt — ein neues Formular bekäme sonst still eine Leiste. Der Wächter liest `lib/core/config/router.dart` und prüft jede Route, deren Builder ein `*FormScreen` erzeugt. Dieselbe Konvention trägt schon der Datenverlust-Schutz aus A7 (`test/formular_schutz_waechter_test.dart` prüft `*_form_screen.dart`).

- [ ] **Step 1: Wächter schreiben**

```dart
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
  String echterPfad(String muster) => muster
      .split('/')
      .map((s) => s.startsWith(':') ? 'x1' : s)
      .join('/');

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
    expect(tot, isEmpty,
        reason: 'Eintraege ohne passende Route (Pfad umbenannt oder Screen '
            'entfernt?):\n${tot.join('\n')}');
  });
}
```

- [ ] **Step 2: Test laufen lassen**

Run: `flutter test test/formular_ohne_navigation_waechter_test.dart`
Erwartet: BESTANDEN, 3 Tests. Schlägt der zweite Test fehl, nennt er die Route: Sie gehört in `kFormularPfade` (bzw. ihre Endung in `_formularEndungen`) — die Liste anpassen, nicht den Test.

- [ ] **Step 3: Gegenprobe**

In `lib/core/util/navigation_ziele.dart` vorübergehend `'/rechnungsadresse'` aus `_formularEndungen` entfernen. Der Wächter muss FEHLSCHLAGEN und `/betriebe/:id/rechnungsadresse` nennen. Zeile wieder einfügen, Test erneut grün.

- [ ] **Step 4: Commit**

```bash
git add test/formular_ohne_navigation_waechter_test.dart
git commit -m "test: Waechter - kein Formular traegt die Navigationsleiste (B1)"
```

---

### Task 5: Die Startseite aufräumen

**Files:**
- Modify: `lib/presentation/screens/home_screen.dart` (Kachel-Gitter ab Zeile ~111, Zähler ab Zeile ~95)
- Modify: `lib/presentation/providers/kachel_zaehler_providers.dart`
- Modify: `test/kachel_zaehler_test.dart`, `test/kachel_text_test.dart`

Sieben Kacheln zeigen dorthin, wo jetzt die Leiste hinführt: **Betriebe** (`/betriebe`), **Reinigungen**, **Störungen**, **Montagen**, **Eigenaufträge**, **Eröffnungen** (alle `/einsaetze?typ=…`) und **Tourenplanung** (`/touren`). Es bleiben **Kontakte**, **Aufgaben**, **Spesen**. Die «Weitere»-Liste darunter bleibt unverändert — dort hängt der Zugang zu Buchhaltung, Dokumenten, Material und Events.

- [ ] **Step 1: Kacheln entfernen**

In `lib/presentation/screens/home_screen.dart` im `GridView.count` (ab Zeile ~111) die sieben `DashboardTile`-Blöcke löschen; nur die drei für **Kontakte**, **Aufgaben** und **Spesen** bleiben stehen, in dieser Reihenfolge. Über dem Gitter den bestehenden Kommentar zur B2-Umleitung durch diesen ersetzen:

```dart
        // Seit v0.107.0 (B1) führt die untere Navigationsleiste zu Heute,
        // Einsätzen, Betrieben und Tour. Hier stehen nur noch die Ziele, die
        // sie nicht abdeckt — und «Weitere» darunter den Rest.
```

Dann die Zähler-Variablen entfernen, die niemand mehr liest (Zeilen ~95–99): `reinigungenDieseWoche`, `offeneStoerungen`, `geplanteMontagen`, `offeneEigenauftraege`. `aufgabenCount` bleibt (Aufgaben-Kachel). Prüfe mit `grep -n "faelligeCount" lib/presentation/screens/home_screen.dart`, ob der Tourenplan-Zähler noch irgendwo gebraucht wird; wird er nur von der entfernten Kachel gelesen, fällt er mit.

- [ ] **Step 2: Provider aufräumen**

Run: `grep -rn "reinigungenDieseWocheProvider\|offeneStoerungenCountProvider\|geplanteMontagenCountProvider\|offeneEigenauftraegeCountProvider" lib/ test/`

Jeden Provider, der danach nur noch in `kachel_zaehler_providers.dart` selbst und in `test/kachel_zaehler_test.dart` vorkommt, aus beiden Dateien entfernen. Bleibt einer anderswo in Gebrauch, bleibt er stehen — melde in dem Fall, welcher und wo.

- [ ] **Step 3: Tests anpassen**

`test/kachel_zaehler_test.dart` und `test/kachel_text_test.dart` prüfen die Kachelzähler und ihre Beschriftung. Entferne die Fälle der gelöschten Kacheln; die Fälle für **Aufgaben** bleiben. Lösche keinen Test, der noch etwas Bestehendes prüft — wenn nach dem Entfernen eine Testdatei leer wäre, melde das, statt sie zu löschen.

Ergänze in `test/kachel_text_test.dart` einen Test, der den neuen Zustand festhält:

```dart
  testWidgets('die Startseite zeigt nur noch die drei Kacheln ohne Leisten-Ziel',
      (tester) async {
    final quelle =
        File('lib/presentation/screens/home_screen.dart').readAsStringSync();
    for (final weg in [
      "label: 'Reinigungen'",
      "label: 'Störungen'",
      "label: 'Montagen'",
      "label: 'Eigenaufträge'",
      "label: 'Eröffnungen'",
      "label: 'Betriebe'",
      "label: 'Tourenplanung'",
    ]) {
      expect(quelle.contains(weg), isFalse,
          reason: '$weg doppelt die Navigationsleiste (B1)');
    }
    for (final bleibt in ["label: 'Aufgaben'", "label: 'Spesen'", "label: 'Kontakte'"]) {
      expect(quelle.contains(bleibt), isTrue, reason: bleibt);
    }
  });
```

Dieser Test braucht `import 'dart:io';` in der Datei.

- [ ] **Step 4: Prüfen**

Run: `flutter analyze`
Erwartet: 56 oder weniger — melde die Zahl. Unbenutzte Importe in `home_screen.dart` entfernen, falls der Analyzer sie meldet.

Run: `flutter test`
Erwartet: alles grün.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/screens/home_screen.dart lib/presentation/providers/kachel_zaehler_providers.dart test/kachel_zaehler_test.dart test/kachel_text_test.dart
git commit -m "feat: sieben doppelte Kacheln entfernt - die Leiste fuehrt dorthin (B1)"
```

---

### Task 6: Sichtprüfung, Version, Auslieferung, Doku

Macht der Koordinator selbst.

- [ ] **Step 1: Volle Suite und Analyse**

Run: `flutter analyze && flutter test`
Erwartet: 56 Befunde oder weniger, alle Tests grün.

- [ ] **Step 2: Sichtprüfung im Browser**

Wegwerf-Datei `lib/heute_probe.dart` (wie bei B2 und B6), gebaut mit
`flutter build web -t lib/heute_probe.dart --base-href "/"` und über
`.claude/launch.json` («flutter-web») im Browser geöffnet. Sie zeigt zwei
Dinge auf 360 px und 1400 px:

1. `HauptNavigation` in allen vier aktiven Zuständen und einmal ohne aktives
   Ziel — vier Ziele lesbar und gleich breit, aktives Ziel grün, Trennlinie
   sichtbar, `SafeArea` unten.
2. Das neue Kachel-Gitter der Startseite mit den drei verbleibenden Kacheln
   (`GridView.count` mit zwei Spalten und `childAspectRatio: 2.1` ergibt bei
   drei Kacheln eineinhalb Zeilen — die zweite Zeile hat rechts eine Lücke;
   sieht das schief aus, ist das hier zu sehen und vor der Auslieferung zu
   entscheiden, nicht danach).

Die Wege durch die angemeldete App prüft Daniels Klicktest. Die Probe-Datei
danach löschen, nie committen.

- [ ] **Step 3: Version und Auslieferung**

`pubspec.yaml` Zeile 4 auf `0.107.0+752`, `kAppVersion` in `lib/core/app_version.dart` auf `'0.107.0'`; `flutter test test/app_version_test.dart`. Dann nach `CLAUDE.md`: Build mit `--base-href "/sbs-projer-dev/" --pwa-strategy=none`, `main.dart.js` in `flutter_bootstrap.js` cache-busten, `flutter_service_worker.js` löschen, `404.html` mitliefern, auf `gh-pages` ausliefern, Live-`version.json` prüfen.

- [ ] **Step 4: Doku**

- `ToDo.md`: B1 erledigt, mit dem Befund aus der Nutzungsmessung (Büro raus, Tour rein) und dem Klicktest.
- `docs/app-analyse-2026-09.md`: B1 ✅ mit der Abweichung vom ursprünglichen Vorschlag.
- Memory `app_analyse_2026_09.md` und `MEMORY.md` nachziehen.

**Klicktest Daniel:** Aus einer Eingangsrechnung mit einem Tipp zurück auf Heute · Einsätze und Tour von überall erreichbar · im Reinigungsformular keine Leiste · Glocke sitzt über der Leiste · Browser-Zurück verhält sich wie erwartet · Startseite zeigt drei Kacheln.

---

## Nach der Auslieferung

- [ ] Klicktest Daniel (Task 6).
- [ ] Nach zwei Wochen die Nutzungsmessung erneut ansehen: Wird `/touren` über die Leiste häufiger geöffnet? Bleibt `/buchhaltung` am Handy bei null? Das entscheidet, ob die vier Ziele stimmen — und liefert die Grundlage für A6 (Ballast im Hauptmenü).

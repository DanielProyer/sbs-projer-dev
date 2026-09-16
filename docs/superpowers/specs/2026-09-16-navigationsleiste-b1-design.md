# Untere Navigationsleiste (B1) — Entwurf

Stand 16.09.2026 · Vorschlag B1 aus `docs/app-analyse-2026-09.md` · setzt B2 (`/einsaetze`, v0.105.0) und B6 (eine Aufgabenliste, v0.106.0) voraus.

## 1. Befund

Die App hat **97 Routen und keine globale Navigation**. Jeder Weg ist `push` und `pop`: Aus einer Eingangsrechnung zurück zur Startseite sind es drei Mal «zurück».

Die Nutzungsmessung (`route_nutzung`, 09.–16.09.2026, acht Tage) zeigt, wohin tatsächlich navigiert wird:

| Route | gesamt | Handy | PC |
|---|---|---|---|
| `/reinigungen/neu` | 64 | 64 | – |
| `/` (Startseite) | 55 | 21 | 34 |
| `/betriebe/:id` | 33 | 26 | 7 |
| Einsatz-Listen (Reinigung, Störung, Montage) | 30 | 23 | 7 |
| `/touren` | 19 | 9 | 10 |
| `/betriebe` | 12 | 6 | 6 |
| `/buchhaltung` | 11 | **0** | 11 |
| `/rechnungen` | 9 | **0** | 9 |
| `/spesen` | 4 | 4 | – |

**Das widerlegt einen Teil des ursprünglichen Vorschlags.** Die Analyse schlug «Heute · Betriebe · Einsätze · Büro» vor; die Daten zeigen, dass Büro auf dem Handy **nie** geöffnet wird — 20 Aufrufe von Buchhaltung und Rechnungen, alle vom PC. Ein Viertel einer einhändigen Leiste läge brach. Stark unterwegs sind stattdessen die Betriebsseite (26), die Einsätze (23) und der Tourenplan (9).

Zweiter Befund: Seit B2 zeigen **sieben der zehn Kacheln** dorthin, wo auch die Leiste hinführte — fünf auf `/einsaetze` mit unterschiedlichem Filter, dazu Betriebe und Tourenplanung.

## 2. Entscheidungen

1. **Vier Ziele: Heute · Einsätze · Betriebe · Tour.** Büro bleibt draussen (Nutzungsdaten); Buchhaltung, Rechnungen und Dokumente sind weiterhin über «Weitere» auf der Startseite erreichbar, wo sie am PC ohnehin geöffnet werden.
2. **Leiste überall — ausser in Formularen.** Der lange Weg aus der Tiefe wird kurz, und ein Fehltipp auf «Tour» mitten im Reinigungsformular kann gar nicht erst passieren.
3. **Die sieben doppelten Kacheln fallen.** Es bleiben Aufgaben, Spesen, Kontakte.
4. **Am PC dieselbe Leiste unten**, in der 720-px-Spalte. Ein Code-Pfad, kein zweiter Aufbau.
5. **CanvasKit:** eigene Zeile aus `InkWell` + `Container`, kein `NavigationBar` — dreimal bestätigte Falle (CLAUDE.md).

## 3. Bauteile

### 3.1 `lib/core/util/navigation_ziele.dart` — Ziele und Regeln (rein)

```dart
enum NavZiel { heute, einsaetze, betriebe, tour }

/// Pfad, Beschriftung und Symbol je Ziel.
String navPfad(NavZiel z);      // '/', '/einsaetze', '/betriebe', '/touren'
String navLabel(NavZiel z);     // 'Heute', 'Einsätze', 'Betriebe', 'Tour'

/// Welches Ziel ist zum aktuellen Pfad hervorgehoben? null = keines.
NavZiel? aktivesZiel(String pfad);

/// Zeigt dieser Pfad die Leiste?
bool zeigtNavigation(String pfad);

/// Höhe der Leiste ohne SafeArea — Polster für Screens mit fixierter
/// Unterleiste.
const double kNavigationHoehe = 56;
```

`aktivesZiel`: `/` exakt → heute; Präfix `/einsaetze` → einsaetze; Präfix `/betriebe` → betriebe; Präfix `/touren` → tour. Zusätzlich zeigen die Detailseiten der Einsatztypen auf **Einsätze**: `/reinigungen`, `/stoerungen`, `/montagen`, `/eigenauftraege`, `/eroeffnungsreinigungen`, `/pikett`. Alles andere → `null` (kein Ziel hervorgehoben; die Leiste bleibt sichtbar).

`zeigtNavigation`: `false` für `/login`, für jeden Pfad, der auf `/neu` oder `/bearbeiten` endet, und für `kFormularPfade` — die Formulare mit abweichendem Pfad, am Code belegt (16.09.2026): `/betriebe/:id/rechnungsadresse` und `/einstellungen/preise/:id` (beides `*FormScreen`), dazu die mehrstufigen Vorgänge `/spesen` (Scanner, eigene `bottomNavigationBar`), `/buchhaltung/camt-import`, `/buchhaltung/eingangsrechnungen/upload`, `/materialien/bestellen` und das Vollflächen-Werkzeug `/events/:id/lageplan`. Sonst `true`.

Ein Wächter-Test liest `router.dart` und prüft: **jede** Route, deren Builder ein `*FormScreen` erzeugt, wird von `zeigtNavigation` ausgeschlossen. Damit fängt er ein neues Formular automatisch — dieselbe Konvention, an der schon der Datenverlust-Schutz aus A7 hängt (`test/formular_schutz_waechter_test.dart` prüft `*_form_screen.dart`).

### 3.2 `lib/presentation/widgets/haupt_navigation.dart` — die Leiste

`HauptNavigation(aktiv, onZiel)` — reine Darstellung, testbar ohne Router: `Row` mit vier `Expanded`, je `InkWell` + `Container` + `Column` (Icon 22 px über Label 11 px), 56 px hoch, oben eine Trennlinie, unten `SafeArea`. Aktives Ziel in `AppColors.primary`, übrige in `AppColors.textSecondary`.

Darüber `HauptNavigationLeiste()` — angebunden: beobachtet `router.routeInformationProvider` (ein `Listenable`) mit `AnimatedBuilder`, liest `router.routeInformationProvider.value.uri.path`, entscheidet über `zeigtNavigation` und `aktivesZiel` und ruft beim Tippen `router.go(navPfad(ziel))`. Im `MaterialApp.builder` gibt es kein `GoRouterState.of(context)` — der builder-Kontext liegt über dem Router.

`router.go` statt `push`: Der Stapel wird ersetzt, die Browser-Zurück-Geste führt eine Seite zurück statt durch einen wachsenden Stapel.

### 3.3 `lib/app.dart` — Einbau

Die Leiste kommt **innerhalb** von `InhaltsBreite` (am PC in der 720er-Spalte), die Glocke bleibt aussen:

```dart
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

### 3.4 Glocke und Freiraum

Die Glocke rückt von `bottom: 96` auf `bottom: 152` (`aufgaben_glocke.dart`), damit sie nicht auf der Leiste sitzt — sie liegt als `Stack`-Geschwister über allem und misst vom Fensterboden.

**Kein Screen braucht ein Polster.** Die Leiste steht in einer `Column` unter dem Inhalt, nicht in einem `Stack` darüber: Der Screen bekommt damit von vornherein weniger Höhe, und alles darin — auch schwebende Aktionsknöpfe — sitzt korrekt über der Leiste. Der einzige Screen mit eigener fixierter Unterleiste ist der Spesen-Scanner (`/spesen`, `bottomNavigationBar`); er steht in `kFormularPfade` und bekommt gar keine Leiste, statt zwei übereinander zu tragen.

### 3.5 Startseite

Sieben Kacheln fallen (Reinigungen, Störungen, Montagen, Eigenaufträge, Eröffnungen, Betriebe, Tourenplanung); es bleiben **Aufgaben** (Badge), **Spesen**, **Kontakte**. Die «Weitere»-Liste bleibt unverändert. Zähler-Provider, die danach niemand mehr liest, fallen mit — geprüft per Suche, nicht vermutet.

## 4. Tests

- `test/navigation_ziele_test.dart`: `aktivesZiel` (vier Ziele, sechs Einsatz-Präfixe, Unbekanntes → null), `zeigtNavigation` (Login, `/neu`, `/bearbeiten`, Ausnahmeliste, Detailseiten, die vier Ziele).
- `test/haupt_navigation_test.dart` (Roboto, 360 px): vier Ziele ohne gekürzte Labels, aktives Ziel farbig, Tippen meldet das Ziel, kein `NavigationBar`/`BottomNavigationBar`.
- `test/formular_ohne_navigation_waechter_test.dart`: jede Route aus `router.dart`, deren Pfad auf `/neu` oder `/bearbeiten` endet, wird von `zeigtNavigation` ausgeschlossen; jeder Eintrag in `kFormularPfade` existiert als Route (keine Karteileichen).
- `test/canvaskit_sichere_widgets_test.dart`: `haupt_navigation.dart` in die Dateiliste.
- Kachel-Tests auf die drei verbleibenden Kacheln angepasst.

## 5. Lieferung

v0.107.0. Sichtprüfung im Browser auf 360 px und 1400 px (Wegwerf-Probe wie bei B2/B6): Leiste sichtbar und lesbar, im Reinigungsformular nicht vorhanden, Glocke über der Leiste, aktives Ziel wandert beim Navigieren, Startseite mit drei Kacheln.

Klicktest Daniel: Aus einer Eingangsrechnung mit einem Tipp zurück auf Heute · Einsätze und Tour direkt erreichbar · im Reinigungsformular keine Leiste · Browser-Zurück verhält sich wie erwartet.

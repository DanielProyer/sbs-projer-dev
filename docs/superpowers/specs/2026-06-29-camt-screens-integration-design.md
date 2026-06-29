# camt-Screens in Bankauszug-Import integrieren — Design

**Datum:** 2026-06-29
**Status:** Design freigegeben (Daniel), bereit für Plan
**Bezug:** Aufräumung der Buchhaltung. Baut auf dem vereinten camt-Import auf (TP-A/B/C, `camt_import_merge`).

## Ziel

Die drei eigenständigen camt-Screens **Prüfliste**, **Regeln** und **Dateien** in den **Bankauszug-Import-Screen** integrieren, sodass die Buchhaltung übersichtlicher wird: ein Einstieg, eine Kachel, ein Screen mit vier Tabs — statt vier gleichrangiger Dashboard-Kacheln.

## Ausgangslage (kartiert)

Vier flache Routen unter `/buchhaltung`, alle nur über je eine Dashboard-Kachel erreichbar:

| Screen | Datei | Widget-Typ | Route | Besonderheit |
|---|---|---|---|---|
| Bankauszug Import | `presentation/screens/buchhaltung/camt_import_screen.dart` (637 Z.) | `ConsumerStatefulWidget` | `/buchhaltung/camt-import` | 3-Schritt-Wizard (`int _step`), nutzt u.a. `camtPrueflisteProvider` |
| camt-Prüfliste | `…/camt_pruefliste_screen.dart` (274 Z.) | `ConsumerWidget` | `/buchhaltung/camt-pruefliste` | teilt `camtPrueflisteProvider` mit Import; „Regel anlegen" via `showRegelDialog` |
| camt-Regeln | `…/camt_regeln_screen.dart` (318 Z.) | `ConsumerWidget` | `/buchhaltung/camt-regeln` | **eigener FloatingActionButton**; Top-Level `showRegelDialog()` |
| camt-Dateien | `…/camt_dateien_screen.dart` (186 Z.) | `ConsumerWidget` | `/buchhaltung/camt-dateien` | Lücken-Banner + Download via signierte URL |

Routen: `core/config/router.dart` (~Z.464–477). Dashboard-Kacheln: `buchhaltung_dashboard_screen.dart` (~Z.182–205). Querlinks heute: Import-Schritt 2 hat „Zur Prüfliste"-Button; Prüfliste öffnet `showRegelDialog`.

## Freigegebene Entscheidungen

1. **Aufbau:** Vier **Tabs** unter einem Host-Screen — Import · Prüfliste · Regeln · Dateien.
2. **Dashboard:** **Eine** Kachel „Bankauszug Import" (statt vier).
3. **Routen:** Die drei alten Routen bleiben als **Redirects** auf den Host mit passendem Start-Tab (keine gebrochenen Lesezeichen).
4. **FAB:** „Neue Regel"-FAB erscheint **nur im Regeln-Tab**.
5. **Verhalten:** Nach erfolgreichem Verbuchen **Auto-Sprung auf den Prüflisten-Tab**; der „Zur Prüfliste"-Button entfällt.

## Architektur

**Host-Screen** `CamtBankauszugScreen` (`ConsumerStatefulWidget`):
- Ein `Scaffold` + eine `AppBar` (Titel „Bankauszug Import") + `TabBar` (4 Tabs mit Icon+Label) + `TabBarView`.
- `TabController` (length 4) im State; initialer Index aus optionalem Konstruktor-Parameter `initialTab` (für Redirects/`?tab=`).
- **FAB kontextabhängig:** lauscht auf `_tabController.index` (Listener → `setState`); `floatingActionButton` ist non-null nur, wenn der Regeln-Tab aktiv ist, und ruft `showRegelDialog` auf.
- **Auto-Sprung:** stellt den vier Tab-Bodies einen Callback `onImportFertig` bzw. eine Methode `wechsleZuPruefliste()` bereit; der Import-Tab ruft ihn nach erfolgreichem Verbuchen statt zu navigieren. Alternativ animiert der Host nach dem Import via `_tabController.animateTo(1)`.

**Tab-Bodies** — je ein neues Widget, das den bisherigen Screen-Body (alles unter der AppBar) übernimmt, ohne eigenes Scaffold/AppBar/FAB:
- `CamtImportTab` (`ConsumerStatefulWidget`) — der Wizard inkl. `_step`-State; erhält vom Host einen Callback für den Auto-Sprung; „Zur Prüfliste"-Button entfällt.
- `CamtPrueflisteTab` (`ConsumerWidget`).
- `CamtRegelnTab` (`ConsumerWidget`) — der FAB wird zum Host hochgezogen; `showRegelDialog` bleibt Top-Level-Funktion und wird von Host (FAB) und Prüfliste (Regel-anlegen) gleichermaßen genutzt.
- `CamtDateienTab` (`ConsumerWidget`).

Die alten Screen-Klassen werden entfernt (ihr Inhalt lebt in den Tab-Widgets weiter); die Dateien werden zu den Tab-Widgets umbenannt/aufgeteilt, damit jede Datei eine klare Verantwortung behält.

**Wizard-State über Tab-Wechsel:** `TabBarView` hält die Kinder im Baum; der `_step`-State des Import-Tabs bleibt beim Wechseln erhalten. Nach einem abgeschlossenen Import setzt der Import-Tab seinen Wizard auf `_step = 0` zurück.

**Provider-Invalidierung:** `ref.invalidate(camtPrueflisteProvider)` nach dem Verbuchen bleibt; da der Prüflisten-Tab denselben Provider beobachtet, zeigt er nach dem Auto-Sprung frische Daten.

## Routen & Navigation

- `/buchhaltung/camt-import` → `CamtBankauszugScreen` (Default-Tab Import), nimmt optional `?tab=pruefliste|regeln|dateien`.
- `/buchhaltung/camt-pruefliste|camt-regeln|camt-dateien` → **`redirect`** auf `/buchhaltung/camt-import?tab=…` (GoRouter-`redirect` an der jeweiligen Route).
- **Dashboard:** die vier `_NavTile`-Kacheln werden zu **einer** Kachel „Bankauszug Import" → `/buchhaltung/camt-import`. Die Wochen-Erinnerung bleibt auf `/buchhaltung/camt-import`.
- Import-interner „Zur Prüfliste"-`context.push` entfällt (wird Auto-Sprung).

## Datei-Struktur (Verantwortlichkeiten)

```
presentation/screens/buchhaltung/
  camt_bankauszug_screen.dart      # NEU: Host (Scaffold, AppBar, TabBar/TabBarView, FAB-Logik, Auto-Sprung)
  camt/                            # NEU: Unterordner für die vier Tab-Bodies
    camt_import_tab.dart           # aus camt_import_screen.dart (Body + Wizard)
    camt_pruefliste_tab.dart       # aus camt_pruefliste_screen.dart
    camt_regeln_tab.dart           # aus camt_regeln_screen.dart (ohne FAB)
    camt_dateien_tab.dart          # aus camt_dateien_screen.dart
```
`showRegelDialog`, Provider, Repositories, Services bleiben unverändert an ihren Orten.

## Risiken & Gegenmaßnahmen

- **Funktions-Regression durch Body-Extraktion:** Bodies möglichst unverändert übernehmen; `flutter analyze` + Widget-Test + visueller Browser-Check vor Deploy.
- **FAB-Doppelung:** FAB ausschließlich im Host, gated auf Tab-Index; die alten Screen-FABs werden entfernt.
- **Redirect-Schleifen:** Redirect zeigt nur von den drei Alt-Pfaden auf den Host (kein gegenseitiges Reden); Host selbst hat keinen Redirect.
- **Verwaiste Referenzen:** alle `context.push('/buchhaltung/camt-*')` und Dashboard-Kacheln werden mitgezogen (Suche im Code als Teil des Plans).

## Tests

- Widget-Test: Host rendert genau 4 Tabs; FAB nur sichtbar/aktiv im Regeln-Tab; `initialTab` setzt den richtigen Start-Tab.
- Router-Test/Smoke: die drei Alt-Routen lösen auf den Host mit korrektem Tab auf.
- Bestehende Tests bleiben grün (`flutter test`), `flutter analyze` 0 Fehler.
- Manuell (Browser, vor Deploy): Tab-Wechsel, Import→Auto-Sprung, FAB nur im Regeln-Tab, Download im Dateien-Tab, Regel anlegen aus Prüfliste.

## Bewusst NICHT jetzt (YAGNI)

- Keine inhaltliche Neugestaltung der einzelnen Bereiche — reiner Zusammenführungs-/Navigations-Umbau.
- Keine neuen Funktionen in Prüfliste/Regeln/Dateien.
- Kein Persistieren des zuletzt aktiven Tabs über App-Neustart hinaus.

## TP-Zerlegung (für den Plan)

| TP | Inhalt |
|---|---|
| **TP-1** | Tab-Bodies extrahieren: vier neue Tab-Widgets aus den bestehenden Screen-Bodies (ohne Scaffold/AppBar/FAB), Verhalten unverändert. |
| **TP-2** | Host-Screen `CamtBankauszugScreen`: Scaffold + AppBar + TabBar/TabBarView + `initialTab`, FAB gated auf Regeln-Tab, Auto-Sprung-Callback. |
| **TP-3** | Routen: Host-Route mit `?tab=`, drei Alt-Routen als Redirects; alte Screen-Klassen entfernen. |
| **TP-4** | Dashboard auf eine Kachel reduzieren; Import-interner „Zur Prüfliste"-Push → Auto-Sprung. |
| **TP-5** | Tests (Widget + Router-Smoke), `analyze`, visueller Check, Deploy. |

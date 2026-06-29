# camt-Screens in Bankauszug-Import integrieren — Implementierungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prüfliste, Regeln und Dateien als drei Tabs in den Bankauszug-Import-Screen zusammenführen, sodass aus vier Dashboard-Kacheln eine wird.

**Architecture:** Ein neuer Host-Screen `CamtBankauszugScreen` (`ConsumerStatefulWidget` mit `TabController`, 4 Tabs) hält eine AppBar und einen kontextabhängigen FAB. Die vier bestehenden Screen-Bodies werden in vier Tab-Widgets (ohne eigenes Scaffold/AppBar/FAB) ausgelagert. Routen der drei Altseiten werden zu Redirects auf den Host; das Dashboard bekommt eine Kachel.

**Tech Stack:** Flutter, Riverpod (`flutter_riverpod`), GoRouter, Material 3.

**Bezug:** Spec `docs/superpowers/specs/2026-06-29-camt-screens-integration-design.md`.

**Wichtige Fakten aus dem Code (verifiziert):**
- `camt_import_screen.dart` (637 Z.): `CamtImportScreen` (`ConsumerStatefulWidget`) → State `_CamtImportScreenState`. `build` = `Scaffold(appBar: AppBar(title 'Bankauszug Import'), body: _buildBody())`. „Zur Prüfliste"-Button Z.480-485 ruft `context.push('/buchhaltung/camt-pruefliste')`. „Fertig"-Button Z.504 ruft `Navigator.of(context).pop()`. Helfer-Klasse `_ResultRow` am Dateiende.
- `camt_pruefliste_screen.dart` (274 Z.): `CamtPrueflisteScreen` (`ConsumerWidget`). `build` = `Scaffold(appBar: AppBar('camt-Prüfliste'), body: async.when(...))`. Methode `_setStatus`. Statische `_kategorieLabel` (referenziert in `_PrueflisteCard` via `CamtPrueflisteScreen._kategorieLabel`, Z.166). Importiert `showRegelDialog` aus `camt_regeln_screen.dart` (Z.8).
- `camt_regeln_screen.dart` (318 Z.): Top-Level `showRegelDialog(...)` (Z.13-146) + `CamtRegelnScreen` (`ConsumerWidget`). `build` = `Scaffold(appBar: AppBar('camt-Regeln'), floatingActionButton: FloatingActionButton(onPressed: () => showRegelDialog(context, ref), child: Icon(add)), body: async.when(...))`. Methode `_delete`.
- `camt_dateien_screen.dart` (186 Z.): `CamtDateienScreen` (`ConsumerWidget`). `build` = `Scaffold(appBar: AppBar('camt-Dateien'), body: async.when(...))`. Methode `_download`. Statische `_fmt` (referenziert in `_LueckeBanner`/`_DateiCard` via `CamtDateienScreen._fmt`). Helfer `_LueckeBanner`, `_DateiCard`.
- Provider-Signaturen: `camtPrueflisteProvider`/`camtRegelnProvider` = `FutureProvider.autoDispose<List<...>>`; `camtDateienProvider` = `FutureProvider<List<CamtDatei>>`; `buchungsVorlagenProvider` = `Provider<List<BuchungsVorlage>>`.
- Routen `router.dart` Z.463-478 (4 GoRoutes). Dashboard-Kacheln `buchhaltung_dashboard_screen.dart` Z.182-205 (4 `_NavTile`). Keine weiteren Referenzen (per Grep bestätigt; `'camt-dateien'` in `camt_datei_repository.dart` ist ein Storage-Bucket-Name — NICHT anfassen).

**Konventionen:** Bash mit `export PATH="$PATH:/c/flutter/bin"`; App-Verzeichnis `sbs_projer_app`. Jeder Commit endet mit `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`. Nicht pushen außer in Task 6.

---

## Datei-Struktur

```
presentation/screens/buchhaltung/
  camt_bankauszug_screen.dart        # NEU (Task 2): Host (Scaffold, AppBar, TabBar/TabBarView, FAB-Gate, Tab-Wechsel)
  camt/                              # NEU (Task 1): die vier Tab-Bodies
    camt_import_tab.dart             # aus camt_import_screen.dart
    camt_pruefliste_tab.dart         # aus camt_pruefliste_screen.dart
    camt_regeln_tab.dart             # aus camt_regeln_screen.dart (inkl. showRegelDialog, ohne FAB)
    camt_dateien_tab.dart            # aus camt_dateien_screen.dart
  camt_import_screen.dart            # GELÖSCHT (Task 3)
  camt_pruefliste_screen.dart        # GELÖSCHT (Task 3)
  camt_regeln_screen.dart            # GELÖSCHT (Task 3)
  camt_dateien_screen.dart           # GELÖSCHT (Task 3)
test/
  camt_bankauszug_screen_test.dart   # NEU (Task 5)
```

---

## Task 1: Vier Tab-Widgets aus den bestehenden Screen-Bodies auslagern

Reine Mechanik: Body unverändert übernehmen, Scaffold/AppBar (und beim Regeln-Tab den FAB) entfernen, Klasse umbenennen, interne Static-Refs anpassen. Die alten Screen-Dateien bleiben in diesem Task unberührt (App kompiliert weiter).

**Files:**
- Create: `sbs_projer_app/lib/presentation/screens/buchhaltung/camt/camt_import_tab.dart`
- Create: `sbs_projer_app/lib/presentation/screens/buchhaltung/camt/camt_pruefliste_tab.dart`
- Create: `sbs_projer_app/lib/presentation/screens/buchhaltung/camt/camt_regeln_tab.dart`
- Create: `sbs_projer_app/lib/presentation/screens/buchhaltung/camt/camt_dateien_tab.dart`

- [ ] **Step 1: `camt_dateien_tab.dart` anlegen** (einfachster, keine Querbezüge)

Kopiere den GESAMTEN Inhalt von `camt_dateien_screen.dart` in die neue Datei und ändere:
1. Klassenname `CamtDateienScreen` → `CamtDateienTab` (auch der Konstruktor `const CamtDateienTab({super.key});`).
2. `build` gibt nur den Body zurück statt des Scaffolds:
```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(camtDateienProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Fehler beim Laden: $err',
              style: const TextStyle(color: AppColors.error),
              textAlign: TextAlign.center),
        ),
      ),
      data: (dateien) {
        // ... unveränderter data-Block aus camt_dateien_screen.dart ...
      },
    );
  }
```
(Das `Scaffold(appBar: AppBar(title: const Text('camt-Dateien')), body: ...)` entfällt — der Body wird direkt zurückgegeben.)
3. Beide Vorkommen `CamtDateienScreen._fmt` (in `_LueckeBanner` und `_DateiCard`) → `CamtDateienTab._fmt`.
4. Die Helfer-Klassen `_LueckeBanner` und `_DateiCard` 1:1 mitnehmen.
5. Importe unverändert übernehmen (alle `package:`-absolut, durch den Unterordner unverändert gültig).

- [ ] **Step 2: `camt_regeln_tab.dart` anlegen** (mit `showRegelDialog`, ohne FAB)

Kopiere den GESAMTEN Inhalt von `camt_regeln_screen.dart` und ändere:
1. Die Top-Level-Funktion `showRegelDialog(...)` 1:1 übernehmen (bleibt Top-Level — Host und Prüfliste-Tab nutzen sie).
2. Klassenname `CamtRegelnScreen` → `CamtRegelnTab` (`const CamtRegelnTab({super.key});`).
3. `build` ohne Scaffold UND ohne `floatingActionButton` — nur der Body:
```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(camtRegelnProvider);
    final vorlagen = ref.watch(buchungsVorlagenProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Fehler beim Laden: $err',
              style: const TextStyle(color: AppColors.error),
              textAlign: TextAlign.center),
        ),
      ),
      data: (regeln) {
        // ... unveränderter data-Block (Empty-State + ListView.builder) ...
      },
    );
  }
```
(Das `Scaffold(appBar: ..., floatingActionButton: FloatingActionButton(...), body: ...)` entfällt komplett; der FAB wird in Task 2 im Host neu gebaut.)
4. Methode `_delete` 1:1 mitnehmen.

- [ ] **Step 3: `camt_pruefliste_tab.dart` anlegen**

Kopiere den GESAMTEN Inhalt von `camt_pruefliste_screen.dart` und ändere:
1. Import Z.8 `import 'package:sbs_projer_app/presentation/screens/buchhaltung/camt_regeln_screen.dart';` → `import 'package:sbs_projer_app/presentation/screens/buchhaltung/camt/camt_regeln_tab.dart';` (für `showRegelDialog`).
2. Klassenname `CamtPrueflisteScreen` → `CamtPrueflisteTab` (`const CamtPrueflisteTab({super.key});`).
3. `build` ohne Scaffold — nur der Body:
```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(camtPrueflisteProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(/* ... unverändert ... */),
      data: (eintraege) {
        // ... unveränderter data-Block ...
      },
    );
  }
```
4. `_kategorieLabel` bleibt statische Methode der Klasse; die Referenz in `_PrueflisteCard` (`CamtPrueflisteScreen._kategorieLabel`, Z.166) → `CamtPrueflisteTab._kategorieLabel`.
5. Methode `_setStatus` und Helfer `_PrueflisteCard` 1:1 mitnehmen.

- [ ] **Step 4: `camt_import_tab.dart` anlegen** (Stateful, mit Tab-Wechsel-Callback + KeepAlive)

Kopiere den GESAMTEN Inhalt von `camt_import_screen.dart` und ändere:
1. Importe: `import 'package:go_router/go_router.dart';` wird NICHT mehr gebraucht (der einzige `context.push` entfällt) — entfernen, damit `flutter analyze` keine ungenutzten Importe meldet. Alle übrigen Importe bleiben.
2. Widget-Klasse umbenennen und einen Callback ergänzen:
```dart
class CamtImportTab extends ConsumerStatefulWidget {
  /// Wird vom Host aufgerufen, um auf den Prüflisten-Tab zu wechseln.
  final VoidCallback? onZurPruefliste;
  const CamtImportTab({super.key, this.onZurPruefliste});

  @override
  ConsumerState<CamtImportTab> createState() => _CamtImportTabState();
}
```
3. State-Klasse `_CamtImportScreenState` → `_CamtImportTabState extends ConsumerState<CamtImportTab> with AutomaticKeepAliveClientMixin`. KeepAlive hält den Wizard-Schritt über Tab-Wechsel hinweg.
4. KeepAlive verdrahten — am Anfang der State-Klasse:
```dart
  @override
  bool get wantKeepAlive => true;
```
5. `build` ohne Scaffold/AppBar; `super.build(context)` ist für KeepAlive Pflicht:
```dart
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _buildBody();
  }
```
6. Der „Zur Prüfliste"-Button (heute `() => context.push('/buchhaltung/camt-pruefliste')`, Z.480-485) ruft stattdessen den Host-Callback:
```dart
            Align(
              alignment: Alignment.center,
              child: _tapButton(
                'Zur Prüfliste',
                () => widget.onZurPruefliste?.call(),
                primaer: false,
              ),
            ),
```
7. Der „Fertig"-Button (`() => Navigator.of(context).pop()`) bleibt unverändert (schließt den ganzen Host-Screen → zurück zum Dashboard). Helfer `_ResultRow` 1:1 mitnehmen.

- [ ] **Step 5: Analyse der vier neuen Dateien**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze lib/presentation/screens/buchhaltung/camt/`
Expected: „No issues found!" (die alten Screens existieren noch, daher kompiliert die App weiter; die neuen Dateien sind noch ungenutzt, das ist ok).

- [ ] **Step 6: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/buchhaltung/camt/
git commit -m "refactor(camt): vier Tab-Bodies aus den Screens ausgelagert"
```

---

## Task 2: Host-Screen `CamtBankauszugScreen`

**Files:**
- Create: `sbs_projer_app/lib/presentation/screens/buchhaltung/camt_bankauszug_screen.dart`

- [ ] **Step 1: Host-Screen schreiben**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/camt/camt_import_tab.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/camt/camt_pruefliste_tab.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/camt/camt_regeln_tab.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/camt/camt_dateien_tab.dart';

/// Vereint Bankauszug-Import, Prüfliste, Regeln und Dateien in einem Screen
/// mit vier Tabs. Der „Neue Regel"-FAB erscheint nur im Regeln-Tab.
class CamtBankauszugScreen extends ConsumerStatefulWidget {
  /// Start-Tab: 0=Import, 1=Prüfliste, 2=Regeln, 3=Dateien.
  final int initialTab;
  const CamtBankauszugScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<CamtBankauszugScreen> createState() =>
      _CamtBankauszugScreenState();
}

class _CamtBankauszugScreenState extends ConsumerState<CamtBankauszugScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
    // FAB-Sichtbarkeit hängt vom aktiven Tab ab → bei Wechsel neu bauen.
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final istRegelnTab = _tab.index == 2;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bankauszug Import'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(icon: Icon(Icons.upload_file), text: 'Import'),
            Tab(icon: Icon(Icons.fact_check), text: 'Prüfliste'),
            Tab(icon: Icon(Icons.rule), text: 'Regeln'),
            Tab(icon: Icon(Icons.folder_open), text: 'Dateien'),
          ],
        ),
      ),
      floatingActionButton: istRegelnTab
          ? FloatingActionButton(
              onPressed: () => showRegelDialog(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
      body: TabBarView(
        controller: _tab,
        children: [
          CamtImportTab(onZurPruefliste: () => _tab.animateTo(1)),
          const CamtPrueflisteTab(),
          const CamtRegelnTab(),
          const CamtDateienTab(),
        ],
      ),
    );
  }
}
```
`showRegelDialog` stammt aus `camt_regeln_tab.dart` (über den Import dort verfügbar).

- [ ] **Step 2: Analyse**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze lib/presentation/screens/buchhaltung/camt_bankauszug_screen.dart`
Expected: „No issues found!"

- [ ] **Step 3: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/buchhaltung/camt_bankauszug_screen.dart
git commit -m "feat(camt): Host-Screen mit 4 Tabs + kontextabhängigem FAB"
```

---

## Task 3: Routen umstellen + alte Screens löschen

**Files:**
- Modify: `sbs_projer_app/lib/core/config/router.dart` (Importe oben + Z.463-478)
- Delete: `sbs_projer_app/lib/presentation/screens/buchhaltung/camt_import_screen.dart`
- Delete: `sbs_projer_app/lib/presentation/screens/buchhaltung/camt_pruefliste_screen.dart`
- Delete: `sbs_projer_app/lib/presentation/screens/buchhaltung/camt_regeln_screen.dart`
- Delete: `sbs_projer_app/lib/presentation/screens/buchhaltung/camt_dateien_screen.dart`

- [ ] **Step 1: Router-Importe anpassen**

Suche im Importblock von `router.dart` die vier Zeilen, die `camt_import_screen.dart`, `camt_pruefliste_screen.dart`, `camt_regeln_screen.dart`, `camt_dateien_screen.dart` importieren, und ersetze sie durch den einen Host-Import:
```dart
import 'package:sbs_projer_app/presentation/screens/buchhaltung/camt_bankauszug_screen.dart';
```
(Falls die genaue Importzeile abweicht: alle vier `…/buchhaltung/camt_*_screen.dart`-Importe entfernen, den Host-Import ergänzen.)

- [ ] **Step 2: Die vier GoRoutes (Z.463-478) ersetzen**

```dart
    GoRoute(
      path: '/buchhaltung/camt-import',
      builder: (context, state) {
        final tab = state.uri.queryParameters['tab'];
        final initial = switch (tab) {
          'pruefliste' => 1,
          'regeln' => 2,
          'dateien' => 3,
          _ => 0,
        };
        return CamtBankauszugScreen(initialTab: initial);
      },
    ),
    GoRoute(
      path: '/buchhaltung/camt-pruefliste',
      redirect: (context, state) => '/buchhaltung/camt-import?tab=pruefliste',
    ),
    GoRoute(
      path: '/buchhaltung/camt-regeln',
      redirect: (context, state) => '/buchhaltung/camt-import?tab=regeln',
    ),
    GoRoute(
      path: '/buchhaltung/camt-dateien',
      redirect: (context, state) => '/buchhaltung/camt-import?tab=dateien',
    ),
```

- [ ] **Step 3: Die vier alten Screen-Dateien löschen**

```bash
cd "D:/01_SBS_Projer_GmbH/00_Entwicklung/SBS Projer DEV"
rm sbs_projer_app/lib/presentation/screens/buchhaltung/camt_import_screen.dart \
   sbs_projer_app/lib/presentation/screens/buchhaltung/camt_pruefliste_screen.dart \
   sbs_projer_app/lib/presentation/screens/buchhaltung/camt_regeln_screen.dart \
   sbs_projer_app/lib/presentation/screens/buchhaltung/camt_dateien_screen.dart
```

- [ ] **Step 4: Voll-Analyse (es darf keine verwaiste Referenz übrig sein)**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze`
Expected: „No issues found!" — falls „Target of URI doesn't exist" o.ä. auf eine der gelöschten Dateien zeigt, ist eine Referenz übersehen (Task 4 betrifft das Dashboard; alles andere muss hier sauber sein).

- [ ] **Step 5: Commit**

```bash
git add -A sbs_projer_app/lib/core/config/router.dart sbs_projer_app/lib/presentation/screens/buchhaltung/
git commit -m "refactor(camt): Routen auf Host umgestellt, Altseiten als Redirects, alte Screens entfernt"
```

---

## Task 4: Dashboard auf eine Kachel reduzieren

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/buchhaltung/buchhaltung_dashboard_screen.dart:182-205`

- [ ] **Step 1: Vier `_NavTile` (Z.182-205) durch eine ersetzen**

Ersetze den Block der vier Kacheln (Bankauszug Import, camt-Prüfliste, camt-Regeln, camt-Dateien) durch:
```dart
          _NavTile(
            icon: Icons.account_balance,
            title: 'Bankauszug Import',
            subtitle: 'Import, Prüfliste, Regeln & Dateien',
            onTap: () => context.push('/buchhaltung/camt-import'),
          ),
```
Die übrigen Kacheln (Lohnbuchhaltung etc.) und die Wochen-Erinnerung (zeigt auf `/buchhaltung/camt-import`) bleiben unverändert.

- [ ] **Step 2: Analyse**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze lib/presentation/screens/buchhaltung/buchhaltung_dashboard_screen.dart`
Expected: „No issues found!"

- [ ] **Step 3: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/buchhaltung/buchhaltung_dashboard_screen.dart
git commit -m "refactor(camt): Dashboard auf eine Bankauszug-Kachel reduziert"
```

---

## Task 5: Widget-Test für Host (Tabs + FAB-Gate)

**Files:**
- Create: `sbs_projer_app/test/camt_bankauszug_screen_test.dart`

- [ ] **Step 1: Test schreiben (erst rot, da geprüft wird, dass die echte Verdrahtung steht)**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/models/buchungs_vorlage.dart';
import 'package:sbs_projer_app/data/models/camt_datei.dart';
import 'package:sbs_projer_app/data/models/camt_pruefliste_eintrag.dart';
import 'package:sbs_projer_app/data/models/camt_regel.dart';
import 'package:sbs_projer_app/presentation/providers/buchungs_vorlage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/camt_abgleich_providers.dart';
import 'package:sbs_projer_app/presentation/providers/camt_pruefliste_providers.dart';
import 'package:sbs_projer_app/presentation/providers/camt_regel_providers.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/camt_bankauszug_screen.dart';

List<Override> _overrides() => [
      camtPrueflisteProvider
          .overrideWith((ref) async => <CamtPrueflisteEintrag>[]),
      camtRegelnProvider.overrideWith((ref) async => <CamtRegel>[]),
      camtDateienProvider.overrideWith((ref) async => <CamtDatei>[]),
      buchungsVorlagenProvider.overrideWithValue(<BuchungsVorlage>[]),
    ];

Future<void> _pump(WidgetTester tester, {int initialTab = 0}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: _overrides(),
    child: MaterialApp(home: CamtBankauszugScreen(initialTab: initialTab)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('zeigt vier Tabs', (tester) async {
    await _pump(tester);
    expect(find.byType(Tab), findsNWidgets(4));
    expect(find.widgetWithText(Tab, 'Import'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Prüfliste'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Regeln'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Dateien'), findsOneWidget);
  });

  testWidgets('FAB erscheint nur im Regeln-Tab', (tester) async {
    await _pump(tester);
    // Import-Tab aktiv → kein FAB
    expect(find.byType(FloatingActionButton), findsNothing);

    await tester.tap(find.widgetWithText(Tab, 'Regeln'));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester.tap(find.widgetWithText(Tab, 'Dateien'));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('initialTab=2 öffnet den Regeln-Tab (FAB sichtbar)',
      (tester) async {
    await _pump(tester, initialTab: 2);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
```

- [ ] **Step 2: Test laufen lassen**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test test/camt_bankauszug_screen_test.dart`
Expected: 3 Tests grün. Falls eine `overrideWith`-Signatur nicht passt (autoDispose-FutureProvider erwartet `FutureOr<T> Function(ref)`), an die im Provider definierte Signatur anpassen — die obigen Aufrufe entsprechen `FutureProvider.autoDispose<List<…>>` bzw. `Provider<List<…>>`.

- [ ] **Step 3: Commit**

```bash
git add sbs_projer_app/test/camt_bankauszug_screen_test.dart
git commit -m "test(camt): Host rendert 4 Tabs, FAB nur im Regeln-Tab, initialTab"
```

---

## Task 6: Voll-Verifikation, visueller Check, Deploy

**Files:** keine Code-Änderung (außer Versions-Bump).

- [ ] **Step 1: Voll-Analyse + alle Tests**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze && flutter test`
Expected: „No issues found!" und alle Tests grün (die 201 bestehenden + 3 neue = 204).

- [ ] **Step 2: Visueller Browser-Check (Pflicht laut Projekt-Regel „UI vor Deploy testen")**

`flutter run -d edge` (oder Preview), dann im Buchhaltungs-Dashboard die eine „Bankauszug Import"-Kachel öffnen und prüfen:
- Vier Tabs sichtbar, wechselbar; je Tab der erwartete Inhalt (Import-Wizard / Prüfliste / Regeln / Dateien).
- FAB „+" nur im Regeln-Tab; legt über `showRegelDialog` eine Regel an.
- Import → Schritt 2/3 durchspielen; „Zur Prüfliste" wechselt auf den Prüflisten-Tab (kein neuer Screen, AppBar/Tabs bleiben).
- Wizard-Schritt bleibt erhalten, wenn man zwischendurch auf einen anderen Tab und zurück wechselt.
- Dateien-Tab: Download-Icon funktioniert; Prüfliste-Tab: „Regel anlegen" öffnet den Dialog.
- Direktaufruf der alten URLs (`/buchhaltung/camt-pruefliste|regeln|dateien`) landet im richtigen Tab.

- [ ] **Step 3: Versions-Bump**

In `sbs_projer_app/pubspec.yaml` Zeile 4 beide Teile erhöhen (von `0.16.18+476` auf `0.16.19+477`).

```bash
git add sbs_projer_app/pubspec.yaml
git commit -m "chore: Version 0.16.19+477 (camt-Screens in Bankauszug-Import integriert)"
```

- [ ] **Step 4: Build + Deploy (Standard-Workflow aus CLAUDE.md)**

```bash
cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && export MSYS_NO_PATHCONV=1 \
  && flutter build web --base-href "/sbs-projer-dev/" --pwa-strategy=none
cd .. && VER=$(grep -o '"version":"[^"]*"' sbs_projer_app/build/web/version.json | cut -d'"' -f4) \
  && sed -i "s/\"mainJsPath\":\"main.dart.js\"/\"mainJsPath\":\"main.dart.js?v=$VER\"/g" sbs_projer_app/build/web/flutter_bootstrap.js \
  && rm -f sbs_projer_app/build/web/flutter_service_worker.js
git checkout gh-pages
rm -rf assets canvaskit icons main.dart.js* flutter*.js index.html manifest.json favicon.png version.json docs
cp -r sbs_projer_app/build/web/* .
touch .nojekyll
git add index.html main.dart.js* flutter*.js manifest.json favicon.png version.json .nojekyll assets/ canvaskit/ icons/
git commit -m "deploy v0.16.19 — camt-Screens in Bankauszug-Import integriert"
git push origin gh-pages
git checkout main
git push origin main
```
(Bei DNS-Flakiness `git push` in einer Retry-Schleife wiederholen.)

- [ ] **Step 5: Live verifizieren + ToDo/Memory aktualisieren**

`curl -s "https://danielproyer.github.io/sbs-projer-dev/version.json"` zeigt `0.16.19`. `ToDo.md` (Stand + neuer erledigt-Eintrag) und Memory `camt_import_merge` ergänzen, `git status` muss sauber sein.

---

## Self-Review (gegen die Spec geprüft)

1. **Spec-Coverage:** 4 Tabs (Task 1+2) ✓; 1 Dashboard-Kachel (Task 4) ✓; alte Routen als Redirects (Task 3) ✓; FAB nur im Regeln-Tab (Task 2) ✓; „Zur Prüfliste" als Tab-Wechsel statt Push (Task 1 Step 4 + Task 2) ✓; AppBar nur einmal (Task 1 entfernt alle, Task 2 baut eine) ✓; Wizard-State über Tab-Wechsel (KeepAlive, Task 1 Step 4) ✓; Provider-Invalidierung `camtPrueflisteProvider` bleibt im Import-Body unverändert ✓; Tests + visueller Check (Task 5+6) ✓.
2. **Platzhalter:** keine — alle geänderten Zeilen mit konkretem Code; Body-Übernahmen explizit als „1:1 kopieren" mit benannten Diffs.
3. **Typ-Konsistenz:** `CamtImportTab.onZurPruefliste` (VoidCallback?) ↔ Host übergibt `() => _tab.animateTo(1)` ✓; `initialTab` (int) ↔ Route-Mapping `switch` ✓; `showRegelDialog(context, ref)` aus `camt_regeln_tab.dart` ↔ Host-FAB + Prüfliste-Tab-Import ✓; Provider-Override-Signaturen entsprechen den gelesenen Definitionen ✓.

**Hinweis (bewusste Abweichung von der Spec-Formulierung):** Die Spec sprach von „Auto-Sprung nach Verbuchen". Da der Import-Ergebnis-Schritt aktionsbehaftet ist (Kundenzahlungen-Abgleich + „zu bestätigen"), würde ein sofortiger automatischer Sprung diesen Report überspringen. Deshalb wird der bestehende „Zur Prüfliste"-Button zum Tab-Wechsel (kein Route-Push) — gleiche Wirkung (ein Screen, Tab-Navigation), aber der Report bleibt sichtbar. Mit Daniel beim Handoff bestätigt.

# App-weite UI-Vereinheitlichung (Ansicht-Filter) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Die Filter-/Auswahl-Leisten der Listen-Screens auf einen einheitlichen, schlichten Stil bringen (schlichte Dropdowns im Wrap + FilterChip nur für Toggles), über neue Shared-Widgets, inkrementell pro Screen — Verhalten je Screen unverändert.

**Architecture:** Drei neue Shared-Widgets in `lib/presentation/widgets/filter/` (`AppFilterBar` mit `AppFilterItem`-Varianten, `AppActiveFilters`, `showAppFilterSheet`). Danach ersetzt jeder Listen-Screen seine inline Filter-UI durch diese Bausteine, ohne die bestehende Filter-Logik/State zu ändern.

**Tech Stack:** Flutter (Web, Material 3), Riverpod. Styling in den Widgets gekapselt (kein globaler Theme-Eingriff).

**Referenz-Spec:** `docs/superpowers/specs/2026-07-11-ui-vereinheitlichung-filter-design.md`

**Deploy:** Nach jedem Prio-Bündel Version-Bump + gh-pages-Deploy; der User prüft die migrierten Screens visuell im Browser (CanvasKit im Preview-Harness nicht renderbar).

---

### Task 1: Shared-Widgets + Widget-Tests

**Files:**
- Create: `sbs_projer_app/lib/presentation/widgets/filter/app_filter_bar.dart`
- Create: `sbs_projer_app/lib/presentation/widgets/filter/app_active_filters.dart`
- Create: `sbs_projer_app/lib/presentation/widgets/filter/app_filter_sheet.dart`
- Test: `sbs_projer_app/test/widgets/app_filter_widgets_test.dart`

- [ ] **Step 1: Failing Widget-Test schreiben**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/presentation/widgets/filter/app_filter_bar.dart';
import 'package:sbs_projer_app/presentation/widgets/filter/app_active_filters.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('AppFilterBar rendert Dropdown + Toggle; Callbacks feuern', (t) async {
    String? gewaehlt = 'x';
    bool toggle = false;
    await t.pumpWidget(_wrap(StatefulBuilder(
      builder: (c, setState) => AppFilterBar(items: [
        AppFilterDropdown<String>(
          hint: 'Alle Status',
          value: null,
          options: const [('offen', 'Offen'), ('zu', 'Geschlossen')],
          onChanged: (v) => setState(() => gewaehlt = v),
        ),
        AppFilterToggle(
          label: 'Nur fällige',
          value: toggle,
          onChanged: (v) => setState(() => toggle = v),
        ),
      ]),
    )));
    expect(find.text('Alle Status'), findsWidgets);
    expect(find.text('Nur fällige'), findsOneWidget);
    // Toggle antippen
    await t.tap(find.text('Nur fällige'));
    await t.pumpAndSettle();
    expect(toggle, isTrue);
    // Dropdown öffnen + Option wählen
    await t.tap(find.text('Alle Status').first);
    await t.pumpAndSettle();
    await t.tap(find.text('Geschlossen').last);
    await t.pumpAndSettle();
    expect(gewaehlt, 'zu');
  });

  testWidgets('AppActiveFilters: leer -> shrink, sonst löschbar', (t) async {
    await t.pumpWidget(_wrap(const AppActiveFilters(chips: [])));
    expect(find.byType(Chip), findsNothing);

    var entfernt = false;
    await t.pumpWidget(_wrap(AppActiveFilters(chips: [
      ('Region: Chur', () => entfernt = true),
    ])));
    expect(find.text('Region: Chur'), findsOneWidget);
    await t.tap(find.byIcon(Icons.close));
    await t.pumpAndSettle();
    expect(entfernt, isTrue);
  });
}
```

- [ ] **Step 2: Test ausführen (FAIL)**

Run: `export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter test test/widgets/app_filter_widgets_test.dart`
Expected: FAIL — Widgets existieren nicht.

- [ ] **Step 3: `app_filter_bar.dart` erstellen**

```dart
import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';

/// Ein Element der [AppFilterBar].
abstract class AppFilterItem {
  Widget build(BuildContext context);
}

/// Randloser Auswahl-Dropdown im 'Alle …'-Stil.
class AppFilterDropdown<T> extends AppFilterItem {
  final String hint;
  final T? value;
  final List<(T, String)> options;
  final ValueChanged<T?> onChanged;
  final bool nullable;
  AppFilterDropdown({
    required this.hint,
    required this.value,
    required this.options,
    required this.onChanged,
    this.nullable = true,
  });

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        );
    return DropdownButton<T?>(
      value: value,
      hint: Text(hint, style: style),
      isDense: true,
      underline: const SizedBox.shrink(),
      style: style,
      borderRadius: BorderRadius.circular(8),
      items: [
        if (nullable)
          DropdownMenuItem<T?>(value: null, child: Text(hint, style: style)),
        for (final (v, label) in options)
          DropdownMenuItem<T?>(value: v, child: Text(label, style: style)),
      ],
      onChanged: onChanged,
    );
  }
}

/// Binärer An/Aus-Filter als schlichter FilterChip.
class AppFilterToggle extends AppFilterItem {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  AppFilterToggle(
      {required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: value,
      onSelected: onChanged,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

/// Öffnet ein Multi-Select-Sheet; Label zeigt die Auswahl (z.B. 'Regionen (3)').
class AppFilterSheetButton extends AppFilterItem {
  final String label;
  final VoidCallback onTap;
  AppFilterSheetButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.filter_list, size: 16),
      label: Text(label),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

/// Einheitliche Filter-Leiste (unter der SearchBar).
class AppFilterBar extends StatelessWidget {
  final List<AppFilterItem> items;
  final EdgeInsetsGeometry padding;
  const AppFilterBar({
    super.key,
    required this.items,
    this.padding = const EdgeInsets.fromLTRB(12, 8, 12, 4),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [for (final i in items) i.build(context)],
      ),
    );
  }
}
```

- [ ] **Step 4: `app_active_filters.dart` erstellen**

```dart
import 'package:flutter/material.dart';

/// Zeigt aktive Filter als löschbare Chips. Leere Liste -> nichts.
class AppActiveFilters extends StatelessWidget {
  final List<(String, VoidCallback)> chips;
  final EdgeInsetsGeometry padding;
  const AppActiveFilters({
    super.key,
    required this.chips,
    this.padding = const EdgeInsets.fromLTRB(12, 0, 12, 4),
  });

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: padding,
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final (label, onRemove) in chips)
            Chip(
              label: Text(label),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: onRemove,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: `app_filter_sheet.dart` erstellen**

```dart
import 'package:flutter/material.dart';

/// Standardisiertes Multi-Select-Bottom-Sheet. Gibt die neue Auswahl zurück
/// oder null bei Abbruch (Sheet weggewischt).
Future<Set<T>?> showAppFilterSheet<T>({
  required BuildContext context,
  required String titel,
  required List<(T, String)> options,
  required Set<T> selected,
}) {
  return showModalBottomSheet<Set<T>>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      final sel = Set<T>.from(selected);
      return StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(titel, style: Theme.of(ctx).textTheme.titleMedium),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final (v, label) in options)
                      CheckboxListTile(
                        dense: true,
                        value: sel.contains(v),
                        title: Text(label),
                        onChanged: (b) => setSheet(() {
                          if (b == true) {
                            sel.add(v);
                          } else {
                            sel.remove(v);
                          }
                        }),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    if (sel.isNotEmpty)
                      TextButton(
                        onPressed: () => setSheet(sel.clear),
                        child: const Text('Zurücksetzen'),
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, sel),
                      child: const Text('Anwenden'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
```

- [ ] **Step 6: Test ausführen (PASS)**

Run: `export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter test test/widgets/app_filter_widgets_test.dart`
Expected: beide grün. Falls die Dropdown-Interaktion im Test hakt (Overlay-Timing), `pumpAndSettle` prüfen; Logik bleibt wie oben.

- [ ] **Step 7: Analyze + Commit**

```bash
export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter analyze lib/presentation/widgets/filter
git add sbs_projer_app/lib/presentation/widgets/filter sbs_projer_app/test/widgets/app_filter_widgets_test.dart
git commit -m "feat(ui): Shared-Filter-Widgets (AppFilterBar/AppActiveFilters/AppFilterSheet, Tests)"
```

---

### Task 2: Prio-1 — Touren, Kontakte, Betriebe migrieren

Die drei grössten Abweichler. Pro Screen: aktuelle inline Filter-UI durch die Shared-Widgets ersetzen, **Filter-State/-Logik unverändert lassen** (nur die Widgets tauschen).

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/touren/tourenplanung_screen.dart`
- Modify: `sbs_projer_app/lib/presentation/screens/kontakte/kontakte_list_screen.dart`
- Modify: `sbs_projer_app/lib/presentation/screens/betriebe/betriebe_list_screen.dart`

- [ ] **Step 1: Touren** — `_InlineFilterLeiste` durch `AppFilterBar` ersetzen. Die zwei Filter-Zeilen (Fälligkeit, Region) werden zu `AppFilterDropdown` (Fälligkeit: Optionen aus den Fälligkeitsstufen, hint „Alle Fälligkeiten"; Region: hint „Alle Regionen"). Bestehende `onChanged`-Handler/Provider-Aufrufe 1:1 übernehmen. `_filterZeile`/`_InlineFilterLeiste` + die stark umgestylten Chips entfernen. Die kompakte Höhe via `AppFilterBar`-Default beibehalten.

- [ ] **Step 2: Kontakte** — den selbstgebauten `_FilterChip` (Container/GestureDetector) durch `AppFilterBar` mit `AppFilterToggle` je Kategorie ODER einem `AppFilterDropdown` (Alle/Betrieb/Heineken/Event) ersetzen. Da es sich um exklusive Kategorien handelt: `AppFilterDropdown<Kategorie>` (hint „Alle Kontakte"). Auswahl-State + Filter-Logik unverändert. `_FilterChip`-Klasse entfernen.

- [ ] **Step 3: Betriebe** — `_FilterSheet` beibehalten, aber die aktive-Filter-Chip-Leiste auf `AppActiveFilters` umstellen; die Karten-Filter-Row (Region-DropdownButton, „Meine Kunden"/„Nur fällige" FilterChips) durch `AppFilterBar` (Region als `AppFilterDropdown`, die zwei als `AppFilterToggle`) ersetzen. Region-Mehrfachauswahl im Sheet: auf `showAppFilterSheet` umstellen (Checkbox-Grid ersetzen), Ergebnis-Set in den bestehenden State schreiben. Filter-Logik/Anwenden-Verhalten unverändert.

- [ ] **Step 4: Analyze + Test + Commit**

```bash
export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter analyze lib/presentation/screens/touren lib/presentation/screens/kontakte lib/presentation/screens/betriebe && flutter test 2>&1 | tail -2
git add sbs_projer_app/lib/presentation/screens/touren sbs_projer_app/lib/presentation/screens/kontakte sbs_projer_app/lib/presentation/screens/betriebe
git commit -m "refactor(ui): Touren/Kontakte/Betriebe auf AppFilterBar (Verhalten unveraendert)"
```

- [ ] **Step 5: Deploy-Checkpoint v0.38.0 + User-Visuell-Check**

Version bump (`pubspec.yaml`), Web-Build, Cache-Bust, gh-pages-Deploy (Standard-Workflow aus CLAUDE.md). Danach: **User prüft** Touren-Filter, Kontakte-Kategorien, Betriebe-Sheet + Karten-Filter im Browser — jede Option filtert wie vorher, aktive-Chips, Reset.

---

### Task 3: Prio-2 — Anlagen, Materialien, Rechnungen (Popup → Leiste)

AppBar-`PopupMenuButton`-Filter durch `AppFilterBar`-Dropdown im Body ersetzen.

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/anlagen/anlagen_list_screen.dart`
- Modify: `sbs_projer_app/lib/presentation/screens/materialien/materialien_list_screen.dart`
- Modify: `sbs_projer_app/lib/presentation/screens/rechnungen/rechnungen_list_screen.dart`

- [ ] **Step 1: Anlagen** — Status-`PopupMenuButton` (AppBar) entfernen; Status als `AppFilterDropdown` in eine `AppFilterBar` unter dem Kennzahlen-Kopf. Aktiver-Filter-Chip → Teil der Bar/`AppActiveFilters`. `_filterItem` entfernen.
- [ ] **Step 2: Materialien** — Kategorie-`PopupMenuButton` → `AppFilterDropdown`; den „Nur niedrig"-FilterChip als `AppFilterToggle` in dieselbe Bar. Aktiver Chip → `AppActiveFilters`.
- [ ] **Step 3: Rechnungen** — Status-`PopupMenuButton` (mit Dividern) → `AppFilterDropdown`; Jahr/Monat-DropdownButton in dieselbe `AppFilterBar` heben (als `AppFilterDropdown<int>`). Summary-Card unverändert.
- [ ] **Step 4: Analyze + Test + Commit**

```bash
export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter analyze lib/presentation/screens/anlagen lib/presentation/screens/materialien lib/presentation/screens/rechnungen && flutter test 2>&1 | tail -2
git add sbs_projer_app/lib/presentation/screens/anlagen sbs_projer_app/lib/presentation/screens/materialien sbs_projer_app/lib/presentation/screens/rechnungen
git commit -m "refactor(ui): Anlagen/Materialien/Rechnungen Popup-Filter -> AppFilterBar"
```

- [ ] **Step 5: Deploy-Checkpoint v0.39.0 + User-Visuell-Check** (Filter jetzt im Body statt AppBar; Verhalten identisch).

---

### Task 4: Prio-3 — Reinigungen, Störungen (Sheet + Region-Multiselect)

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/reinigungen/reinigungen_list_screen.dart`
- Modify: `sbs_projer_app/lib/presentation/screens/stoerungen/stoerungen_list_screen.dart`

- [ ] **Step 1: Reinigungen** — Regionen-Sheet (Checkbox-Grid) → `showAppFilterSheet`, ausgelöst über `AppFilterSheetButton` („Regionen (n)") in einer `AppFilterBar`; Jahr/Monat-DropdownButtons in dieselbe Bar; aktive Regionen → `AppActiveFilters`. Filter-Logik unverändert.
- [ ] **Step 2: Störungen** — Filter-Sheet (ChoiceChips Anlagentyp + Km) beibehalten ODER — konsistenter — Anlagentyp/Km als `AppFilterDropdown`/`AppFilterToggle` in eine `AppFilterBar` heben (live-apply-Verhalten beibehalten). Jahr/Monat-Row in dieselbe Bar.
- [ ] **Step 3: Analyze + Test + Commit**

```bash
export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter analyze lib/presentation/screens/reinigungen lib/presentation/screens/stoerungen && flutter test 2>&1 | tail -2
git add sbs_projer_app/lib/presentation/screens/reinigungen sbs_projer_app/lib/presentation/screens/stoerungen
git commit -m "refactor(ui): Reinigungen/Stoerungen auf AppFilterBar + AppFilterSheet"
```

- [ ] **Step 4: Deploy-Checkpoint v0.40.0 + User-Visuell-Check** (v.a. Region-Multiselect-Interaktion).

---

### Task 5: Prio-4 — Eingangsrechnungen, Events

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/eingangsrechnungen/eingangsrechnung_liste_screen.dart`
- Modify: `sbs_projer_app/lib/presentation/screens/events/events_list_screen.dart`

- [ ] **Step 1: Eingangsrechnungen** — Kategorie-`DropdownButtonFormField` (Form-Optik im Filter) → `AppFilterDropdown` in `AppFilterBar`; SegmentedButton (Rechnungen/Ablage) bleibt.
- [ ] **Step 2: Events** — rohes `TextField` der Suche → Material `SearchBar` (wie die übrigen Listen), damit die Sucheingabe app-weit einheitlich ist.
- [ ] **Step 3: Analyze + Test + Commit**

```bash
export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter analyze lib/presentation/screens/eingangsrechnungen lib/presentation/screens/events && flutter test 2>&1 | tail -2
git add sbs_projer_app/lib/presentation/screens/eingangsrechnungen sbs_projer_app/lib/presentation/screens/events
git commit -m "refactor(ui): Eingangsrechnungen Kategorie-Filter + Events SearchBar vereinheitlicht"
```

---

### Task 6: Prio-5 — Jahr/Monat-Rows auf AppFilterBar (kosmetisch)

Die schon nah-am-Ziel-Screens: die kopierte Jahr/Monat-DropdownButton-Row durch `AppFilterBar` mit `AppFilterDropdown<int>` ersetzen (einheitliche Anordnung/Stil). Buchungen zusätzlich vom Default-underline/`Wrap`-Sonderstil auf den Standard bringen.

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/montagen/montagen_list_screen.dart`
- Modify: `sbs_projer_app/lib/presentation/screens/pikett/pikett_dienste_list_screen.dart`
- Modify: `sbs_projer_app/lib/presentation/screens/eroeffnungsreinigungen/eroeffnungsreinigung_list_screen.dart`
- Modify: `sbs_projer_app/lib/presentation/screens/eigenauftraege/eigenauftrag_list_screen.dart`
- Modify: `sbs_projer_app/lib/presentation/screens/bergkundenpauschalen/bergkundenpauschale_list_screen.dart`
- Modify: `sbs_projer_app/lib/presentation/screens/buchhaltung/buchungen_list_screen.dart`

- [ ] **Step 1:** Je Screen die Jahr/Monat-Row auf `AppFilterBar` heben (Jahr + Monat als `AppFilterDropdown<int>`, hint „Alle Jahre"/„Ganzes Jahr"). Bei Buchungen zusätzlich Soll/Haben-Dropdown + Betrags-Row belassen, nur die Jahr/Monat-Dropdowns angleichen. Verhalten unverändert.
- [ ] **Step 2: Analyze + Test + Commit**

```bash
export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter analyze lib/presentation/screens/montagen lib/presentation/screens/pikett lib/presentation/screens/eroeffnungsreinigungen lib/presentation/screens/eigenauftraege lib/presentation/screens/bergkundenpauschalen lib/presentation/screens/buchhaltung/buchungen_list_screen.dart && flutter test 2>&1 | tail -2
git add sbs_projer_app/lib/presentation/screens/montagen sbs_projer_app/lib/presentation/screens/pikett sbs_projer_app/lib/presentation/screens/eroeffnungsreinigungen sbs_projer_app/lib/presentation/screens/eigenauftraege sbs_projer_app/lib/presentation/screens/bergkundenpauschalen sbs_projer_app/lib/presentation/screens/buchhaltung/buchungen_list_screen.dart
git commit -m "refactor(ui): Jahr/Monat-Filter-Rows auf AppFilterBar vereinheitlicht"
```

- [ ] **Step 3: Deploy-Checkpoint v0.41.0 + User-Visuell-Check** — Stichprobe der Listen (Jahr/Monat filtert, Suche, Sortierung).

---

## Self-Review
- **Spec-Abdeckung:** Shared-Widgets (Task 1) + alle Prio-Bündel (Task 2–6) decken die ~16 Ansicht-Filter-Screens der Spec. Formular-Dropdowns bewusst NICHT (out of scope).
- **Keine Platzhalter im Fundament:** Task 1 enthält vollständigen Code aller drei Widgets + Tests. Die Screen-Tasks beschreiben die konkrete Zuordnung (welcher inline-Filter → welches AppFilterItem); der Executor liest den aktuellen Screen und überträgt die bestehende Logik 1:1 (das ist bei 16 heterogenen Screens der ehrliche, robuste Weg — kein spekulativer Voll-Code pro Screen).
- **Typkonsistenz:** `AppFilterDropdown<T>`, `AppFilterToggle`, `AppFilterSheetButton`, `AppFilterBar(items:)`, `AppActiveFilters(chips:)`, `showAppFilterSheet<T>(...)` — in Task 1 definiert, in Task 2–6 identisch verwendet.
- **Verhalten:** Jede Screen-Task betont „Filter-Logik/State unverändert" — nur UI-Bausteine tauschen. Per-Screen visueller Check ist Pflicht (Analyze/Tests fangen Render-/Filter-Regressionen nicht).
- **Risiko-Guard:** Deploy-Checkpoints pro Bündel, damit der User inkrementell gegenprüft.

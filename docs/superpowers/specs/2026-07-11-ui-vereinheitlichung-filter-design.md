# App-weite UI-Vereinheitlichung — Filter & Auswahl (Ansicht-Filter)

**Datum:** 2026-07-11 · **Status:** abgenommen (Design)

## Ziel

Die Filter-/Auswahl-Leisten der Listen-Screens auf **einen einheitlichen, schlichten Stil** bringen: schlichte, randlose **Dropdowns in einer Wrap-Leiste** (`AppFilterBar`) für Auswahl mit mehreren Optionen, **FilterChip nur für binäre Toggles**, aktive Filter einheitlich als löschbare Chips (`AppActiveFilters`), Region-Mehrfachauswahl über ein standardisiertes **Bottom-Sheet** (`AppFilterSheet`). Formular-Eingabe-Dropdowns bleiben separat und vorerst unangetastet.

## Ist-Zustand (aus Inventur 11.07.2026)

Die Filter-UIs sind stark fragmentiert. Vier parallele Auslöse-Paradigmen koexistieren:
1. **Bottom-Sheet** via AppBar `filter_list` (Betriebe `_FilterSheet`, Störungen, Reinigungen-Regionen) — teils eigener Drag-Handle, teils `showDragHandle:true`, teils „Anwenden"-Button, teils live-apply.
2. **AppBar-PopupMenuButton** als Filter (Anlagen Status, Materialien Kategorie, Rechnungen Status).
3. **Dauerhafte Inline-Leiste** (Touren `_InlineFilterLeiste` mit stark umgestylten Chips, Kontakte mit selbstgebauten Container-Chips, Eingangsrechnungen mit Form-Dropdown).
4. **Reine Jahr/Monat-Dropdown-Zeile** (Montagen, Pikett, Reinigungen, Eröffnung, Eigenauftrag, Bergkunden) — das einzige konsistent kopierte Muster (`isDense`, underline via `SizedBox.shrink()`, `bodySmall`+`textPrimary`+`w600`); Buchungen weicht selbst davon ab.

Für denselben Zweck existieren **drei Chip-Implementierungen**: Material-`FilterChip`/`ChoiceChip`, stark umgestylte Touren-Chips, komplett selbstgebauter Container-Chip (Kontakte). Region-Mehrfachauswahl in **vier** Varianten (2-Spalten-Checkbox-Grid, FilterChips, DropdownButton, DropdownButtonFormField). Zentral fehlt **jede Abstraktion**: `lib/presentation/widgets/` hat kein Filter-/Dropdown-Widget, `app_theme.dart` weder `ChipThemeData` noch Dropdown-Theme — die Optik wird pro Screen dupliziert. Formular-Dropdowns (`DropdownButtonFormField` mit `InputDecoration`) sind demgegenüber schon relativ einheitlich.

## Entscheidungen (vom User abgenommen)

1. **Kanonische Komponente: Hybrid** — Dropdowns im Wrap für Mehr-Optionen-Auswahl, `FilterChip` nur für echte An/Aus-Toggles; `SegmentedButton` nur für Ansichts-Modi (Liste/Karte).
2. **Scope: nur Ansicht-Filter** — Formular-`DropdownButtonFormField` bleiben (separater, späterer Scope).
3. **AppBar-Popup-Filter abschaffen** — Status-/Kategorie-Filter von Anlagen/Materialien/Rechnungen wandern in die `AppFilterBar`; PopupMenuButton nur noch für echte Aktions-/Overflow-Menüs.
4. **Region-Mehrfachauswahl: Bottom-Sheet** mit Checkbox-Liste (`AppFilterSheet`), aktive Auswahl darunter als löschbare Chips.

Weitere (Default) Festlegungen:
- **Rollout inkrementell** nach Prio-Liste; jeder Screen einzeln deploybar und vom User im Browser visuell geprüft.
- **Nur Optik** — das Filter-Verhalten jedes Screens (live-apply vs. Anwenden-Button, Filter-Logik, Provider-Invalidierung) bleibt **unverändert**.
- **Styling gekapselt in den Shared-Widgets**, kein globaler `ChipThemeData`-Eingriff (vermeidet Theme-Nebenwirkungen auf unbeteiligte Chips/Screens). Ein zentrales Theme kann später separat folgen.

## Ziel-Design

### Kanonischer Filter-Stil
- Eine Filter-Leiste unter der SearchBar: `Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center)`.
- Jeder Auswahl-Filter = **randloser `DropdownButton`**: `underline: SizedBox.shrink()`, `isDense: true`, `style` = `bodySmall` + `AppColors.textPrimary` + `FontWeight.w600`, `hint` = „Alle …", Null-Item „Alle …" wenn nullable.
- Binäre Filter = schlichter Material-`FilterChip` (`selected`/`onSelected`), Standard-Farben, kompakt.
- Ansichts-Modi (2–3 exklusive) = `SegmentedButton` (unverändert, wo schon vorhanden).

### Shared-Widgets (neu, in `lib/presentation/widgets/filter/`)

**`AppFilterBar`** — rendert eine Liste heterogener Filter-Items als Wrap.
```dart
abstract class AppFilterItem {
  Widget build(BuildContext context);
}

class AppFilterDropdown<T> extends AppFilterItem {
  final String hint;                 // 'Alle Regionen'
  final T? value;
  final List<(T value, String label)> options;
  final ValueChanged<T?> onChanged;
  final bool nullable;               // fügt 'Alle …' (null) hinzu
  AppFilterDropdown({required this.hint, required this.value,
    required this.options, required this.onChanged, this.nullable = true});
  @override Widget build(BuildContext context) { /* randloser DropdownButton, s.o. */ }
}

class AppFilterToggle extends AppFilterItem {
  final String label;                // 'Nur fällige'
  final bool value;
  final ValueChanged<bool> onChanged;
  AppFilterToggle({required this.label, required this.value, required this.onChanged});
  @override Widget build(BuildContext context) { /* schlichter FilterChip */ }
}

class AppFilterSheetButton extends AppFilterItem {
  final String label;                // 'Regionen (3)' — Anzahl gewählter
  final VoidCallback onTap;          // öffnet showAppFilterSheet
  AppFilterSheetButton({required this.label, required this.onTap});
  @override Widget build(BuildContext context) { /* ActionChip/OutlinedButton mit Icon */ }
}

class AppFilterBar extends StatelessWidget {
  final List<AppFilterItem> items;
  final EdgeInsetsGeometry padding;
  const AppFilterBar({super.key, required this.items,
    this.padding = const EdgeInsets.fromLTRB(12, 8, 12, 4)});
  // Wrap(spacing:12, runSpacing:8, crossAxisAlignment:center) über items.map((i)=>i.build(context))
}
```

**`AppActiveFilters`** — aktive Filter als löschbare Chips.
```dart
class AppActiveFilters extends StatelessWidget {
  final List<(String label, VoidCallback onRemove)> chips;
  const AppActiveFilters({super.key, required this.chips});
  // chips leer -> SizedBox.shrink(); sonst Wrap(spacing:6, runSpacing:4) mit
  // Chip(label, deleteIcon: Icon(Icons.close, size:16), onDeleted: onRemove)
}
```

**`AppFilterSheet`** — standardisiertes Multi-Select-Sheet.
```dart
Future<Set<T>?> showAppFilterSheet<T>({
  required BuildContext context,
  required String titel,
  required List<(T value, String label)> options,
  required Set<T> selected,
}) { /* showModalBottomSheet(showDragHandle:true) mit CheckboxListTile-Liste,
        'Anwenden'-Button -> Navigator.pop(neueAuswahl); Abbruch -> pop(null) */ }
```

### Reine Hilfsfunktion (TDD-fähig)
Damit die Toggle-/Dropdown-Anzeige (z.B. „Regionen (3)"-Label, aktive-Filter-Chip-Texte) testbar ist, eine reine Funktion `aktiveFilterLabels(...)` bzw. Label-Helfer in `core/util/` — soweit sinnvoll. Die Widgets selbst werden per Widget-Smoke-Test abgedeckt.

## Scope & Priorität (nur Ansicht-Filter, ~16 Screens)

- **Prio 1 (grösste Abweichler):** `touren/tourenplanung_screen.dart` (`_InlineFilterLeiste`), `kontakte/kontakte_list_screen.dart` (Custom-Container-Chips), `betriebe/betriebe_list_screen.dart` (`_FilterSheet` + Karten-Filter + Checkbox-Grid).
- **Prio 2 (Popup → Leiste):** `anlagen/anlagen_list_screen.dart`, `materialien/materialien_list_screen.dart`, `rechnungen/rechnungen_list_screen.dart`.
- **Prio 3 (Sheet + Region-Multiselect):** `reinigungen/reinigungen_list_screen.dart`, `stoerungen/stoerungen_list_screen.dart`.
- **Prio 4 (Sonderfälle):** `eingangsrechnungen/eingangsrechnung_liste_screen.dart` (Form-Dropdown als Filter → AppFilterBar), `events/events_list_screen.dart` (rohes TextField → Material `SearchBar`).
- **Prio 5 (nah am Ziel, kosmetisch):** `montagen`, `pikett_dienste`, `eroeffnungsreinigung`, `eigenauftrag`, `bergkundenpauschale`, `buchhaltung/buchungen_list` — Jahr/Monat-Row auf `AppFilterBar` heben.

## Rollout

Inkrementell: **erst die Shared-Widgets bauen** (mit Widget-Smoke-Tests), **dann Screen für Screen** nach Prio migrieren. Jeder Screen ist eine eigene, deploybare Einheit; nach jedem (oder jedem kleinen Bündel) Version-Bump + Deploy, und der **User prüft den Screen visuell im Browser** (CanvasKit ist im Preview-Harness nicht renderbar → visuelle Prüfung ist User-getrieben). **Filter-Verhalten bleibt je Screen identisch** — nur die UI-Bausteine werden getauscht.

## Nicht im Scope
- Formular-`DropdownButtonFormField` (eigener späterer Durchgang; bereits weitgehend konsistent).
- Verhaltens-Harmonisierung (live-apply vs. Anwenden-Button überall gleich) — Folge-Entscheidung.
- Globaler `ChipThemeData`/Dropdown-Theme-Eingriff (Nebenwirkungs-Risiko) — Styling bleibt in den Shared-Widgets gekapselt.
- Dark-Theme (existiert nicht; Widgets bedienen weiter nur `.light`).

## Risiken
- **Verhaltens-/State-Regressionen pro Screen:** Filter-Logik ist inline und teils subtil (Trigger-Zeitpunkt, Reset, Provider-Invalidierung). Beim Extrahieren strikt das bestehende Verhalten erhalten; jeder Screen einzeln visuell prüfen.
- **Touren `_InlineFilterLeiste`** ist die jüngste, bewusst kompakte Lösung — beim Umbau auf schlichte Dropdowns kann Dichte/horizontale Scrollbarkeit auf schmalen Ansichten leiden. Ggf. Kompaktheit in `AppFilterBar` erhalten.
- **Multiselect-Migration** (Checkbox-Grid → Sheet) ändert die Interaktion spürbar — Akzeptanz beim User prüfen.
- **Popup → Leiste** verschiebt den Filter von der AppBar in den Body (Layout/Scroll/Platz für die Liste).
- **Aktive-Filter-Chips hinzufügen** ändert Screenhöhe/Abstände dort, wo es sie vorher nicht gab.
- Analyze/Tests fangen Render-/Filter-Regressionen **nicht** → per-Screen visuelle Kontrolle ist Pflicht.

## Verifikation
- Shared-Widgets: Widget-Smoke-Tests (rendert, onChanged/onSelected feuern, leere-aktive-Filter → shrink).
- Pro migriertem Screen: `flutter analyze` + Test-Suite grün, **User-Browser-Check** des Filter-Verhaltens (jede Option filtert wie vorher, aktive-Chips, Reset).

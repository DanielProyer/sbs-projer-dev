# Material: Kategorie-Chips + Karten-Swipe — Umsetzungsplan

> Für Subagenten: superpowers:subagent-driven-development. Stand 27.09.2026.

**Ziel:** `/materialien` bekommt eine Chip-Zeile mit den Kategorien oben und
zwei Ansichten: Liste (wie heute) und Karten, durch die man per Swipe geht.
Vorbild: v2-Materialkatalog der Heineken-App — ohne dessen Fehler (Controller im
Build, 60er-Deckel, Karten ohne Key, kein Sprung auf Seite 1, Dropdown ignoriert
Gruppe, nichts gemerkt).

**Architektur:** Reine Logik (Filter, Chips, Sortierung) in
`lib/core/util/material_filter.dart`; Prefs in
`lib/services/storage/material_ansicht_speicher.dart`; Chip-Zeile und Karte als
eigene Widgets unter `screens/materialien/widgets/`; der Screen hält
`PageController`, Foto-URL-Cache und Modus.

**Stack:** Flutter Web (CanvasKit!), Riverpod 2.5, GoRouter 14, shared_preferences
2.5, Supabase (nur über bestehende Repositories).

## Dateien

- Neu `lib/core/util/material_filter.dart`
- Neu `lib/services/storage/material_ansicht_speicher.dart`
- Neu `lib/presentation/screens/materialien/widgets/material_kategorie_chips.dart`
- Neu `lib/presentation/screens/materialien/widgets/material_karte.dart`
- Ändern `lib/presentation/screens/materialien/materialien_list_screen.dart`
- Tests `test/material_filter_test.dart`, `test/material_ansicht_speicher_test.dart`,
  `test/materialien_list_screen_test.dart`, `test/material_providers_test.dart`

## Regeln (verbindlich)

- CanvasKit: keine neuen `FilledButton`/`OutlinedButton` (Ratsche
  `test/canvaskit_ratsche_test.dart` = 81, darf nur sinken); Knöpfe als
  `TapKnopf` oder `InkWell`/`GestureDetector` + `Container`. Kein `ExpansionTile`
  mit `dense: true`. `FilterChip`/`IconButton` sind in Ordnung (bewährt).
- Kein `dart format` über ganze Dateien. Keine Version bumpen (macht die
  Hauptsession). `flutter analyze` 0, alle Tests grün.
- Commit-Trailer: `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- Deutsch in Code-Kommentaren (WARUM, nicht WAS) und Tests.

Die Tasks stehen im Auftrag an den Implementer (gleicher Text).

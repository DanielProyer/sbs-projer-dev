# P1 Quick Wins — Implementierungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 7 abgenommene Quick-Win-Optimierungen aus `docs/superpowers/specs/2026-07-07-p1-quick-wins-design.md` umsetzen, ohne bestehende Funktionen zu tangieren.

**Architecture:** Reine UI-Anpassungen in bestehenden Screens (Tasks 1–5), eine Rollen-Erweiterung mit DB-CHECK-Migration (Task 4), sowie Erweiterung der Betriebsferien von 3 auf 5 Slots über einen neuen zentralen Ferien-Util (Tasks 6–10), der gleichzeitig den bestehenden Bug behebt, dass `isBetriebOffen`/`_isBetriebAktiv` nur Ferien 1 prüfen.

**Tech Stack:** Flutter/Dart, Riverpod, Isar (Conditional Exports Native/Web), Supabase (Migrationen via MCP `apply_migration`, Project-ID `pltbaqqwpnmdajwgnhpd`).

**Wichtige Projektregeln:**
- Alle Shell-Kommandos in Git Bash mit `export PATH="$PATH:/c/flutter/bin"`, App-Verzeichnis `sbs_projer_app`.
- Imports von Local-Models IMMER über `*_export.dart`.
- Nach jedem Task: `flutter analyze` sauber, dann committen.
- Migrations-SQL zusätzlich als Datei in `Datenbank/migrations/` ablegen (durchnummeriert, aktuell höchste: 116).

---

### Task 1: Eigenaufträge — Status-Filter entfernen

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/eigenauftraege/eigenauftrag_list_screen.dart`

- [ ] **Step 1: Filter-Button aus AppBar entfernen**

Zeilen 96–108 (der `actions:`-Block mit `PopupMenuButton`) ersatzlos löschen, sodass die AppBar nur noch den Titel hat:

```dart
      appBar: AppBar(
        title: const Text('Eigenaufträge'),
      ),
```

- [ ] **Step 2: Filter-State und -Logik entfernen**

Zeile 30 löschen: `String _statusFilter = 'alle';`
Zeile 55 löschen: `if (_statusFilter != 'alle' && e.status != _statusFilter) return false;`
Die Methode `PopupMenuItem<String> _filterItem(...)` in derselben Datei (per Suche nach `_filterItem` finden, analog `stoerungen_list_screen.dart:331`) komplett löschen.

- [ ] **Step 3: Analyze**

Run: `export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/eigenauftraege/eigenauftrag_list_screen.dart
git commit -m "feat(eigenauftraege): Status-Filter entfernt (P1.1)"
```

---

### Task 2: Reinigung Detail — Chip „Protokoll" + Service-Art statt Service-Typ

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/reinigungen/reinigung_detail_screen.dart:127-128, 896-901`

- [ ] **Step 1: Chip umbenennen**

Zeilen 896–901, aus:

```dart
        if (reinigung.protokollFotoPfad != null)
          const _StatusChip(
            label: 'Foto',
            color: AppColors.success,
            icon: Icons.photo_camera,
          ),
```

wird:

```dart
        if (reinigung.protokollFotoPfad != null)
          const _StatusChip(
            label: 'Protokoll',
            color: AppColors.success,
            icon: Icons.description,
          ),
```

- [ ] **Step 2: Service-Art statt roher Service-Typ in der Preis-Karte**

Zeilen 127–128, aus:

```dart
                if (reinigung.serviceTyp != null)
                  _InfoRow('Service-Typ', reinigung.serviceTyp!),
```

wird:

```dart
                _InfoRow('Service-Art',
                    _serviceArtLabel(reinigung.serviceArt ?? 'standardservice')),
```

`_serviceArtLabel` existiert bereits als static Methode in dieser Datei (Zeile 310) und ist im Build-Kontext erreichbar. `serviceTyp` wird nirgends sonst in der Anzeige verwendet — Preisberechnung bleibt unberührt.

- [ ] **Step 3: Analyze**

Run: `export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/reinigungen/reinigung_detail_screen.dart
git commit -m "feat(reinigung): Chip Protokoll statt Foto, Service-Art statt rohem Service-Typ (P1.3+P1.4)"
```

---

### Task 3: Reinigung Formular — Zeiterfassung einzeilig

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/reinigungen/reinigung_form_screen.dart:941-992`

- [ ] **Step 1: Datum + Start + Ende in eine Zeile legen**

Den Block ab `_sectionTitle(context, 'Zeiterfassung')` (Z. 942) bis zum Ende der Start/Ende-Row (Z. 992, inkl. des `if (!_istHeinekenMonteur)`-Beginns) ersetzen durch:

```dart
            // === Zeiterfassung ===
            _sectionTitle(context, 'Zeiterfassung'),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _datum,
                        firstDate: DateTime(2024),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (picked != null) {
                        setState(() => _datum = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Datum',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(_formatDate(_datum)),
                    ),
                  ),
                ),
                if (!_istHeinekenMonteur) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _uhrzeitStartController,
                      decoration: const InputDecoration(
                        labelText: 'Start',
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _uhrzeitEndeController,
                      decoration: const InputDecoration(
                        labelText: 'Ende',
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              ],
            ),

            if (!_istHeinekenMonteur) ...[
              const SizedBox(height: 24),
```

WICHTIG: Der ursprüngliche `if (!_istHeinekenMonteur) ...[`-Block begann vor der Start/Ende-Row und läuft bis weit hinter die Service-Art-Sektion (schliessende `],` nach der Protokoll-Sektion). Die Start/Ende-Felder wandern in die Datum-Row (mit eigenem Collection-if); der bestehende grosse `if`-Block beginnt neu erst bei `const SizedBox(height: 24),` vor `_sectionTitle(context, 'Service-Art')`. Die schliessende Klammer des grossen Blocks bleibt unverändert.

- [ ] **Step 2: Analyze**

Run: `export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/reinigungen/reinigung_form_screen.dart
git commit -m "feat(reinigung): Zeiterfassung kompakt einzeilig Datum/Start/Ende (P1.5)"
```

---

### Task 4: Kontakte — Heineken-Rolle „Stardrinks"

**Files:**
- Create: `Datenbank/migrations/117_kontakt_rolle_stardrinks.sql`
- Modify: `sbs_projer_app/lib/data/models/kontakt.dart:105-146`

- [ ] **Step 1: Migration schreiben**

Datei `Datenbank/migrations/117_kontakt_rolle_stardrinks.sql`:

```sql
-- ============================================================
-- Migration 117: Kontakt-Rolle «Stardrinks» für Heineken
-- Projekt: SBS Projer App
-- Stand: 07.07.2026
-- ============================================================

ALTER TABLE kontakte DROP CONSTRAINT IF EXISTS kontakte_rolle_check;
ALTER TABLE kontakte ADD CONSTRAINT kontakte_rolle_check
  CHECK (rolle IN (
    'geschaeftsfuehrer', 'fb_manager', 'mitarbeiter', 'hauswart', 'sonstige',
    'rsl', 'vertreter', 'buero', 'monteur', 'event_heineken', 'pikett',
    'stardrinks',
    'ok', 'bau', 'stand'
  ));
```

- [ ] **Step 2: Migration anwenden**

Via Supabase MCP: `apply_migration` mit name `117_kontakt_rolle_stardrinks` und obigem SQL (Project `pltbaqqwpnmdajwgnhpd`).
Expected: Success, keine Fehlermeldung.

- [ ] **Step 3: Model erweitern**

In `sbs_projer_app/lib/data/models/kontakt.dart`:

Zeile 125, aus:
```dart
    'heineken' => ['rsl', 'vertreter', 'buero', 'monteur', 'event_heineken', 'pikett'],
```
wird:
```dart
    'heineken' => ['rsl', 'vertreter', 'buero', 'monteur', 'event_heineken', 'pikett', 'stardrinks'],
```

In BEIDEN Label-Switches (`rolleLabel` Z. 105–121 und `rolleLabelStatic` Z. 130–146) nach `'vertreter' => 'Vertreter',` je eine Zeile ergänzen:
```dart
    'stardrinks' => 'Stardrinks',
```

- [ ] **Step 4: Analyze + Commit**

Run: `export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter analyze`
Expected: `No issues found!`

```bash
git add Datenbank/migrations/117_kontakt_rolle_stardrinks.sql sbs_projer_app/lib/data/models/kontakt.dart
git commit -m "feat(kontakte): Heineken-Rolle Stardrinks (P1.6, Migration 117)"
```

---

### Task 5: Störungen — Filter-BottomSheet (Status + Anlagentyp + Km)

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/stoerungen/stoerungen_list_screen.dart`

- [ ] **Step 1: Filter-State erweitern**

Nach Zeile 30 (`String _statusFilter = 'alle';`) ergänzen:

```dart
  String? _anlagenTypFilter; // null = alle, 'ohne' = ohne Anlagentyp
  String _kmFilter = 'alle'; // 'alle' | 'mit' | 'ohne'
```

- [ ] **Step 2: Filterbedingungen ergänzen**

Nach Zeile 55 (`if (_statusFilter != 'alle' && ...) return false;`) einfügen:

```dart
      if (_anlagenTypFilter != null) {
        if (_anlagenTypFilter == 'ohne') {
          if (s.anlageTyp != null) return false;
        } else if (s.anlageTyp != _anlagenTypFilter) {
          return false;
        }
      }
      if (_kmFilter == 'mit' && !s.istKilometerabrechnung) return false;
      if (_kmFilter == 'ohne' && s.istKilometerabrechnung) return false;
```

- [ ] **Step 3: AppBar-Action ersetzen (Badge + BottomSheet)**

Zeilen 97–108 (`PopupMenuButton<String>(...)`) ersetzen durch:

```dart
          IconButton(
            tooltip: 'Filter',
            onPressed: () => _showFilterSheet(stoerungen),
            icon: Badge.count(
              count: _aktiveFilterAnzahl,
              isLabelVisible: _aktiveFilterAnzahl > 0,
              child: const Icon(Icons.filter_list),
            ),
          ),
```

- [ ] **Step 4: Getter, BottomSheet und Aufräumen**

Die nicht mehr benötigte Methode `_filterItem` (Z. 331 ff.) löschen. Am Ende der State-Klasse ergänzen:

```dart
  int get _aktiveFilterAnzahl =>
      (_statusFilter != 'alle' ? 1 : 0) +
      (_anlagenTypFilter != null ? 1 : 0) +
      (_kmFilter != 'alle' ? 1 : 0);

  void _showFilterSheet(List<StoerungLocal> stoerungen) {
    final anlagenTypen = stoerungen
        .map((s) => s.anlageTyp)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
    final hatOhneTyp = stoerungen.any((s) => s.anlageTyp == null);

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          void apply(VoidCallback fn) {
            setSheetState(fn);
            setState(() {});
          }

          Widget section(String titel) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(titel,
                    style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        )),
              );

          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  section('Status'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        for (final e in const [
                          ('alle', 'Alle'),
                          ('offen', 'Offen'),
                          ('behoben', 'Behoben'),
                          ('nicht_behebbar', 'Nicht behebbar'),
                        ])
                          ChoiceChip(
                            label: Text(e.$2),
                            selected: _statusFilter == e.$1,
                            onSelected: (_) =>
                                apply(() => _statusFilter = e.$1),
                          ),
                      ],
                    ),
                  ),
                  section('Anlagentyp'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        ChoiceChip(
                          label: const Text('Alle'),
                          selected: _anlagenTypFilter == null,
                          onSelected: (_) =>
                              apply(() => _anlagenTypFilter = null),
                        ),
                        for (final typ in anlagenTypen)
                          ChoiceChip(
                            label: Text(typ),
                            selected: _anlagenTypFilter == typ,
                            onSelected: (_) =>
                                apply(() => _anlagenTypFilter = typ),
                          ),
                        if (hatOhneTyp)
                          ChoiceChip(
                            label: const Text('Ohne Anlagentyp'),
                            selected: _anlagenTypFilter == 'ohne',
                            onSelected: (_) =>
                                apply(() => _anlagenTypFilter = 'ohne'),
                          ),
                      ],
                    ),
                  ),
                  section('Km-Abrechnung'),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        for (final e in const [
                          ('alle', 'Alle'),
                          ('mit', 'Nur mit Km'),
                          ('ohne', 'Nur ohne Km'),
                        ])
                          ChoiceChip(
                            label: Text(e.$2),
                            selected: _kmFilter == e.$1,
                            onSelected: (_) => apply(() => _kmFilter = e.$1),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
```

- [ ] **Step 5: Analyze**

Run: `export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/stoerungen/stoerungen_list_screen.dart
git commit -m "feat(stoerungen): Filter-Sheet mit Status, Anlagentyp und Km-Abrechnung (P1.2)"
```

---

### Task 6: Betriebsferien — Model + DB auf 5 Slots erweitern

**Files:**
- Create: `Datenbank/migrations/118_betrieb_ferien45.sql`
- Modify: `sbs_projer_app/lib/data/local/betrieb_local.dart:56`
- Modify: `sbs_projer_app/lib/data/local/web/betrieb_local_web.dart` (Ferien-Block analog)
- Modify: `sbs_projer_app/lib/data/models/betrieb.dart:38, 86, 142, 195`
- Modify: `sbs_projer_app/lib/data/mappers/betrieb_mapper.dart:44, 98`

- [ ] **Step 1: Migration schreiben und anwenden**

Datei `Datenbank/migrations/118_betrieb_ferien45.sql`:

```sql
-- ============================================================
-- Migration 118: Betriebsferien 4+5 (Erweiterung von 3 auf 5 Slots)
-- Projekt: SBS Projer App
-- Stand: 07.07.2026
-- ============================================================

ALTER TABLE betriebe
  ADD COLUMN IF NOT EXISTS ferien4_start date,
  ADD COLUMN IF NOT EXISTS ferien4_ende date,
  ADD COLUMN IF NOT EXISTS ferien5_start date,
  ADD COLUMN IF NOT EXISTS ferien5_ende date;
```

Via Supabase MCP `apply_migration` anwenden (name `118_betrieb_ferien45`).

- [ ] **Step 2: Isar-Model erweitern**

`betrieb_local.dart` nach Zeile 56 (`DateTime? ferien3Ende;`):

```dart
  DateTime? ferien4Start;
  DateTime? ferien4Ende;
  DateTime? ferien5Start;
  DateTime? ferien5Ende;
```

- [ ] **Step 3: Web-Stub identisch erweitern**

In `sbs_projer_app/lib/data/local/web/betrieb_local_web.dart` dieselben 4 Felder direkt nach `ferien3Ende` einfügen (Plain-Dart-Klasse, gleiche Syntax wie Step 2).

- [ ] **Step 4: DTO erweitern**

`betrieb.dart`:
- Nach Z. 38 (`final DateTime? ferien3Ende;`): 4 neue `final DateTime? ferien4Start;` etc.
- Nach Z. 86 (`this.ferien3Ende,` im Konstruktor): `this.ferien4Start, this.ferien4Ende, this.ferien5Start, this.ferien5Ende,`
- In `fromJson` nach Z. 142: 4 Zeilen nach bestehendem Muster (`ferien4Start: json['ferien4_start'] != null ? DateTime.parse(json['ferien4_start']) : null,` usw.)
- In `toJson` nach Z. 195: 4 Zeilen nach Muster (`'ferien4_start': ferien4Start?.toIso8601String().split('T').first,` usw.)

- [ ] **Step 5: Mapper erweitern**

`betrieb_mapper.dart`:
- `fromDto` nach Z. 44: `local.ferien4Start = dto.ferien4Start;` (4 Zeilen)
- `toJson` nach Z. 98: `'ferien4_start': local.ferien4Start?.toIso8601String().split('T').first,` (4 Zeilen)

- [ ] **Step 6: Isar-Code generieren + Analyze**

Run: `export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && dart run build_runner build --delete-conflicting-outputs`
Expected: `Succeeded after ...` (betrieb_local.g.dart neu generiert)

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add Datenbank/migrations/118_betrieb_ferien45.sql sbs_projer_app/lib/data/local/betrieb_local.dart sbs_projer_app/lib/data/local/betrieb_local.g.dart sbs_projer_app/lib/data/local/web/betrieb_local_web.dart sbs_projer_app/lib/data/models/betrieb.dart sbs_projer_app/lib/data/mappers/betrieb_mapper.dart
git commit -m "feat(betriebe): Ferien-Slots 4+5 in DB, Model, DTO, Mapper (P1.7, Migration 118)"
```

---

### Task 7: Ferien-Util mit Tests (TDD)

**Files:**
- Create: `sbs_projer_app/lib/core/util/betrieb_ferien.dart`
- Test: `sbs_projer_app/test/core/util/betrieb_ferien_test.dart`

- [ ] **Step 1: Failing Test schreiben**

`test/core/util/betrieb_ferien_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/betrieb_ferien.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';

BetriebLocal _betrieb() => BetriebLocal()
  ..userId = 'test'
  ..name = 'Test';

void main() {
  group('ferienSlots', () {
    test('ohne Ferien: 5 leere Slots', () {
      final slots = ferienSlots(_betrieb());
      expect(slots.length, 5);
      expect(slots.every((s) => s.start == null && s.ende == null), isTrue);
    });

    test('liefert alle 5 Slots in Reihenfolge', () {
      final b = _betrieb()
        ..ferienStart = DateTime(2026, 1, 1)
        ..ferien4Start = DateTime(2026, 4, 1)
        ..ferien5Ende = DateTime(2026, 5, 31);
      final slots = ferienSlots(b);
      expect(slots[0].start, DateTime(2026, 1, 1));
      expect(slots[3].start, DateTime(2026, 4, 1));
      expect(slots[4].ende, DateTime(2026, 5, 31));
    });
  });

  group('ferienStarts / ferienEnden', () {
    test('nur belegte Werte, auch aus Slot 4+5', () {
      final b = _betrieb()
        ..ferien2Start = DateTime(2026, 2, 1)
        ..ferien5Start = DateTime(2026, 5, 1)
        ..ferien3Ende = DateTime(2026, 3, 15);
      expect(ferienStarts(b),
          [DateTime(2026, 2, 1), DateTime(2026, 5, 1)]);
      expect(ferienEnden(b), [DateTime(2026, 3, 15)]);
    });
  });

  group('istInFerien', () {
    test('innerhalb Ferien 2 → true (Bugfix: bisher nur Ferien 1 geprüft)', () {
      final b = _betrieb()
        ..ferien2Start = DateTime(2026, 7, 10)
        ..ferien2Ende = DateTime(2026, 7, 20);
      expect(istInFerien(b, DateTime(2026, 7, 15)), isTrue);
    });

    test('Randtage inklusive', () {
      final b = _betrieb()
        ..ferien4Start = DateTime(2026, 8, 1)
        ..ferien4Ende = DateTime(2026, 8, 14);
      expect(istInFerien(b, DateTime(2026, 8, 1)), isTrue);
      expect(istInFerien(b, DateTime(2026, 8, 14)), isTrue);
      expect(istInFerien(b, DateTime(2026, 7, 31)), isFalse);
      expect(istInFerien(b, DateTime(2026, 8, 15)), isFalse);
    });

    test('unvollständiger Slot (nur Start) zählt nicht', () {
      final b = _betrieb()..ferien3Start = DateTime(2026, 9, 1);
      expect(istInFerien(b, DateTime(2026, 9, 5)), isFalse);
    });
  });
}
```

- [ ] **Step 2: Test laufen lassen — muss fehlschlagen**

Run: `export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter test test/core/util/betrieb_ferien_test.dart`
Expected: FAIL (Datei `betrieb_ferien.dart` existiert nicht)

- [ ] **Step 3: Util implementieren**

`lib/core/util/betrieb_ferien.dart`:

```dart
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';

/// Ein Ferien-Slot (Start/Ende können einzeln null sein).
typedef FerienSlot = ({DateTime? start, DateTime? ende});

/// Alle 5 Ferien-Slots eines Betriebs in fester Reihenfolge.
/// Prüft NICHT [BetriebLocal.keineBetriebsferien] — das bleibt Sache der Aufrufer.
List<FerienSlot> ferienSlots(BetriebLocal b) => [
      (start: b.ferienStart, ende: b.ferienEnde),
      (start: b.ferien2Start, ende: b.ferien2Ende),
      (start: b.ferien3Start, ende: b.ferien3Ende),
      (start: b.ferien4Start, ende: b.ferien4Ende),
      (start: b.ferien5Start, ende: b.ferien5Ende),
    ];

/// Alle belegten Ferien-Startdaten.
List<DateTime> ferienStarts(BetriebLocal b) =>
    [for (final s in ferienSlots(b)) if (s.start != null) s.start!];

/// Alle belegten Ferien-Enddaten.
List<DateTime> ferienEnden(BetriebLocal b) =>
    [for (final s in ferienSlots(b)) if (s.ende != null) s.ende!];

/// True wenn [datum] in einer vollständig erfassten Ferienperiode liegt
/// (Randtage inklusive).
bool istInFerien(BetriebLocal b, DateTime datum) {
  for (final s in ferienSlots(b)) {
    if (s.start == null || s.ende == null) continue;
    if (!datum.isBefore(s.start!) && !datum.isAfter(s.ende!)) return true;
  }
  return false;
}
```

- [ ] **Step 4: Test laufen lassen — muss bestehen**

Run: `flutter test test/core/util/betrieb_ferien_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/core/util/betrieb_ferien.dart sbs_projer_app/test/core/util/betrieb_ferien_test.dart
git commit -m "feat(betriebe): zentraler Ferien-Util für 5 Slots inkl. Tests (P1.7)"
```

---

### Task 8: Ferien-Logik auf 5 Slots umstellen (Tourenplanung, Termine, Raster)

**Files:**
- Modify: `sbs_projer_app/lib/presentation/providers/tour_providers.dart:133-141, 166-177, 276-280, 324-328`
- Modify: `sbs_projer_app/lib/data/repositories/termin_repository.dart:251-258`
- Modify: `sbs_projer_app/lib/presentation/screens/heineken/heineken_raster_screen.dart:124-135`

- [ ] **Step 1: tour_providers.dart umstellen**

Import ergänzen: `import 'package:sbs_projer_app/core/util/betrieb_ferien.dart';`

`_naechsteSchliessung` (Z. 133–141), aus:
```dart
  for (final fs in [
    betrieb.ferienStart,
    betrieb.ferien2Start,
    betrieb.ferien3Start,
  ]) {
    if (fs != null && fs.isAfter(datum)) {
```
wird:
```dart
  for (final fs in ferienStarts(betrieb)) {
    if (fs.isAfter(datum)) {
```
(Rest der Schleife unverändert.)

`_naechsteOeffnung` (Z. 166–177), aus:
```dart
  for (final fe in [
    betrieb.ferienEnde,
    betrieb.ferien2Ende,
    betrieb.ferien3Ende,
  ]) {
    if (fe != null) {
      final reopen = fe.add(const Duration(days: 1));
```
wird:
```dart
  for (final fe in ferienEnden(betrieb)) {
    final reopen = fe.add(const Duration(days: 1));
```
(Innere Bedingungen unverändert, eine Verschachtelungsebene weniger.)

`isBetriebOffen` (Z. 276–280) und `_isBetriebAktiv` (Z. 324–328) — beide Ferien-Checks, aus:
```dart
  if (b.ferienStart != null && b.ferienEnde != null) {
    if (!datum.isBefore(b.ferienStart!) && !datum.isAfter(b.ferienEnde!)) {
      return false;
    }
  }
```
wird jeweils:
```dart
  if (istInFerien(b, datum)) return false;
```
Das behebt bewusst den bestehenden Bug, dass nur Ferien 1 geprüft wurde (Ferien 2–5 zählten bisher nicht als „geschlossen").

Zusätzlich prüfen: `_wiederoeffnungNachEndreinigung` (per Suche in der Datei finden) — falls dort ebenfalls über `ferienEnde/ferien2Ende/ferien3Ende` iteriert wird, gleich auf `ferienEnden(betrieb)` umstellen.

- [ ] **Step 2: termin_repository.dart umstellen**

Import ergänzen: `import 'package:sbs_projer_app/core/util/betrieb_ferien.dart';`

Z. 251–258, aus:
```dart
      if (!betrieb.keineBetriebsferien) {
        _addFerienSoll(soll, bId, name, betrieb.ferienStart, betrieb.ferienEnde,
            skipEroeffnung);
        _addFerienSoll(soll, bId, name, betrieb.ferien2Start,
            betrieb.ferien2Ende, skipEroeffnung);
        _addFerienSoll(soll, bId, name, betrieb.ferien3Start,
            betrieb.ferien3Ende, skipEroeffnung);
      }
```
wird:
```dart
      if (!betrieb.keineBetriebsferien) {
        for (final slot in ferienSlots(betrieb)) {
          _addFerienSoll(
              soll, bId, name, slot.start, slot.ende, skipEroeffnung);
        }
      }
```

- [ ] **Step 3: heineken_raster_screen.dart umstellen**

Import ergänzen: `import 'package:sbs_projer_app/core/util/betrieb_ferien.dart';`

Z. 124–135, aus den drei einzelnen `if (b.ferienStart != null && ...)`-Blöcken wird:
```dart
        final ferien = <FerienPeriode>[];
        if (!b.keineBetriebsferien) {
          for (final slot in ferienSlots(b)) {
            if (slot.start != null && slot.ende != null) {
              ferien.add(FerienPeriode(slot.start!, slot.ende!));
            }
          }
        }
```

- [ ] **Step 4: Analyze + Tests**

Run: `export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter analyze && flutter test`
Expected: `No issues found!` und alle Tests grün.

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/presentation/providers/tour_providers.dart sbs_projer_app/lib/data/repositories/termin_repository.dart sbs_projer_app/lib/presentation/screens/heineken/heineken_raster_screen.dart
git commit -m "feat(betriebe): Ferien-Logik auf 5 Slots, Bugfix Ferien 2+ in isBetriebOffen (P1.7)"
```

---

### Task 9: Betrieb-Formular — dynamische Ferien-Zeilen (1 sichtbar, + bis 5)

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/betriebe/betrieb_form_screen.dart:60-66, 134-140, 201-207, 746-832`

- [ ] **Step 1: State auf Listen umstellen**

Zeilen 60–66, aus den Einzelfeldern (`_ferienStart` … `_ferien3Ende`, `_keineBetriebsferien`) wird:

```dart
  final List<DateTime?> _ferienStarts = List.filled(5, null);
  final List<DateTime?> _ferienEnden = List.filled(5, null);
  int _ferienZeilen = 1;
  bool _keineBetriebsferien = false;
```

- [ ] **Step 2: Laden anpassen**

Zeilen 134–140, aus den Einzel-Zuweisungen wird:

```dart
      final geladeneStarts = [
        betrieb.ferienStart, betrieb.ferien2Start, betrieb.ferien3Start,
        betrieb.ferien4Start, betrieb.ferien5Start,
      ];
      final geladeneEnden = [
        betrieb.ferienEnde, betrieb.ferien2Ende, betrieb.ferien3Ende,
        betrieb.ferien4Ende, betrieb.ferien5Ende,
      ];
      for (var i = 0; i < 5; i++) {
        _ferienStarts[i] = geladeneStarts[i];
        _ferienEnden[i] = geladeneEnden[i];
      }
      _ferienZeilen = 1;
      for (var i = 4; i >= 0; i--) {
        if (_ferienStarts[i] != null || _ferienEnden[i] != null) {
          _ferienZeilen = i + 1;
          break;
        }
      }
      _keineBetriebsferien = betrieb.keineBetriebsferien;
```

- [ ] **Step 3: Speichern anpassen**

Zeilen 201–207, aus den Einzel-Zuweisungen wird:

```dart
      betrieb.ferienStart = _keineBetriebsferien ? null : _ferienStarts[0];
      betrieb.ferienEnde = _keineBetriebsferien ? null : _ferienEnden[0];
      betrieb.ferien2Start = _keineBetriebsferien ? null : _ferienStarts[1];
      betrieb.ferien2Ende = _keineBetriebsferien ? null : _ferienEnden[1];
      betrieb.ferien3Start = _keineBetriebsferien ? null : _ferienStarts[2];
      betrieb.ferien3Ende = _keineBetriebsferien ? null : _ferienEnden[2];
      betrieb.ferien4Start = _keineBetriebsferien ? null : _ferienStarts[3];
      betrieb.ferien4Ende = _keineBetriebsferien ? null : _ferienEnden[3];
      betrieb.ferien5Start = _keineBetriebsferien ? null : _ferienStarts[4];
      betrieb.ferien5Ende = _keineBetriebsferien ? null : _ferienEnden[4];
      betrieb.keineBetriebsferien = _keineBetriebsferien;
```

- [ ] **Step 4: UI dynamisch rendern**

Zeilen 746–832 (Kommentar `=== Betriebsferien ===` bis `], // Ende if (!_keineBetriebsferien)`) ersetzen durch:

```dart
            // === Betriebsferien (bis 5 Perioden, kompakt) ===
            const SizedBox(height: 16),
            Text('Betriebsferien',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Keine Betriebsferien'),
              value: _keineBetriebsferien,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(() {
                _keineBetriebsferien = v;
                if (v) {
                  for (var i = 0; i < 5; i++) {
                    _ferienStarts[i] = null;
                    _ferienEnden[i] = null;
                  }
                  _ferienZeilen = 1;
                }
              }),
            ),
            if (!_keineBetriebsferien) ...[
              for (var i = 0; i < _ferienZeilen; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DatePickerField(
                        label: 'Ferien ${i + 1} von',
                        value: _ferienStarts[i],
                        onChanged: (v) =>
                            setState(() => _ferienStarts[i] = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DatePickerField(
                        label: 'Ferien ${i + 1} bis',
                        value: _ferienEnden[i],
                        onChanged: (v) =>
                            setState(() => _ferienEnden[i] = v),
                      ),
                    ),
                  ],
                ),
              ],
              if (_ferienZeilen < 5)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _ferienZeilen++),
                    icon: const Icon(Icons.add),
                    label: const Text('Weitere Ferien'),
                  ),
                ),
            ],
```

- [ ] **Step 5: Restliche Referenzen prüfen**

In der Datei nach `_ferienStart`, `_ferien2`, `_ferien3` suchen — alle verbliebenen Verwendungen (z. B. im SwitchListTile-Altcode) müssen entfernt/umgestellt sein.

- [ ] **Step 6: Analyze + Commit**

Run: `export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter analyze`
Expected: `No issues found!`

```bash
git add sbs_projer_app/lib/presentation/screens/betriebe/betrieb_form_screen.dart
git commit -m "feat(betriebe): Ferien-Formular kompakt, dynamisch bis 5 Perioden (P1.7)"
```

---

### Task 10: Betrieb-Detail — Ferien 1–5 anzeigen

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/betriebe/betrieb_detail_screen.dart:162-181`

- [ ] **Step 1: Anzeige auf Schleife umstellen**

Import ergänzen: `import 'package:sbs_projer_app/core/util/betrieb_ferien.dart';`

Zeilen 162–181, aus der Bedingung + den drei `_InfoRow('Ferien N', ...)`-Zeilen wird:

```dart
          // Ruhetage & Ferien (für alle Betriebe)
          if (betrieb.ruhetage.isNotEmpty ||
              ferienStarts(betrieb).isNotEmpty ||
              betrieb.keineBetriebsferien)
            _SectionCard(
              title: 'Ruhetage & Ferien',
              icon: Icons.event_busy,
              children: [
                _InfoRow(
                    'Ruhetage',
                    betrieb.ruhetage.isEmpty
                        ? 'Keine'
                        : betrieb.ruhetage.join(', ')),
                if (betrieb.keineBetriebsferien)
                  const _InfoRow('Betriebsferien', 'Keine'),
                if (!betrieb.keineBetriebsferien)
                  for (final (i, slot) in ferienSlots(betrieb).indexed)
                    if (slot.start != null)
                      _InfoRow('Ferien ${i + 1}',
                          '${_formatDate(slot.start!)} – ${slot.ende != null ? _formatDate(slot.ende!) : '?'}'),
              ],
            ),
```

(Die bestehende `_InfoRow('Ruhetage', ...)`-Zeile aus dem Original übernehmen — nur die Ferien-Zeilen ändern sich.)

- [ ] **Step 2: Analyze + Commit**

Run: `export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter analyze`
Expected: `No issues found!`

```bash
git add sbs_projer_app/lib/presentation/screens/betriebe/betrieb_detail_screen.dart
git commit -m "feat(betriebe): Detail zeigt Ferien 1-5 (P1.7)"
```

---

### Task 11: Gesamtverifikation, visueller Test, Deploy

**Files:** keine neuen Änderungen (nur Version + Doku)

- [ ] **Step 1: Voller Analyze- und Testlauf**

Run: `export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter analyze && flutter test`
Expected: `No issues found!`, alle Tests grün.

- [ ] **Step 2: Visueller Test im Browser (PFLICHT vor Deploy)**

App starten (`flutter run -d edge` bzw. Preview-Tooling) und prüfen:
1. Eigenaufträge: kein Filter-Icon mehr oben rechts, Liste unverändert
2. Störungen: Filter-Icon öffnet Sheet mit 3 Sektionen, Badge zählt, Filter wirken
3. Reinigung-Detail: Chip „Protokoll", Preis-Karte zeigt „Service-Art: Standardservice" o. ä.
4. Reinigung-Formular: Datum/Start/Ende in einer Zeile, lesbar auf schmalem Viewport (~380px testen)
5. Kontakt-Formular: Kategorie Heineken bietet Rolle „Stardrinks"
6. Betrieb-Formular: nur belegte Ferien-Zeilen + „Weitere Ferien" bis max. 5; Speichern und Wiederöffnen konsistent
7. Betrieb-Detail: Ferien 4/5 erscheinen nach Erfassung

- [ ] **Step 3: Version bumpen**

In `sbs_projer_app/pubspec.yaml` Zeile 4: Version und Build-Nummer erhöhen (z. B. `0.16.19+477` → `0.16.20+478`).

- [ ] **Step 4: Deploy gemäss CLAUDE.md**

Ablauf strikt nach CLAUDE.md-Abschnitt „Deployment": erst ALLE Änderungen auf `main` committen und pushen, dann Web-Build mit `--pwa-strategy=none`, Cache-Bust, gh-pages-Deploy, zurück auf `main`.

- [ ] **Step 5: Doku nachführen**

`ToDo.md` (P1 erledigt markieren, offene Folge-Punkte eintragen) und Projekt-Header/`Projekt.md` gemäss bestehendem Muster auf neue Version aktualisieren. Commit + Push.

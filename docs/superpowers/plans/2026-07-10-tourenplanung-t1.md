# Tourenplanung T1 (UX & Verhalten) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Die Tourenplanung wird planungsfreundlicher: leerer Tagesplan-Start, Auto-Speicherung ohne Button, sichtbare Ruhetage/Servicezeiten mit Ruhetag-Warnung, übersichtliche Inline-Filter und ein grosser Drag-Griff.

**Architecture:** Reine Anzeige-Helfer in `core/util/touren_anzeige.dart` (TDD). `TourEintrag` trägt Ruhetage + Servicezeit-Text durch. `TagesplanNotifier` bekommt entprellte Auto-Speicherung und lädt default leer. Der Screen ersetzt Speicherbutton + Filter-Sheet durch Auto-Save + Inline-Filter-Leiste und einen grossen Greif-Griff.

**Tech Stack:** Flutter, Riverpod (StateNotifier/StateProvider), Supabase (`tagesplaene`-Tabelle), `flutter_test`.

**Wichtige Fakten (verifiziert):**
- `BetriebLocal.ruhetage` ist `List<String>` mit **vollen** Wochentagsnamen (`'Montag'`, `'Dienstag'`, …, `'Sonntag'`); `isBetriebOffen` prüft `b.ruhetage.contains(wochentag)` mit vollem Namen (tour_providers.dart:292-297). `'keine'` bzw. leere Liste = keine Ruhetage.
- Servicezeit-Felder: `servicezeitMorgenAb/Bis`, `servicezeitNachmittagAb/Bis` (alle `String?`, Format „HH:MM").
- `selectedFaelligkeitProvider` default `{}` (= alles zeigen); `selectedRegionenProvider` default `{}`.
- `faelligkeitLabel(status)` / `faelligkeitFarbe(status)` sind bereits **öffentlich** in tour_providers.dart.
- `TourEintrag`-JSON-Roundtrip: `_tourEintragToJson` / `_tourEintragFromJson` (tour_providers.dart:729-751).
- Keine DB-Migration. Deploy als **v0.29.0**.

**Umgebung/Befehle:**
```bash
export PATH="$PATH:/c/flutter/bin"
cd "D:/01_SBS_Projer_GmbH/00_Entwicklung/SBS Projer DEV/sbs_projer_app"
```
Tests: `flutter test test/touren_anzeige_test.dart`
Analyse: `flutter analyze`

---

## File Structure

- **Neu:** `sbs_projer_app/lib/core/util/touren_anzeige.dart` — reine Helfer `istRuhetag`, `servicezeitText`, `ruhetageText`.
- **Neu:** `sbs_projer_app/test/touren_anzeige_test.dart` — Unit-Tests dazu.
- **Ändern:** `sbs_projer_app/lib/presentation/providers/tour_providers.dart` — `TourEintrag` + Felder, Populate an Build-Sites, JSON-Roundtrip, `TagesplanNotifier` (Auto-Save + default-leer), Default-Fälligkeitsfilter.
- **Ändern:** `sbs_projer_app/lib/presentation/screens/touren/tourenplanung_screen.dart` — Lade-Logik (leer), Header ohne Speicherbutton, Fällige-übernehmen gefiltert, Inline-Filter-Leiste, Karten-Anzeige (Ruhetage/Servicezeit + Warnung), grosser Drag-Griff.
- **Ändern:** `sbs_projer_app/pubspec.yaml` — Version-Bump.

---

## Task 1: Anzeige-Helfer `touren_anzeige.dart` (TDD)

**Files:**
- Create: `sbs_projer_app/lib/core/util/touren_anzeige.dart`
- Test: `sbs_projer_app/test/touren_anzeige_test.dart`

- [ ] **Step 1: Failing-Test schreiben**

Create `sbs_projer_app/test/touren_anzeige_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/touren_anzeige.dart';

void main() {
  group('istRuhetag', () {
    // 2026-07-06 ist ein Montag, 2026-07-11 ein Samstag, 2026-07-12 Sonntag
    test('Montag als Ruhetag → true an einem Montag', () {
      expect(istRuhetag(['Montag'], DateTime(2026, 7, 6)), isTrue);
    });
    test('Montag als Ruhetag → false an einem Dienstag', () {
      expect(istRuhetag(['Montag'], DateTime(2026, 7, 7)), isFalse);
    });
    test('mehrere Ruhetage', () {
      expect(istRuhetag(['Montag', 'Samstag'], DateTime(2026, 7, 11)), isTrue);
    });
    test('Sonntag', () {
      expect(istRuhetag(['Sonntag'], DateTime(2026, 7, 12)), isTrue);
    });
    test('leere Liste → false', () {
      expect(istRuhetag([], DateTime(2026, 7, 6)), isFalse);
    });
    test("['keine'] → false", () {
      expect(istRuhetag(['keine'], DateTime(2026, 7, 6)), isFalse);
    });
  });

  group('ruhetageText', () {
    test('kürzt volle Namen', () {
      expect(ruhetageText(['Montag', 'Dienstag']), 'Mo, Di');
    });
    test('Sonntag', () {
      expect(ruhetageText(['Sonntag']), 'So');
    });
    test('leer → leerer String', () {
      expect(ruhetageText([]), '');
    });
    test("['keine'] → leerer String", () {
      expect(ruhetageText(['keine']), '');
    });
  });

  group('servicezeitText', () {
    test('beide Blöcke', () {
      expect(servicezeitText('08:00', '12:00', '13:30', '17:00'),
          '08:00–12:00 · 13:30–17:00');
    });
    test('nur Morgen', () {
      expect(servicezeitText('08:00', '12:00', null, null), '08:00–12:00');
    });
    test('nur Nachmittag', () {
      expect(servicezeitText(null, null, '13:30', '17:00'), '13:30–17:00');
    });
    test('leere Strings zählen als nicht gesetzt', () {
      expect(servicezeitText('', '', '', ''), '');
    });
    test('alles null → leerer String', () {
      expect(servicezeitText(null, null, null, null), '');
    });
    test('halber Block (nur Ab) → ignoriert', () {
      expect(servicezeitText('08:00', null, null, null), '');
    });
  });
}
```

- [ ] **Step 2: Test ausführen (muss fehlschlagen)**

Run: `flutter test test/touren_anzeige_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'touren_anzeige.dart'` / „not found".

- [ ] **Step 3: Implementierung schreiben**

Create `sbs_projer_app/lib/core/util/touren_anzeige.dart`:

```dart
/// Reine Anzeige-Helfer für die Tourenplanung (ohne Flutter-Abhängigkeiten).
///
/// Ruhetage werden am Betrieb als volle Wochentagsnamen gespeichert
/// (`'Montag'` … `'Sonntag'`), passend zu `isBetriebOffen` in tour_providers.

const List<String> _wochentageVoll = [
  'Montag',
  'Dienstag',
  'Mittwoch',
  'Donnerstag',
  'Freitag',
  'Samstag',
  'Sonntag',
];

const Map<String, String> _kurzform = {
  'Montag': 'Mo',
  'Dienstag': 'Di',
  'Mittwoch': 'Mi',
  'Donnerstag': 'Do',
  'Freitag': 'Fr',
  'Samstag': 'Sa',
  'Sonntag': 'So',
};

/// Ist [tag] ein Ruhetag laut [ruhetage] (volle Wochentagsnamen)?
bool istRuhetag(List<String> ruhetage, DateTime tag) {
  if (ruhetage.isEmpty) return false;
  final name = _wochentageVoll[tag.weekday - 1];
  return ruhetage.contains(name);
}

/// Kompakte Ruhetags-Anzeige, z.B. `Mo, Di`. Leer bei keinen/`'keine'`.
String ruhetageText(List<String> ruhetage) {
  final teile = <String>[];
  for (final r in ruhetage) {
    final k = _kurzform[r];
    if (k != null) teile.add(k);
  }
  return teile.join(', ');
}

bool _hat(String? s) => s != null && s.isNotEmpty;

/// Servicezeit-Anzeige, z.B. `08:00–12:00 · 13:30–17:00`.
/// Ein Block zählt nur, wenn Ab **und** Bis gesetzt sind. Leer wenn nichts.
String servicezeitText(
  String? morgenAb,
  String? morgenBis,
  String? nachmittagAb,
  String? nachmittagBis,
) {
  final bloecke = <String>[];
  if (_hat(morgenAb) && _hat(morgenBis)) {
    bloecke.add('$morgenAb–$morgenBis');
  }
  if (_hat(nachmittagAb) && _hat(nachmittagBis)) {
    bloecke.add('$nachmittagAb–$nachmittagBis');
  }
  return bloecke.join(' · ');
}
```

- [ ] **Step 4: Test ausführen (muss bestehen)**

Run: `flutter test test/touren_anzeige_test.dart`
Expected: PASS (alle Tests grün).

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/core/util/touren_anzeige.dart sbs_projer_app/test/touren_anzeige_test.dart
git commit -m "feat(touren): Anzeige-Helfer istRuhetag/ruhetageText/servicezeitText (TDD)"
```

---

## Task 2: `TourEintrag` um Ruhetage + Servicezeit erweitern

**Files:**
- Modify: `sbs_projer_app/lib/presentation/providers/tour_providers.dart`

- [ ] **Step 1: Import ergänzen**

Oben bei den Imports (nach `betrieb_ferien.dart`) einfügen:

```dart
import 'package:sbs_projer_app/core/util/touren_anzeige.dart';
```

- [ ] **Step 2: Felder + optionale Konstruktor-Parameter**

In `class TourEintrag` (tour_providers.dart:423-447) die zwei Felder ergänzen und den Konstruktor um optionale Parameter erweitern. Ersetze den Block:

```dart
  final FaelligkeitsStatus? faelligkeit;
  final DateTime? datum;

  const TourEintrag({
    required this.typ,
    required this.id,
    this.betriebId,
    this.anlageId,
    required this.betriebName,
    this.betriebOrt,
    this.regionId,
    required this.beschreibung,
    this.faelligkeit,
    this.datum,
  });
```

durch:

```dart
  final FaelligkeitsStatus? faelligkeit;
  final DateTime? datum;
  final List<String> ruhetage;
  final String? servicezeit;

  const TourEintrag({
    required this.typ,
    required this.id,
    this.betriebId,
    this.anlageId,
    required this.betriebName,
    this.betriebOrt,
    this.regionId,
    required this.beschreibung,
    this.faelligkeit,
    this.datum,
    this.ruhetage = const [],
    this.servicezeit,
  });
```

- [ ] **Step 3: Betrieb-Helfer für Servicezeit ergänzen**

Direkt nach `Map<String, BetriebLocal> _buildBetriebMap(...)` (tour_providers.dart:457-464) einfügen:

```dart
String? _servicezeitAus(BetriebLocal? b) {
  if (b == null) return null;
  final t = servicezeitText(
    b.servicezeitMorgenAb,
    b.servicezeitMorgenBis,
    b.servicezeitNachmittagAb,
    b.servicezeitNachmittagBis,
  );
  return t.isEmpty ? null : t;
}
```

- [ ] **Step 4: Populate an allen 5 Build-Sites**

In `faelligeEintraegeProvider` und `tourVorschlagErweitertProvider` bei **jedem** `TourEintrag(...)`-Aufruf (Reinigung, Störung, Montage — 5 Stellen gesamt) jeweils direkt vor der schliessenden `));` diese zwei Zeilen ergänzen:

```dart
      ruhetage: betrieb?.ruhetage ?? const [],
      servicezeit: _servicezeitAus(betrieb),
```

Konkret betrifft das die Aufrufe an (Original-Zeilen): 482 (Reinigung), 504 (Störung), 524 (Montage) in `faelligeEintraegeProvider`; 597 (Reinigung), 625 (Störung), 649 (Montage) in `tourVorschlagErweitertProvider`. In allen Fällen heisst die lokale Betriebs-Variable `betrieb`.

- [ ] **Step 5: JSON-Roundtrip erweitern**

`_tourEintragToJson` (tour_providers.dart:729-738) ersetzen durch:

```dart
Map<String, dynamic> _tourEintragToJson(TourEintrag e) => {
      'typ': e.typ.name,
      'id': e.id,
      'betriebId': e.betriebId,
      'anlageId': e.anlageId,
      'betriebName': e.betriebName,
      'betriebOrt': e.betriebOrt,
      'regionId': e.regionId,
      'beschreibung': e.beschreibung,
      'ruhetage': e.ruhetage,
      'servicezeit': e.servicezeit,
    };
```

`_tourEintragFromJson` (tour_providers.dart:740-751) ersetzen durch:

```dart
TourEintrag _tourEintragFromJson(Map<String, dynamic> j) => TourEintrag(
      typ: TourEintragTyp.values.firstWhere(
          (t) => t.name == j['typ'],
          orElse: () => TourEintragTyp.reinigung),
      id: j['id'] as String,
      betriebId: j['betriebId'] as String?,
      anlageId: j['anlageId'] as String?,
      betriebName: j['betriebName'] as String? ?? '',
      betriebOrt: j['betriebOrt'] as String?,
      regionId: j['regionId'] as String?,
      beschreibung: j['beschreibung'] as String? ?? '',
      ruhetage: (j['ruhetage'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      servicezeit: j['servicezeit'] as String?,
    );
```

- [ ] **Step 6: Analyse**

Run: `flutter analyze lib/presentation/providers/tour_providers.dart`
Expected: Keine neuen Fehler (evtl. bestehende Infos/Warnings unverändert).

- [ ] **Step 7: Commit**

```bash
git add sbs_projer_app/lib/presentation/providers/tour_providers.dart
git commit -m "feat(touren): TourEintrag traegt Ruhetage + Servicezeit durch"
```

---

## Task 3: `TagesplanNotifier` — Auto-Speicherung + default leer

**Files:**
- Modify: `sbs_projer_app/lib/presentation/providers/tour_providers.dart`

- [ ] **Step 1: `dart:async` importieren**

Ganz oben als erste Import-Zeile ergänzen:

```dart
import 'dart:async';
```

- [ ] **Step 2: Provider mit `ref` bauen**

`tagesplanProvider` (tour_providers.dart:669-672) ersetzen durch:

```dart
final tagesplanProvider =
    StateNotifierProvider<TagesplanNotifier, List<TourEintrag>>((ref) {
  return TagesplanNotifier(ref);
});
```

- [ ] **Step 3: Notifier neu schreiben (Auto-Save, default-leer)**

Die gesamte `class TagesplanNotifier { ... }` (tour_providers.dart:674-725) ersetzen durch:

```dart
class TagesplanNotifier extends StateNotifier<List<TourEintrag>> {
  TagesplanNotifier(this._ref) : super([]);

  final Ref _ref;
  Timer? _saveTimer;

  /// Speichert den aktuellen Stand entprellt für den aktiven Tag.
  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), () {
      final tag = _ref.read(aktiverTagesplanTagProvider);
      if (tag == null) return;
      tagesplanSpeichern(tag, state);
    });
  }

  void _cancelSave() {
    _saveTimer?.cancel();
    _saveTimer = null;
  }

  /// Gespeicherten Plan laden — löst KEINE Speicherung aus.
  void setFromGespeichert(List<TourEintrag> eintraege) {
    _cancelSave();
    state = List.of(eintraege);
  }

  /// Tag ohne gespeicherten Plan → leer starten (KEINE Speicherung).
  void resetLeer() {
    _cancelSave();
    state = [];
  }

  void hinzufuegen(TourEintrag eintrag) {
    if (state.any((e) => e.id == eintrag.id)) return;
    state = [...state, eintrag];
    _scheduleSave();
  }

  void entfernen(String id) {
    state = state.where((e) => e.id != id).toList();
    _scheduleSave();
  }

  /// User-Aktion „Leeren" → persistiert den leeren Plan.
  void leeren() {
    state = [];
    _scheduleSave();
  }

  void reorder(int oldIndex, int newIndex) {
    final items = List.of(state);
    if (newIndex > oldIndex) newIndex--;
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    state = items;
    _scheduleSave();
  }

  void befuellenAusFaellig(List<TourEintrag> faellige) {
    final existing = state.map((e) => e.id).toSet();
    final neue = faellige.where((e) => !existing.contains(e.id)).toList();
    if (neue.isEmpty) return;
    state = [...state, ...neue];
    _scheduleSave();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
```

Damit entfallen `setFromVorschlag`, `markGespeichert`, `_gespeichert`/`gespeichert`. Der Screen wird in Task 4 entsprechend angepasst.

- [ ] **Step 4: Analyse (Screen-Fehler sind hier erwartet)**

Run: `flutter analyze lib/presentation/providers/tour_providers.dart`
Expected: Diese Datei ist sauber. (Der Screen referenziert noch `gespeichert`/`setFromVorschlag`/`markGespeichert` — das wird in Task 4 behoben; separat analysieren.)

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/presentation/providers/tour_providers.dart
git commit -m "feat(touren): TagesplanNotifier auto-speichert entprellt, startet leer"
```

---

## Task 4: Screen — leer laden, Auto-Save-Wiring, Default-Filter, Fällige gefiltert

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/touren/tourenplanung_screen.dart`
- Modify: `sbs_projer_app/lib/presentation/providers/tour_providers.dart` (Default-Filter)

- [ ] **Step 1: Default-Fälligkeitsfilter setzen**

In `tour_providers.dart` `selectedFaelligkeitProvider` (Zeile 452-453) ersetzen durch:

```dart
final selectedFaelligkeitProvider =
    StateProvider<Set<FaelligkeitsStatus>>((ref) => {
      FaelligkeitsStatus.ueberfaellig,
      FaelligkeitsStatus.faellig,
    });
```

- [ ] **Step 2: Lade-Logik auf „default leer" umstellen**

In `tourenplanung_screen.dart` den Block (Zeile 76-108) ersetzen durch:

```dart
    if (_loadedForDate != _selectedDate) {
      gespeichertAsync.when(
        data: (gespeichert) {
          if (_loadedForDate != _selectedDate) {
            _loadedForDate = _selectedDate;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              if (gespeichert != null) {
                ref
                    .read(tagesplanProvider.notifier)
                    .setFromGespeichert(gespeichert);
              } else {
                ref.read(tagesplanProvider.notifier).resetLeer();
              }
            });
          }
        },
        loading: () {},
        error: (_, _) {
          _loadedForDate = _selectedDate;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ref.read(tagesplanProvider.notifier).resetLeer();
          });
        },
      );
    }
```

- [ ] **Step 3: `_TagesplanHeader`-Aufruf ohne Speicherbutton**

Den `_TagesplanHeader(...)`-Aufruf (Zeile 226-260) ersetzen durch:

```dart
                    _TagesplanHeader(
                      datum: _selectedDate,
                      onLeeren: () =>
                          ref.read(tagesplanProvider.notifier).leeren(),
                      onAusFaelligBefuellen: () {
                        ref
                            .read(tagesplanProvider.notifier)
                            .befuellenAusFaellig(angezeigtFaellig);
                      },
                    ),
```

(`angezeigtFaellig` ist die gefilterte Liste aus Zeile 131 — so werden nur die aktuell angezeigten überfällig/fälligen übernommen.)

- [ ] **Step 4: `_TagesplanHeader`-Widget verschlanken**

Die `class _TagesplanHeader` (Zeile 704-774) ersetzen durch:

```dart
class _TagesplanHeader extends StatelessWidget {
  final DateTime datum;
  final VoidCallback onLeeren;
  final VoidCallback onAusFaelligBefuellen;

  const _TagesplanHeader({
    required this.datum,
    required this.onLeeren,
    required this.onAusFaelligBefuellen,
  });

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('EE, d. MMM', 'de_CH');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 2),
      child: Row(
        children: [
          Text(
            df.format(datum),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: onAusFaelligBefuellen,
            icon: const Icon(Icons.playlist_add, size: 18),
            label: const Text('Fällige übernehmen',
                style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
          TextButton.icon(
            onPressed: onLeeren,
            icon: const Icon(Icons.clear_all, size: 18),
            label: const Text('Leeren', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: AppColors.error,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Analyse**

Run: `flutter analyze lib/presentation/screens/touren/tourenplanung_screen.dart`
Expected: Es verbleiben nur noch Fehler zu `_showFilterPicker` (falls schon entfernt) — diese werden in Task 5 aufgelöst. Keine Fehler mehr zu `gespeichert`, `setFromVorschlag`, `markGespeichert`, `onSpeichern`, `istGespeichert`.

- [ ] **Step 6: Commit**

```bash
git add sbs_projer_app/lib/presentation/providers/tour_providers.dart sbs_projer_app/lib/presentation/screens/touren/tourenplanung_screen.dart
git commit -m "feat(touren): Plan startet leer, Auto-Save, Fällige-übernehmen gefiltert, Default-Filter ueberfaellig+faellig"
```

---

## Task 5: Inline-Filter-Leiste statt Bottom-Sheet

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/touren/tourenplanung_screen.dart`

- [ ] **Step 1: AppBar-Filter-Button entfernen**

Die `AppBar` (Zeile 136-172) ersetzen durch:

```dart
      appBar: AppBar(
        title: const Text('Tourenplanung'),
      ),
```

- [ ] **Step 2: Alte Filter-Chips-Leiste durch Inline-Leiste ersetzen**

Den Block (Zeile 202-216, der bedingte `_FilterChips`) ersetzen durch:

```dart
          // Inline-Filter (Region + Fälligkeit, immer sichtbar)
          _InlineFilterLeiste(
            regionen: regionen,
            selectedRegionen: selectedRegionen,
            selectedFaelligkeit: selectedFaelligkeit,
            onRegionenChanged: (updated) {
              ref.read(selectedRegionenProvider.notifier).state = updated;
            },
            onFaelligkeitChanged: (updated) {
              ref.read(selectedFaelligkeitProvider.notifier).state = updated;
            },
          ),
```

- [ ] **Step 3: `_showFilterPicker` + `_faelligkeitsOptionen` + `_FaelligkeitsOption` + `_FilterChips` entfernen**

Löschen:
- Die Methode `_showFilterPicker(...)` komplett (Zeile 366-514).
- Die statische Liste `static const _faelligkeitsOptionen = [...]` (Zeile 516-542).
- Die `class _FaelligkeitsOption { ... }` (Zeile 1140-1150).
- Die `class _FilterChips extends StatelessWidget { ... }` (Zeile 1154-1261).

- [ ] **Step 4: `_InlineFilterLeiste` neu anlegen**

Am Dateiende (nach der letzten Klasse) einfügen:

```dart
// ─── Inline-Filter-Leiste (Region + Fälligkeit getrennt) ───

class _InlineFilterLeiste extends StatelessWidget {
  final List<dynamic> regionen;
  final Set<String> selectedRegionen;
  final Set<FaelligkeitsStatus> selectedFaelligkeit;
  final void Function(Set<String>) onRegionenChanged;
  final void Function(Set<FaelligkeitsStatus>) onFaelligkeitChanged;

  const _InlineFilterLeiste({
    required this.regionen,
    required this.selectedRegionen,
    required this.selectedFaelligkeit,
    required this.onRegionenChanged,
    required this.onFaelligkeitChanged,
  });

  static const _faelligStatuses = [
    FaelligkeitsStatus.ueberfaellig,
    FaelligkeitsStatus.faellig,
    FaelligkeitsStatus.baldFaellig,
    FaelligkeitsStatus.endreinigungFaellig,
    FaelligkeitsStatus.eroeffnungFaellig,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fälligkeit
          _filterZeile(
            label: 'Fälligkeit',
            child: Row(
              children: _faelligStatuses.map((s) {
                final selected = selectedFaelligkeit.contains(s);
                final color = faelligkeitFarbe(s);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(faelligkeitLabel(s),
                        style: TextStyle(
                            fontSize: 11,
                            color: selected ? color : AppColors.textSecondary,
                            fontWeight: FontWeight.w600)),
                    selected: selected,
                    showCheckmark: false,
                    backgroundColor: AppColors.surface,
                    selectedColor: color.withAlpha(25),
                    side: BorderSide(
                        color: selected
                            ? color.withAlpha(120)
                            : AppColors.textSecondary.withAlpha(50)),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onSelected: (v) {
                      final updated =
                          Set<FaelligkeitsStatus>.from(selectedFaelligkeit);
                      if (v) {
                        updated.add(s);
                      } else {
                        updated.remove(s);
                      }
                      onFaelligkeitChanged(updated);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          if (regionen.isNotEmpty) const SizedBox(height: 4),
          // Region
          if (regionen.isNotEmpty)
            _filterZeile(
              label: 'Region',
              child: Row(
                children: regionen.map((r) {
                  final id = r.routeId as String;
                  final selected = selectedRegionen.contains(id);
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(r.name as String,
                          style: TextStyle(
                              fontSize: 11,
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w600)),
                      selected: selected,
                      showCheckmark: false,
                      backgroundColor: AppColors.surface,
                      selectedColor: AppColors.primary.withAlpha(25),
                      side: BorderSide(
                          color: selected
                              ? AppColors.primary.withAlpha(120)
                              : AppColors.textSecondary.withAlpha(50)),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onSelected: (v) {
                        final updated = Set<String>.from(selectedRegionen);
                        if (v) {
                          updated.add(id);
                        } else {
                          updated.remove(id);
                        }
                        onRegionenChanged(updated);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterZeile({required String label, required Widget child}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, right: 8),
          child: SizedBox(
            width: 62,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(right: 12),
            child: child,
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Analyse**

Run: `flutter analyze lib/presentation/screens/touren/tourenplanung_screen.dart`
Expected: Keine Fehler. (Falls „unused" zu entfernten Symbolen: sicherstellen, dass alle vier gelöschten Blöcke weg sind.)

- [ ] **Step 6: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/touren/tourenplanung_screen.dart
git commit -m "feat(touren): Inline-Filter-Leiste Region+Faelligkeit statt Bottom-Sheet"
```

---

## Task 6: Karten — Ruhetage/Servicezeit + Ruhetag-Warnung

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/touren/tourenplanung_screen.dart`

- [ ] **Step 1: Import des Anzeige-Helfers**

Bei den Imports (nach `tour_providers.dart`) ergänzen:

```dart
import 'package:sbs_projer_app/core/util/touren_anzeige.dart';
```

- [ ] **Step 2: Aktives Datum an die Listen/Karten durchreichen**

`_TagesplanListe(...)`-Aufruf (Zeile 267-276) um `datum: _selectedDate` erweitern:

```dart
                          : _TagesplanListe(
                              datum: _selectedDate,
                              eintraege: angezeigtTagesplan,
                              onReorder: (old, neu) => ref
                                  .read(tagesplanProvider.notifier)
                                  .reorder(old, neu),
                              onDismiss: (id) => ref
                                  .read(tagesplanProvider.notifier)
                                  .entfernen(id),
                              onTap: _navigateToDetail,
                            ),
```

`_FaelligEintragKarte(...)`-Aufruf (Zeile 293-302) um `datum: _selectedDate` erweitern:

```dart
                          return _FaelligEintragKarte(
                            datum: _selectedDate,
                            eintrag: e,
                            imPlan: imPlan,
                            onAdd: () {
                              ref
                                  .read(tagesplanProvider.notifier)
                                  .hinzufuegen(e);
                            },
                            onTap: () => _navigateToDetail(e),
                          );
```

- [ ] **Step 3: `_TagesplanListe` reicht `datum` an die Karte**

`class _TagesplanListe` (Zeile 778-826): Feld + Konstruktor + Karten-Aufruf ergänzen. Ersetze den Kopf:

```dart
class _TagesplanListe extends StatelessWidget {
  final List<TourEintrag> eintraege;
  final void Function(int, int) onReorder;
  final void Function(String) onDismiss;
  final void Function(TourEintrag) onTap;

  const _TagesplanListe({
    required this.eintraege,
    required this.onReorder,
    required this.onDismiss,
    required this.onTap,
  });
```

durch:

```dart
class _TagesplanListe extends StatelessWidget {
  final DateTime datum;
  final List<TourEintrag> eintraege;
  final void Function(int, int) onReorder;
  final void Function(String) onDismiss;
  final void Function(TourEintrag) onTap;

  const _TagesplanListe({
    required this.datum,
    required this.eintraege,
    required this.onReorder,
    required this.onDismiss,
    required this.onTap,
  });
```

Und im `itemBuilder` den `_TourEintragKarte(...)`-Aufruf (Zeile 817-821) ersetzen durch:

```dart
          child: _TourEintragKarte(
            datum: datum,
            eintrag: eintrag,
            position: index + 1,
            onTap: () => onTap(eintrag),
          ),
```

- [ ] **Step 4: `_TourEintragKarte` — Feld + Info-Zeile**

`class _TourEintragKarte` Kopf (Zeile 830-839) ersetzen durch:

```dart
class _TourEintragKarte extends StatelessWidget {
  final DateTime datum;
  final TourEintrag eintrag;
  final int position;
  final VoidCallback onTap;

  const _TourEintragKarte({
    required this.datum,
    required this.eintrag,
    required this.position,
    required this.onTap,
  });
```

In der inneren Text-`Column` (die `crossAxisAlignment: CrossAxisAlignment.start` bei Zeile 884) nach der zweiten `Row` (die mit `_StatusBadge`, endet Zeile 924) — also direkt vor dem schliessenden `],` der Column (Zeile 925) — die Info-Zeile einfügen:

```dart
                            _TourInfoZeile(datum: datum, eintrag: eintrag),
```

- [ ] **Step 5: `_FaelligEintragKarte` — Feld + Info-Zeile**

`class _FaelligEintragKarte` Kopf (Zeile 1034-1045) ersetzen durch:

```dart
class _FaelligEintragKarte extends StatelessWidget {
  final DateTime datum;
  final TourEintrag eintrag;
  final bool imPlan;
  final VoidCallback onAdd;
  final VoidCallback onTap;

  const _FaelligEintragKarte({
    required this.datum,
    required this.eintrag,
    required this.imPlan,
    required this.onAdd,
    required this.onTap,
  });
```

In dessen innerer Text-`Column` nach dem `Text(eintrag.beschreibung, ...)` (endet Zeile 1105) — direkt vor dem schliessenden `],` der Column (Zeile 1106) — einfügen:

```dart
                            _TourInfoZeile(datum: datum, eintrag: eintrag),
```

- [ ] **Step 6: `_TourInfoZeile`-Widget anlegen**

Vor `class _StatusBadge` (Zeile 978) einfügen:

```dart
// ─── Info-Zeile: Ruhetage / Servicezeiten / Ruhetag-Warnung ───

class _TourInfoZeile extends StatelessWidget {
  final DateTime datum;
  final TourEintrag eintrag;

  const _TourInfoZeile({required this.datum, required this.eintrag});

  @override
  Widget build(BuildContext context) {
    final heuteRuhetag = istRuhetag(eintrag.ruhetage, datum);
    final ruheTxt = ruhetageText(eintrag.ruhetage);
    final zeitTxt = eintrag.servicezeit;

    // Nichts anzuzeigen
    if (!heuteRuhetag && ruheTxt.isEmpty && (zeitTxt == null)) {
      return const SizedBox.shrink();
    }

    final children = <Widget>[];

    if (heuteRuhetag) {
      children.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.block, size: 13, color: AppColors.error),
          SizedBox(width: 3),
          Text('Heute Ruhetag',
              style: TextStyle(
                  fontSize: 11,
                  color: AppColors.error,
                  fontWeight: FontWeight.w700)),
        ],
      ));
    } else if (ruheTxt.isNotEmpty) {
      children.add(_infoChip(Icons.event_busy, 'Ruhetag: $ruheTxt'));
    }

    if (zeitTxt != null) {
      children.add(_infoChip(Icons.schedule, zeitTxt));
    }

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Wrap(
        spacing: 10,
        runSpacing: 2,
        children: children,
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textSecondary),
        const SizedBox(width: 3),
        Text(text,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}
```

- [ ] **Step 7: Analyse**

Run: `flutter analyze lib/presentation/screens/touren/tourenplanung_screen.dart`
Expected: Keine Fehler.

- [ ] **Step 8: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/touren/tourenplanung_screen.dart
git commit -m "feat(touren): Ruhetage/Servicezeiten + Ruhetag-Warnung auf Tour-Karten"
```

---

## Task 7: Grosser Drag-Griff

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/touren/tourenplanung_screen.dart`

- [ ] **Step 1: Default-Drag-Handles abschalten**

In `_TagesplanListe.build` den `ReorderableListView.builder(...)` (Zeile 793) um `buildDefaultDragHandles: false` ergänzen — direkt nach `padding: ...`:

```dart
    return ReorderableListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      buildDefaultDragHandles: false,
      itemCount: eintraege.length,
      onReorder: onReorder,
```

- [ ] **Step 2: Kleinen Handle durch grossen Greif-Griff ersetzen**

In `_TourEintragKarte.build` den Block (Zeile 928-937):

```dart
                      const SizedBox(width: 4),
                      // Drag Handle
                      ReorderableDragStartListener(
                        index: position - 1,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.drag_handle,
                              color: AppColors.textSecondary, size: 20),
                        ),
                      ),
```

ersetzen durch:

```dart
                      const SizedBox(width: 4),
                      // Grosser Greif-Griff (leicht zu treffen)
                      ReorderableDragStartListener(
                        index: position - 1,
                        child: Container(
                          width: 48,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.textSecondary.withAlpha(15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.drag_indicator,
                              color: AppColors.textSecondary, size: 28),
                        ),
                      ),
```

- [ ] **Step 3: Analyse**

Run: `flutter analyze lib/presentation/screens/touren/tourenplanung_screen.dart`
Expected: Keine Fehler.

- [ ] **Step 4: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/touren/tourenplanung_screen.dart
git commit -m "feat(touren): grosser Drag-Griff, Default-Handles aus"
```

---

## Task 8: Gesamtverifikation, visueller Test, Deploy v0.29.0

**Files:**
- Modify: `sbs_projer_app/pubspec.yaml`

- [ ] **Step 1: Volle Analyse + Tests**

Run:
```bash
flutter analyze
flutter test test/touren_anzeige_test.dart
```
Expected: analyze ohne neue Fehler; Tests grün.

- [ ] **Step 2: Visueller Browser-Test (Pflicht — siehe Memory „UI vor Deploy testen")**

Preview starten, `/touren` öffnen und prüfen:
- Neuer/leerer Tag → **Tagesplan leer** (Empty-State).
- **Fällig** zeigt default nur überfällig+fällig; andere Kategorien erst nach Aktivieren im Fälligkeits-Filter.
- **„Fällige übernehmen"** füllt den Plan mit den angezeigten Einträgen.
- Änderung (Hinzufügen/Entfernen/Reorder) → nach **Reload** noch da (Auto-Save), **kein** Speicherbutton.
- **Ruhetage/Servicezeiten** je Karte sichtbar; an einem Ruhetag rote **„Heute Ruhetag"**-Warnung.
- **Inline-Filter** (Region + Fälligkeit) wirken sofort.
- **Verschieben** über den grossen Griff flüssig; Tap auf die Karte öffnet weiterhin das Detail.

Konsole/Netzwerk auf Fehler prüfen (`preview_console_logs`, `preview_network` failed).

- [ ] **Step 3: Version bumpen**

In `pubspec.yaml` Zeile 4 `version:` auf `0.29.0+<neueBuildnr>` erhöhen (Build-Teil +1 ggü. aktuellem Stand).

- [ ] **Step 4: Deploy nach CLAUDE.md-Workflow**

Build + Cache-Bust + gh-pages, dann main pushen:
```bash
cd sbs_projer_app && export MSYS_NO_PATHCONV=1 \
  && flutter build web --base-href "/sbs-projer-dev/" --pwa-strategy=none
cd .. && VER=$(grep -o '"version":"[^"]*"' sbs_projer_app/build/web/version.json | cut -d'"' -f4) \
  && sed -i "s/\"mainJsPath\":\"main.dart.js\"/\"mainJsPath\":\"main.dart.js?v=$VER\"/g" \
       sbs_projer_app/build/web/flutter_bootstrap.js \
  && rm -f sbs_projer_app/build/web/flutter_service_worker.js
git add sbs_projer_app/pubspec.yaml && git commit -m "chore: Version 0.29.0 (Tourenplanung T1)"
git checkout gh-pages
rm -rf assets canvaskit icons main.dart.js* flutter*.js index.html manifest.json favicon.png version.json docs
cp -r sbs_projer_app/build/web/* .
touch .nojekyll
git add index.html main.dart.js* flutter*.js manifest.json favicon.png version.json .nojekyll assets/ canvaskit/ icons/
git commit -m "deploy v0.29.0 — Tourenplanung T1 (UX & Verhalten)"
git push origin gh-pages
git checkout main
git push origin main
```

- [ ] **Step 5: ToDo aktualisieren**

In `ToDo.md` den Paket-06-Punkt „Tourenplanung" auf T1 erledigt / T2 offen setzen.

```bash
git add ToDo.md && git commit -m "docs: ToDo — Tourenplanung T1 erledigt, T2 offen"
git push origin main
```

---

## Self-Review

**1. Spec coverage:**
- A default leer + „Fällige übernehmen" → Task 4 (resetLeer im Load, Header-Button auf `angezeigtFaellig`), Default-Filter überfällig+fällig → Task 4 Step 1. ✅
- B Auto-Speicherung → Task 3 (entprellt) + Task 4 (Speicherbutton entfernt). ✅
- C Ruhetage/Servicezeiten + Warnung → Task 1 (Helfer), Task 2 (Durchreichen), Task 6 (Anzeige). ✅
- D Inline-Filter → Task 5. ✅
- E grosser Drag-Griff → Task 7. ✅
- Keine Migration, Deploy v0.29.0 → Task 8. ✅

**2. Placeholder scan:** Keine TBD/TODO/„handle edge cases"; alle Code-Schritte vollständig. ✅

**3. Type consistency:** Feldname `servicezeit` (nicht `servicezeitText`, um Kollision mit der Helfer-Funktion `servicezeitText()` zu vermeiden) durchgehend in TourEintrag, JSON-Roundtrip, `_TourInfoZeile`. `resetLeer`/`setFromGespeichert`/`befuellenAusFaellig`/`leeren` konsistent zwischen Notifier (Task 3) und Screen (Task 4/6). `datum`-Parameter konsistent durch `_TagesplanListe` → `_TourEintragKarte`, `_FaelligEintragKarte`, `_TourInfoZeile`. Default-Filter-Set nutzt existierende Enum-Werte. ✅

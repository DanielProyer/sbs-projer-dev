# Einsatzplanung Etappe 1 — Planung und Zeiterfassung

> **Für agentische Ausführung:** ERFORDERLICHE SUB-SKILL: `superpowers:subagent-driven-development`. Schritte als Checkboxen.

**Ziel:** Störungen und Montagen lassen sich auf einen Tag und eine Uhrzeit planen, erscheinen nur dort, und ihre tatsächliche Arbeitszeit wird erfasst.

**Warum zuerst:** Das behebt Daniels Kritik («die Planung gefällt mir noch nicht») vollständig — ohne Sprache, ohne Kalender. Beides baut darauf auf.

**Spec:** `docs/superpowers/specs/2026-07-31-einsatzplanung-sprache-design.md`

**Ausgangslage:** 887 Tests grün, analyze Baseline 54. Arbeiten auf `main`. Version zuletzt 0.66.0+645.

---

## Task 1: Migration 163 — Plan- und Arbeitszeitfelder

**Files:** Create `Datenbank/migrations/163_einsatz_planung.sql`

- [ ] **Schritt 1: Migration schreiben**

```sql
-- 163: Planung und Zeiterfassung fuer Stoerungen und Montagen
-- Spec: docs/superpowers/specs/2026-07-31-einsatzplanung-sprache-design.md
--
-- Bisher gab es genau EIN Datumsfeld (`datum`, im Code als Meldedatum
-- kommentiert). "Gemeldet am" und "geplant fuer" fielen zusammen, ein Termin
-- liess sich gar nicht ausdruecken. Ergebnis: Der Schalter "Erst geplant"
-- wurde seit v0.60.0 kein einziges Mal benutzt (1108 Stoerungen und 810
-- Montagen stehen alle auf erledigt).

alter table public.stoerungen
  add column if not exists geplant_am date,
  add column if not exists geplant_zeit time,
  add column if not exists geplant_dauer_min int,
  add column if not exists arbeit_von time,
  add column if not exists arbeit_bis time,
  add column if not exists gemeldet_am timestamptz;

alter table public.montagen
  add column if not exists geplant_am date,
  add column if not exists geplant_zeit time,
  add column if not exists geplant_dauer_min int,
  add column if not exists arbeit_von time,
  add column if not exists arbeit_bis time;

create index if not exists stoerungen_geplant_am_idx on public.stoerungen (geplant_am);
create index if not exists montagen_geplant_am_idx on public.montagen (geplant_am);

comment on column public.stoerungen.geplant_am is
  'Zieltag des Einsatzes. NULL = noch nicht eingeplant (Rueckstand).';
comment on column public.stoerungen.arbeit_von is
  'Tatsaechlicher Arbeitsbeginn vor Ort. Speist NICHT die generierte Spalte '
  'dauer_minuten (die haengt an uhrzeit_start/uhrzeit_ende) und aendert '
  'keine Abrechnung — Stoerungen werden ueber Pauschalen abgerechnet.';
comment on column public.stoerungen.gemeldet_am is
  'Wann der Auftrag hereinkam. Uebernommen aus dem alten Freitextfeld '
  'uhrzeit_start ("Stoerungseingang") — dessen 109 Altwerte sind '
  'uneinheitlich belegt (teils Erfassungszeit), also nur ein Anhaltspunkt.';

-- Altwerte sichern und umziehen.
create schema if not exists import;
create table if not exists import.stoerung_uhrzeit_start_vor_163 as
  select id, datum, uhrzeit_start from public.stoerungen where uhrzeit_start is not null;

update public.stoerungen
set gemeldet_am = (datum + uhrzeit_start)::timestamptz
where uhrzeit_start is not null and gemeldet_am is null;
```

- [ ] **Schritt 2:** `npx supabase db query --linked --file Datenbank/migrations/163_einsatz_planung.sql`
- [ ] **Schritt 3: Kontrolle** — erwartet: 109 Zeilen in `import.stoerung_uhrzeit_start_vor_163`, 109 mit `gemeldet_am`:

```sql
select (select count(*) from import.stoerung_uhrzeit_start_vor_163) as gesichert,
       (select count(*) from stoerungen where gemeldet_am is not null) as umgezogen;
```

- [ ] **Schritt 4: Rollback-Skript** `Datenbank/wartung/rollback_163_einsatz_planung.sql` schreiben (setzt `gemeldet_am` zurück auf NULL, Spalten bleiben).
- [ ] **Schritt 5: Commit**

---

## Task 2: Modelle, Mapper, Repositories

**Files:** Modify `lib/data/models/stoerung.dart`, `montage.dart`, die zugehörigen `_local.dart` + `web/`-Stubs, Mapper, Repositories.

- [ ] Felder `geplantAm`, `geplantZeit`, `geplantDauerMin`, `arbeitVon`, `arbeitBis` (+ `gemeldetAm` nur Störung) in DTO, Isar-Local und Web-Stub ergänzen; `dart run build_runner build --delete-conflicting-outputs`.
- [ ] Mapper und `toJson` erweitern.
- [ ] Repository-Methoden: `einplanen({id, geplantAm, geplantZeit, dauerMin})` und `arbeitszeitSetzen({id, von, bis})` für beide Entitäten.
- [ ] `flutter analyze` (Baseline 54), `flutter test`, **`flutter build web`** (Web-Stubs!)
- [ ] Commit

---

## Task 3: Fällig-Liste nach Plandatum filtern (TDD)

**Files:** Create `lib/core/util/einsatz_faellig.dart` + `test/einsatz_faellig_test.dart`; Modify `lib/presentation/providers/tour_providers.dart` (`faelligeEintraegeProvider`, Zeile ~601)

- [ ] **Schritt 1: Test schreiben**

```dart
// Ein Einsatz gehoert an einen Tag, wenn er dafuer geplant ist ODER
// gar kein Plandatum hat (Rueckstand, muss sichtbar bleiben).
test('fuer heute geplant -> sichtbar', () {
  expect(einsatzGehoertZuTag(geplantAm: DateTime(2026,8,1),
      tag: DateTime(2026,8,1)), isTrue);
});
test('fuer morgen geplant -> heute NICHT sichtbar', () {
  expect(einsatzGehoertZuTag(geplantAm: DateTime(2026,8,2),
      tag: DateTime(2026,8,1)), isFalse);
});
test('ohne Plandatum -> immer sichtbar (Rueckstand)', () {
  expect(einsatzGehoertZuTag(geplantAm: null, tag: DateTime(2026,8,1)), isTrue);
});
test('Termin in der Vergangenheit -> weiter sichtbar, nicht verschwinden', () {
  expect(einsatzGehoertZuTag(geplantAm: DateTime(2026,7,20),
      tag: DateTime(2026,8,1)), isTrue);
});
```

- [ ] Test rot → `einsatzGehoertZuTag` implementieren → grün
- [ ] `faelligeEintraegeProvider` nutzt die Funktion für Störungen und Montagen. **Wichtig:** Der bestehende Kommentar «Fälligkeits-Filter nur auf Reinigungen; Störungen/Montagen durchlassen» in `tourenplanung_screen.dart:171` wird damit hinfällig — anpassen.
- [ ] `TourEintrag` um `geplantZeit` erweitern, damit der Anker aus dem Einsatz kommt.
- [ ] Tests + Build, Commit

---

## Task 4: «Einplanen» — Sheet und Rückschreiben

**Files:** Create `lib/presentation/widgets/einplanen_sheet.dart`; Modify Fällig-Liste im Tourenplan, `aufgaben_screen.dart`, Block-Sheet im Tagesplan

- [ ] Sheet mit Tag (Vorauswahl morgen), optionaler Uhrzeit und Dauer; CanvasKit-Regel (GestureDetector + Container).
- [ ] Aufruf aus der Fällig-Liste und aus dem Aufgaben-Screen (dort fehlt heute jede Aktion ausser Navigation).
- [ ] Speichern schreibt `geplant_am`/`geplant_zeit`/`geplant_dauer_min` an den Einsatz **und** legt ihn in den Tagesplan des Zieltags (`TagesplanNotifier.hinzufuegen`).
- [ ] **Rückschreiben:** Ändert man im Block-Sheet die Anker-Zeit oder die Dauer, wird das an den Einsatz zurückgeschrieben — sonst geht der Termin beim Entfernen aus dem Plan verloren (heutiger Mangel).
- [ ] Tests, visuelle Prüfung, Build, Commit

---

## Task 5: Zeiterfassung beim Erledigen

**Files:** Modify `stoerung_form_screen.dart`, `montage_form_screen.dart`

- [ ] Beim Öffnen eines geplanten Einsatzes ein Knopf «Beginn» → setzt `arbeit_von` auf jetzt. Beim Speichern als erledigt → `arbeit_bis` auf jetzt.
- [ ] Beide Zeiten bleiben von Hand änderbar (Nachtragen), vorbelegt aus der Planzeit.
- [ ] **Wegpunkt-Stempel auch beim Abschliessen eines geplanten Einsatzes** — heute entsteht er nur bei sofort erledigten (`!_isEdit && !_geplant`), wodurch der Fahrzeit-Lernkurve genau die geplanten Fahrten fehlen.
- [ ] Die bestehende Pausen-Prüfung (`pausePruefenNachEreignis`) ebenfalls an dieser Stelle auslösen.
- [ ] Abrechnung bleibt unangetastet (Montage: `dauer_stunden`; Störung: Pauschalen) — im Code kommentieren.
- [ ] Tests, visuelle Prüfung, Build, Commit

---

## Task 6: Dauer-Vorgaben je Art (TDD)

**Files:** Modify `lib/core/util/besuch_dauer.dart` + Test

- [ ] `einsatzDauerVorgabe({required String art, String? montageTyp, List<int>? stoerungBereiche})` — Vorgaben statt pauschal 60 Minuten. Anfangswerte konservativ (60 min Standard, kürzer für einfache Störungsbereiche, länger für Neumontagen), im Code als «bis genug Ist-Zeiten vorliegen» kommentiert.
- [ ] Verwendung in `_dauerFuer()` im Tourenplan.
- [ ] Tests, Commit

---

## Task 7: Gesamtverifikation und Deploy

- [ ] `flutter analyze` (54), `flutter test` (alle grün), `flutter build web`
- [ ] Version bumpen (pubspec + `kAppVersion`), Cache-Bust, gh-pages-Deploy in Einzelschritten mit Branch-Prüfung
- [ ] `ToDo.md`, `Projekt.md`, Memory nachziehen
- [ ] **Prüfpunkte für Daniel:** (1) Störung auf morgen einplanen → erscheint sie morgen im Tagesplan und heute nicht mehr in der Fällig-Liste? (2) Anker-Zeit im Block ändern → steht sie nach dem Neuladen noch am Einsatz? (3) Geplanten Einsatz erledigen → sind Arbeitszeit und Wegpunkt erfasst?

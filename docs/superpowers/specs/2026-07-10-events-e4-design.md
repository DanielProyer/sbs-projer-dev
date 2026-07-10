# Events-Modul — Phase E4: Zeit-/Spesenerfassung + Auto-Montage (Design)

**Datum:** 2026-07-10
**Aufbauend auf:** E1 (Kontakte, live v0.17.0), E2 (Stände/Anlagen/Dokumente, live v0.18.1),
E3 (Inbetriebnahme/GPS-Karte/Pikett-Einsätze, live v0.19.0)
**Phasenübersicht:** `2026-07-09-events-e1-design.md`
**Status:** Vom User abgenommen (10.07.2026)

## Ziel & Kontext

Am Event leistet Daniel Aufbau, Inbetriebnahme und Pikettdienst. Alle Arbeiten (inkl.
Spesen) werden der Heineken über die Monatsrechnung verrechnet — heute über eine **Montage
Typ „Anlass"** (Freitext-Tageszeilen × Stundensatz). Diese Abrechnungsart samt Montage-PDF
für die Monatsrechnung soll **unverändert bestehen bleiben**.

E4 macht die Erfassung „so einfach wie möglich": Zeit (Anfahrt, Inbetriebnahme, Pikettdienst)
und Spesen werden am Event pro Tag erfasst, und daraus wird mit einem Tipp die Abrechnungs-
Montage **vorbefüllt erzeugt**. E4 ist die Datengrundlage, auf der **E5 (Abschluss-Mail mit
PDF)** aufbaut.

## Entscheidungen (mit User geklärt)

- **Aufteilung:** E4 = Zeit-/Spesenerfassung + Auto-Montage. **E5 = Abschluss-Mail** (separat).
- **Zeit-Eingabe:** Zeilen mit **Datum + Kategorie + Notiz + Stunden**. So sieht man, was an
  welchem Tag wie lange gemacht wurde.
- **Pikettdienst** (z.B. 10:00–02:00 = 16 h) ist ein eigener Zeitblock, **unabhängig** von den
  E3-Einsätzen. Die Einsätze werden **nicht separat verrechnet** (reine Dokumentation).
- **Spesen** werden über **zusätzliche Arbeitszeit** verrechnet (z.B. 120.- Spesen → 1.5 h
  mehr). Kein separates CHF-Feld, keine zweite Montage — alles läuft über Stunden. Die
  Kategorie `spesen` + Notiz hält den Kontext fest (relevant für die E5-PDF).
- **Montage-Generierung:** Aggregation **pro Eventtag** (bewährt), Montage-Formular wird
  **vorbefüllt geöffnet** zum Bestätigen (sicher bei der Abrechnung).
- **Platzierung:** neuer **5. Tab „Zeit"** im Event-Detail.

## Datenmodell (Migration 123)

**`event_aufwand`** — neue Tabelle:

| Feld | Typ | Zweck |
|---|---|---|
| `id` | uuid PK | Client-generiert (Uuid v4) |
| `user_id` | uuid NOT NULL | RLS `user_id = auth.uid()` |
| `event_id` | uuid NOT NULL | → `events` ON DELETE CASCADE |
| `datum` | date NOT NULL | Welcher Tag |
| `kategorie` | text NOT NULL | `anfahrt` / `inbetriebnahme` / `pikett` / `spesen` |
| `notiz` | text (nullable) | z.B. „10:00–02:00" oder „Essen/Übernachtung CHF 120" |
| `stunden` | numeric NOT NULL | Dezimalstunden (auch Spesen als umgerechnete Std) |
| `created_at` / `updated_at` | timestamptz | updated_at-Trigger |

Index (`user_id`, `event_id`). CHECK auf `kategorie IN ('anfahrt','inbetriebnahme','pikett','spesen')`.

**Flutter:** `event_aufwand` als volle Sync-Vertikale nach E1–E3-Muster (DTO mit
fromJson/toJson, Isar-Local `@collection`, Web-Stub, Conditional Export, Mapper fromDto/toJson,
IsarService typed Queries inkl. `eventAufwandGet(int)`, Repository mit kIsWeb-Branching +
Client-UUID (`serverId ??= Uuid().v4()`) + serverseitigem Native-Delete (W1-Muster),
Provider `eventAufwaendeProvider(eventId)` (FutureProvider.family), Sync-Tier 3.
Sync-`toJson`/`fromJson` erweitern (Push/Pull).

camelCase ↔ snake_case: `eventId`↔`event_id`, `createdAt`↔`created_at`, `updatedAt`↔`updated_at`.

## Bausteine

### 1. Erfassungs-UI — neuer 5. Tab „Zeit"

- Event-Detail-Tabs werden zu **Kontakte | Stände | Einsätze | Zeit | Dokumente** (5 Tabs).
  Die `TabBar` wird `isScrollable: true` (passt sonst nicht auf schmale Phone-Breite). FAB-
  `switch` und Tab-Reihenfolge im `event_detail_screen.dart` entsprechend erweitern (neuer
  Index 3 = Zeit, Dokumente rückt auf Index 4).
- **Zeit-Tab** (`_ZeitTab`, ConsumerWidget): Liste aller Aufwand-Zeilen, **sortiert nach Datum**
  (aufsteigend), pro Zeile: Datum, Kategorie-Label + Icon, Notiz, Stunden (`x.xx h`). Kopf-Chip
  mit **Total Stunden** über alle Zeilen. Leer-Zustand „Noch keine Zeiten erfasst.".
- **FAB „Zeit erfassen"** (Index 3) → `EventAufwandFormScreen` (minimal):
  - **Datum** (Pflicht, default heute, Datepicker)
  - **Kategorie** (Pflicht, 4 Optionen `anfahrt`/`inbetriebnahme`/`pikett`/`spesen`, Dropdown
    oder ChoiceChips; default `pikett`)
  - **Notiz** (Freitext, optional)
  - **Stunden** (Pflicht, Dezimal, > 0)
- Bearbeiten (Tap auf Zeile) und Löschen (mit Bestätigungsdialog). Nach Speichern/Löschen
  `ref.invalidate(eventAufwaendeProvider(eventId))`.

### 2. Auto-Montage-Generierung

- Im Zeit-Tab Button **„Montage generieren"** (z.B. oberhalb der Liste, neben dem Total-Chip;
  deaktiviert wenn keine Zeilen).
- **Aggregation pro Eventtag** (reine Funktion, unit-getestet): alle Aufwand-Zeilen nach
  `datum` gruppieren, je Tag die Stunden summieren, eine Slot-Zeile je Tag erzeugen mit
  Label = Datum kurz (z.B. „Fr 25.7.") und Stunden = Tages-Summe. Ergebnis nach Datum sortiert.
  - Der Montage-Typ „Anlass" summiert nur die **ersten 5 Slots** (`_anlassTotalStunden`, i<5).
    Bei **> 5 Eventtagen** werden die Zeilen auf 5 reduziert: die ersten 4 Tage einzeln, ein
    5. Sammel-Slot „Weitere Tage" mit der Rest-Summe. So bleibt die Gesamt-Stundenzahl korrekt.
    Ein `log`/Hinweis-Text macht die Zusammenfassung transparent.
- Öffnet das **bestehende Montage-Formular** (`MontageFormScreen`) über `Navigator.push`
  (MaterialPageRoute, wie die Event-Formulare) mit neuem optionalem Parameter
  `vorbefuellung` (Record/Klasse): `montageTyp = 'anlass'`, `betriebId = event.betriebId`,
  `datum = event.terminVon ?? heute`, `slots = List<({String text, double stunden})>` (max 5).
  - `MontageFormScreen` erhält den optionalen Parameter (bestehende Aufrufe unverändert). In
    `initState`/`_loadMontage`: wenn `vorbefuellung != null` und `montageId == null`, Typ +
    Betrieb + Datum + Anlass-Slots (`_materialControllers`/`_materialIds`/`_materialMengen`/
    `_materialMengenControllers`) vorbelegen; danach übernimmt die bestehende Formular-Logik
    (Stundensatz aus Preisliste des Betriebs, Summenvorschau, Speichern).
- Der User **prüft/korrigiert und speichert** — ab da normaler Heineken-Abrechnungsfluss
  (Montage Typ Anlass → Monatsrechnung + Montage-PDF, unverändert).
- **Keine harte Verknüpfung/Duplikat-Sperre** in E4 (manuelle Bestätigung). Optionaler,
  nicht zwingender Hinweis bleibt außen vor (YAGNI).

### Bedienfluss

Event-Detail → Tab „Zeit": während/nach dem Event Zeilen erfassen (Datum, Kategorie, Std,
Spesen als Std). Am Schluss „Montage generieren" → vorbefülltes Montage-Formular prüfen +
speichern. Die erfassten Zeiten/Spesen sind zugleich die Grundlage für die **E5-Abschluss-Mail**.

## Abgrenzung E4

Nicht enthalten: Abschluss-Mail + PDF (E5), CHF-Spesen-Automatik / Umrechnung Stundensatz,
Verknüpfung Einsätze↔Abrechnung, Änderungen an der bestehenden Montage-/Heineken-Abrechnung
außer dem additiven optionalen `vorbefuellung`-Parameter am `MontageFormScreen`.

## Technik-Risiken (verifizieren)

- **Anlass-5-Slot-Grenze:** `_anlassTotalStunden` zählt nur die ersten 5 Slots. Die Aggregation
  muss zwingend ≤ 5 Slots liefern, sonst fehlen Stunden in der Abrechnung. Im Unit-Test mit
  6+ Tagen absichern.
- **Vorbefüllung des Montage-Formulars:** additive, rückwärtskompatible Erweiterung; bestehende
  Montage-Erfassung darf sich nicht ändern (visuell + `flutter analyze` prüfen).
- **5. Tab / scrollbare TabBar:** Layout auf Phone-Breite prüfen (Tabs scrollbar, kein Overflow).
- build_runner: **kein** `?ausdruck` (null-aware Collection-Elemente) in neuen `@collection`-
  Klassen — bricht isar_generator (analyzer-Pin). Stattdessen `if (x != null) …`.

## Tests & Verifikation

- Unit-Tests: Aggregation Aufwand→Montage-Slots (pro Tag summiert, Sortierung, 1/n Tage,
  > 5-Tage-Zusammenfassung auf 5 Slots mit erhaltener Gesamtsumme, leere Liste), Total-Stunden.
- `flutter analyze` ohne neue Findings; alle Tests grün; build_runner „Succeeded".
- Visueller Browser-Test vor Deploy (Pflicht): Zeit erfassen/bearbeiten/löschen, Total stimmt;
  „Montage generieren" → Montage-Formular korrekt vorbefüllt (Typ Anlass, Betrieb = Event-
  Betrieb, Slots pro Tag, Stundensatz aus Preisliste), speicherbar; Kontakte/Stände/Einsätze/
  Dokumente unverändert.

## Deploy

Als ein Paket **v0.20.0**. Migration 123 vorab auf Prod anwenden + verifizieren. Deploy-Workflow
wie E1–E3 (pubspec bump, Merge nach main, gh-pages, Cache-Bust).

# Events-Modul — Phase E2: Dokumente + Stände + Anlagen (Design)

**Datum:** 2026-07-10
**Aufbauend auf:** E1 (live v0.17.0), Phasenübersicht in `2026-07-09-events-e1-design.md`
**Referenz-Beispiele:** `00_Event/Lageplan 2024.pdf` (Geländeplan, 4.4 MB) + `00_Event/Verteilung.pdf`
(Pro-POS-Liste: pro Stand Anlagen + Material) — unversioniert, nur Referenz.
**Status:** Vom User abgenommen (10.07.2026)

## Ziel

Plan und Stände in der App (User-Zitat: „auch für die Störungserfassung und die
koordinierte Inbetriebnahme der Anlagen") — mit möglichst wenig Erfassungsaufwand.
E2 liefert die Struktur (Dokumente, Stände, Anlagen); E3 baut Inbetriebnahme-Checkliste,
GPS/Karte und Pikett-Einsätze darauf auf.

## Entscheidungen (mit User geklärt)

- **Nur Schankanlagen** pro Stand, Typen: **Oberthekengerät (OT), Hollandbuffet,
  Ausschankwagen** (+ `sonstige` als Reserve). Übriges Material bleibt in der
  Verteilungs-PDF nachschlagbar.
- **Dokument-Ablage** pro Event-Jahr (Lageplan, Verteilung, weitere Heineken-PDFs)
  statt eines fest verdrahteten Lageplan-Felds. View-only (Öffnen im nativen
  PDF-Viewer mit Zoom), keine Pins/Georeferenzierung (E1-Entscheid).
- Dokumente werden NICHT aus dem Vorjahr übernommen (Pläne sind jährlich neu);
  Stände inkl. Anlagen SCHON (eigene Checkbox).

## Datenmodell (Migration 120 + Storage-Bucket)

**`event_dokumente`**
- `id` uuid PK, `user_id` uuid NOT NULL
- `event_id` uuid NOT NULL → `events` ON DELETE CASCADE
- `bezeichnung` text NOT NULL (z. B. „Lageplan", „Verteilung")
- `datei_pfad` text NOT NULL (Pfad im Storage-Bucket)
- `created_at`/`updated_at`, RLS + updated_at-Trigger wie üblich
- Index (`user_id`, `event_id`)

**`event_staende`**
- `id` uuid PK, `user_id` uuid NOT NULL
- `event_id` uuid NOT NULL → `events` ON DELETE CASCADE
- `name` text NOT NULL (z. B. „Signina Bar"), `standnummer` text (Referenz zum Plan)
- `sortierung` int NOT NULL DEFAULT 0, `notizen` text
- `created_at`/`updated_at`, RLS + Trigger, Index (`user_id`, `event_id`)

**`event_stand_anlagen`**
- `id` uuid PK, `user_id` uuid NOT NULL
- `stand_id` uuid NOT NULL → `event_staende` ON DELETE CASCADE
- `typ` text NOT NULL CHECK IN (`'oberthekengeraet'`, `'hollandbuffet'`,
  `'ausschankwagen'`, `'sonstige'`)
- `bezeichnung` text (z. B. „2H", Gerätenummer), `anzahl` int NOT NULL DEFAULT 1
- `sortierung` int NOT NULL DEFAULT 0
- `created_at`/`updated_at`, RLS + Trigger, Index (`user_id`, `stand_id`)

**Storage:** neuer privater Bucket `event-dokumente` (Anlage + RLS-Policies nach dem
Muster des bestehenden Belege-/Foto-Buckets). Pfad-Konvention `<eventId>/<uuid>.pdf`.
Upload nach bestehendem Eingangsrechnungs-Muster (Datei wählen → Upload → Pfad speichern);
Öffnen über signed URL (nativer PDF-Viewer, Zoom inklusive).

**Flutter:** Alle drei Entities als volle Sync-Vertikale exakt nach E1-Muster
(DTO, Isar-Local, Web-Stub, Export, Mapper, IsarService inkl. `…Get(int)`,
Repository mit client-seitiger UUID (`serverId ??= Uuid().v4()`), Provider, Sync).
Native-Delete IMMER serverseitig + lokal (E1-Review-Muster W1).
Sync-Reihenfolge: `event_dokumente` + `event_staende` nach `events`;
`event_stand_anlagen` nach `event_staende`.

## UI

**Event-Detail → 3 Tabs** (Muster CamtBankauszug-Host): Kopf-Card (Name, Termin,
Status-Badge, Ort, Notizen) bleibt über den Tabs; darunter **Kontakte | Stände | Dokumente**.
Bestehende Kontakte-Funktionalität unverändert in den ersten Tab. FAB je Tab
(Kontakt zuordnen / Stand hinzufügen / Dokument hochladen). E3 ergänzt später
Karte + Einsätze.

**Stände-Tab:**
- Karten pro Stand, sortiert nach `sortierung`, dann Name: Titel = Name
  (+ Standnummer-Chip), Untertitel = Anlagen-Zusammenfassung („7× OT · 26× Hollandbuffet")
- Aufklappbar (ExpansionTile): Anlagen-Zeilen (Typ-Label, Bezeichnung, Anzahl), Notizen
- Tap auf Stift → Stand-Formular (bearbeiten); Swipe/Menü → Stand löschen
  (Dialog; löscht Stand + Anlagen, serverseitig via CASCADE, native explizit)
- Menü im Tab: „Stände aus Vorjahr übernehmen" (kopiert Stände + Anlagen;
  Merge-Regel: Stand-`name` case-insensitive gleich → überspringen)

**Stand-Formular** (`event_stand_form_screen.dart` oder Sheet):
- Name (Pflicht), Standnummer, Notizen
- **Dynamische Anlagen-Zeilen** (Muster Ferien-Zeilen): pro Zeile Typ-Dropdown
  (OT/Hollandbuffet/Ausschankwagen/Sonstige), Bezeichnung (optional), Anzahl
  (Stepper oder Zahlfeld, min 1); „+ Anlage"-Button; Zeile entfernbar
- Speichern legt Stand + Anlagen an (Anlagen-Diff: gelöschte Zeilen werden entfernt)

**Dokumente-Tab:**
- Liste: Bezeichnung, Upload-Datum; Tap → signed URL öffnen (PDF-Viewer)
- FAB „Dokument hochladen": Datei wählen (PDF), Bezeichnung eingeben
  (Vorschlag = Dateiname ohne Endung), Upload mit Fortschritt/Fehlermeldung
- Löschen (Dialog): Storage-Datei + Datensatz

**Event-Formular:** zweite Checkbox **„Stände aus Vorjahr übernehmen"**
(sichtbar/vorausgewählt wie die Kontakte-Checkbox, gleiche Quelle-Logik).
Snackbar fasst zusammen („3 Kontakte, 12 Stände übernommen").

## Vorjahres-Übernahme Stände (Regel)

Quelle = jüngstes Event desselben Betriebs mit kleinerem Jahr (wie E1).
Kopiert werden Stände (name, standnummer, sortierung, notizen) + deren Anlagen.
Merge: existiert im Ziel bereits ein Stand mit gleichem Namen
(case-insensitive, getrimmt), wird er samt Anlagen übersprungen. Rückgabe: Anzahl Stände.

## Abgrenzung E2

Nicht enthalten: Inbetriebnahme-Status, GPS/Karte, Einsätze, Störungs-Verknüpfung
(alles E3), Verteilung-KI-Import (spätere Ausbaustufe), Abschluss-Mail (E4).
Keine Änderungen an bestehenden Features ausserhalb des Events-Moduls.

## Tests & Verifikation

- Unit-Tests: Stände-Merge-Regel (Name case-insensitive), Anlagen-Zusammenfassungs-Text,
  Anlagen-Diff beim Stand-Speichern (falls als pure Funktion gebaut).
- `flutter analyze` ohne neue Findings; alle Tests grün; build_runner „Succeeded".
- Visueller Web-Test vor Deploy: Tabs, Stand anlegen/bearbeiten/löschen mit Anlagen-Zeilen,
  Dokument hochladen/öffnen/löschen (mit echtem Lageplan-PDF aus `00_Event/`),
  Vorjahres-Übernahme Stände, Kontakte-Tab unverändert funktionsfähig.

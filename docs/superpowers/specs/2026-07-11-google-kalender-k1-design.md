# Google-Kalender K1 — App-Kalender ablösen + Saison-Reinigung mit Bestätigung (Design)

**Datum:** 2026-07-11
**Status:** Vom User abgenommen (11.07.2026) — Spec zur Review.
**Herkunft:** Termine-Überarbeitung, Paket 06. Ersetzt die früher geplanten G3/G4.
Grundlage: [Recherche](2026-07-10-google-kalender-recherche.md), [G2](2026-07-11-google-kalender-g2-design.md).
Nachgelagert: **K2** (Bestehende Google-Einträge normalisieren) — eigenes Paket.

## Ziel & Kontext

Der Google Kalender wird der **eine** Kalender. Der ungeliebte App-Kalender (Screen + Termin-Formular)
wird **entfernt**. Manuelle Termine erfasst der User direkt in Google (macht er längst). Neu: Beim
**Speichern von Ferien/Saison-Daten an einem Betrieb** fragt die App per **Bestätigungs-Dialog** nach
Eröffnung/Endreinigung und trägt die bestätigten in Google ein.

**Ist-Zustand (verifiziert):**
- Kalender läuft: G1 (OAuth verbunden, dani.proyer@gmail.com), G2 (`google-calendar-sync` push+reconcile
  für Pikett/Events/Termine, Mapping-Tabelle `google_calendar_events(entity_type check
  termin/pikett/event, entity_id uuid, google_event_id, content_hash, …)`).
- **Der Google-Kalender enthält bereits viele manuelle Reinigungs-/Eröffnungs-Einträge** des Users
  (Format uneinheitlich „Ort - Betrieb  Notiz", mit wichtigen Notizen/Uhrzeiten) sowie private Einträge.
  → deshalb **keine** stummen Massen-Pushs; Saison-Reinigungen laufen **nur mit Bestätigung**.
- Termine-Modul: `termine_kalender_screen`, `termin_form_screen`, `termin_repository`
  (`save`/`delete` mit G2-Push + `ReminderService`), `termin_providers`, `termin_mapper`, Isar-Locals;
  Routen `/termine`, `/termine/neu`, `/termine/:id/bearbeiten` (router.dart); Dashboard-Kachel
  „Termine" (home_screen.dart Z. 146); App-Start `ReminderService.rescheduleAll` (app.dart Z. 60);
  Auto-Vorschläge `TerminRepository.synchronisiereVorschlaege` (betrieb_form_screen Z. 413).
- Betrieb: Saison (`sommer/winterStartDatum`/`…EndeDatum`/`…SaisonAktiv`), Ferien 1–5
  (`betrieb_ferien.dart`), `name`, `ort`. Reine Saison-Helfer in `touren_saison.dart`.
- Mapping-Tabelle: 0 gepushte Termine bisher (nichts zu bereinigen). 219 alte `vorgeschlagen`-Termine
  in `termine` (bleiben ungenutzt liegen; nicht in Google).

**Entscheidungen (abgenommen):**
- Ablösen **vollständig** (App-Kalender-UI + Termin-Datenschicht raus).
- Saison-Reinigungen: **App generiert, aber nur mit Bestätigung** beim Ferien-/Saison-Speichern.
- Bestehende manuelle Einträge: **nicht** hier anfassen (→ K2, vorschau-gestützt).
- Deploy **v0.33.0**. Keine destruktive DB-Änderung.

## Baustein A — App-Kalender ablösen (Entfernen)

- **Löschen:** `termine_kalender_screen.dart`, `termin_form_screen.dart`, `termin_repository.dart`,
  `termin_providers.dart`, `termin_mapper.dart`, `termin_local.dart`(+`.g.dart`), `web/termin_local_web.dart`,
  `termin_local_export.dart`.
- **router.dart:** die drei `/termine…`-Routen + zugehörige Imports entfernen.
- **home_screen.dart:** Kachel „Termine" → **„Google Kalender"**; `onTap` öffnet
  `https://calendar.google.com` extern (url_launcher, neuer Tab).
- **app.dart:** den `TerminRepository.getAll()`→`ReminderService.rescheduleAll`-Block + Import entfernen.
- **betrieb_form_screen.dart:** den `synchronisiereVorschlaege`-Aufruf + `termineStreamProvider`-Invalidate
  entfernen (ersetzt durch Baustein B).
- **sync_service.dart:** den Termin-Sync-Tier entfernen. **isar_service.dart:** Termin-Methoden entfernen
  (+ `build_runner`-Regenerierung).
- **reminder_service** (+ `_web`/`reminder_time`/Export): entfernen, **falls** keine anderen Aufrufer mehr
  (auf Web ohnehin wirkungslos). Andernfalls nur die Termin-Aufrufe kappen.
- **`termine`-Tabelle:** bleibt (nicht-destruktiv), wird nicht mehr genutzt. Kein Google-Cleanup nötig
  (0 gepushte Termine).

## Baustein B — Saison-Reinigung mit Bestätigung (Neu)

**Reine Funktion (TDD)** `betriebReinigungen(BetriebLocal b) → List<BetriebReinigung>` in neuer
`core/util/betrieb_reinigung.dart`. `BetriebReinigung { String slotKey; String art; DateTime datum;
String label; }` (art ∈ `endreinigung`|`eroeffnung`, label = `"${b.name}, ${b.ort}"`):
- Saison (falls aktiv): `sommer_eroeffnung`=sommerStart, `sommer_endreinigung`=sommerEnde;
  `winter_eroeffnung`=winterStart, `winter_endreinigung`=winterEnde.
- Ferien-Slots 1–5 (falls Start+Ende gesetzt): `ferienN_endreinigung`=ferienStart − 1 Tag;
  `ferienN_eroeffnung`=ferienEnde + 1 Tag.
- Nur Boundaries mit vorhandenem Datum; sortiert nach Datum.

**Ablauf** (in `betrieb_form_screen._save`, nach erfolgreichem Speichern):
- Wenn Google verbunden **und** `betriebReinigungen(betrieb)` nicht leer → Dialog
  `_SaisonReinigungDialog` zeigen:
  - Liste je Reinigung: `<Art> — <Betrieb>, <Ort>` + Datum, mit **Checkbox** (default alle an).
  - Buttons **„In Google eintragen"** / **„Später"**.
- Bei „In Google eintragen": **ein** Aufruf
  `GoogleCalendarSyncService.syncBetriebReinigungen(betriebId, label, items)` mit
  `items = [{slot_key, art, datum, aktiv}]` (aktiv = Checkbox).
- Idempotent: gleiche `slotKey` aktualisiert denselben Google-Eintrag (kein Duplikat); abgehakt-entfernt
  löscht ihn. Ändern sich Ferien/Saison später → beim nächsten Speichern zeigt der Dialog die neuen
  Daten, Bestätigung aktualisiert.

**Edge Function `google-calendar-sync` — Erweiterung:**
- Neue Aktion `sync_reinigungen` (JWT-auth): Body `{ betrieb_id, label, reinigungen:[{slot_key, art,
  datum, aktiv}] }`. Für jede `aktiv`: Google-Event **upserten** (ganztags `datum`, `end.date`=datum+1,
  Titel `SBS · Endreinigung|Eröffnung — <label>`, grün `colorId:10`, `reminders` = E-Mail+Popup 1440 Min),
  Mapping `entity_type='betrieb_reinigung'`, `entity_id='${betrieb_id}:${slot_key}'`. Für nicht-`aktiv`:
  Google-Event + Mapping löschen (falls vorhanden). Access-Token-Refresh wie bei push (bestehende Logik).
- **Termin-Behandlung entfernen** (App verwaltet keine Termine mehr): `pushOne`/`reconcile`/`buildEvent`/
  `loadEntity` nur noch `pikett`/`event`.
- **`reconcile` fasst `betrieb_reinigung` NICHT an** (kein Orphan-Delete dafür — die werden ausschliesslich
  über den Bestätigungs-Dialog verwaltet). Orphan-Delete nur für `pikett`/`event`.

**Migration 132** (`132_gcal_events_reinigung.sql`):
- `alter table public.google_calendar_events alter column entity_id type text;` (UUIDs passen als Text).
- CHECK auf `entity_type` neu: `in ('termin','pikett','event','betrieb_reinigung')` (drop+add).

## Abgrenzung

- **Kein** Anfassen bestehender manueller Google-Einträge (→ K2).
- **Kein** Import Google→App.
- Pikett/Events-Push (G2) bleibt unverändert.
- Manuelle Termine: nur noch in Google (kein App-Formular).

## Sicherheit

- Reinigungs-Push **nur mit expliziter User-Bestätigung** im Dialog → keine ungefragten Kalender-Writes.
- JWT-authentifiziert pro Nutzer. Token/Refresh serverseitig (unverändert).
- Mapping-Tabelle service_role-only.

## Tests & Verifikation

- **Unit-Tests** (`betrieb_reinigung_test.dart`): Saison sommer/winter → richtige slotKeys/Daten/art;
  Ferien-Slot → Endreinigung (Start−1) + Eröffnung (Ende+1); nur belegte Slots; leerer Betrieb → leer;
  Sortierung; label-Format „Name, Ort" (und ohne Ort nur Name).
- `flutter analyze` ohne neue Findings; Tests grün; `build_runner` sauber nach Isar-Entfernung.
- **DB/Function:** Migration 132; Function deployen.
- **Live-Test** (User, real gegen Google):
  - App-Kalender-Screen/Termin-Formular weg; Kachel „Google Kalender" öffnet calendar.google.com.
  - Betrieb mit Ferien/Saison speichern → Dialog erscheint mit den Reinigungen → „In Google eintragen"
    → Einträge erscheinen (grün, „SBS · … — Betrieb, Ort", Erinnerung). Häkchen entfernen + erneut
    bestätigen → Eintrag verschwindet. Ferien-Datum ändern + bestätigen → Eintrag verschiebt sich.
  - Keine Duplikate; Pikett/Events (G2) weiterhin ok; „Jetzt abgleichen" lässt Reinigungen unangetastet.

## Deploy

Ein Paket **v0.33.0**: Migration 132 + Edge-Function-Update + App (Entfernen + Dialog) nach
Deploy-Workflow (CLAUDE.md).

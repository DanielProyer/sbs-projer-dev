# Google-Kalender G2 — Push App → Google (Design)

**Datum:** 2026-07-11
**Status:** Vom User abgenommen (11.07.2026) — Spec zur Review.
**Herkunft:** Termine-Überarbeitung, Paket 06. Drittes Teil-Paket (nach
[G1](2026-07-10-google-kalender-g1-design.md)). Grundlage: [Recherche](2026-07-10-google-kalender-recherche.md).

## Ziel & Kontext

Pikett-Dienste, Events und Termine werden **automatisch in den Google Kalender geschrieben**
(Einweg App→Google, „App gewinnt"), inkl. Erinnerungen (email + popup), die real auf dem
Android-Handy ankommen. **Sofort** beim Speichern in der App + Cron-Backup.

**Ist-Zustand (verifiziert):**
- G1 live: OAuth verbunden (dani.proyer@gmail.com), Refresh-Token in `google_calendar_tokens`
  (RLS: nur service_role), Scope `calendar.events`, Access-Token + Expiry gespeichert.
- Edge-Function-Muster (`betrieb-google-lookup`, `google-oauth-exchange`): Deno.serve + CORS +
  `Deno.env.get`, Deploy via MCP, auto-Secrets `SUPABASE_URL/ANON_KEY/SERVICE_ROLE_KEY`.
- DB-Spalten (server-seitig): `termine(datum date, uhrzeit_von/bis time, titel, notizen,
  erinnerungen jsonb, betrieb_id)`, `pikett_dienste(datum_start/ende date, referenz_nr, notizen,
  google_calendar_event_id, kalender_sync_status/fehler/at)`, `events(termin_von/bis date, betrieb_id,
  notizen)`. `betriebe.name` für Event-Titel.
- Extensions `pg_cron`/`pg_net` müssen aktiviert werden (via MCP prüfen/aktivieren).

**Entscheidungen (abgenommen):**
- Ziel = **primary** (Haupt-Kalender); kein Neu-Verbinden. Einträge farblich + Präfix „SBS · ".
- Pikett & Events: Default-Erinnerung **email + popup, 1 Tag vorher**. Termine: aus `erinnerungen`.
- Sync: **Sofort-Push beim Speichern/Löschen** + **pg_cron-Reconcile** (~15 Min) als Backup.
- Konflikt: **App gewinnt** (Push überschreibt Google). App-Löschung → Google-Event weg.

## Baustein A — Mapping-Tabelle (Migration 131)

`google_calendar_events` — zentrale Zuordnung Entity ↔ Google-Event:
- `id bigserial pk`, `user_id uuid`, `entity_type text` ('termin'|'pikett'|'event'),
  `entity_id uuid`, `google_event_id text`, `content_hash text`, `synced_at timestamptz`,
  `status text` ('ok'|'error'), `fehler text`, `updated_at timestamptz`.
- Unique `(user_id, entity_type, entity_id)`.
- RLS aktiv, **keine Client-Policy** (nur service_role). Der Browser braucht sie nicht.
- Ersetzt die Sync-Buchführung; `pikett_dienste`-Inline-Felder bleiben unangetastet (dürfen später weg).

## Baustein B — Edge Function `google-calendar-sync`

Gemeinsame Helfer: **Access-Token gültig halten** — Token-Zeile lesen; wenn `access_token_expiry`
< jetzt+60 s, via `refresh_token` (grant_type=refresh_token, client_id+secret) erneuern und
`access_token`/Expiry zurückschreiben. Google-Calendar-REST unter
`https://www.googleapis.com/calendar/v3/calendars/primary/events`.

**Modus `push`** — Body `{ action:'push', entity_type, entity_id }`, **JWT-authentifiziert**
(Nutzer aus Auth-Header). Wenn kein Google-Token für den Nutzer → `{skipped:'not_connected'}`.
- Entity aus DB laden (service_role). Existiert sie **nicht mehr** → falls Mapping vorhanden:
  Google-Event **löschen** + Mapping-Zeile löschen.
- Existiert sie → Google-Event **bauen** (Baustein D), `content_hash` berechnen.
  - Kein Mapping → `events.insert` (POST) → `google_event_id` speichern.
  - Mapping vorhanden → `events.update` (PUT) auf `google_event_id` (bei 404: neu inserten).
  - `synced_at`/`content_hash`/`status='ok'` schreiben; bei Fehler `status='error'`, `fehler=…`.

**Modus `reconcile`** — Body `{ action:'reconcile', secret }`, ausgelöst von **pg_cron** (kein
User-JWT). `secret` muss `CRON_SECRET` (Supabase-Secret) entsprechen. Für jeden Nutzer mit Token:
- Alle `termine`/`pikett_dienste`/`events` durchgehen; `content_hash` bilden; bei Abweichung/fehlendem
  Mapping → push-Logik. **Waisen** (Mapping ohne existierende Entity) → Google-Event + Mapping löschen.
- Rate: einfache sequenzielle Abarbeitung (Einzelnutzer, kleine Mengen).

## Baustein C — Sofort-Push aus der App

- Neuer `GoogleCalendarSyncService.push(entityType, entityId)` (App): ruft
  `functions.invoke('google-calendar-sync', body:{action:'push', entity_type, entity_id})` —
  **fehlertolerant** (Fehler blockieren das Speichern nie; nur `debugPrint`).
- Aufruf **nach erfolgreichem Speichern** und **nach Löschen** in den Repositories/Flows von
  Termin, Pikett und Event (jeweils die eine Choke-Point-Stelle). Kleine, unaufdringliche Bestätigung
  optional (kein Blockieren).
- Läuft nur sinnvoll online; offline fängt der Reconcile-Cron nach.

## Baustein D — Google-Event-Mapping (Format)

Alle Events tragen `extendedProperties.private = { app:'sbs_projer', entity_type, entity_id }`
(Idempotenz/Wiedererkennung) und `reminders.useDefault=false`.

- **Termin** (`entity_type='termin'`): Titel `SBS · <titel>`; Beschreibung `notizen`.
  - Uhrzeit gesetzt → getimt: `start.dateTime`/`end.dateTime` mit `timeZone:'Europe/Zurich'`
    (ohne `uhrzeit_bis`: Ende = Start + 1 h).
  - Sonst ganztags: `start.date=datum`, `end.date=datum + 1 Tag`.
  - `reminders.overrides` = aus `erinnerungen`-jsonb (`{method, minutes}`), max 5. `colorId='10'` (grün).
- **Pikett** (`entity_type='pikett'`): ganztags `start.date=datum_start`, **`end.date=datum_ende + 1`**
  (exklusiv). Titel `SBS · Pikett` (+ ` <referenz_nr>` falls vorhanden). Beschreibung `notizen`.
  `reminders.overrides=[{method:'email',minutes:1440},{method:'popup',minutes:1440}]`. `colorId='11'` (rot).
- **Event** (`entity_type='event'`): ganztags `termin_von`…`termin_bis + 1`. Titel
  `SBS · Event: <betrieb.name>` (Join `betriebe`). Beschreibung `notizen`.
  `reminders` = email+popup 1440 min. `colorId='5'` (gelb).
- `content_hash` = Hash über die relevanten Event-Felder (summary/start/end/description/reminders/colorId).

## Baustein E — pg_cron

- Extensions `pg_cron` + `pg_net` sicherstellen (MCP).
- Job alle 15 Min: `pg_net.http_post` auf die Function-URL mit Header
  `Authorization: Bearer <service_role_key>` und Body `{action:'reconcile', secret:'<CRON_SECRET>'}`.
- `CRON_SECRET` als Supabase-Secret; die Function prüft ihn im Reconcile-Modus.

## Abgrenzung

- **Kein** Import Google→App (freie Google-Termine) — das ist **G3**.
- Scope bleibt `calendar.events` (kein Neu-Verbinden; primary schreibbar).
- Keine Änderung an bestehender Termin/Pikett/Event-Fachlogik ausser dem Push-Aufruf.

## Sicherheit

- Refresh-/Access-Token nur in `google_calendar_tokens` (service_role). Access-Token-Refresh serverseitig.
- `push` JWT-authentifiziert (pro Nutzer); `reconcile` per `CRON_SECRET`.
- Mapping-Tabelle service_role-only. `client_secret`/`CRON_SECRET` nur als Supabase-Secret.

## Tests & Verifikation

- **Unit-Tests** (reiner Event-Builder als testbare Funktion, falls in TS schwer: in der Function als
  reine Hilfsfunktion; alternativ Dart-seitige reine Helfer für Titel/Reminder-Defaults mit Tests):
  - Ganztags `end.date` = Ende + 1 (exklusiv); getimter Termin mit/ohne `uhrzeit_bis`; Reminder-Mapping
    aus `erinnerungen`; Pikett/Event Default-Reminder; Titel-Präfix.
- `flutter analyze` sauber; Dart-Tests grün.
- **DB/Function**: Migration 131 anwenden; Function deployen; pg_cron-Job anlegen.
- **Live-Test** (Pflicht, real gegen Google):
  - Termin (getimt + ganztags) speichern → erscheint sofort im Google Kalender (grün, „SBS · …"),
    Erinnerungen gesetzt. Ändern → Google aktualisiert. Löschen → Google-Event weg.
  - Pikett (mehrtägig) → korrekter Zeitraum (letzter Tag inkl.), rot, Erinnerung 1 Tag vorher.
  - Event → gelb, Titel mit Betrieb.
  - Reconcile-Cron: manuell auslösen → keine Duplikate, Waisen entfernt.
  - **Erinnerungs-Empfang** real prüfen (E-Mail + Popup am Pixel 9).

## Deploy

Ein Paket **v0.32.0**: Migration 131 + Edge Function `google-calendar-sync` + pg_cron-Job +
`CRON_SECRET`-Secret + App-Änderungen (Push nach Speichern/Löschen) nach Deploy-Workflow (CLAUDE.md).

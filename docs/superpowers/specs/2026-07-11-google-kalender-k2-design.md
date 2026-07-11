# Google-Kalender K2 — Bestehende Termine den Betrieben zuordnen & taggen

**Datum:** 2026-07-11 · **Status:** abgenommen (Design) · **Vorgänger:** K1 (live v0.33.0)

## Ziel

Die bereits **manuell** im Google Kalender eingetragenen Service-Termine (Format grob „Ort - Betrieb Notiz", inkonsistent, mit Tippfehlern, gemischt mit privaten Terminen) sollen den Betrieben in der App zugeordnet und **nur getaggt/eingefärbt/mit Erinnerung versehen** werden. **Titel und Notizen bleiben unangetastet.** Nichts wird ohne Vorschau + Batch-Freigabe geändert; nur eindeutig erkannte Termine werden vorgeschlagen; alles ist reversibel.

Abgrenzung: K2 ist der riskanteste Teil der Google-Kalender-Integration, weil es hunderte echte, teils private Kalender-Einträge liest und (nach Freigabe) verändert. Deshalb konservatives Matching + strikte Sicherheitsgarantien.

## Ausgangslage (aus Read-only-Untersuchung 11.07.2026)

- **Kein Lese-Pfad vorhanden.** Die Edge Function `google-calendar-sync` kennt nur Schreib-Aktionen (`push`, `reconcile`, `sync_reinigungen`), Richtung strikt App→Google. `events.list` (GET) und ein PATCH-nur-Muster müssen **neu** gebaut werden.
- **Betriebsdaten:** 406 Betriebe (292 `aktiv`, 105 `geschlossen`, 9 `inaktiv`), nur **1** ohne `ort`. Aber **14 Namens-Kollisionen** über mehrere Orte (Alpina in 4 Orten; Surselva/Sunstar/Gemsli je 3; Calanda Chur/Felsberg; …) → **Name allein ist nicht eindeutig, der Ort ist Pflicht-Disambiguator.**
- **Ort ist selbst uneinheitlich:** Slash-Namen (`Lenzerheide/Lai`, `Breil/Brigels`, `Disentis/Mustér`), DB-Inkonsistenz (`Disentis` vs. `Disentis/Mustér`), Davos-Aufsplittung (`Davos`/`Davos Dorf`/`Davos Platz`). Google-Titel kürzen oft ab → Normalisierung nötig.
- **Gattungswörter sind Namensbestandteil:** „Bernina" ≠ „Bernina Bar" (beide Thusis!), „Alpina" ≠ „Alpina Resort" → **kein pauschales Strippen** von Bar/Restaurant/Hotel/Resort.
- **Live-Kalender aktuell nicht lesbar** (Access-Token zum Untersuchungszeitpunkt abgelaufen; Refresh braucht das `client_secret`, das nur die Edge Function hat). In der echten Function refresht `getAccessToken()` automatisch. Konsequenz: die **reale Match-Rate ist unbekannt** → zweistufiger Rollout mit Kalibrier-Scan zuerst.

## Entscheidungen (vom User abgenommen)

1. **Vorgehen: zweistufig.** Erst read-only Kalibrier-Scan (zeigt echte Titel + Match-Vorschau, ändert nichts), dann — nach kalibrierten Schwellen — die eigentliche Tagging-Logik.
2. **Was geändert wird:** Farbe + Erinnerung + unsichtbarer Betrieb-Tag. Titel/Notizen nie.
3. **Zeitraum:** Zukunft + jüngste Vergangenheit, in der UI wählbar (Default z.B. −3 Monate bis +12 Monate).
4. **Match-Strenge: konservativ** — exakt Name+Ort, nur leichte Tippfehler-Toleranz am Namen, Ort als harter Filter; Auto-Vorschlag nur bei genau 1 Kandidaten.
5. **Farbe: Lavendel** (Google `colorId = "1"`), klar abgesetzt von SBS-Push (grün 10 / rot 11 / gelb 5).

## Architektur — zweistufiger Rollout

### K2a — Kalibrier-Scan (zuerst, read-only, schreibt NICHTS)

- Neue Edge-Aktion `scan_manual` in `google-calendar-sync`.
- Liest `events.list` auf `primary` über `timeMin`/`timeMax` (aus Request), `singleEvents=true`, `orderBy=startTime`, `maxResults=250`, **Paginierung** über `nextPageToken` bis erschöpft.
- Überspringt bereits von der App erzeugte/getaggte Events (Filter `privateExtendedProperty=app=sbs_projer` bzw. Property-Prüfung).
- Matcht jeden Titel gegen die Betriebsliste (Matching-Logik unten). Gibt eine **Vorschlagsliste** + Statistik zurück, **ohne** Google zu verändern und **ohne** Mapping-Zeilen zu schreiben.
- Client: neuer Screen zeigt die Liste (Titel, Datum, vorgeschlagener Betrieb, Bucket, Grund) + Zähler „X eindeutig · Y mehrdeutig · Z ohne Treffer".
- **Zweck:** echte Datenlage sichtbar machen → Schwellen final kalibrieren, bevor Schreib-Logik gebaut wird.

### K2b — Taggen + Rückgängig (danach, mit kalibrierten Schwellen)

- Migration 133: `google_calendar_events.entity_type`-CHECK um `betrieb_manuell` erweitern (analog 132). `entity_id` ist bereits `text` → hier = Google-Event-ID.
- Edge-Aktion `apply_tags`: Eingabe Liste `[{event_id, betrieb_id}]` (nur freigegebene). Pro Event:
  - **PATCH** auf `${CAL}/${event_id}` mit **ausschliesslich** `colorId: "1"`, `reminders: {useDefault:false, overrides:[{email,1440},{popup,1440}]}`, `extendedProperties.private: {app:"sbs_projer", entity_type:"betrieb_manuell", betrieb_id:<serverId>}`. **Kein** `summary`/`description`/`start`/`end` im Body → bleiben unberührt.
  - Mapping-Upsert in `google_calendar_events` (`entity_type='betrieb_manuell'`, `entity_id=event_id`, `google_event_id=event_id`, `status`, `synced_at`).
  - Idempotenz: Events, die bereits den Marker tragen, werden übersprungen (kein doppeltes Taggen).
- Edge-Aktion `untag_manual`: alle (oder ausgewählte) `betrieb_manuell`-Mappings → PATCH, der `colorId` auf Default zurücksetzt, `reminders` auf `{useDefault:true}`, `extendedProperties.private.app` entfernt; danach Mapping-Zeile löschen. Batch-fähig → Fehllauf vollständig reversibel.
- Client: Screen um **Häkchen-Freigabe** erweitert — eindeutige Treffer vorangehakt, mehrdeutige mit Betrieb-Dropdown (Handauswahl), kein-Treffer ausgegraut; Button „X Termine taggen" → `apply_tags`; Button „K2-Tags entfernen" → `untag_manual`.

## Matching-Algorithmus (reine Funktion, TDD)

Reine Dart-Funktion (client-seitig, gegen `betriebNameMap`/`betriebOrtMap` bzw. eine Betriebsliste) **und** spiegelbildlich serverseitig im Scan — die kanonische Logik wird als reine Funktion mit Unit-Tests gebaut; der Scan nutzt dieselbe Normalisierung. (Entscheidung Implementierung: Matching primär im Client aus den bereits vorhandenen Betriebs-Maps, damit die reine Funktion voll testbar ist und die Edge-Function schlank bleibt; der Scan liefert nur rohe Events, der Client matcht. Alternative — Matching in der Function — wird im Plan bewertet, Default = Client.)

**Normalisierung (beidseitig, Titel & Betrieb):**
- lowercase; Umlaut-/Akzent-Faltung (`ä→a`/`ae`, `é→e`, `ü→u`, `ö→o`, `ß→ss`); Whitespace-Kollaps; Satzzeichen zu Leerzeichen.
- **Ort zusätzlich:** Teil vor `/` bzw. `-` nehmen (`Lenzerheide/Lai`→`lenzerheide`, `Klosters-Serneus`→`klosters`); Davos-Suffixe tolerant (`davos dorf`/`davos platz`/`davos` matchen alle auf `davos`); DB-Varianten (`disentis` ⊇ `disentis/mustér`) über den Präfix.

**Kandidatensuche:**
1. Kandidat = Betrieb, dessen normalisierter **Name** als zusammenhängende Token-Folge im normalisierten Titel vorkommt — exakt **oder** mit Tippfehler-Toleranz (Levenshtein ≤1 für kurze, ≤2 für längere Namen; Schwelle nach Kalibrier-Scan final).
2. **Harte Ort-Bestätigung:** Kandidat nur gültig, wenn sein normalisierter **Ort** ebenfalls im normalisierten Titel vorkommt.
3. Bucket:
   - **eindeutig** — genau 1 gültiger Kandidat (mit klarem Abstand zum nächstbesten) → Auto-Vorschlag, in Vorschau vorangehakt.
   - **mehrdeutig** — ≥2 gültige Kandidaten → angezeigt mit Dropdown, **nie** auto-getaggt.
   - **kein Treffer** — 0 gültige Kandidaten (auch: privater/fremder Termin) → nicht angefasst, ausgegraut.
- **Keine Gattungswort-Entfernung** (Bernina/Bernina Bar, Alpina/Alpina Resort bleiben getrennt).

## Datenmodell

- **Migration 133** (`Datenbank/migrations/133_gcal_events_betrieb_manuell.sql`): `ALTER TABLE google_calendar_events DROP CONSTRAINT … ; ADD CONSTRAINT … CHECK (entity_type IN ('termin','pikett','event','betrieb_reinigung','betrieb_manuell'))`. Keine weiteren Spalten (entity_id ist `text`, RLS service_role-only bleibt).

## Edge-Function-Aktionen (Request/Response)

```
action = "scan_manual"
  req:  { time_min: ISO, time_max: ISO }
  resp: { ok: true, events: [ { event_id, summary, start_date, is_all_day } ], scanned: N, skipped_tagged: M }
        (nur ROHE Events; Matching im Client. Kein Schreiben.)

action = "apply_tags"
  req:  { items: [ { event_id, betrieb_id } ] }
  resp: { ok: true, tagged: N, skipped_already: K, errors: [ {event_id, fehler} ] }

action = "untag_manual"
  req:  { event_ids?: [..] }        // leer/fehlend = alle betrieb_manuell des Users
  resp: { ok: true, untagged: N, errors: [ … ] }
```

- Alle Aktionen: JWT-Auth (getUser→401), Token via `getAccessToken()` (Refresh automatisch), `not_connected`→`{skipped}`.
- `reconcile` bleibt unberührt und fasst `betrieb_manuell` **nicht** an (Orphan-Delete ist bereits auf `pikett`/`event` begrenzt).

## Client

- `GoogleCalendarSyncService`: neue Methoden `scanManuelleTermine(timeMin, timeMax)`, `applyTags(items)`, `untagManuelle(eventIds?)` (invoke-Muster wie `syncBetriebReinigungen`).
- Reine Matching-Funktion `core/util/google_termin_match.dart` (Normalisierung + Kandidatenlogik + Bucket) mit TDD-Suite (Kollisionen Alpina/Calanda, Ort-Slash/Davos, Tippfehler, Gattungswort-Trennung, kein-Treffer/privat).
- Neuer Screen `presentation/screens/google_kalender/google_termine_screen.dart`: Zeitraum-Auswahl, „Laden"-Button (`scan_manual` → Client-Matching → Buckets), Vorschau-Liste (Häkchen-Muster wie `saison_reinigung_dialog`/`_zeigeUebernahmeDialog`), „X Termine taggen", „K2-Tags entfernen", Fortschritts-/Fehleranzeige.
- Einstieg: Eintrag in Einstellungen (bei den Google-Kalender-Optionen) oder Dashboard — Gate über `googleCalendarStatusProvider` (nur wenn verbunden).
- Route in `router.dart`.

## Sicherheitsmodell (verbindlich)

- **Nur PATCH, nie PUT/POST** für bestehende Events → `summary`/`description`/Zeiten werden nie mitgesendet.
- **Idempotenz:** Marker (`extendedProperties.private.app=sbs_projer`, `entity_type=betrieb_manuell`) + Mapping-Zeile; getaggte Events werden beim Scan/Apply übersprungen.
- **Nur klar erkannt:** Auto-Aktion ausschliesslich bei genau-1-Treffer inkl. Ort-Bestätigung; 0/mehrdeutig/privat werden nie automatisch angefasst.
- **Vorschau-Pflicht:** `scan_manual` schreibt nichts; Änderung nur nach Häkchen-Freigabe via `apply_tags` mit expliziter Event-Liste.
- **Reversibel:** `untag_manual` entfernt Farbe/Erinnerung/Tag + Mapping (Farb-Reset auf Default testen — Google setzt „keine Farbe" nur implizit).
- **Privat geschützt:** Termine ohne gültigen Betrieb-Match fallen in „kein Treffer" und bleiben unberührt.

## Edge Cases

- Serientermine: `singleEvents=true` → Einzeltermine statt Master.
- Paginierung: `nextPageToken` bis erschöpft.
- Rate-Limits: PATCH pro Event; Fortschrittsanzeige + idempotente Wiederaufnahme (bereits Getaggte werden übersprungen).
- Ganztägig vs. Zeit-Termin: Erinnerung einheitlich `email`+`popup` je 1440 Min (wie K1), unabhängig davon ob all-day oder Zeit-Termin.
- Event ohne Ort im Titel: bleibt „kein Treffer" (bewusst konservativ).

## Wiederverwendung

Server: `getAccessToken` (Refresh), `gfetch`, `CAL`, `extendedProperties`-Muster, JWT-Auth, `google_calendar_events`. Client: `GoogleCalendarSyncService`-Invoke-Muster, `googleCalendarStatusProvider`, `betriebNameMapProvider`/`betriebOrtMapProvider`, Häkchen-Dialog-Muster, `reconcile`-Button-Muster.

## Test-Strategie

- **TDD** für die reine Matching-Funktion (Kern des Risikos): Normalisierung, Kollisionen, Ort-Disambiguierung, Tippfehler-Toleranz, Gattungswort-Trennung, Buckets.
- Kalibrier-Scan (K2a) als reale Datenprobe → Schwellen justieren, bevor K2b gebaut wird.
- Live-Test User-getrieben: erst Scan ansehen, dann kleine Freigabe, dann Untag prüfen.

## Rollout / Deploy

- **v0.34.0** = K2a (Scan-Aktion + Screen, read-only). User sieht echte Daten → Feedback → Schwellen final.
- **v0.35.0** = K2b (Migration 133 + `apply_tags`/`untag_manual` + Freigabe-UI). Nach Live-Prüfung scharf.
- Edge-Function-Deploy via CLI (`npx supabase functions deploy google-calendar-sync --project-ref pltbaqqwpnmdajwgnhpd`), App-Deploy via gh-pages-Workflow.

## Risiken

- Match-Rate real unbekannt bis K2a → Schwellen erst danach fixierbar (deshalb read-only zuerst).
- Fehlzuordnung bei Kollisionen, wenn der Ort im Titel fehlt/abgekürzt ist → harte Ort-Bestätigung, sonst mehrdeutig/kein Treffer.
- Ort-Inkonsistenz in der DB → Normalisierung (Slash/Davos/Präfix), aber Über-Verschmelzung vermeiden.
- Versehentliches PUT statt PATCH würde Titel überschreiben → K2 nutzt striktes eigenes PATCH-Muster, nicht `upsertEvent`.
- Farb-Reset beim Untag muss verifiziert werden (Google-Default-Verhalten).
- CHECK-Constraint: neuer `entity_type` muss per Migration 133 vor `apply_tags` existieren.

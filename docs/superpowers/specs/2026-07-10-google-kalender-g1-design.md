# Google-Kalender G1 — Verbindung & Datenmodell (Design)

**Datum:** 2026-07-10
**Status:** Vom User abgenommen (Richtung + Entscheidungen 10.07.2026) — Spec zur Review.
**Herkunft:** Termine-Komplettüberarbeitung, Paket 06. Erstes von vier Teil-Paketen (G1–G4).
Grundlage: [Recherche](2026-07-10-google-kalender-recherche.md).

## Ziel & Kontext

Das **Fundament** für die Hybrid-Google-Kalender-Integration: eine sichere Verbindung zwischen
SBS-Projer und dem Google Kalender des Nutzers herstellen (OAuth, serverseitig), und das
`Termin`-Datenmodell auf **mehrere frei einstellbare Erinnerungen** umstellen. **Noch kein sichtbarer
Sync** — das kommt in G2 (Push) und G3 (Import).

**Getroffene Entscheidungen (abgenommen):**
- Konto: **privates @gmail**, OAuth-Consent-Screen auf **„In Production"** (einmalige Unverified-Warnung
  akzeptieren, danach stabiler Refresh-Token). Scope: **`calendar.events`** (kleiner sensitive scope;
  der eigene „SBS Projer"-Kalender wird in G2 einmal manuell angelegt).
- Login bleibt (E-Mail/Passwort); **separater „Mit Google Kalender verbinden"-Button** in Einstellungen.
- Erinnerungs-Kanäle: **E-Mail immer + Popup** (Nutzer: **Android/Pixel 9** → Popup zuverlässig).
- Mehrere Erinnerungen pro Termin (bis 5), frei in Minuten.
- OAuth **serverseitig**; Refresh-Token **nie im Browser**.

**Ist-Zustand (verifiziert):**
- Edge-Function-Muster vorhanden (`supabase/functions/*`, Deno.serve + CORS + `Deno.env.get`, Deploy
  `supabase functions deploy X`, Secrets `supabase secrets set`). Beispiel: `betrieb-google-lookup`.
- `Termin` (data/models/termin.dart): Felder `erinnerungTage=3`, `erinnerungAktiv=false`,
  `erinnerungVorlaufMinuten=1440` (**einzelne** Erinnerung), `betriebId` **Pflichtfeld**.
- Supabase Auth = E-Mail/Passwort. Supabase-Projekt `pltbaqqwpnmdajwgnhpd`.

## Baustein 1 — Google Cloud Console Setup (manuell, von mir Schritt-für-Schritt angeleitet)

Einmalige Einrichtung durch den User (keine Secrets im Chat):
1. Google-Cloud-Projekt anlegen, **Google Calendar API** aktivieren.
2. **OAuth-Consent-Screen**: User Type „External", Publishing Status **„In Production"**, Scope
   **`.../auth/calendar.events`**, App-Name „SBS Projer".
3. **OAuth-Client-ID** (Typ **„Web application"**):
   - Authorized redirect URI: `https://danielproyer.github.io/sbs-projer-dev/` (App-Root; App liest
     `?code` beim Start) — zusätzlich `http://localhost:PORT/` fürs lokale Testen.
   - Ergebnis: **Client-ID** (öffentlich, darf in die App) + **Client-Secret**.
4. Client-Secret als Supabase-Secret setzen: `GOOGLE_OAUTH_CLIENT_SECRET`. Client-ID als
   `GOOGLE_OAUTH_CLIENT_ID` (Secret) **und** in die App-`.env` (öffentlich).

*(Diese Schritte liefere ich als Klick-Anleitung; Umsetzung im Plan als „Prerequisite"-Task.)*

## Baustein 2 — Datenbank

**Migration `129_google_calendar_tokens.sql`:**
- Tabelle `google_calendar_tokens`: `user_id uuid PK REFERENCES auth.users`, `refresh_token text`,
  `access_token text`, `access_token_expiry timestamptz`, `google_email text`, `scope text`,
  `calendar_id text NULL` (in G2 gesetzt), `connected_at timestamptz`, `updated_at timestamptz`.
  - **RLS aktiv, KEINE Client-Policy** → nur `service_role` (Edge Functions) liest/schreibt. Der
    Browser bekommt die Tokens nie.
- Tabelle `google_calendar_status` (Client-lesbar): `user_id uuid PK`, `connected boolean default false`,
  `google_email text`, `connected_at timestamptz`, `updated_at timestamptz`.
  - RLS: `SELECT`/keine Writes für `auth.uid() = user_id`. Wird von der Edge Function (service_role)
    geschrieben. So sieht die App den **Status**, nie den Token.

## Baustein 3 — Edge Functions

**`google-oauth-exchange`** (JWT-verifiziert — Nutzer aus Auth-Kontext):
- Input `{ code, code_verifier, redirect_uri }`.
- Nutzer-ID aus dem Supabase-Auth-Header (Client mit Caller-JWT → `auth.getUser()`).
- Token-Tausch gegen `https://oauth2.googleapis.com/token` mit `client_id` + **`client_secret`** +
  `code` + `code_verifier` + `grant_type=authorization_code` + `redirect_uri`.
  (Consent-URL setzt `access_type=offline` + `prompt=consent` → Refresh-Token garantiert.)
- Speichert `refresh_token`/`access_token`/Expiry in `google_calendar_tokens` (service_role) und
  setzt `google_calendar_status.connected=true` + `google_email`.
- Antwort `{ connected: true, email }`.

**`google-calendar-disconnect`** (JWT-verifiziert):
- Widerruft den Token bei Google (`https://oauth2.googleapis.com/revoke`), löscht die Token-Zeile,
  setzt `status.connected=false`.

*(Ein Access-Token-Refresh-Helper wird in G2 gebraucht — hier noch nicht.)*

## Baustein 4 — App: Verbinden-Flow + Einstellungen

- `GoogleCalendarAuthService` (neu, `services/google_calendar/`):
  - `startVerbinden()`: erzeugt PKCE (`code_verifier`/`code_challenge` S256) + `state`, legt beide in
    `sessionStorage` ab, öffnet die Google-Consent-URL (redirect same-tab) mit `scope=calendar.events`,
    `access_type=offline`, `prompt=consent`, `include_granted_scopes=true`.
  - `verarbeiteRedirect()`: beim App-Start prüfen, ob `?code`+`state` in der URL sind; `state`
    validieren; `code`+`code_verifier` an `google-oauth-exchange` senden; URL bereinigen (History
    ersetzen).
  - `trennen()`: ruft `google-calendar-disconnect`.
- `googleCalendarStatusProvider` (Riverpod): liest `google_calendar_status` (verbunden? welche Mail?).
- **Einstellungen-Screen**: Abschnitt „Google Kalender" mit Status (verbunden mit `email` / nicht
  verbunden), Button **„Verbinden"** bzw. **„Trennen"**, kurzer Hinweistext.
- Web-first: läuft im Browser; nutzt `Uri.base`/`window` für den Redirect.

## Baustein 5 — `Termin`: mehrere Erinnerungen

- **Migration `130_termin_erinnerungen.sql`:** Spalte `erinnerungen jsonb NOT NULL DEFAULT '[]'`
  (Array `[{ "methode": "email"|"popup", "minuten": int }]`, max 5). Backfill: wenn
  `erinnerung_aktiv` → `[{methode:'popup', minuten: erinnerung_vorlauf_minuten}]`, sonst `[]`. Alte
  Spalten bleiben vorerst (Fallback), werden in G4 entfernt.
- **Modell** `TerminErinnerung { String methode; int minuten }` + `Termin.erinnerungen:
  List<TerminErinnerung>`. DTO fromJson/toJson (jsonb ↔ Liste). Isar-Local: als `String
  erinnerungenJson` (serialisiert) speichern, Mapper konvertiert (Isar-freundlich, folgt Projekt-Gotcha).
- **Reminder-Editor** im `termin_form_screen.dart`: Liste von Zeilen (Methode-Dropdown E-Mail/Popup +
  Minuten-Eingabe mit lesbaren Presets 0/10/30/60/1440/2880 + frei), „+ Erinnerung" (bis 5), Löschen je
  Zeile. Ersetzt die bisherigen Einzel-Felder in der Form (die alten Felder bleiben im Modell als
  Fallback bis G4).
- Reine Helfer `erinnerung_util.dart` (TDD): `minutenLabel(int) → String` („2 Std. vorher",
  „1 Tag vorher"), `parseErinnerungen(jsonb)`, `erinnerungenToJson(list)`.

## Abgrenzung (spätere Pakete)

- **G2**: „SBS Projer"-Kalender anlegen; Edge Function `google-calendar-sync` (Push App→Google) +
  pg_cron; Pikett/Events/App-Termine als Events mit `reminders.overrides` (E-Mail+Popup,
  `Europe/Zurich`, all-day `end.date`-exklusiv, Konflikt-Regel „App gewinnt"); Access-Token-Refresh.
- **G3**: Import Google→App via `syncToken` (410-Fallback), read-only; `Termin.betriebId` optional.
- **G4**: Termine-Screen/Kalender-UI-Politur, alte Einzel-Erinnerungsfelder entfernen.

## Sicherheit

- Refresh-/Access-Token **ausschliesslich** in `google_calendar_tokens` (RLS: nur service_role). Der
  Browser sieht nur `google_calendar_status`.
- `client_secret` nur als Supabase-Secret; nie in der App, nie im Chat.
- OAuth mit **PKCE (S256)** + `state` (CSRF). `code_verifier` nur in `sessionStorage`, einmalig.
- Edge Functions JWT-verifiziert → Tokens sind pro authentifiziertem Nutzer.

## Tests & Verifikation

- **Unit-Tests** (`erinnerung_util_test.dart`): `minutenLabel` (Minuten/Stunden/Tage-Grenzen),
  `parseErinnerungen`/`erinnerungenToJson` (Round-Trip, leer, max 5, ungültige Einträge gefiltert).
- `flutter analyze` sauber; Tests grün.
- **DB**: Migrationen via MCP anwenden; RLS prüfen (Client kann `google_calendar_tokens` **nicht**
  lesen, `google_calendar_status` schon).
- **Edge Functions**: deploy; `google-oauth-exchange` mit echtem Consent einmal durchspielen →
  Token gespeichert, Status „verbunden mit <email>". `trennen` → Status weg, Token gelöscht.
- **Visueller Live-Test** (Pflicht, da UI): Einstellungen zeigen Verbinden/Status/Trennen; Termin-
  Formular erlaubt mehrere Erinnerungen anzulegen/speichern/wieder öffnen.

## Deploy

Ein Paket **v0.31.0** nach Deploy-Workflow (CLAUDE.md) + `apply_migration` (129, 130) +
`deploy_edge_function` (google-oauth-exchange, google-calendar-disconnect). Secrets vom User gesetzt.

# Google-Kalender G1 (Verbindung & Datenmodell) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** SBS-Projer sicher mit dem Google Kalender verbinden (OAuth serverseitig) und `Termin` auf mehrere frei einstellbare Erinnerungen umstellen — das Fundament für den späteren Sync (G2/G3).

**Architecture:** OAuth läuft ausschliesslich serverseitig: die Flutter-Web-App startet den PKCE-Flow, eine Supabase Edge Function tauscht den Code gegen Tokens und legt den Refresh-Token in einer RLS-gesperrten Tabelle ab (Browser sieht nur Verbindungs-Status). `Termin` bekommt ein `erinnerungen`-jsonb-Array (bis 5) mit Reminder-Editor im Formular.

**Tech Stack:** Flutter Web, Riverpod, Supabase (Postgres/Edge Functions/Auth), Deno/TypeScript, `crypto` (PKCE), `flutter_test`.

**Wichtige Fakten (verifiziert):**
- Edge-Function-Aufruf: `SupabaseService.client.functions.invoke('name', body: {...})` → `response.data` / `response.status` (Muster: `betrieb_google_service.dart`). Edge Functions liegen in `supabase/functions/<name>/index.ts`, Deploy via MCP `deploy_edge_function`. Supabase liefert in Functions automatisch `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`.
- Env: `dotenv.env['KEY']`; `.env` liegt im App-Root (`sbs_projer_app/.env`, bereits als Asset in `pubspec.yaml`). `SupabaseService.client`, `SupabaseService.isAuthenticated`.
- `main()` (main.dart): `dotenv.load` → `SupabaseService.initialize` → Auth-Refresh → (native: Isar/Sync) → `runApp`.
- `Termin` (data/models/termin.dart): Felder inkl. `erinnerungTage`/`erinnerungAktiv`/`erinnerungVorlaufMinuten` (einzeln), `fromJson`/`toJson`.
- `TerminLocal` (data/local/termin_local.dart @collection + web/termin_local_web.dart) + `TerminMapper` (fromDto/toJson).
- `termin_form_screen.dart`: State `_erinnerungTage=3`/`_erinnerungAktiv=false`/`_erinnerungVorlauf=1440` (Z. 44-46), Laden (Z. 83-85), Speichern (Z. 148-150), Abschnitt „Erinnerung" (Z. ~481-518, `SwitchListTile` + `DropdownButtonFormField` mit `erinnerungVorlaufOptionen`).
- Migrationen: `Datenbank/migrations/`, angewandt via MCP `apply_migration`. Zuletzt 128.
- Konto @gmail, Scope `calendar.events` (+ `email` für Anzeige der verbundenen Adresse). Deploy **v0.31.0**.

**Umgebung/Befehle:**
```bash
export PATH="$PATH:/c/flutter/bin"
cd "D:/01_SBS_Projer_GmbH/00_Entwicklung/SBS Projer DEV/sbs_projer_app"
```
Tests: `flutter test test/erinnerung_util_test.dart`  ·  Analyse: `flutter analyze`  ·  Isar-Codegen: `dart run build_runner build --delete-conflicting-outputs`

---

## File Structure

- `supabase/functions/google-oauth-exchange/index.ts` — Code→Token-Tausch, Token speichern (Create).
- `supabase/functions/google-calendar-disconnect/index.ts` — Token widerrufen/löschen (Create).
- `Datenbank/migrations/129_google_calendar_tokens.sql` — Token- + Status-Tabelle (Create).
- `Datenbank/migrations/130_termin_erinnerungen.sql` — `termine.erinnerungen` jsonb (Create).
- `sbs_projer_app/lib/services/google_calendar/google_calendar_auth_service.dart` — PKCE-Flow (Create).
- `sbs_projer_app/lib/services/google_calendar/browser_redirect.dart` (+ `_web.dart`/`_stub.dart`) — Web-Redirect/sessionStorage (Create).
- `sbs_projer_app/lib/presentation/providers/google_calendar_providers.dart` — Status-Provider (Create).
- `sbs_projer_app/lib/data/models/termin_erinnerung.dart` — Erinnerungs-Wertobjekt (Create).
- `sbs_projer_app/lib/core/util/erinnerung_util.dart` (+ Test) — Label/Parse/Serialize (Create).
- Modify: `termin.dart`, `termin_local.dart`, `web/termin_local_web.dart`, `termin_mapper.dart`, `termin_form_screen.dart`, `einstellungen_screen.dart`, `main.dart`, `sbs_projer_app/.env`, `pubspec.yaml`.

---

## Task 1: Prerequisite — Google Cloud Console + Secrets (User, geführt)

**Kein Code.** Diese Schritte macht **der User** (Daniel) einmalig; der Implementer kann parallel Tasks 2–10 bauen, nur der Live-Test (Task 11) braucht sie fertig.

- [ ] **Step 1: Projekt + API** — In der [Google Cloud Console](https://console.cloud.google.com) ein Projekt „SBS Projer" anlegen → **Google Calendar API** aktivieren.
- [ ] **Step 2: OAuth-Consent-Screen** — User Type „External"; App-Name „SBS Projer"; Support-Mail = eigene @gmail; Scope **`.../auth/calendar.events`** + `email` hinzufügen; **Publishing Status → „In Production"** (die „unbestätigte App"-Warnung wird beim Verbinden einmal akzeptiert).
- [ ] **Step 3: OAuth-Client-ID** — Typ **„Web application"**; Name „SBS Projer Web".
  - **Authorized redirect URIs:** `https://danielproyer.github.io/sbs-projer-dev/`
  - **Authorized JavaScript origins:** `https://danielproyer.github.io`
  - Ergebnis: **Client-ID** (öffentlich) + **Client-Secret** notieren.
- [ ] **Step 4: Supabase-Secrets** setzen (Projekt `pltbaqqwpnmdajwgnhpd`) — via Supabase-Dashboard → Edge Functions → Secrets, oder CLI:
  `supabase secrets set GOOGLE_OAUTH_CLIENT_ID=<id> GOOGLE_OAUTH_CLIENT_SECRET=<secret>`
- [ ] **Step 5: Client-ID an den Implementer geben** — die **Client-ID** (nicht das Secret!) kommt in Task 9 in die App-`.env`.

*(Ich liefere Daniel diese Schritte als Klick-Anleitung im Chat; das Secret gibt er nie im Chat ein.)*

---

## Task 2: Migration 129 — Token- + Status-Tabelle

**Files:**
- Create: `Datenbank/migrations/129_google_calendar_tokens.sql`

- [ ] **Step 1: SQL schreiben**

```sql
-- 129: Google-Kalender OAuth-Token (server-only) + Verbindungs-Status (client-lesbar)

create table if not exists public.google_calendar_tokens (
  user_id uuid primary key references auth.users(id) on delete cascade,
  refresh_token text not null,
  access_token text,
  access_token_expiry timestamptz,
  google_email text,
  scope text,
  calendar_id text,
  connected_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.google_calendar_tokens enable row level security;
-- BEWUSST keine Policy: nur service_role (Edge Functions) hat Zugriff. Der Browser sieht die Tokens nie.

create table if not exists public.google_calendar_status (
  user_id uuid primary key references auth.users(id) on delete cascade,
  connected boolean not null default false,
  google_email text,
  connected_at timestamptz,
  updated_at timestamptz not null default now()
);
alter table public.google_calendar_status enable row level security;
create policy "gcal_status_select_own" on public.google_calendar_status
  for select using (auth.uid() = user_id);
-- kein INSERT/UPDATE/DELETE fuer Clients: nur service_role schreibt.
```

- [ ] **Step 2: Migration anwenden** — via MCP `apply_migration` (name `129_google_calendar_tokens`, obiges SQL) auf Projekt `pltbaqqwpnmdajwgnhpd`.

- [ ] **Step 3: RLS prüfen** — via MCP `execute_sql`:
  `select tablename, rowsecurity from pg_tables where tablename in ('google_calendar_tokens','google_calendar_status');`
  Expected: beide `rowsecurity = true`.

- [ ] **Step 4: Commit**

```bash
git add Datenbank/migrations/129_google_calendar_tokens.sql
git commit -m "feat(gcal): Migration 129 google_calendar_tokens + status (RLS)"
```

---

## Task 3: Edge Function `google-oauth-exchange`

**Files:**
- Create: `supabase/functions/google-oauth-exchange/index.ts`

- [ ] **Step 1: Function schreiben**

```ts
// Supabase Edge Function: google-oauth-exchange
// Tauscht OAuth-Code (PKCE) gegen Tokens und speichert den Refresh-Token server-seitig.
// Deploy: supabase functions deploy google-oauth-exchange
// Secrets: GOOGLE_OAUTH_CLIENT_ID, GOOGLE_OAUTH_CLIENT_SECRET
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  const json = (b: unknown, s = 200) =>
    new Response(JSON.stringify(b), {
      status: s,
      headers: { ...CORS, "Content-Type": "application/json" },
    });

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const clientId = Deno.env.get("GOOGLE_OAUTH_CLIENT_ID");
    const clientSecret = Deno.env.get("GOOGLE_OAUTH_CLIENT_SECRET");
    if (!clientId || !clientSecret) {
      return json({ error: "OAuth not configured" }, 500);
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return json({ error: "unauthorized" }, 401);

    const { code, code_verifier, redirect_uri } = await req.json();
    if (!code || !code_verifier || !redirect_uri) {
      return json({ error: "missing params" }, 400);
    }

    const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        code,
        client_id: clientId,
        client_secret: clientSecret,
        redirect_uri,
        grant_type: "authorization_code",
        code_verifier,
      }),
    });
    const token = await tokenRes.json();
    if (!tokenRes.ok || !token.refresh_token) {
      console.error("token exchange failed", token);
      return json(
        { error: token.error_description || token.error || "no refresh_token" },
        502,
      );
    }

    let email: string | null = null;
    try {
      const infoRes = await fetch(
        "https://www.googleapis.com/oauth2/v2/userinfo",
        { headers: { Authorization: `Bearer ${token.access_token}` } },
      );
      if (infoRes.ok) email = (await infoRes.json()).email ?? null;
    } catch (_) { /* egal */ }

    const now = new Date().toISOString();
    const expiry = new Date(Date.now() + (token.expires_in ?? 3600) * 1000)
      .toISOString();
    const admin = createClient(supabaseUrl, serviceKey);
    await admin.from("google_calendar_tokens").upsert({
      user_id: user.id,
      refresh_token: token.refresh_token,
      access_token: token.access_token,
      access_token_expiry: expiry,
      google_email: email,
      scope: token.scope,
      updated_at: now,
    });
    await admin.from("google_calendar_status").upsert({
      user_id: user.id,
      connected: true,
      google_email: email,
      connected_at: now,
      updated_at: now,
    });
    return json({ connected: true, email });
  } catch (e) {
    console.error(e);
    return json({ error: (e as Error).message }, 500);
  }
});
```

- [ ] **Step 2: Deployen** — via MCP `deploy_edge_function` (name `google-oauth-exchange`, obiger Code) auf `pltbaqqwpnmdajwgnhpd`.

- [ ] **Step 3: Commit**

```bash
git add supabase/functions/google-oauth-exchange/index.ts
git commit -m "feat(gcal): Edge Function google-oauth-exchange (PKCE Token-Tausch)"
```

---

## Task 4: Edge Function `google-calendar-disconnect`

**Files:**
- Create: `supabase/functions/google-calendar-disconnect/index.ts`

- [ ] **Step 1: Function schreiben**

```ts
// Supabase Edge Function: google-calendar-disconnect
// Widerruft den Google-Refresh-Token und loescht die Verbindung.
// Deploy: supabase functions deploy google-calendar-disconnect
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  const json = (b: unknown, s = 200) =>
    new Response(JSON.stringify(b), {
      status: s,
      headers: { ...CORS, "Content-Type": "application/json" },
    });

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const authHeader = req.headers.get("Authorization") ?? "";
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return json({ error: "unauthorized" }, 401);

    const admin = createClient(supabaseUrl, serviceKey);
    const { data: row } = await admin
      .from("google_calendar_tokens")
      .select("refresh_token")
      .eq("user_id", user.id)
      .maybeSingle();
    if (row?.refresh_token) {
      try {
        await fetch(
          "https://oauth2.googleapis.com/revoke?token=" +
            encodeURIComponent(row.refresh_token),
          {
            method: "POST",
            headers: { "Content-Type": "application/x-www-form-urlencoded" },
          },
        );
      } catch (_) { /* egal */ }
    }
    await admin.from("google_calendar_tokens").delete().eq("user_id", user.id);
    await admin.from("google_calendar_status").upsert({
      user_id: user.id,
      connected: false,
      google_email: null,
      connected_at: null,
      updated_at: new Date().toISOString(),
    });
    return json({ connected: false });
  } catch (e) {
    console.error(e);
    return json({ error: (e as Error).message }, 500);
  }
});
```

- [ ] **Step 2: Deployen** — via MCP `deploy_edge_function` (name `google-calendar-disconnect`).

- [ ] **Step 3: Commit**

```bash
git add supabase/functions/google-calendar-disconnect/index.ts
git commit -m "feat(gcal): Edge Function google-calendar-disconnect (revoke)"
```

---

## Task 5: App — PKCE-Auth-Service + Browser-Helper + Status-Provider

**Files:**
- Create: `sbs_projer_app/lib/services/google_calendar/browser_redirect.dart`
- Create: `sbs_projer_app/lib/services/google_calendar/browser_redirect_web.dart`
- Create: `sbs_projer_app/lib/services/google_calendar/browser_redirect_stub.dart`
- Create: `sbs_projer_app/lib/services/google_calendar/google_calendar_auth_service.dart`
- Create: `sbs_projer_app/lib/presentation/providers/google_calendar_providers.dart`
- Modify: `sbs_projer_app/pubspec.yaml` (crypto), `sbs_projer_app/.env`, `sbs_projer_app/lib/main.dart`

- [ ] **Step 1: `crypto`-Abhängigkeit sicherstellen**

Run: `flutter pub add crypto`
Expected: `crypto` erscheint in `pubspec.yaml` unter `dependencies` (falls schon vorhanden: „already a dependency", ok).

- [ ] **Step 2: Browser-Helper (conditional export)**

Create `browser_redirect_stub.dart`:

```dart
// Native-Stub: der OAuth-Verbinden-Flow läuft nur im Web.
void navigateTo(String url) =>
    throw UnsupportedError('Google-Verbinden nur im Web verfügbar');
void clearQuery(String cleanUrl) {}
void sessionSet(String key, String value) {}
String? sessionGet(String key) => null;
void sessionRemove(String key) {}
```

Create `browser_redirect_web.dart`:

```dart
import 'dart:html' as html;

void navigateTo(String url) => html.window.location.href = url;

void clearQuery(String cleanUrl) =>
    html.window.history.replaceState(null, '', cleanUrl);

void sessionSet(String key, String value) =>
    html.window.sessionStorage[key] = value;

String? sessionGet(String key) => html.window.sessionStorage[key];

void sessionRemove(String key) => html.window.sessionStorage.remove(key);
```

Create `browser_redirect.dart`:

```dart
export 'browser_redirect_stub.dart'
    if (dart.library.html) 'browser_redirect_web.dart';
```

- [ ] **Step 3: Auth-Service**

Create `google_calendar_auth_service.dart`:

```dart
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sbs_projer_app/services/google_calendar/browser_redirect.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class GoogleCalendarVerbindenResult {
  final bool erfolg;
  final String? info; // E-Mail bei Erfolg, Fehlermeldung sonst
  const GoogleCalendarVerbindenResult(this.erfolg, this.info);
}

class GoogleCalendarAuthService {
  static const _authEndpoint =
      'https://accounts.google.com/o/oauth2/v2/auth';
  static const _scope =
      'https://www.googleapis.com/auth/calendar.events email';

  static String get _clientId => dotenv.env['GOOGLE_OAUTH_CLIENT_ID'] ?? '';
  static String get _redirectUri =>
      dotenv.env['GOOGLE_OAUTH_REDIRECT_URI'] ??
      '${Uri.base.origin}${Uri.base.path}';

  /// Startet den Verbinden-Flow (Web): PKCE erzeugen, zu Google navigieren.
  static void verbinden() {
    final verifier = _randomString(64);
    final challenge = _s256(verifier);
    final state = _randomString(24);
    sessionSet('gcal_verifier', verifier);
    sessionSet('gcal_state', state);
    final url = Uri.parse(_authEndpoint).replace(queryParameters: {
      'client_id': _clientId,
      'redirect_uri': _redirectUri,
      'response_type': 'code',
      'scope': _scope,
      'access_type': 'offline',
      'prompt': 'consent',
      'include_granted_scopes': 'true',
      'state': state,
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
    }).toString();
    navigateTo(url);
  }

  /// Beim App-Start (Web): prüft `?code`, tauscht über die Edge Function.
  /// Gibt null zurück, wenn kein OAuth-Redirect vorliegt.
  static Future<GoogleCalendarVerbindenResult?> verarbeiteRedirect() async {
    if (!kIsWeb) return null;
    final params = Uri.base.queryParameters;
    final code = params['code'];
    final state = params['state'];
    if (code == null || state == null) return null;

    final savedState = sessionGet('gcal_state');
    final verifier = sessionGet('gcal_verifier');
    clearQuery(_redirectUri); // URL immer bereinigen
    if (savedState == null || state != savedState || verifier == null) {
      return const GoogleCalendarVerbindenResult(false, 'Ungültiger State');
    }
    sessionRemove('gcal_state');
    sessionRemove('gcal_verifier');

    try {
      final res = await SupabaseService.client.functions.invoke(
        'google-oauth-exchange',
        body: {
          'code': code,
          'code_verifier': verifier,
          'redirect_uri': _redirectUri,
        },
      );
      final data = res.data;
      if (res.status != 200 || data is! Map || data['connected'] != true) {
        final msg = data is Map ? data['error']?.toString() : null;
        return GoogleCalendarVerbindenResult(false, msg ?? 'Fehler');
      }
      return GoogleCalendarVerbindenResult(true, data['email']?.toString());
    } catch (e) {
      return GoogleCalendarVerbindenResult(false, e.toString());
    }
  }

  static Future<void> trennen() async {
    await SupabaseService.client.functions
        .invoke('google-calendar-disconnect');
  }

  static String _s256(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  static String _randomString(int len) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final r = Random.secure();
    return List.generate(len, (_) => chars[r.nextInt(chars.length)]).join();
  }
}
```

- [ ] **Step 4: Status-Provider**

Create `google_calendar_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class GoogleCalendarStatus {
  final bool connected;
  final String? email;
  const GoogleCalendarStatus({required this.connected, this.email});
}

final googleCalendarStatusProvider =
    FutureProvider<GoogleCalendarStatus>((ref) async {
  final rows = await SupabaseService.client
      .from('google_calendar_status')
      .select()
      .limit(1);
  if (rows.isEmpty) return const GoogleCalendarStatus(connected: false);
  final r = rows.first;
  return GoogleCalendarStatus(
    connected: r['connected'] == true,
    email: r['google_email'] as String?,
  );
});
```

- [ ] **Step 5: `.env` ergänzen**

In `sbs_projer_app/.env` anhängen (Client-ID aus Task 1 Step 5; **kein** Secret hier):

```
GOOGLE_OAUTH_CLIENT_ID=DEINE_CLIENT_ID.apps.googleusercontent.com
GOOGLE_OAUTH_REDIRECT_URI=https://danielproyer.github.io/sbs-projer-dev/
```

- [ ] **Step 6: Redirect beim App-Start verarbeiten**

In `main.dart` **nach** dem Auth-Refresh-Block (nach Zeile 35, vor dem `if (!kIsWeb)`-Block) einfügen:

```dart
  // OAuth-Redirect von Google verarbeiten (Web)
  if (kIsWeb && SupabaseService.isAuthenticated) {
    await GoogleCalendarAuthService.verarbeiteRedirect();
  }
```

Und den Import ergänzen:

```dart
import 'package:sbs_projer_app/services/google_calendar/google_calendar_auth_service.dart';
```

- [ ] **Step 7: Analyse**

Run: `flutter analyze lib/services/google_calendar/ lib/presentation/providers/google_calendar_providers.dart lib/main.dart`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add sbs_projer_app/lib/services/google_calendar/ sbs_projer_app/lib/presentation/providers/google_calendar_providers.dart sbs_projer_app/lib/main.dart sbs_projer_app/pubspec.yaml sbs_projer_app/.env
git commit -m "feat(gcal): PKCE-Auth-Service + Status-Provider + Redirect-Handling"
```

---

## Task 6: Einstellungen — Abschnitt „Google Kalender"

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/einstellungen/einstellungen_screen.dart`

- [ ] **Step 1: Imports ergänzen**

Nach den bestehenden Imports einfügen:

```dart
import 'package:sbs_projer_app/presentation/providers/google_calendar_providers.dart';
import 'package:sbs_projer_app/services/google_calendar/google_calendar_auth_service.dart';
```

- [ ] **Step 2: Google-Kalender-Karte in die ListView**

Im `build` (die `ListView(children: [...])`) direkt **nach** der „Geschäft"-`Card` (endet mit deren schliessender `),`) diese Karte einfügen:

```dart
          // Google Kalender
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              leading: const Icon(Icons.event, color: AppColors.primary),
              title: const Text('Google Kalender',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [
                ref.watch(googleCalendarStatusProvider).when(
                      data: (status) => _buildGoogleKalender(status),
                      loading: () => const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Text('Fehler: $e',
                          style: const TextStyle(color: AppColors.error)),
                    ),
              ],
            ),
          ),
```

- [ ] **Step 3: Helper-Methode `_buildGoogleKalender`**

In `_EinstellungenScreenState` (z.B. vor `build`) einfügen:

```dart
  Widget _buildGoogleKalender(GoogleCalendarStatus status) {
    if (status.connected) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle,
                  color: AppColors.success, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Verbunden${status.email != null ? ' · ${status.email}' : ''}'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Termine, Pikett und Events werden künftig automatisch in deinen Google Kalender geschrieben (folgt in einem nächsten Schritt).',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.link_off, size: 18),
              label: const Text('Trennen'),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              onPressed: () async {
                await GoogleCalendarAuthService.trennen();
                ref.invalidate(googleCalendarStatusProvider);
              },
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Verbinde deinen Google Kalender, um Erinnerungen und Termin-Sync zu nutzen.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            icon: const Icon(Icons.event_available, size: 18),
            label: const Text('Mit Google Kalender verbinden'),
            onPressed: () => GoogleCalendarAuthService.verbinden(),
          ),
        ),
      ],
    );
  }
```

- [ ] **Step 4: Analyse**

Run: `flutter analyze lib/presentation/screens/einstellungen/einstellungen_screen.dart`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/einstellungen/einstellungen_screen.dart
git commit -m "feat(gcal): Einstellungen — Google Kalender verbinden/trennen"
```

---

## Task 7: Migration 130 — `termine.erinnerungen` (jsonb)

**Files:**
- Create: `Datenbank/migrations/130_termin_erinnerungen.sql`

- [ ] **Step 1: SQL schreiben**

```sql
-- 130: Mehrere Erinnerungen pro Termin als jsonb-Array [{methode,minuten}]
alter table public.termine
  add column if not exists erinnerungen jsonb not null default '[]'::jsonb;

-- Backfill aus den bisherigen Einzelfeldern
update public.termine
set erinnerungen = jsonb_build_array(
      jsonb_build_object('methode', 'popup', 'minuten', erinnerung_vorlauf_minuten))
where erinnerung_aktiv = true
  and erinnerungen = '[]'::jsonb;
```

- [ ] **Step 2: Anwenden** — via MCP `apply_migration` (name `130_termin_erinnerungen`).

- [ ] **Step 3: Prüfen** — via MCP `execute_sql`:
  `select count(*) filter (where jsonb_array_length(erinnerungen) > 0) as mit, count(*) as total from public.termine;`
  Expected: `mit` = Anzahl Termine mit vorher aktiver Erinnerung.

- [ ] **Step 4: Commit**

```bash
git add Datenbank/migrations/130_termin_erinnerungen.sql
git commit -m "feat(gcal): Migration 130 termine.erinnerungen jsonb + Backfill"
```

---

## Task 8: `erinnerung_util` + `TerminErinnerung` (TDD)

**Files:**
- Create: `sbs_projer_app/lib/data/models/termin_erinnerung.dart`
- Create: `sbs_projer_app/lib/core/util/erinnerung_util.dart`
- Test: `sbs_projer_app/test/erinnerung_util_test.dart`

- [ ] **Step 1: Failing-Test schreiben**

Create `sbs_projer_app/test/erinnerung_util_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/erinnerung_util.dart';
import 'package:sbs_projer_app/data/models/termin_erinnerung.dart';

void main() {
  group('minutenLabel', () {
    test('0 → Zum Zeitpunkt', () => expect(minutenLabel(0), 'Zum Zeitpunkt'));
    test('10 Min', () => expect(minutenLabel(10), '10 Min. vorher'));
    test('60 → 1 Std', () => expect(minutenLabel(60), '1 Std. vorher'));
    test('120 → 2 Std', () => expect(minutenLabel(120), '2 Std. vorher'));
    test('1440 → 1 Tag', () => expect(minutenLabel(1440), '1 Tag vorher'));
    test('2880 → 2 Tage', () => expect(minutenLabel(2880), '2 Tage vorher'));
    test('90 bleibt Minuten', () => expect(minutenLabel(90), '90 Min. vorher'));
  });

  group('parseErinnerungen', () {
    test('aus Liste von Maps', () {
      final r = parseErinnerungen([
        {'methode': 'email', 'minuten': 60},
        {'methode': 'popup', 'minuten': 1440},
      ]);
      expect(r.length, 2);
      expect(r[0].methode, 'email');
      expect(r[0].minuten, 60);
      expect(r[1].methode, 'popup');
    });
    test('aus JSON-String', () {
      final r = parseErinnerungen('[{"methode":"popup","minuten":30}]');
      expect(r.single.minuten, 30);
    });
    test('leerer String → leer', () => expect(parseErinnerungen(''), isEmpty));
    test('null → leer', () => expect(parseErinnerungen(null), isEmpty));
    test('unbekannte Methode → popup', () {
      expect(parseErinnerungen([{'methode': 'x', 'minuten': 5}]).single.methode,
          'popup');
    });
    test('max 5', () {
      final r = parseErinnerungen(
          List.generate(8, (i) => {'methode': 'popup', 'minuten': i}));
      expect(r.length, 5);
    });
    test('negative/ungültige Minuten gefiltert', () {
      expect(parseErinnerungen([{'methode': 'popup'}]), isEmpty);
    });
  });

  group('erinnerungenToJson', () {
    test('round-trip', () {
      const list = [
        TerminErinnerung(methode: 'email', minuten: 60),
        TerminErinnerung(methode: 'popup', minuten: 0),
      ];
      final json = erinnerungenToJson(list);
      final back = parseErinnerungen(json);
      expect(back.length, 2);
      expect(back[0].methode, 'email');
      expect(back[1].minuten, 0);
    });
    test('kappt auf 5', () {
      final list = List.generate(
          7, (i) => TerminErinnerung(methode: 'popup', minuten: i));
      expect(parseErinnerungen(erinnerungenToJson(list)).length, 5);
    });
  });
}
```

- [ ] **Step 2: Test ausführen (muss fehlschlagen)**

Run: `flutter test test/erinnerung_util_test.dart`
Expected: FAIL — Dateien fehlen.

- [ ] **Step 3: `TerminErinnerung` schreiben**

Create `sbs_projer_app/lib/data/models/termin_erinnerung.dart`:

```dart
/// Eine einzelne Termin-Erinnerung (1:1 auf Google `reminders.overrides`).
class TerminErinnerung {
  final String methode; // 'email' | 'popup'
  final int minuten; // Vorlaufzeit in Minuten (0 = zum Zeitpunkt)

  const TerminErinnerung({required this.methode, required this.minuten});

  factory TerminErinnerung.fromJson(Map<String, dynamic> j) => TerminErinnerung(
        methode: j['methode'] == 'email' ? 'email' : 'popup',
        minuten: (j['minuten'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {'methode': methode, 'minuten': minuten};
}
```

- [ ] **Step 4: `erinnerung_util` schreiben**

Create `sbs_projer_app/lib/core/util/erinnerung_util.dart`:

```dart
import 'dart:convert';

import 'package:sbs_projer_app/data/models/termin_erinnerung.dart';

/// Lesbares Label für eine Vorlaufzeit in Minuten.
String minutenLabel(int minuten) {
  if (minuten <= 0) return 'Zum Zeitpunkt';
  if (minuten % 1440 == 0) {
    final t = minuten ~/ 1440;
    return t == 1 ? '1 Tag vorher' : '$t Tage vorher';
  }
  if (minuten % 60 == 0) {
    final h = minuten ~/ 60;
    return h == 1 ? '1 Std. vorher' : '$h Std. vorher';
  }
  return '$minuten Min. vorher';
}

/// Parst Erinnerungen aus jsonb (List), einem JSON-String oder null. Max 5.
List<TerminErinnerung> parseErinnerungen(dynamic raw) {
  dynamic value = raw;
  if (value is String) {
    if (value.trim().isEmpty) return const [];
    value = jsonDecode(value);
  }
  if (value is! List) return const [];
  final out = <TerminErinnerung>[];
  for (final e in value) {
    if (e is Map) {
      final min = (e['minuten'] as num?)?.toInt();
      if (min == null || min < 0) continue;
      out.add(TerminErinnerung(
        methode: e['methode'] == 'email' ? 'email' : 'popup',
        minuten: min,
      ));
      if (out.length >= 5) break;
    }
  }
  return out;
}

/// Serialisiert (max 5) Erinnerungen zu einem JSON-String (für Isar-Local).
String erinnerungenToJson(List<TerminErinnerung> list) =>
    jsonEncode(list.take(5).map((e) => e.toJson()).toList());
```

- [ ] **Step 5: Test ausführen (muss bestehen)**

Run: `flutter test test/erinnerung_util_test.dart`
Expected: PASS (alle grün).

- [ ] **Step 6: Commit**

```bash
git add sbs_projer_app/lib/data/models/termin_erinnerung.dart sbs_projer_app/lib/core/util/erinnerung_util.dart sbs_projer_app/test/erinnerung_util_test.dart
git commit -m "feat(gcal): TerminErinnerung + erinnerung_util (TDD)"
```

---

## Task 9: `Termin` DTO/Local/Web/Mapper um `erinnerungen`

**Files:**
- Modify: `sbs_projer_app/lib/data/models/termin.dart`
- Modify: `sbs_projer_app/lib/data/local/termin_local.dart`
- Modify: `sbs_projer_app/lib/data/local/web/termin_local_web.dart`
- Modify: `sbs_projer_app/lib/data/mappers/termin_mapper.dart`

- [ ] **Step 1: DTO `Termin` erweitern**

In `termin.dart` den Import ergänzen:

```dart
import 'package:sbs_projer_app/core/util/erinnerung_util.dart';
import 'package:sbs_projer_app/data/models/termin_erinnerung.dart';
```

Feld + Konstruktor-Parameter ergänzen (nach `erinnerungVorlaufMinuten`):

```dart
  final List<TerminErinnerung> erinnerungen;
```
```dart
    this.erinnerungen = const [],
```

In `factory Termin.fromJson`:

```dart
      erinnerungen: parseErinnerungen(json['erinnerungen']),
```

In `toJson()`:

```dart
      'erinnerungen': erinnerungen.map((e) => e.toJson()).toList(),
```

- [ ] **Step 2: Isar-Local + Web-Stub**

In `termin_local.dart` nach `int erinnerungVorlaufMinuten = 1440;` ergänzen:

```dart
  String erinnerungenJson = '[]';
```

Identisch in `web/termin_local_web.dart` nach dem gleichen Feld ergänzen:

```dart
  String erinnerungenJson = '[]';
```

- [ ] **Step 3: Mapper**

In `termin_mapper.dart` den Import ergänzen:

```dart
import 'package:sbs_projer_app/core/util/erinnerung_util.dart';
```

In `fromDto` nach `local.erinnerungVorlaufMinuten = ...;`:

```dart
    local.erinnerungenJson = erinnerungenToJson(dto.erinnerungen);
```

In `toJson` im Map-Literal nach `'erinnerung_vorlauf_minuten': ...,`:

```dart
      'erinnerungen': parseErinnerungen(local.erinnerungenJson)
          .map((e) => e.toJson())
          .toList(),
```

- [ ] **Step 4: Isar-Code generieren**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `termin_local.g.dart` neu generiert, ohne Fehler.

- [ ] **Step 5: Analyse**

Run: `flutter analyze lib/data/models/termin.dart lib/data/mappers/termin_mapper.dart lib/data/local/termin_local.dart`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add sbs_projer_app/lib/data/models/termin.dart sbs_projer_app/lib/data/local/termin_local.dart sbs_projer_app/lib/data/local/web/termin_local_web.dart sbs_projer_app/lib/data/mappers/termin_mapper.dart sbs_projer_app/lib/data/local/termin_local.g.dart
git commit -m "feat(gcal): Termin traegt erinnerungen (DTO/Local/Mapper)"
```

---

## Task 10: Reminder-Editor im Termin-Formular

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/termine/termin_form_screen.dart`

- [ ] **Step 1: Imports ergänzen**

```dart
import 'package:sbs_projer_app/core/util/erinnerung_util.dart';
import 'package:sbs_projer_app/data/models/termin_erinnerung.dart';
```

- [ ] **Step 2: State-Feld ergänzen**

Bei den State-Variablen (dort wo `_erinnerungVorlauf` steht, Z. ~46) ergänzen:

```dart
  List<TerminErinnerung> _erinnerungen = [];
```

(Die alten `_erinnerungTage/_erinnerungAktiv/_erinnerungVorlauf` **bleiben** vorerst — Fallback bis G4.)

- [ ] **Step 3: Laden**

Beim Vorbefüllen aus einem bestehenden `termin` (dort wo `_erinnerungVorlauf = termin.erinnerungVorlaufMinuten;`, Z. ~85) ergänzen:

```dart
      _erinnerungen = List.of(termin.erinnerungen);
```

- [ ] **Step 4: Speichern**

Beim Schreiben in `termin` (dort wo `termin.erinnerungVorlaufMinuten = _erinnerungVorlauf;`, Z. ~150) ergänzen:

```dart
      termin.erinnerungen = _erinnerungen;
      // Legacy-Felder als Fallback konsistent halten
      termin.erinnerungAktiv = _erinnerungen.isNotEmpty;
      if (_erinnerungen.isNotEmpty) {
        termin.erinnerungVorlaufMinuten = _erinnerungen.first.minuten;
      }
```

*(Falls `termin` eine unveränderliche DTO ist und über `copyWith`/Konstruktor gespeichert wird, stattdessen `erinnerungen: _erinnerungen` an der entsprechenden Konstruktion mitgeben — die umliegenden Zeilen zeigen das Muster.)*

- [ ] **Step 5: Alten „Erinnerung"-Abschnitt ersetzen**

Den bisherigen Abschnitt (ab `_buildSectionHeader('Erinnerung')` inkl. `SwitchListTile` + bedingtem `DropdownButtonFormField`, Z. ~482-519) ersetzen durch:

```dart
                  _buildSectionHeader('Erinnerungen'),
                  _buildErinnerungenEditor(),
```

- [ ] **Step 6: Editor-Methode hinzufügen**

In der State-Klasse (z.B. vor `build`) einfügen:

```dart
  static const _minutenPresets = <int>[0, 10, 30, 60, 120, 1440, 2880, 10080];

  Widget _buildErinnerungenEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < _erinnerungen.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  child: DropdownButtonFormField<String>(
                    initialValue: _erinnerungen[i].methode,
                    isDense: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'popup', child: Text('Popup')),
                      DropdownMenuItem(value: 'email', child: Text('E-Mail')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _erinnerungen[i] = TerminErinnerung(
                          methode: v, minuten: _erinnerungen[i].minuten));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _minutenPresets.contains(_erinnerungen[i].minuten)
                        ? _erinnerungen[i].minuten
                        : 60,
                    isDense: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    items: _minutenPresets
                        .map((m) => DropdownMenuItem(
                            value: m, child: Text(minutenLabel(m))))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _erinnerungen[i] = TerminErinnerung(
                          methode: _erinnerungen[i].methode, minuten: v));
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: AppColors.error,
                  tooltip: 'Entfernen',
                  onPressed: () =>
                      setState(() => _erinnerungen.removeAt(i)),
                ),
              ],
            ),
          ),
        if (_erinnerungen.length < 5)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Erinnerung hinzufügen'),
              onPressed: () => setState(() => _erinnerungen.add(
                  const TerminErinnerung(methode: 'popup', minuten: 60))),
            ),
          ),
        if (_erinnerungen.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Keine Erinnerung',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
      ],
    );
  }
```

- [ ] **Step 7: Analyse**

Run: `flutter analyze lib/presentation/screens/termine/termin_form_screen.dart`
Expected: `No issues found!` (falls das alte `erinnerungVorlaufOptionen` jetzt ungenutzt ist und woanders definiert wurde: dort belassen — es kann in G4 aufgeräumt werden; keine Fehler, evtl. ein „unused"-Hinweis den wir in G4 entfernen.)

- [ ] **Step 8: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/termine/termin_form_screen.dart
git commit -m "feat(gcal): Reminder-Editor (mehrere Erinnerungen) im Termin-Formular"
```

---

## Task 11: Gesamtverifikation + Deploy v0.31.0

**Files:**
- Modify: `sbs_projer_app/pubspec.yaml`

- [ ] **Step 1: Analyse + Tests**

Run:
```bash
flutter analyze
flutter test test/erinnerung_util_test.dart
```
Expected: analyze ohne neue Fehler (vorbestehende Isar-`.g.dart`-Warnings ok); Tests grün.

- [ ] **Step 2: DB/Functions bereit?** — Migrationen 129+130 angewandt (Task 2/7), Edge Functions `google-oauth-exchange` + `google-calendar-disconnect` deployed (Task 3/4), Secrets `GOOGLE_OAUTH_CLIENT_ID`/`GOOGLE_OAUTH_CLIENT_SECRET` gesetzt (Task 1), `.env` mit Client-ID (Task 5).

- [ ] **Step 3: Version bumpen** — `pubspec.yaml` Z. 4 auf `0.31.0+510`.

- [ ] **Step 4: Build + Cache-Bust**

```bash
cd sbs_projer_app && export MSYS_NO_PATHCONV=1 \
  && flutter build web --base-href "/sbs-projer-dev/" --pwa-strategy=none
cd .. && VER=$(grep -o '"version":"[^"]*"' sbs_projer_app/build/web/version.json | cut -d'"' -f4) \
  && sed -i "s/\"mainJsPath\":\"main.dart.js\"/\"mainJsPath\":\"main.dart.js?v=$VER\"/g" \
       sbs_projer_app/build/web/flutter_bootstrap.js \
  && rm -f sbs_projer_app/build/web/flutter_service_worker.js
```

- [ ] **Step 5: Live-Test nach Deploy** (Pflicht — Preview-Harness rendert canvaskit nicht; wird live geprüft):
  - Einstellungen → „Google Kalender" → **Verbinden** → Google-Consent (einmalige Unverified-Warnung akzeptieren) → zurück in der App **„Verbunden · <email>"**.
  - Token-Check via MCP `execute_sql`: `select connected, google_email from google_calendar_status;` → `connected = true`.
  - **Trennen** → Status weg; `select * from google_calendar_tokens;` → 0 Zeilen.
  - Termin-Formular: mehrere Erinnerungen anlegen (Popup + E-Mail), speichern, wieder öffnen → bleiben erhalten.

- [ ] **Step 6: Deploy auf gh-pages + main**

```bash
git add sbs_projer_app/pubspec.yaml && git commit -m "chore: Version 0.31.0+510 (Google-Kalender G1)"
git checkout gh-pages
rm -rf assets canvaskit icons main.dart.js* flutter*.js index.html manifest.json favicon.png version.json docs
cp -r sbs_projer_app/build/web/* .
touch .nojekyll
git add index.html main.dart.js* flutter*.js manifest.json favicon.png version.json .nojekyll assets/ canvaskit/ icons/
git commit -m "deploy v0.31.0 — Google-Kalender G1 (Verbindung & Datenmodell)"
git push origin gh-pages
git checkout main
git push origin main
```

- [ ] **Step 7: ToDo aktualisieren**

`ToDo.md`: Termine-Überarbeitung → G1 erledigt, G2–G4 offen.

```bash
git add ToDo.md && git commit -m "docs: ToDo — Google-Kalender G1 erledigt, G2-G4 offen"
git push origin main
```

---

## Self-Review

**1. Spec coverage:**
- Baustein 1 (Cloud Setup, geführt) → Task 1. ✅
- Baustein 2 (Tokens + Status, RLS) → Task 2. ✅
- Baustein 3 (Edge Functions) → Task 3 + Task 4. ✅
- Baustein 4 (Auth-Service + Einstellungen + Provider + Redirect) → Task 5 + Task 6. ✅
- Baustein 5 (Termin Mehrfach-Erinnerungen: Migration/Modell/Util/Mapper/Editor) → Task 7 + 8 + 9 + 10. ✅
- Sicherheit (Token nur service_role, PKCE+state, secret nur Supabase, JWT-verifiziert) → Task 2/3/5. ✅
- Deploy v0.31.0 → Task 11. ✅

**2. Placeholder scan:** Keine TBD/TODO; alle Code-Schritte vollständig. Der einzige „falls"-Hinweis (Task 10 Step 4) ist eine explizite Alternative mit gezeigtem Muster, kein Platzhalter. ✅

**3. Type consistency:** `TerminErinnerung {methode, minuten}` konsistent in Util (Task 8), DTO/Mapper (Task 9), Form (Task 10). `parseErinnerungen`/`erinnerungenToJson` einheitlich benannt. Edge-Function-Antwort `{connected, email}` ↔ Auth-Service-Auswertung (`data['connected']`, `data['email']`) ↔ `GoogleCalendarStatus{connected,email}` (Task 3/5/6). Secrets `GOOGLE_OAUTH_CLIENT_ID`/`GOOGLE_OAUTH_CLIENT_SECRET` und `.env`-Keys `GOOGLE_OAUTH_CLIENT_ID`/`GOOGLE_OAUTH_REDIRECT_URI` konsistent (Task 1/3/5). Redirect-URI identisch in Console/`.env`/Token-Tausch. Tabellen `google_calendar_tokens`/`google_calendar_status` konsistent (Task 2/3/4/5). ✅

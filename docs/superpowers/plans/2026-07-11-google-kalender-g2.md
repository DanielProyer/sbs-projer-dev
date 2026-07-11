# Google-Kalender G2 (Push App → Google) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pikett, Events und (geplante) Termine automatisch in den Google-Haupt­kalender schreiben — sofort beim Speichern/Löschen, mit Erinnerungen, plus ein manueller „Jetzt abgleichen".

**Architecture:** Zentrale Mapping-Tabelle (Entity↔Google-Event) + eine Edge Function `google-calendar-sync` mit Access-Token-Refresh und zwei Modi (`push` = ein Eintrag; `reconcile` = alle + Waisen), beide per User-JWT. Die App ruft `push` nach Speichern/Löschen und bietet einen `reconcile`-Button.

**Tech Stack:** Supabase (Postgres/Edge Functions), Deno/TypeScript, Flutter/Riverpod, Google Calendar REST v3.

**Abweichung zur Spec (bewusst):** Statt `pg_cron` + `CRON_SECRET` wird `reconcile` per **User-JWT** aus der App ausgelöst (Button „Jetzt abgleichen") — kein Secret-in-Chat, keine service_role-Key-Einbettung. Der automatische 15-Min-Cron ist als optionaler Nachzug am Ende dokumentiert.

**Wichtige Fakten (verifiziert):**
- DB-Spalten: `termine(id, user_id, datum date, uhrzeit_von/bis time, titel, notizen, status, erinnerungen jsonb)`,
  `pikett_dienste(id, user_id, datum_start/ende date, referenz_nr, notizen)`,
  `events(id, user_id, betrieb_id, termin_von/bis date, notizen)`, `betriebe(id, name)`.
- **Termin push-würdig nur `status='geplant'`** (Auto-Vorschläge sind `status='vorgeschlagen'` und werden in
  `TerminRepository.synchronisiereVorschlaege` massenhaft ge-`save()`-t — die dürfen NICHT nach Google).
- Repos (kIsWeb-Zweig = Supabase direkt): `TerminRepository.save(TerminLocal)`/`delete(String id)` (setzt
  `serverId ??= uuid`; `delete` lädt vorher `toCancel`), `PikettDienstRepository.save/delete` (setzt **keine**
  UUID → hinzufügen), `EventRepository.save/delete` (setzt `serverId ??= uuid`). Auf Web = `id`/`serverId` die UUID.
- `google_calendar_tokens(user_id, refresh_token, access_token, access_token_expiry, …)` (aus G1).
- Edge-Function-Muster + Secrets `GOOGLE_OAUTH_CLIENT_ID/SECRET` vorhanden (aus G1). Auto-Secrets
  `SUPABASE_URL/ANON_KEY/SERVICE_ROLE_KEY`.
- Fire-and-forget-Muster im Repo: siehe `ReminderService.schedule` (try/catch, bricht Speichern nie).
- Deploy **v0.32.0**.

**Umgebung/Befehle:** `export PATH="$PATH:/c/flutter/bin"`; App unter `sbs_projer_app/`.
Analyse: `flutter analyze`. MCP: `apply_migration`, `deploy_edge_function`, `execute_sql`.

---

## File Structure

- Create: `Datenbank/migrations/131_google_calendar_events.sql` — Mapping-Tabelle.
- Create: `supabase/functions/google-calendar-sync/index.ts` — Sync-Function.
- Create: `sbs_projer_app/lib/services/google_calendar/google_calendar_sync_service.dart` — App-Trigger.
- Modify: `termin_repository.dart`, `pikett_dienst_repository.dart`, `event_repository.dart` (+ ggf.
  `pikett_dienst_mapper.dart`), `einstellungen_screen.dart`, `pubspec.yaml`.

---

## Task 1: Migration 131 — Mapping-Tabelle

**Files:** Create `Datenbank/migrations/131_google_calendar_events.sql`

- [ ] **Step 1: SQL schreiben**

```sql
-- 131: Zuordnung App-Entity <-> Google-Kalender-Event (server-only)
create table if not exists public.google_calendar_events (
  id bigserial primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  entity_type text not null check (entity_type in ('termin','pikett','event')),
  entity_id uuid not null,
  google_event_id text,
  content_hash text,
  synced_at timestamptz,
  status text not null default 'ok',
  fehler text,
  updated_at timestamptz not null default now(),
  unique (user_id, entity_type, entity_id)
);
alter table public.google_calendar_events enable row level security;
-- keine Client-Policy: nur service_role (Edge Function).
```

- [ ] **Step 2: Anwenden** — MCP `apply_migration` (name `131_google_calendar_events`) auf `pltbaqqwpnmdajwgnhpd`.

- [ ] **Step 3: Prüfen** — MCP `execute_sql`: `select rowsecurity from pg_tables where tablename='google_calendar_events';` → `true`.

- [ ] **Step 4: Commit**
```bash
git add Datenbank/migrations/131_google_calendar_events.sql
git commit -m "feat(gcal): Migration 131 google_calendar_events Mapping"
```

---

## Task 2: Edge Function `google-calendar-sync`

**Files:** Create `supabase/functions/google-calendar-sync/index.ts`

- [ ] **Step 1: Function schreiben**

```ts
// Supabase Edge Function: google-calendar-sync
// Push (ein Eintrag) / Reconcile (alle + Waisen) App -> Google. Einweg, App gewinnt.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const CAL = "https://www.googleapis.com/calendar/v3/calendars/primary/events";

// deno-lint-ignore no-explicit-any
type Any = any;

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
    const admin = createClient(supabaseUrl, serviceKey);

    const authHeader = req.headers.get("Authorization") ?? "";
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return json({ error: "unauthorized" }, 401);

    const body = await req.json().catch(() => ({}));
    const action = body.action ?? "push";

    const at = await getAccessToken(admin, user.id);
    if (at === null) return json({ skipped: "not_connected" });
    if (at.error) return json({ error: at.error }, 502);
    const token = at.token;

    if (action === "reconcile") {
      const res = await reconcile(admin, token, user.id);
      return json({ ok: true, ...res });
    }
    const { entity_type, entity_id } = body;
    if (!entity_type || !entity_id) return json({ error: "missing params" }, 400);
    await pushOne(admin, token, user.id, entity_type, entity_id);
    return json({ ok: true });
  } catch (e) {
    console.error(e);
    return json({ error: (e as Error).message }, 500);
  }
});

async function getAccessToken(
  admin: Any,
  userId: string,
): Promise<{ token: string; error?: string } | null> {
  const { data: row } = await admin.from("google_calendar_tokens").select("*")
    .eq("user_id", userId).maybeSingle();
  if (!row) return null;
  const now = Date.now();
  const exp = row.access_token_expiry
    ? new Date(row.access_token_expiry).getTime()
    : 0;
  if (row.access_token && exp > now + 60000) return { token: row.access_token };
  const clientId = Deno.env.get("GOOGLE_OAUTH_CLIENT_ID")!;
  const clientSecret = Deno.env.get("GOOGLE_OAUTH_CLIENT_SECRET")!;
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      refresh_token: row.refresh_token,
      grant_type: "refresh_token",
    }),
  });
  const t = await res.json();
  if (!res.ok || !t.access_token) {
    return { token: "", error: t.error_description || t.error || "refresh_failed" };
  }
  const newExp = new Date(now + (t.expires_in ?? 3600) * 1000).toISOString();
  await admin.from("google_calendar_tokens").update({
    access_token: t.access_token,
    access_token_expiry: newExp,
    updated_at: new Date().toISOString(),
  }).eq("user_id", userId);
  return { token: t.access_token };
}

function addDay(dateStr: string): string {
  const d = new Date(dateStr + "T00:00:00Z");
  d.setUTCDate(d.getUTCDate() + 1);
  return d.toISOString().substring(0, 10);
}

async function sha256Hex(s: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return Array.from(new Uint8Array(buf)).map((b) =>
    b.toString(16).padStart(2, "0")).join("");
}

function mapReminders(raw: Any): Any[] {
  let arr = raw;
  if (typeof arr === "string") {
    try { arr = JSON.parse(arr); } catch { arr = []; }
  }
  if (!Array.isArray(arr)) return [];
  return arr.slice(0, 5).map((e: Any) => ({
    method: e.methode === "email" ? "email" : "popup",
    minutes: Number(e.minuten) || 0,
  }));
}

const ALLDAY = [
  { method: "email", minutes: 1440 },
  { method: "popup", minutes: 1440 },
];

function buildEvent(entityType: string, row: Any): Any | null {
  const ext = {
    private: { app: "sbs_projer", entity_type: entityType, entity_id: row.id },
  };
  if (entityType === "termin") {
    if (row.status !== "geplant") return null;
    const ev: Any = {
      summary: "SBS · " + (row.titel ?? "Termin"),
      description: row.notizen ?? undefined,
      extendedProperties: ext,
      colorId: "10",
      reminders: { useDefault: false, overrides: mapReminders(row.erinnerungen) },
    };
    if (row.uhrzeit_von) {
      let endDate = row.datum;
      let endTime = row.uhrzeit_bis;
      if (!endTime) {
        const e = new Date(`${row.datum}T${row.uhrzeit_von}Z`);
        e.setTime(e.getTime() + 3600000);
        endDate = e.toISOString().substring(0, 10);
        endTime = e.toISOString().substring(11, 19);
      }
      ev.start = { dateTime: `${row.datum}T${row.uhrzeit_von}`, timeZone: "Europe/Zurich" };
      ev.end = { dateTime: `${endDate}T${endTime}`, timeZone: "Europe/Zurich" };
    } else {
      ev.start = { date: row.datum };
      ev.end = { date: addDay(row.datum) };
    }
    return ev;
  }
  if (entityType === "pikett") {
    return {
      summary: "SBS · Pikett" + (row.referenz_nr ? ` ${row.referenz_nr}` : ""),
      description: row.notizen ?? undefined,
      start: { date: row.datum_start },
      end: { date: addDay(row.datum_ende) },
      colorId: "11",
      extendedProperties: ext,
      reminders: { useDefault: false, overrides: ALLDAY },
    };
  }
  if (entityType === "event") {
    return {
      summary: "SBS · Event: " + (row.betrieb_name ?? ""),
      description: row.notizen ?? undefined,
      start: { date: row.termin_von },
      end: { date: addDay(row.termin_bis) },
      colorId: "5",
      extendedProperties: ext,
      reminders: { useDefault: false, overrides: ALLDAY },
    };
  }
  return null;
}

async function loadEntity(admin: Any, entityType: string, entityId: string): Promise<Any> {
  const table = entityType === "termin"
    ? "termine"
    : entityType === "pikett"
    ? "pikett_dienste"
    : entityType === "event"
    ? "events"
    : null;
  if (!table) return null;
  const { data } = await admin.from(table).select("*").eq("id", entityId).maybeSingle();
  if (data && entityType === "event" && data.betrieb_id) {
    const { data: b } = await admin.from("betriebe").select("name")
      .eq("id", data.betrieb_id).maybeSingle();
    data.betrieb_name = b?.name ?? "";
  }
  return data;
}

async function gfetch(token: string, url: string, method: string, body?: Any) {
  return await fetch(url, {
    method,
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: body ? JSON.stringify(body) : undefined,
  });
}

async function pushOne(
  admin: Any,
  token: string,
  userId: string,
  entityType: string,
  entityId: string,
) {
  const { data: mapping } = await admin.from("google_calendar_events").select("*")
    .eq("user_id", userId).eq("entity_type", entityType).eq("entity_id", entityId)
    .maybeSingle();
  const row = await loadEntity(admin, entityType, entityId);
  const ev = row ? buildEvent(entityType, row) : null;
  const nowIso = new Date().toISOString();

  if (!ev) {
    if (mapping?.google_event_id) {
      await gfetch(token, `${CAL}/${mapping.google_event_id}`, "DELETE");
    }
    if (mapping) {
      await admin.from("google_calendar_events").delete().eq("id", mapping.id);
    }
    return;
  }

  const hash = await sha256Hex(JSON.stringify(ev));

  if (mapping?.google_event_id) {
    if (mapping.content_hash === hash) return;
    const res = await gfetch(token, `${CAL}/${mapping.google_event_id}`, "PUT", ev);
    if (res.status === 404) {
      const ins = await gfetch(token, CAL, "POST", ev);
      const created = await ins.json();
      await admin.from("google_calendar_events").update({
        google_event_id: created.id, content_hash: hash, synced_at: nowIso,
        status: "ok", fehler: null, updated_at: nowIso,
      }).eq("id", mapping.id);
      return;
    }
    if (!res.ok) {
      const err = await res.text();
      await admin.from("google_calendar_events").update({
        status: "error", fehler: err.substring(0, 500), updated_at: nowIso,
      }).eq("id", mapping.id);
      return;
    }
    await admin.from("google_calendar_events").update({
      content_hash: hash, synced_at: nowIso, status: "ok", fehler: null, updated_at: nowIso,
    }).eq("id", mapping.id);
    return;
  }

  const ins = await gfetch(token, CAL, "POST", ev);
  if (!ins.ok) {
    const err = await ins.text();
    await admin.from("google_calendar_events").upsert({
      user_id: userId, entity_type: entityType, entity_id: entityId,
      status: "error", fehler: err.substring(0, 500), updated_at: nowIso,
    }, { onConflict: "user_id,entity_type,entity_id" });
    return;
  }
  const created = await ins.json();
  await admin.from("google_calendar_events").upsert({
    user_id: userId, entity_type: entityType, entity_id: entityId,
    google_event_id: created.id, content_hash: hash, synced_at: nowIso,
    status: "ok", fehler: null, updated_at: nowIso,
  }, { onConflict: "user_id,entity_type,entity_id" });
}

async function reconcile(admin: Any, token: string, userId: string) {
  let pushed = 0, deleted = 0;
  const worthy = new Set<string>();
  const { data: termine } = await admin.from("termine").select("id")
    .eq("user_id", userId).eq("status", "geplant");
  const { data: pikett } = await admin.from("pikett_dienste").select("id")
    .eq("user_id", userId);
  const { data: events } = await admin.from("events").select("id")
    .eq("user_id", userId);
  for (const t of termine ?? []) {
    worthy.add("termin:" + t.id);
    await pushOne(admin, token, userId, "termin", t.id);
    pushed++;
  }
  for (const p of pikett ?? []) {
    worthy.add("pikett:" + p.id);
    await pushOne(admin, token, userId, "pikett", p.id);
    pushed++;
  }
  for (const e of events ?? []) {
    worthy.add("event:" + e.id);
    await pushOne(admin, token, userId, "event", e.id);
    pushed++;
  }
  const { data: mappings } = await admin.from("google_calendar_events").select("*")
    .eq("user_id", userId);
  for (const m of mappings ?? []) {
    if (!worthy.has(m.entity_type + ":" + m.entity_id)) {
      if (m.google_event_id) {
        await gfetch(token, `${CAL}/${m.google_event_id}`, "DELETE");
      }
      await admin.from("google_calendar_events").delete().eq("id", m.id);
      deleted++;
    }
  }
  return { pushed, deleted };
}
```

- [ ] **Step 2: Deployen** — MCP `deploy_edge_function` (name `google-calendar-sync`, `verify_jwt: true`, obiger Code).

- [ ] **Step 3: Commit**
```bash
git add supabase/functions/google-calendar-sync/index.ts
git commit -m "feat(gcal): Edge Function google-calendar-sync (push + reconcile)"
```

---

## Task 3: App — Sync-Service + Repo-Trigger + „Jetzt abgleichen"

**Files:**
- Create: `sbs_projer_app/lib/services/google_calendar/google_calendar_sync_service.dart`
- Modify: `termin_repository.dart`, `pikett_dienst_repository.dart`, `event_repository.dart`,
  `pikett_dienst_mapper.dart` (nur falls id fehlt), `einstellungen_screen.dart`

- [ ] **Step 1: Sync-Service anlegen**

Create `google_calendar_sync_service.dart`:

```dart
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Stösst den serverseitigen Push App -> Google Kalender an.
class GoogleCalendarSyncService {
  /// Ein Eintrag sofort synchronisieren. Fehler brechen NIE den Aufrufer.
  static Future<void> push(String entityType, String entityId) async {
    try {
      await SupabaseService.client.functions.invoke(
        'google-calendar-sync',
        body: {'action': 'push', 'entity_type': entityType, 'entity_id': entityId},
      );
    } catch (e) {
      debugPrint('[GCalSync] push $entityType/$entityId: $e');
    }
  }

  /// Vollabgleich (alle Eintraege + Waisen loeschen). Wirft bei Fehler.
  static Future<Map<String, dynamic>> reconcile() async {
    final res = await SupabaseService.client.functions
        .invoke('google-calendar-sync', body: {'action': 'reconcile'});
    final d = res.data;
    return d is Map ? Map<String, dynamic>.from(d) : {};
  }
}
```

- [ ] **Step 2: Termin — Push nach Speichern/Löschen**

In `termin_repository.dart` Import ergänzen:
```dart
import 'package:sbs_projer_app/services/google_calendar/google_calendar_sync_service.dart';
```

In `save(...)` innerhalb des `if (kIsWeb) { … }`-Zweigs, direkt nach
`await SupabaseService.client.from('termine').upsert(json);` einfügen:
```dart
      if (termin.status == 'geplant') {
        await GoogleCalendarSyncService.push('termin', termin.serverId!);
      }
```

In `delete(...)` innerhalb des `if (kIsWeb) { … }`-Zweigs, direkt nach
`await SupabaseService.client.from('termine').delete().eq('id', id);` einfügen:
```dart
      if (toCancel?.status == 'geplant') {
        await GoogleCalendarSyncService.push('termin', id);
      }
```

- [ ] **Step 3: Pikett — UUID sicherstellen + Push**

Zuerst prüfen, dass `pikett_dienst_mapper.dart` bei gesetztem `serverId` die `id` schreibt (Muster
Termin-Mapper). Falls die `toJson`-Map die id **nicht** enthält, ergänze vor `return json;`:
```dart
    if (local.serverId != null) json['id'] = local.serverId;
```

In `pikett_dienst_repository.dart` Import ergänzen:
```dart
import 'package:uuid/uuid.dart';
import 'package:sbs_projer_app/services/google_calendar/google_calendar_sync_service.dart';
```

In `save(...)` ganz am Anfang (nach `pikett.userId = …`) einfügen:
```dart
    pikett.serverId ??= const Uuid().v4();
```
und im `if (kIsWeb) { … }`-Zweig direkt nach dem `upsert(json);` (vor `return;`):
```dart
      await GoogleCalendarSyncService.push('pikett', pikett.serverId!);
```

In `delete(...)` im `if (kIsWeb) { … }`-Zweig direkt nach dem `delete().eq('id', id);` (vor `return;`):
```dart
      await GoogleCalendarSyncService.push('pikett', id);
```

- [ ] **Step 4: Event — Push nach Speichern/Löschen**

In `event_repository.dart` Import ergänzen:
```dart
import 'package:sbs_projer_app/services/google_calendar/google_calendar_sync_service.dart';
```

In `save(...)` im `if (kIsWeb) { … }`-Zweig direkt nach dem `upsert(json);` (vor `return;`):
```dart
      await GoogleCalendarSyncService.push('event', event.serverId!);
```

In `delete(...)` im `if (kIsWeb) { … }`-Zweig direkt nach dem `delete().eq('id', id);` (vor `return;`):
```dart
      await GoogleCalendarSyncService.push('event', id);
```

- [ ] **Step 5: „Jetzt abgleichen"-Button in Einstellungen**

In `einstellungen_screen.dart` Import ergänzen:
```dart
import 'package:sbs_projer_app/services/google_calendar/google_calendar_sync_service.dart';
```

In `_buildGoogleKalender(...)` im `if (status.connected)`-Zweig, in der `Column`-`children`-Liste
**vor** dem „Trennen"-`Align` einfügen:
```dart
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.sync, size: 18),
              label: const Text('Jetzt abgleichen'),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Kalender wird abgeglichen …')),
                );
                try {
                  final r = await GoogleCalendarSyncService.reconcile();
                  messenger.showSnackBar(SnackBar(
                    content: Text(
                        'Abgeglichen: ${r['pushed'] ?? 0} gesendet, ${r['deleted'] ?? 0} entfernt'),
                  ));
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text('Fehler: $e')));
                }
              },
            ),
          ),
```

- [ ] **Step 6: Analyse**

Run: `flutter analyze lib/services/google_calendar/ lib/data/repositories/termin_repository.dart lib/data/repositories/pikett_dienst_repository.dart lib/data/repositories/event_repository.dart lib/presentation/screens/einstellungen/einstellungen_screen.dart`
Expected: `No issues found!`

- [ ] **Step 7: Commit**
```bash
git add sbs_projer_app/lib/services/google_calendar/google_calendar_sync_service.dart sbs_projer_app/lib/data/repositories/termin_repository.dart sbs_projer_app/lib/data/repositories/pikett_dienst_repository.dart sbs_projer_app/lib/data/repositories/event_repository.dart sbs_projer_app/lib/data/mappers/pikett_dienst_mapper.dart sbs_projer_app/lib/presentation/screens/einstellungen/einstellungen_screen.dart
git commit -m "feat(gcal): Sofort-Push + Jetzt-abgleichen fuer Termin/Pikett/Event"
```

---

## Task 4: Verifikation + Live-Test + Deploy v0.32.0

**Files:** Modify `sbs_projer_app/pubspec.yaml`

- [ ] **Step 1: Analyse**

Run: `flutter analyze`
Expected: keine neuen Fehler (nur vorbestehende Isar/`dart:html`-Infos).

- [ ] **Step 2: Version bumpen** — `pubspec.yaml` Z. 4 → `0.32.0+512`.

- [ ] **Step 3: Build + Cache-Bust**
```bash
cd sbs_projer_app && export MSYS_NO_PATHCONV=1 \
  && flutter build web --base-href "/sbs-projer-dev/" --pwa-strategy=none
cd .. && VER=$(grep -o '"version":"[^"]*"' sbs_projer_app/build/web/version.json | cut -d'"' -f4) \
  && sed -i "s/\"mainJsPath\":\"main.dart.js\"/\"mainJsPath\":\"main.dart.js?v=$VER\"/g" \
       sbs_projer_app/build/web/flutter_bootstrap.js \
  && rm -f sbs_projer_app/build/web/flutter_service_worker.js
```

- [ ] **Step 4: Deploy gh-pages + main**
```bash
git add sbs_projer_app/pubspec.yaml && git commit -m "chore: Version 0.32.0+512 (Google-Kalender G2)"
git checkout gh-pages
rm -rf assets canvaskit icons main.dart.js* flutter*.js index.html manifest.json favicon.png version.json docs
cp -r sbs_projer_app/build/web/* .
touch .nojekyll
git add index.html main.dart.js* flutter*.js manifest.json favicon.png version.json .nojekyll assets/ canvaskit/ icons/
git commit -m "deploy v0.32.0 — Google-Kalender G2 (Push App->Google)"
git push origin gh-pages
git checkout main
git push origin main
```

- [ ] **Step 5: Live-Test** (User-getrieben, real gegen Google; ich verifiziere per DB)

Auf https://danielproyer.github.io/sbs-projer-dev/ (Hard-Refresh):
- **Termin** (mit Uhrzeit) `status=geplant` speichern → erscheint sofort im Google Kalender
  (grün, „SBS · <Titel>"), Erinnerungen wie eingestellt. Ganztags-Termin (ohne Uhrzeit) → Ganztags-Event.
- Termin **ändern** → Google aktualisiert. **Löschen** → Google-Event weg.
- **Pikett** (mehrtägig) speichern → roter Ganztags-Block über den **kompletten** Zeitraum (letzter Tag
  inklusive), Erinnerung 1 Tag vorher.
- **Event** speichern → gelb, Titel „SBS · Event: <Betrieb>".
- **„Jetzt abgleichen"** in Einstellungen → SnackBar „x gesendet, y entfernt", keine Duplikate.
- DB-Check (MCP `execute_sql`): `select entity_type, count(*) from public.google_calendar_events group by 1;`
  → Mapping-Zeilen vorhanden, `status='ok'`.
- **Erinnerungs-Empfang** real prüfen (E-Mail + Popup am Pixel 9).

- [ ] **Step 6: ToDo aktualisieren**
```bash
# ToDo.md: G2 erledigt (Live-Test-Vorbehalt), G3/G4 offen
git add ToDo.md && git commit -m "docs: ToDo — Google-Kalender G2 erledigt"
git push origin main
```

---

## Optionaler Nachzug (nicht Teil von v0.32.0): automatischer 15-Min-Reconcile

Wenn gewünscht, später: Extensions `pg_cron` + `pg_net` aktivieren; `CRON_SECRET` als Supabase-Secret;
`reconcile` um einen Secret-Check erweitern (Body `{action:'reconcile', secret}`); pg_cron-Job alle 15 Min
`net.http_post` auf die Function-URL mit anon-Bearer + Secret. Bis dahin deckt Sofort-Push + „Jetzt
abgleichen" den Bedarf ab.

---

## Self-Review

**1. Spec coverage:**
- A Mapping-Tabelle → Task 1. ✅
- B Edge Function push+reconcile + Token-Refresh → Task 2. ✅
- C Sofort-Push in App → Task 3 (Service + 3 Repos). ✅
- D Feld-Mapping (Termin grün getimt/ganztags Europe/Zurich, Pikett rot end.date+1, Event gelb, Präfix
  „SBS · ", extendedProperties, Reminder) → Task 2 `buildEvent`. ✅
- E Auto-Sync: **abgewichen** — statt pg_cron ein „Jetzt abgleichen"-Button (Task 3 Step 5) + Sofort-Push;
  pg_cron als optionaler Nachzug dokumentiert. ✅ (bewusst, begründet)
- Konflikt/Löschen „App gewinnt" → `pushOne` (überschreibt via PUT / löscht). ✅
- Termin nur `status='geplant'` (Vorschläge raus) → `buildEvent` + Repo-Guard. ✅

**2. Placeholder scan:** Keine TBD/TODO; vollständiger Function-Code + exakte Repo-Edits. Der eine „falls"-
Hinweis (Task 3 Step 3, Mapper-id) ist eine konkrete bedingte Ergänzung mit gezeigtem Code. ✅

**3. Type consistency:** `entity_type` Werte 'termin'/'pikett'/'event' konsistent (Migration-CHECK,
`buildEvent`, `loadEntity`, Repo-Aufrufe). `action` 'push'/'reconcile' konsistent (Function ↔
`GoogleCalendarSyncService`). Reminder-Format `{method,minutes}` (Google) aus `{methode,minuten}`
(App-jsonb) in `mapReminders`. colorId 10/11/5 (grün/rot/gelb). `google_calendar_events`-Spalten
konsistent zwischen Migration und Function-Upserts. `serverId`/`id` = Web-UUID als `entity_id`. ✅

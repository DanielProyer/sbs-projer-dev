# Google-Kalender K1 (App-Kalender ablösen + Saison-Reinigung mit Bestätigung) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Den app-eigenen Termine-Kalender entfernen und stattdessen beim Speichern von Ferien/Saison eines Betriebs die Eröffnung/Endreinigung — nach Bestätigung — in den Google Kalender schreiben.

**Architecture:** Reine Funktion `betriebReinigungen()` (Dart) berechnet die Reinigungs-Termine aus Betrieb-Saison/Ferien; ein Bestätigungs-Dialog nach dem Betrieb-Speichern pusht die bestätigten über eine neue `sync_reinigungen`-Aktion der bestehenden `google-calendar-sync`-Edge-Function. Das generische Termine-Modul (Screen/Formular/Datenschicht) wird entfernt.

**Tech Stack:** Flutter/Riverpod, Supabase Edge Functions (Deno/TS), Google Calendar REST, `flutter_test`, `url_launcher` (vorhanden).

**Wichtige Fakten (verifiziert):**
- `google-calendar-sync` (G2) verwaltet aktuell termin/pikett/event; `google_calendar_events(entity_type
  check termin/pikett/event, entity_id **uuid**, google_event_id, content_hash, status, fehler, updated_at)`.
  0 gepushte Termine bisher.
- Entfern-Stellen: `sync_service.dart` Termin-Tier (Aufruf Z. 175 `() => _syncTermine(userId)`, Methode
  Z. 904–929, Imports Z. 26/50/74); `router.dart` Imports Z. 70/71 + Routen Z. 638–655; `home_screen.dart`
  Kachel Z. 144–149; `app.dart` `ReminderService.rescheduleAll`-Block (Z. 60) + Import; `betrieb_form_screen.dart`
  `synchronisiereVorschlaege`-Block (Z. 408–418) + `ref.invalidate(termineStreamProvider)` (Z. 428).
- `ReminderService` wird **nur** von `termin_repository.dart` (wird gelöscht) + `app.dart` genutzt → nach
  Ablösen komplett entfernbar (`reminder_service.dart`, `_web.dart`, `reminder_service_export.dart`, `reminder_time.dart`).
- `url_launcher: ^6.2.0` in pubspec vorhanden.
- `betrieb_ferien.dart` liefert `ferienSlots(b)` (5 Slots, Start/Ende nullbar); `BetriebLocal` hat
  `istSaisonbetrieb`, `sommer/winterSaisonAktiv`, `sommer/winterStartDatum`/`…EndeDatum`, `keineBetriebsferien`,
  `name`, `ort` (String?).
- `googleCalendarStatusProvider` (FutureProvider<GoogleCalendarStatus{connected,email}>) vorhanden.
- Deploy **v0.33.0**. Reihenfolge unten so gewählt, dass der Build zwischen den Tasks kompiliert (Entfernen zuletzt).

**Umgebung/Befehle:** `export PATH="$PATH:/c/flutter/bin"`; App unter `sbs_projer_app/`.
Tests: `flutter test test/betrieb_reinigung_test.dart` · Analyse: `flutter analyze` · Isar:
`dart run build_runner build --delete-conflicting-outputs`. Edge-Deploy: `npx supabase functions deploy
google-calendar-sync --project-ref pltbaqqwpnmdajwgnhpd` (CLI ist verlinkt, Token gesetzt).

---

## File Structure

- Create: `Datenbank/migrations/132_gcal_events_reinigung.sql`.
- Create: `sbs_projer_app/lib/core/util/betrieb_reinigung.dart` (+ Test).
- Create: `sbs_projer_app/lib/presentation/screens/betriebe/widgets/saison_reinigung_dialog.dart`.
- Modify: `supabase/functions/google-calendar-sync/index.ts`, `google_calendar_sync_service.dart`,
  `betrieb_form_screen.dart`, `home_screen.dart`, `router.dart`, `app.dart`, `sync_service.dart`,
  `isar_service.dart`, `pubspec.yaml`.
- Delete: `termine/termine_kalender_screen.dart`, `termine/termin_form_screen.dart`,
  `data/repositories/termin_repository.dart`, `presentation/providers/termin_providers.dart`,
  `data/mappers/termin_mapper.dart`, `data/local/termin_local.dart`(+`.g.dart`),
  `data/local/web/termin_local_web.dart`, `data/local/termin_local_export.dart`,
  `services/notification/reminder_service.dart`, `reminder_service_web.dart`,
  `reminder_service_export.dart`, `reminder_time.dart`.

---

## Task 1: Migration 132 — Mapping-Tabelle für Reinigungen erweitern

**Files:** Create `Datenbank/migrations/132_gcal_events_reinigung.sql`

- [ ] **Step 1: SQL schreiben**

```sql
-- 132: google_calendar_events fuer Betriebs-Reinigungen (zusammengesetzter Schluessel)
alter table public.google_calendar_events
  alter column entity_id type text;

alter table public.google_calendar_events
  drop constraint if exists google_calendar_events_entity_type_check;
alter table public.google_calendar_events
  add constraint google_calendar_events_entity_type_check
  check (entity_type in ('termin','pikett','event','betrieb_reinigung'));
```

- [ ] **Step 2: Anwenden** — MCP `apply_migration` (name `132_gcal_events_reinigung`) auf `pltbaqqwpnmdajwgnhpd`.

- [ ] **Step 3: Prüfen** — MCP `execute_sql`:
  `select data_type from information_schema.columns where table_name='google_calendar_events' and column_name='entity_id';`
  Expected: `text`.

- [ ] **Step 4: Commit**
```bash
git add Datenbank/migrations/132_gcal_events_reinigung.sql
git commit -m "feat(gcal): Migration 132 entity_id text + betrieb_reinigung"
```

---

## Task 2: Edge Function — `sync_reinigungen` + Termin-Handling entfernen

**Files:** Modify `supabase/functions/google-calendar-sync/index.ts` (Vollersatz)

- [ ] **Step 1: Datei ersetzen** durch:

```ts
// Supabase Edge Function: google-calendar-sync
// Push (ein Eintrag) / Reconcile (Pikett+Events) / sync_reinigungen (Betriebs-Reinigungen)
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
const ALLDAY = [
  { method: "email", minutes: 1440 },
  { method: "popup", minutes: 1440 },
];

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
      return json({ ok: true, ...(await reconcile(admin, token, user.id)) });
    }
    if (action === "sync_reinigungen") {
      const { betrieb_id, label, reinigungen } = body;
      if (!betrieb_id || !Array.isArray(reinigungen)) {
        return json({ error: "missing params" }, 400);
      }
      return json({
        ok: true,
        ...(await syncReinigungen(admin, token, user.id, betrieb_id, label ?? "", reinigungen)),
      });
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
  const exp = row.access_token_expiry ? new Date(row.access_token_expiry).getTime() : 0;
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
  return Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, "0")).join("");
}
async function gfetch(token: string, url: string, method: string, body?: Any) {
  return await fetch(url, {
    method,
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: body ? JSON.stringify(body) : undefined,
  });
}

// ── Pikett / Event ─────────────────────────────────────────────
function buildEvent(entityType: string, row: Any): Any | null {
  const ext = { private: { app: "sbs_projer", entity_type: entityType, entity_id: row.id } };
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
  const table = entityType === "pikett" ? "pikett_dienste" : entityType === "event" ? "events" : null;
  if (!table) return null;
  const { data } = await admin.from(table).select("*").eq("id", entityId).maybeSingle();
  if (data && entityType === "event" && data.betrieb_id) {
    const { data: b } = await admin.from("betriebe").select("name").eq("id", data.betrieb_id).maybeSingle();
    data.betrieb_name = b?.name ?? "";
  }
  return data;
}

async function upsertEvent(
  admin: Any, token: string, userId: string, entityType: string, entityId: string, ev: Any,
) {
  const { data: mapping } = await admin.from("google_calendar_events").select("*")
    .eq("user_id", userId).eq("entity_type", entityType).eq("entity_id", entityId).maybeSingle();
  const nowIso = new Date().toISOString();
  const hash = await sha256Hex(JSON.stringify(ev));
  if (mapping?.google_event_id) {
    if (mapping.content_hash === hash) return;
    const res = await gfetch(token, `${CAL}/${mapping.google_event_id}`, "PUT", ev);
    if (res.status === 404) {
      const ins = await gfetch(token, CAL, "POST", ev);
      const c = await ins.json();
      await admin.from("google_calendar_events").update({
        google_event_id: c.id, content_hash: hash, synced_at: nowIso, status: "ok", fehler: null, updated_at: nowIso,
      }).eq("id", mapping.id);
    } else if (res.ok) {
      await admin.from("google_calendar_events").update({
        content_hash: hash, synced_at: nowIso, status: "ok", fehler: null, updated_at: nowIso,
      }).eq("id", mapping.id);
    } else {
      const err = await res.text();
      await admin.from("google_calendar_events").update({
        status: "error", fehler: err.substring(0, 500), updated_at: nowIso,
      }).eq("id", mapping.id);
    }
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
  const c = await ins.json();
  await admin.from("google_calendar_events").upsert({
    user_id: userId, entity_type: entityType, entity_id: entityId,
    google_event_id: c.id, content_hash: hash, synced_at: nowIso, status: "ok", fehler: null, updated_at: nowIso,
  }, { onConflict: "user_id,entity_type,entity_id" });
}

async function deleteMapping(admin: Any, token: string, mapping: Any) {
  if (mapping?.google_event_id) await gfetch(token, `${CAL}/${mapping.google_event_id}`, "DELETE");
  if (mapping) await admin.from("google_calendar_events").delete().eq("id", mapping.id);
}

async function pushOne(
  admin: Any, token: string, userId: string, entityType: string, entityId: string,
) {
  const row = await loadEntity(admin, entityType, entityId);
  const ev = row ? buildEvent(entityType, row) : null;
  if (!ev) {
    const { data: mapping } = await admin.from("google_calendar_events").select("*")
      .eq("user_id", userId).eq("entity_type", entityType).eq("entity_id", entityId).maybeSingle();
    await deleteMapping(admin, token, mapping);
    return;
  }
  await upsertEvent(admin, token, userId, entityType, entityId, ev);
}

async function reconcile(admin: Any, token: string, userId: string) {
  let pushed = 0, deleted = 0;
  const worthy = new Set<string>();
  const { data: pikett } = await admin.from("pikett_dienste").select("id").eq("user_id", userId);
  const { data: events } = await admin.from("events").select("id").eq("user_id", userId);
  for (const p of pikett ?? []) { worthy.add("pikett:" + p.id); await pushOne(admin, token, userId, "pikett", p.id); pushed++; }
  for (const e of events ?? []) { worthy.add("event:" + e.id); await pushOne(admin, token, userId, "event", e.id); pushed++; }
  const { data: mappings } = await admin.from("google_calendar_events").select("*")
    .eq("user_id", userId).in("entity_type", ["pikett", "event"]);
  for (const m of mappings ?? []) {
    if (!worthy.has(m.entity_type + ":" + m.entity_id)) { await deleteMapping(admin, token, m); deleted++; }
  }
  return { pushed, deleted };
}

// ── Betriebs-Reinigungen (mit Bestaetigung) ────────────────────
async function syncReinigungen(
  admin: Any, token: string, userId: string, betriebId: string, label: string, items: Any[],
) {
  let pushed = 0, deleted = 0;
  for (const it of items) {
    const entityId = `${betriebId}:${it.slot_key}`;
    if (!it.aktiv) {
      const { data: mapping } = await admin.from("google_calendar_events").select("*")
        .eq("user_id", userId).eq("entity_type", "betrieb_reinigung").eq("entity_id", entityId).maybeSingle();
      if (mapping) { await deleteMapping(admin, token, mapping); deleted++; }
      continue;
    }
    const artLabel = it.art === "endreinigung" ? "Endreinigung" : "Eröffnung";
    const ev = {
      summary: `SBS · ${artLabel} — ${label}`,
      start: { date: it.datum },
      end: { date: addDay(it.datum) },
      colorId: "10",
      extendedProperties: {
        private: { app: "sbs_projer", entity_type: "betrieb_reinigung", entity_id: entityId },
      },
      reminders: { useDefault: false, overrides: ALLDAY },
    };
    await upsertEvent(admin, token, userId, "betrieb_reinigung", entityId, ev);
    pushed++;
  }
  return { pushed, deleted };
}
```

- [ ] **Step 2: Deployen**
```bash
cd "D:/01_SBS_Projer_GmbH/00_Entwicklung/SBS Projer DEV"
npx supabase functions deploy google-calendar-sync --project-ref pltbaqqwpnmdajwgnhpd
```
Expected: `Deployed Functions.`

- [ ] **Step 3: Commit**
```bash
git add supabase/functions/google-calendar-sync/index.ts
git commit -m "feat(gcal): sync_reinigungen + Termin-Handling raus"
```

---

## Task 3: `betrieb_reinigung.dart` (TDD)

**Files:**
- Create: `sbs_projer_app/lib/core/util/betrieb_reinigung.dart`
- Test: `sbs_projer_app/test/betrieb_reinigung_test.dart`

- [ ] **Step 1: Failing-Test**

Create `sbs_projer_app/test/betrieb_reinigung_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/betrieb_reinigung.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';

BetriebLocal _b() => BetriebLocal()
  ..userId = 't'
  ..name = 'Calanda'
  ..ort = 'Chur';

void main() {
  test('kein Saisonbetrieb, keine Ferien → leer', () {
    expect(betriebReinigungen(_b()), isEmpty);
  });

  test('Sommer-Saison → Eröffnung=Start, Endreinigung=Ende', () {
    final b = _b()
      ..istSaisonbetrieb = true
      ..sommerSaisonAktiv = true
      ..sommerStartDatum = DateTime(2026, 5, 1)
      ..sommerEndeDatum = DateTime(2026, 9, 30);
    final r = betriebReinigungen(b);
    final e = r.firstWhere((x) => x.slotKey == 'sommer_eroeffnung');
    final end = r.firstWhere((x) => x.slotKey == 'sommer_endreinigung');
    expect(e.art, 'eroeffnung');
    expect(e.datum, DateTime(2026, 5, 1));
    expect(end.art, 'endreinigung');
    expect(end.datum, DateTime(2026, 9, 30));
    expect(e.label, 'Calanda, Chur');
  });

  test('Ferien-Slot → Endreinigung=Start-1, Eröffnung=Ende+1', () {
    final b = _b()
      ..ferienStart = DateTime(2026, 7, 10)
      ..ferienEnde = DateTime(2026, 7, 20);
    final r = betriebReinigungen(b);
    final end = r.firstWhere((x) => x.slotKey == 'ferien1_endreinigung');
    final auf = r.firstWhere((x) => x.slotKey == 'ferien1_eroeffnung');
    expect(end.datum, DateTime(2026, 7, 9));
    expect(auf.datum, DateTime(2026, 7, 21));
  });

  test('keineBetriebsferien → Ferien ignoriert', () {
    final b = _b()
      ..keineBetriebsferien = true
      ..ferienStart = DateTime(2026, 7, 10)
      ..ferienEnde = DateTime(2026, 7, 20);
    expect(betriebReinigungen(b), isEmpty);
  });

  test('nur belegte Ferien-Slots', () {
    final b = _b()
      ..ferien2Start = DateTime(2026, 8, 1)
      ..ferien2Ende = DateTime(2026, 8, 10);
    final keys = betriebReinigungen(b).map((x) => x.slotKey).toSet();
    expect(keys, {'ferien2_endreinigung', 'ferien2_eroeffnung'});
  });

  test('sortiert nach Datum', () {
    final b = _b()
      ..istSaisonbetrieb = true
      ..sommerSaisonAktiv = true
      ..sommerStartDatum = DateTime(2026, 5, 1)
      ..sommerEndeDatum = DateTime(2026, 9, 30)
      ..ferienStart = DateTime(2026, 7, 10)
      ..ferienEnde = DateTime(2026, 7, 20);
    final ds = betriebReinigungen(b).map((x) => x.datum).toList();
    final sorted = [...ds]..sort();
    expect(ds, sorted);
  });

  test('label ohne Ort → nur Name', () {
    final b = _b()
      ..ort = null
      ..istSaisonbetrieb = true
      ..sommerSaisonAktiv = true
      ..sommerStartDatum = DateTime(2026, 5, 1)
      ..sommerEndeDatum = DateTime(2026, 9, 30);
    expect(betriebReinigungen(b).first.label, 'Calanda');
  });
}
```

- [ ] **Step 2: Test ausführen (FAIL)** — `flutter test test/betrieb_reinigung_test.dart` → nicht gefunden.

- [ ] **Step 3: Implementierung**

Create `sbs_projer_app/lib/core/util/betrieb_reinigung.dart`:

```dart
import 'package:sbs_projer_app/core/util/betrieb_ferien.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';

/// Eine berechnete Saison-/Ferien-Reinigung eines Betriebs.
class BetriebReinigung {
  final String slotKey; // stabiler Schlüssel, z.B. 'sommer_eroeffnung', 'ferien1_endreinigung'
  final String art; // 'endreinigung' | 'eroeffnung'
  final DateTime datum;
  final String label; // "Name, Ort"
  const BetriebReinigung({
    required this.slotKey,
    required this.art,
    required this.datum,
    required this.label,
  });
}

String _label(BetriebLocal b) {
  final ort = b.ort?.trim() ?? '';
  return ort.isEmpty ? b.name : '${b.name}, $ort';
}

/// Berechnet die Eröffnung/Endreinigung aus Saison- und Ferien-Daten.
List<BetriebReinigung> betriebReinigungen(BetriebLocal b) {
  final label = _label(b);
  final out = <BetriebReinigung>[];
  void add(String slotKey, String art, DateTime? d) {
    if (d == null) return;
    out.add(BetriebReinigung(
        slotKey: slotKey,
        art: art,
        datum: DateTime(d.year, d.month, d.day),
        label: label));
  }

  if (b.istSaisonbetrieb) {
    if (b.sommerSaisonAktiv) {
      add('sommer_eroeffnung', 'eroeffnung', b.sommerStartDatum);
      add('sommer_endreinigung', 'endreinigung', b.sommerEndeDatum);
    }
    if (b.winterSaisonAktiv) {
      add('winter_eroeffnung', 'eroeffnung', b.winterStartDatum);
      add('winter_endreinigung', 'endreinigung', b.winterEndeDatum);
    }
  }

  if (!b.keineBetriebsferien) {
    final slots = ferienSlots(b);
    for (var i = 0; i < slots.length; i++) {
      final s = slots[i];
      if (s.start != null && s.ende != null) {
        add('ferien${i + 1}_endreinigung', 'endreinigung',
            s.start!.subtract(const Duration(days: 1)));
        add('ferien${i + 1}_eroeffnung', 'eroeffnung',
            s.ende!.add(const Duration(days: 1)));
      }
    }
  }

  out.sort((x, y) => x.datum.compareTo(y.datum));
  return out;
}
```

- [ ] **Step 4: Test ausführen (PASS)** — `flutter test test/betrieb_reinigung_test.dart` → alle grün.

- [ ] **Step 5: Commit**
```bash
git add sbs_projer_app/lib/core/util/betrieb_reinigung.dart sbs_projer_app/test/betrieb_reinigung_test.dart
git commit -m "feat(gcal): betriebReinigungen (Saison/Ferien → Reinigungen, TDD)"
```

---

## Task 4: Sync-Service — `syncBetriebReinigungen`

**Files:** Modify `sbs_projer_app/lib/services/google_calendar/google_calendar_sync_service.dart`

- [ ] **Step 1: Methode ergänzen**

In `class GoogleCalendarSyncService` nach `reconcile()` einfügen:

```dart
  /// Betriebs-Reinigungen (Saison/Ferien) synchronisieren. [reinigungen] =
  /// Liste von {slot_key, art, datum (yyyy-MM-dd), aktiv}. Wirft bei Fehler.
  static Future<Map<String, dynamic>> syncBetriebReinigungen(
    String betriebId,
    String label,
    List<Map<String, dynamic>> reinigungen,
  ) async {
    final res = await SupabaseService.client.functions.invoke(
      'google-calendar-sync',
      body: {
        'action': 'sync_reinigungen',
        'betrieb_id': betriebId,
        'label': label,
        'reinigungen': reinigungen,
      },
    );
    final d = res.data;
    return d is Map ? Map<String, dynamic>.from(d) : {};
  }
```

- [ ] **Step 2: Analyse** — `flutter analyze lib/services/google_calendar/google_calendar_sync_service.dart` → `No issues found!`

- [ ] **Step 3: Commit**
```bash
git add sbs_projer_app/lib/services/google_calendar/google_calendar_sync_service.dart
git commit -m "feat(gcal): syncBetriebReinigungen im Sync-Service"
```

---

## Task 5: Bestätigungs-Dialog + Betrieb-Formular-Trigger

**Files:**
- Create: `sbs_projer_app/lib/presentation/screens/betriebe/widgets/saison_reinigung_dialog.dart`
- Modify: `sbs_projer_app/lib/presentation/screens/betriebe/betrieb_form_screen.dart`

- [ ] **Step 1: Dialog anlegen**

Create `saison_reinigung_dialog.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/util/betrieb_reinigung.dart';

/// Fragt vor dem Eintragen in Google Kalender ab, welche Saison-/Ferien-
/// Reinigungen übernommen werden sollen. Gibt bei Bestätigung die Items
/// (slot_key/art/datum/aktiv) zurück, sonst null.
class SaisonReinigungDialog extends StatefulWidget {
  final List<BetriebReinigung> reinigungen;
  const SaisonReinigungDialog({super.key, required this.reinigungen});

  @override
  State<SaisonReinigungDialog> createState() => _SaisonReinigungDialogState();
}

class _SaisonReinigungDialogState extends State<SaisonReinigungDialog> {
  late final List<bool> _aktiv =
      List<bool>.filled(widget.reinigungen.length, true);

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('EE, d. MMM yyyy', 'de_CH');
    return AlertDialog(
      title: const Text('In Google Kalender eintragen?'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Reinigungs-Termine aus Saison/Ferien:',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.reinigungen.length,
                itemBuilder: (_, i) {
                  final r = widget.reinigungen[i];
                  final art =
                      r.art == 'endreinigung' ? 'Endreinigung' : 'Eröffnung';
                  return CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: _aktiv[i],
                    onChanged: (v) => setState(() => _aktiv[i] = v ?? false),
                    title: Text('$art — ${r.label}'),
                    subtitle: Text(df.format(r.datum)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Später'),
        ),
        FilledButton(
          onPressed: () {
            final items = <Map<String, dynamic>>[
              for (var i = 0; i < widget.reinigungen.length; i++)
                {
                  'slot_key': widget.reinigungen[i].slotKey,
                  'art': widget.reinigungen[i].art,
                  'datum':
                      widget.reinigungen[i].datum.toIso8601String().split('T').first,
                  'aktiv': _aktiv[i],
                },
            ];
            Navigator.pop(context, items);
          },
          child: const Text('In Google eintragen'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Betrieb-Formular — alten Trigger ersetzen**

In `betrieb_form_screen.dart` Imports ergänzen:
```dart
import 'package:sbs_projer_app/core/util/betrieb_reinigung.dart';
import 'package:sbs_projer_app/presentation/providers/google_calendar_providers.dart';
import 'package:sbs_projer_app/presentation/screens/betriebe/widgets/saison_reinigung_dialog.dart';
import 'package:sbs_projer_app/services/google_calendar/google_calendar_sync_service.dart';
```

Den alten Block (nach `await BetriebRepository.save(betrieb);`) ersetzen:
```dart
      // Saison-/Ferien-Termine im Kalender für diesen Betrieb aktualisieren
      // (veraltete Auto-Vorschläge entfernen, neue erstellen).
      final betriebSid = betrieb.serverId;
      if (betriebSid != null && betriebSid.isNotEmpty) {
        try {
          await TerminRepository.synchronisiereVorschlaege(
              nurBetriebId: betriebSid);
        } catch (e) {
          debugPrint('[Termin-Sync] fehlgeschlagen: $e');
        }
      }
```
durch:
```dart
      // Saison-/Ferien-Reinigungen (mit Bestätigung) in Google Kalender.
      final betriebSid = betrieb.serverId;
      final reinigungen = betriebReinigungen(betrieb);
      if (mounted && betriebSid != null && betriebSid.isNotEmpty &&
          reinigungen.isNotEmpty) {
        final status = await ref.read(googleCalendarStatusProvider.future);
        if (status.connected && mounted) {
          final items = await showDialog<List<Map<String, dynamic>>>(
            context: context,
            builder: (_) => SaisonReinigungDialog(reinigungen: reinigungen),
          );
          if (items != null) {
            try {
              await GoogleCalendarSyncService.syncBetriebReinigungen(
                  betriebSid, reinigungen.first.label, items);
            } catch (e) {
              debugPrint('[Reinigung-Sync] fehlgeschlagen: $e');
            }
          }
        }
      }
```

Und den `termineStreamProvider`-Invalidate entfernen — ersetze:
```dart
        if (kIsWeb) {
          ref.invalidate(betriebeStreamProvider);
          ref.invalidate(termineStreamProvider);
        }
```
durch:
```dart
        if (kIsWeb) {
          ref.invalidate(betriebeStreamProvider);
        }
```

Sowie den jetzt ungenutzten Import `termin_repository.dart` (und ggf. `termin_providers.dart`) aus
`betrieb_form_screen.dart` **entfernen**.

- [ ] **Step 3: Analyse** — `flutter analyze lib/presentation/screens/betriebe/` → `No issues found!`

- [ ] **Step 4: Commit**
```bash
git add sbs_projer_app/lib/presentation/screens/betriebe/widgets/saison_reinigung_dialog.dart sbs_projer_app/lib/presentation/screens/betriebe/betrieb_form_screen.dart
git commit -m "feat(gcal): Bestaetigungs-Dialog Saison-Reinigung im Betrieb-Formular"
```

---

## Task 6: Ablösen — Termine-Modul + App-Reminder entfernen

**Files:** Delete + Modify (siehe File Structure). **Atomar** — der Build kompiliert erst am Ende wieder.

- [ ] **Step 1: home_screen — Kachel auf Google Kalender**

In `home_screen.dart` Import ergänzen:
```dart
import 'package:url_launcher/url_launcher.dart';
```
Kachel (Z. 144–149) ersetzen:
```dart
        _DashboardTile(
          icon: Icons.calendar_month,
          label: 'Termine',
          color: Colors.deepOrange,
          onTap: () => context.push('/termine'),
        ),
```
durch:
```dart
        _DashboardTile(
          icon: Icons.calendar_month,
          label: 'Google Kalender',
          color: Colors.deepOrange,
          onTap: () => launchUrl(
            Uri.parse('https://calendar.google.com'),
            mode: LaunchMode.externalApplication,
          ),
        ),
```

- [ ] **Step 2: router.dart — Routen + Imports raus**

Entfernen: Imports Z. 70/71 (`termine_kalender_screen.dart`, `termin_form_screen.dart`) und die drei
Routen (`/termine`, `/termine/neu`, `/termine/:id/bearbeiten`, ca. Z. 638–655).

- [ ] **Step 3: app.dart — Reminder-Reschedule raus**

Entfernen: den Block
```dart
      final termine = await TerminRepository.getAll();
      await ReminderService.rescheduleAll(termine);
```
(inkl. umschliessender `if`, falls vorhanden) sowie die Imports von `termin_repository.dart` und
`reminder_service_export.dart` in `app.dart`.

- [ ] **Step 4: sync_service.dart — Termin-Tier raus**

Entfernen: den Tier-Aufruf `() => _syncTermine(userId),` (Z. 175), die Methode `_syncTermine` (Z. ~904–929)
und die Imports `termin_local.dart` (Z. 26), `models/termin.dart` (Z. 50), `mappers/termin_mapper.dart` (Z. 74).

- [ ] **Step 5: isar_service.dart — Termin-Methoden + Schema raus**

Alle `termin`-bezogenen Methoden entfernen (Grep `termin`/`Termin` in `isar_service.dart` +
`isar_service_web.dart`), inkl. der `TerminLocalSchema`-Registrierung im `Isar.open([...])`-Aufruf und dem
Import von `termin_local.dart`.

- [ ] **Step 6: Dateien löschen**
```bash
cd "D:/01_SBS_Projer_GmbH/00_Entwicklung/SBS Projer DEV/sbs_projer_app"
rm lib/presentation/screens/termine/termine_kalender_screen.dart \
   lib/presentation/screens/termine/termin_form_screen.dart \
   lib/data/repositories/termin_repository.dart \
   lib/presentation/providers/termin_providers.dart \
   lib/data/mappers/termin_mapper.dart \
   lib/data/local/termin_local.dart \
   lib/data/local/termin_local.g.dart \
   lib/data/local/web/termin_local_web.dart \
   lib/data/local/termin_local_export.dart \
   lib/services/notification/reminder_service.dart \
   lib/services/notification/reminder_service_web.dart \
   lib/services/notification/reminder_service_export.dart \
   lib/services/notification/reminder_time.dart
rmdir lib/presentation/screens/termine 2>/dev/null || true
```

- [ ] **Step 7: Isar-Code regenerieren**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: erfolgreich, ohne Verweis auf `TerminLocal`.

- [ ] **Step 8: Volle Analyse**

Run: `flutter analyze`
Expected: keine `error`/`warning` zu `termin`/`Reminder` (nur vorbestehende Isar/`dart:html`-Infos).
Falls „unused import" oder Restverweise (z.B. `termineStreamProvider`, `ReminderService`) auftauchen:
diese Stellen entfernen, bis sauber.

- [ ] **Step 9: Commit**
```bash
cd "D:/01_SBS_Projer_GmbH/00_Entwicklung/SBS Projer DEV"
git add -A sbs_projer_app/lib
git commit -m "refactor(termine): App-Kalender + Termin-Datenschicht + App-Reminder entfernt"
```

---

## Task 7: Verifikation + Live-Test + Deploy v0.33.0

**Files:** Modify `sbs_projer_app/pubspec.yaml`

- [ ] **Step 1: Analyse + Tests**
```bash
flutter analyze
flutter test test/betrieb_reinigung_test.dart
```
Expected: analyze ohne neue Fehler; Tests grün.

- [ ] **Step 2: Version** — `pubspec.yaml` Z. 4 → `0.33.0+514`.

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
git add sbs_projer_app/pubspec.yaml && git commit -m "chore: Version 0.33.0+514 (Google-Kalender K1)"
git checkout gh-pages
rm -rf assets canvaskit icons main.dart.js* flutter*.js index.html manifest.json favicon.png version.json docs
cp -r sbs_projer_app/build/web/* .
touch .nojekyll
git add index.html main.dart.js* flutter*.js manifest.json favicon.png version.json .nojekyll assets/ canvaskit/ icons/
git commit -m "deploy v0.33.0 — Google-Kalender K1 (App-Kalender abgeloest)"
git push origin gh-pages
git checkout main
git push origin main
```

- [ ] **Step 5: Live-Test** (User, real gegen Google; ich verifiziere per DB `google_calendar_events`):
  - Dashboard: Kachel „Google Kalender" öffnet calendar.google.com; kein App-Kalender/Termin-Formular mehr.
  - Betrieb mit Ferien/Saison speichern → Dialog erscheint → „In Google eintragen" → Einträge erscheinen
    (grün, „SBS · Endreinigung|Eröffnung — Betrieb, Ort", Erinnerung). Häkchen entfernen + erneut speichern
    → Eintrag verschwindet. Ferien-Datum ändern + bestätigen → Eintrag verschiebt sich.
  - Pikett/Events (G2) weiterhin ok; „Jetzt abgleichen" lässt die Reinigungen unangetastet.
  - DB: `select entity_type, count(*) from public.google_calendar_events group by 1;` → `betrieb_reinigung`-Zeilen `status='ok'`.

- [ ] **Step 6: ToDo aktualisieren**
```bash
# ToDo.md: K1 erledigt (Live-Test offen), K2 (Normalisierung) offen
git add ToDo.md && git commit -m "docs: ToDo — Google-Kalender K1 erledigt, K2 offen"
git push origin main
```

---

## Self-Review

**1. Spec coverage:**
- Baustein A Ablösen (Screens/Formular/Datenschicht/Routen/Kachel/app-Reminder/sync-Tier/isar) → Task 6. ✅
- Baustein B `betriebReinigungen` (TDD) → Task 3; Dialog + Trigger → Task 5; `syncBetriebReinigungen` → Task 4;
  Edge `sync_reinigungen` + Termin-raus + reconcile-skip → Task 2; Migration 132 (entity_id text +
  betrieb_reinigung) → Task 1. ✅
- Sicherheit (nur mit Bestätigung, JWT) → Task 2/5. ✅
- `termine`-Tabelle bleibt (nicht-destruktiv) → keine DB-Löschung im Plan. ✅
- Deploy v0.33.0 → Task 7. ✅

**2. Placeholder scan:** Keine TBD/TODO. Task 6 Step 5/8 enthalten Grep-geführte Entfernungen (kein
Platzhalter, sondern präzise Anweisung + Abschluss-Gate `flutter analyze`). ✅

**3. Type consistency:** `BetriebReinigung{slotKey,art,datum,label}` konsistent (Helfer Task 3, Dialog Task 5,
Items `{slot_key,art,datum,aktiv}` Task 5→4→2). `action:'sync_reinigungen'` + Body `{betrieb_id,label,
reinigungen}` konsistent (Service Task 4 ↔ Function Task 2). `entity_type='betrieb_reinigung'`,
`entity_id='${betriebId}:${slotKey}'`, `colorId:'10'`, Reminder `ALLDAY` (email+popup 1440) einheitlich.
`entity_id` als Text (Migration 132) passt zum zusammengesetzten Schlüssel. reconcile `.in(['pikett','event'])`
lässt `betrieb_reinigung` unangetastet. ✅

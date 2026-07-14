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
    if (action === "scan_manual") {
      const { time_min, time_max } = body;
      if (!time_min || !time_max) return json({ error: "missing params" }, 400);
      return json({ ok: true, ...(await scanManual(token, time_min, time_max)) });
    }
    if (action === "apply_tags") {
      const { items } = body;
      if (!Array.isArray(items)) return json({ error: "missing params" }, 400);
      return json({ ok: true, ...(await applyTags(admin, token, user.id, items)) });
    }
    if (action === "untag_manual") {
      const { event_ids } = body;
      return json({ ok: true, ...(await untagManual(admin, token, user.id, event_ids)) });
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
  // Zeitstempel des Vollabgleichs festhalten (Trigger + Anzeige für den
  // täglichen Auto-Sync der App).
  await admin.from("google_calendar_status")
    .update({ last_sync_at: new Date().toISOString() }).eq("user_id", userId);
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

// ── K2: bestehende Termine scannen (read-only) ─────────────────
async function scanManual(token: string, timeMin: string, timeMax: string) {
  const events: Any[] = [];
  let skippedTagged = 0;
  let pageToken: string | undefined = undefined;
  do {
    const p = new URLSearchParams({
      singleEvents: "true",
      orderBy: "startTime",
      maxResults: "250",
      timeMin,
      timeMax,
    });
    if (pageToken) p.set("pageToken", pageToken);
    const res = await gfetch(token, `${CAL}?${p.toString()}`, "GET");
    if (!res.ok) throw new Error(`events.list ${res.status}: ${await res.text()}`);
    const data = await res.json();
    for (const ev of data.items ?? []) {
      if (ev.status === "cancelled") continue;
      if (ev.extendedProperties?.private?.app === "sbs_projer") {
        skippedTagged++;
        continue;
      }
      events.push({
        event_id: ev.id,
        summary: ev.summary ?? "",
        start: ev.start?.date ?? ev.start?.dateTime ?? null,
        is_all_day: !!ev.start?.date,
      });
    }
    pageToken = data.nextPageToken;
  } while (pageToken);
  return { events, scanned: events.length, skipped_tagged: skippedTagged };
}

// ── K2b: Termine taggen (PATCH: nur Farbe/Erinnerung/Tag) ──────
async function applyTags(
  admin: Any,
  token: string,
  userId: string,
  items: Any[],
) {
  let tagged = 0;
  const errors: Any[] = [];
  const nowIso = new Date().toISOString();
  const DEFAULT_REM = { useDefault: true, overrides: [] };
  for (const it of items) {
    const eventId = it.event_id;
    const betriebId = it.betrieb_id;
    if (!eventId || !betriebId) continue;

    // 1) Originalzustand (Farbe/Erinnerung) lesen, um Untag exakt umkehrbar zu machen.
    let origColor: string | null = null;
    let origReminders: Any = null;
    const getRes = await gfetch(token, `${CAL}/${eventId}`, "GET");
    if (getRes.ok) {
      const cur = await getRes.json();
      origColor = cur.colorId ?? null;
      origReminders = cur.reminders ?? null;
    }

    // 2) Taggen — NUR PATCH mit colorId/reminders/extendedProperties.
    // summary/description/start/end werden NIE gesendet -> bleiben unangetastet.
    const ev = {
      colorId: "1", // Lavendel
      reminders: { useDefault: false, overrides: ALLDAY },
      extendedProperties: {
        private: {
          app: "sbs_projer",
          entity_type: "betrieb_manuell",
          betrieb_id: betriebId,
        },
      },
    };
    const res = await gfetch(token, `${CAL}/${eventId}`, "PATCH", ev);
    if (!res.ok) {
      errors.push({ event_id: eventId, fehler: (await res.text()).substring(0, 200) });
      continue;
    }

    // 3) Mapping + Originalzustand persistieren. Scheitert die DB, den Google-Tag
    // sofort zurücknehmen (keine Waisen-Tags, die untag nie erreicht).
    try {
      await admin.from("google_calendar_events").upsert({
        user_id: userId,
        entity_type: "betrieb_manuell",
        entity_id: eventId,
        google_event_id: eventId,
        original_color_id: origColor,
        original_reminders: origReminders,
        synced_at: nowIso,
        status: "ok",
        fehler: null,
        updated_at: nowIso,
      }, { onConflict: "user_id,entity_type,entity_id" });
      tagged++;
    } catch (dbErr) {
      await gfetch(token, `${CAL}/${eventId}`, "PATCH", {
        colorId: origColor,
        reminders: origReminders ?? DEFAULT_REM,
        extendedProperties: { private: { app: null, entity_type: null, betrieb_id: null } },
      });
      errors.push({ event_id: eventId, fehler: "db: " + (dbErr as Error).message });
    }
  }
  return { tagged, errors };
}

async function untagManual(
  admin: Any,
  token: string,
  userId: string,
  eventIds?: string[],
) {
  let q = admin.from("google_calendar_events").select("*")
    .eq("user_id", userId).eq("entity_type", "betrieb_manuell");
  if (Array.isArray(eventIds) && eventIds.length > 0) {
    q = q.in("entity_id", eventIds);
  }
  const { data: mappings } = await q;
  let untagged = 0;
  const errors: Any[] = [];
  const DEFAULT_REM = { useDefault: true, overrides: [] };
  for (const m of mappings ?? []) {
    const evId = m.google_event_id ?? m.entity_id;
    // Ursprungszustand wiederherstellen: Original-Farbe (oder null = kein Color),
    // Original-Erinnerung (oder Default), app-Properties entfernen (null löscht Key).
    // Titel/Notiz/Datum unangetastet.
    const ev: Any = {
      colorId: m.original_color_id ?? null,
      reminders: m.original_reminders ?? DEFAULT_REM,
      extendedProperties: { private: { app: null, entity_type: null, betrieb_id: null } },
    };
    let res = await gfetch(token, `${CAL}/${evId}`, "PATCH", ev);
    // Sicherheitsnetz: falls colorId:null abgelehnt wird, ohne colorId erneut
    // patchen — so wird der app-Tag garantiert gelöst (Termin wieder scanbar).
    if (!res.ok && res.status !== 404 && res.status !== 410) {
      res = await gfetch(token, `${CAL}/${evId}`, "PATCH", {
        reminders: ev.reminders,
        extendedProperties: ev.extendedProperties,
      });
    }
    if (res.ok || res.status === 404 || res.status === 410) {
      await admin.from("google_calendar_events").delete().eq("id", m.id);
      untagged++;
    } else {
      errors.push({ event_id: evId, fehler: (await res.text()).substring(0, 200) });
    }
  }
  return { untagged, errors };
}

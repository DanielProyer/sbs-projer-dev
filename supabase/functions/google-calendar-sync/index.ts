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

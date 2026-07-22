// Supabase Edge Function: google-contacts-sync
// Einseitiger Abgleich App -> Google Kontakte (Label "SBS App").
// Identitaet: clientData.sbs_id = "kontakt:<uuid>" | "betrieb:<uuid>".
// Sicherheitsregel: Nur Eintraege MIT sbs_id werden je angefasst/geloescht.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const PEOPLE = "https://people.googleapis.com/v1";
const LABEL_NAME = "SBS App";
const PERSON_FIELDS =
  "names,organizations,phoneNumbers,emailAddresses,memberships,clientData";
// deno-lint-ignore no-explicit-any
type Any = any;

// ── Reine Funktionen (Soll-Filter + Mapping + Vergleich) ──

export function istSyncWuerdigKontakt(k: Any): boolean {
  const tel = (k.telefon ?? "").trim();
  const mail = (k.email ?? "").trim();
  return tel !== "" || mail !== "";
}

export function istSyncWuerdigBetrieb(b: Any): boolean {
  const tel = (b.telefon ?? "").trim();
  return (b.status === "aktiv" || b.status === "saisonpause") && tel !== "";
}

// Person-Payload fuer einen App-Kontakt. betriebText = "Name, Ort" oder "".
export function personAusKontakt(k: Any, betriebText: string): Any {
  const p: Any = {
    names: [{
      givenName: (k.vorname ?? "").trim(),
      familyName: (k.nachname ?? "").trim(),
    }],
    clientData: [{ key: "sbs_id", value: `kontakt:${k.id}` }],
  };
  if (betriebText || (k.funktion ?? k.rolle)) {
    p.organizations = [{
      name: betriebText,
      title: ((k.funktion ?? k.rolle) ?? "").trim(),
    }];
  }
  const tel = (k.telefon ?? "").trim();
  if (tel) p.phoneNumbers = [{ value: tel, type: "mobile" }];
  const mail = (k.email ?? "").trim();
  if (mail) p.emailAddresses = [{ value: mail }];
  return p;
}

export function personAusBetrieb(b: Any): Any {
  const anzeige = [b.name, b.ort].filter((x: Any) => (x ?? "").trim() !== "")
    .join(" ");
  return {
    names: [{ unstructuredName: anzeige }],
    organizations: [{ name: (b.name ?? "").trim() }],
    phoneNumbers: [{ value: (b.telefon ?? "").trim(), type: "work" }],
    clientData: [{ key: "sbs_id", value: `betrieb:${b.id}` }],
  };
}

// Vergleichs-Schluessel: alles, was wir schreiben, normalisiert.
export function vergleichsKey(p: Any): string {
  const n = p.names?.[0] ?? {};
  const o = p.organizations?.[0] ?? {};
  return JSON.stringify([
    n.givenName ?? "",
    n.familyName ?? "",
    n.unstructuredName ?? "",
    o.name ?? "",
    o.title ?? "",
    p.phoneNumbers?.[0]?.value ?? "",
    p.emailAddresses?.[0]?.value ?? "",
  ]);
}

export function sbsIdVon(p: Any): string | null {
  for (const c of p.clientData ?? []) {
    if (c.key === "sbs_id" && c.value) return c.value as string;
  }
  return null;
}

// ── People-API-Helfer ──

async function gapi(token: string, method: string, path: string, body?: Any) {
  const res = await fetch(`${PEOPLE}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(`People API ${res.status}: ${data.error?.message ?? path}`);
  }
  return data;
}

async function ensureLabel(token: string): Promise<string> {
  const list = await gapi(token, "GET", "/contactGroups?pageSize=200");
  const found = (list.contactGroups ?? []).find(
    (g: Any) => g.name === LABEL_NAME && g.groupType === "USER_CONTACT_GROUP",
  );
  if (found) return found.resourceName;
  const created = await gapi(token, "POST", "/contactGroups", {
    contactGroup: { name: LABEL_NAME },
  });
  return created.resourceName;
}

// Alle Google-Kontakte im Label MIT sbs_id -> Map sbs_id -> Person.
async function listeIst(
  token: string,
  label: string,
): Promise<Map<string, Any>> {
  const ist = new Map<string, Any>();
  let pageToken = "";
  do {
    const q = `personFields=${PERSON_FIELDS}&pageSize=1000` +
      (pageToken ? `&pageToken=${pageToken}` : "");
    const data = await gapi(token, "GET", `/people/me/connections?${q}`);
    for (const p of data.connections ?? []) {
      const imLabel = (p.memberships ?? []).some(
        (m: Any) =>
          m.contactGroupMembership?.contactGroupResourceName === label,
      );
      const id = sbsIdVon(p);
      if (imLabel && id) ist.set(id, p);
    }
    pageToken = data.nextPageToken ?? "";
  } while (pageToken);
  return ist;
}

function chunks<T>(arr: T[], n: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < arr.length; i += n) out.push(arr.slice(i, i + n));
  return out;
}

// ── Reconcile ──

async function reconcile(admin: Any, token: string, userId: string) {
  // Soll-Zustand laden
  const { data: kontakte } = await admin.from("kontakte").select(
    "id, vorname, nachname, funktion, rolle, telefon, email, betrieb_id",
  ).eq("user_id", userId);
  const { data: betriebe } = await admin.from("betriebe").select(
    "id, name, ort, telefon, status",
  ).eq("user_id", userId);
  const betriebText = new Map<string, string>();
  for (const b of betriebe ?? []) {
    betriebText.set(
      b.id,
      [b.name, b.ort].filter((x: Any) => (x ?? "").trim() !== "").join(", "),
    );
  }

  const label = await ensureLabel(token);
  const membership = {
    memberships: [{
      contactGroupMembership: { contactGroupResourceName: label },
    }],
  };

  const soll = new Map<string, Any>(); // sbs_id -> Person-Payload
  for (const k of (kontakte ?? []).filter(istSyncWuerdigKontakt)) {
    soll.set(`kontakt:${k.id}`, {
      ...personAusKontakt(k, betriebText.get(k.betrieb_id) ?? ""),
      ...membership,
    });
  }
  for (const b of (betriebe ?? []).filter(istSyncWuerdigBetrieb)) {
    soll.set(`betrieb:${b.id}`, { ...personAusBetrieb(b), ...membership });
  }

  const ist = await listeIst(token, label);

  // Diff
  const anlegen: Any[] = [];
  const aktualisieren: { resourceName: string; etag: string; person: Any }[] =
    [];
  for (const [id, person] of soll) {
    const vorhanden = ist.get(id);
    if (!vorhanden) {
      anlegen.push(person);
    } else if (vergleichsKey(person) !== vergleichsKey(vorhanden)) {
      aktualisieren.push({
        resourceName: vorhanden.resourceName,
        etag: vorhanden.etag,
        person,
      });
    }
  }
  const loeschen = [...ist.entries()]
    .filter(([id]) => !soll.has(id))
    .map(([, p]) => p.resourceName);

  // Ausfuehren (Batch-Limits: create 200, delete 500)
  for (const teil of chunks(anlegen, 200)) {
    await gapi(token, "POST", "/people:batchCreateContacts", {
      contacts: teil.map((p) => ({ contactPerson: p })),
      readMask: "names",
    });
  }
  for (const u of aktualisieren) {
    await gapi(
      token,
      "PATCH",
      `/${u.resourceName}:updateContact?updatePersonFields=names,organizations,phoneNumbers,emailAddresses`,
      { ...u.person, etag: u.etag },
    );
  }
  for (const teil of chunks(loeschen, 500)) {
    await gapi(token, "POST", "/people:batchDeleteContacts", {
      resourceNames: teil,
    });
  }

  const kontakteAnz =
    [...soll.keys()].filter((k) => k.startsWith("kontakt:")).length;
  const betriebeAnz = soll.size - kontakteAnz;
  return {
    created: anlegen.length,
    updated: aktualisieren.length,
    deleted: loeschen.length,
    total: soll.size,
    info: `${kontakteAnz} Kontakte, ${betriebeAnz} Betriebe`,
  };
}

// ── HTTP-Handler ──

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

    const at = await getAccessToken(admin, user.id);
    if (at === null) return json({ skipped: "not_connected" });
    if (at.error) return json({ error: at.error }, 502);

    try {
      const r = await reconcile(admin, at.token, user.id);
      await admin.from("google_calendar_status").update({
        contacts_last_sync_at: new Date().toISOString(),
        contacts_last_sync_info: r.info,
      }).eq("user_id", user.id);
      return json({ ok: true, ...r });
    } catch (e) {
      await admin.from("google_calendar_status").update({
        contacts_last_sync_at: new Date().toISOString(),
        contacts_last_sync_info: `Fehler: ${
          e instanceof Error ? e.message : e
        }`,
      }).eq("user_id", user.id);
      throw e;
    }
  } catch (e) {
    console.error("google-contacts-sync", e);
    return json({ error: e instanceof Error ? e.message : "unknown" }, 500);
  }
});

// Wörtlich übernommen aus google-calendar-sync/index.ts (gleiche Token-Logik,
// gleiche Tabelle google_calendar_tokens — der Kontakte-Sync nutzt dieselbe
// Google-Verbindung).
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
    return {
      token: "",
      error: t.error_description || t.error || "refresh_failed",
    };
  }
  const newExp = new Date(now + (t.expires_in ?? 3600) * 1000).toISOString();
  await admin.from("google_calendar_tokens").update({
    access_token: t.access_token,
    access_token_expiry: newExp,
    updated_at: new Date().toISOString(),
  }).eq("user_id", userId);
  return { token: t.access_token };
}

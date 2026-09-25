// Anfahrtszeiten von den festen Startorten zu Betrieben.
//
// Zwei Quellen (Wunsch Daniel: «2 Werte sind besser als einer»): Google
// Routes API (computeRouteMatrix, TRAFFIC_UNAWARE = Standardzeiten ohne
// Verkehr) und OSRM als kostenloser Rückfall. Die Tabelle `anfahrtszeiten`
// hält beide Werte nebeneinander; `minuten` bevorzugt Google (Migration 157).
//
// Zwei Betriebsarten:
//   POST {}                    -> Voll-Lauf: Betriebe mit GPS, seitenweise
//   POST {"limit": 200, "offset": 200}  (limit hoechstens 200, sortiert nach id)
//   POST {"betriebId": "..."}  -> nur dieser Betrieb (neuer Betrieb aus dem
//                                 Formular, direkt nach «aus Google übernehmen»)
//
// Zugang (seit 25.09.2026, Analyse R11): nur angemeldete Benutzer, und nur
// deren eigene Betriebe. Vorher genuegte der Anon-Key fuer einen Voll-Lauf
// ueber alle Betriebe (Google-Kosten) plus Upsert in `anfahrtszeiten`; die
// user_id der Zeilen wurde aus «irgendeiner» bestehenden Zeile geraten —
// jetzt ist es der angemeldete Benutzer.
//
// Secret: GOOGLE_PLACES_KEY (derselbe Key wie betrieb-google-lookup — die
// Routes API muss im Google-Cloud-Projekt aktiviert sein; ohne sie liefert
// die Funktion die OSRM-Werte und meldet Google als übersprungen).

import { createClient } from "jsr:@supabase/supabase-js@2";

const STARTORTE = [
  { key: "domat_ems", lat: 46.8328452, lng: 9.4529918 }, // Via Rezia 8
  { key: "chur", lat: 46.8639692, lng: 9.5278708 }, // Giacomettistrasse 89
];

// computeRouteMatrix: origins × destinations ≤ 625 pro Anfrage.
const CHUNK = 300;
// Voll-Lauf seitenweise: begrenzt die Google-Kosten je Aufruf.
const MAX_LIMIT = 200;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// Die App ruft die Function aus dem Browser auf (Web-Build) — ohne CORS
// scheitert dort schon der Preflight.
const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

/** Angemeldeter Benutzer aus dem Bearer-JWT (Auth-API), sonst null. */
async function ermittleUserId(req: Request): Promise<string | null> {
  const auth = req.headers.get("Authorization") ?? "";
  if (!auth.startsWith("Bearer ")) return null;
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !anonKey) throw new Error("SUPABASE_URL/SUPABASE_ANON_KEY not configured");
  const res = await fetch(`${supabaseUrl}/auth/v1/user`, {
    headers: { "apikey": anonKey, "Authorization": auth },
  });
  if (!res.ok) return null;
  const user = await res.json();
  return typeof user?.id === "string" && user.id.length > 0 ? user.id : null;
}

/// OSRM-Fallback: eine Strecke Startort -> Betrieb. `null` bei jedem Fehler
/// (die Funktion soll nie am Routing scheitern — ohne Wert greift in der App
/// weiterhin die Luftlinien-Heuristik).
async function osrmStrecke(
  von: { lat: number; lng: number },
  nachLat: number,
  nachLng: number,
): Promise<{ minuten: number; km: number } | null> {
  try {
    const url =
      `https://router.project-osrm.org/route/v1/driving/` +
      `${von.lng},${von.lat};${nachLng},${nachLat}?overview=false`;
    const res = await fetch(url, {
      headers: { "User-Agent": "sbs-projer-app" },
    });
    if (!res.ok) return null;
    const data = await res.json();
    const route = data?.routes?.[0];
    if (!route?.duration) return null;
    return {
      minuten: Math.max(1, Math.round(route.duration / 60)),
      km: Math.round((route.distance ?? 0) / 100) / 10,
    };
  } catch (_) {
    return null;
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return json({ error: "POST erwartet" }, 405);

  let userId: string | null;
  try {
    userId = await ermittleUserId(req);
  } catch (e) {
    return json({ error: (e as Error).message }, 500);
  }
  if (!userId) return json({ error: "unauthorized" }, 401);

  const apiKey = Deno.env.get("GOOGLE_PLACES_KEY");

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Optionaler Einzelbetrieb (Aufruf aus dem Betriebs-Formular).
  let nurBetriebId: string | null = null;
  let limit = MAX_LIMIT;
  let offset = 0;
  // deno-lint-ignore no-explicit-any
  let body: any = {};
  try {
    body = await req.json();
  } catch (_) {
    // leerer Body = Voll-Lauf (erste Seite)
  }
  if (body?.betriebId !== undefined) {
    if (typeof body.betriebId !== "string" || !UUID_RE.test(body.betriebId)) {
      return json({ error: "betriebId muss eine UUID sein" }, 400);
    }
    nurBetriebId = body.betriebId;
  }
  if (typeof body?.limit === "number" && Number.isFinite(body.limit) && body.limit > 0) {
    limit = Math.min(Math.floor(body.limit), MAX_LIMIT);
  }
  if (typeof body?.offset === "number" && Number.isFinite(body.offset) && body.offset > 0) {
    offset = Math.floor(body.offset);
  }

  let query = supabase
    .from("betriebe")
    .select("id, latitude, longitude")
    .eq("user_id", userId)
    .not("latitude", "is", null)
    .not("longitude", "is", null);
  if (nurBetriebId) {
    query = query.eq("id", nurBetriebId);
  } else {
    query = query.order("id").range(offset, offset + limit - 1);
  }

  const { data, error } = await query;
  const betriebe = (data ?? []) as { id: string; latitude: number; longitude: number }[];
  if (error) return json({ error: error.message }, 500);
  if (!betriebe.length) return json({ error: "keine Betriebe mit GPS" }, 400);
  // Voll-Lauf: Hinweis fuer die naechste Seite (null = fertig).
  const naechsterOffset = !nurBetriebId && betriebe.length === limit ? offset + limit : null;

  let geschrieben = 0;
  let osrmGeschrieben = 0;
  const fehler: string[] = [];

  // ── OSRM-Werte (kostenlos, immer) ──
  // Beim Einzelbetrieb sind das genau zwei Anfragen; beim Voll-Lauf wäre es
  // eine pro Paar — dort bleibt es beim separaten Matrix-Skript.
  if (nurBetriebId) {
    for (const b of betriebe) {
      for (const start of STARTORTE) {
        const r = await osrmStrecke(
          start,
          Number(b.latitude),
          Number(b.longitude),
        );
        if (r == null) {
          fehler.push(`osrm ${start.key}: keine Route`);
          continue;
        }
        const { error: upErr } = await supabase.from("anfahrtszeiten").upsert(
          {
            user_id: userId,
            startort: start.key,
            betrieb_id: b.id,
            minuten_osrm: r.minuten,
            distanz_km_osrm: r.km,
          },
          { onConflict: "user_id,startort,betrieb_id" },
        );
        if (upErr) {
          fehler.push(`osrm ${start.key}: ${upErr.message}`);
        } else {
          osrmGeschrieben++;
        }
      }
    }
  }

  // ── Google-Werte (nur wenn Key vorhanden und API freigeschaltet) ──
  if (!apiKey) {
    return json({
      geschrieben,
      osrmGeschrieben,
      betriebe: betriebe.length,
      naechsterOffset,
      fehler: [...fehler, "GOOGLE_PLACES_KEY fehlt — nur OSRM"],
    });
  }

  for (const start of STARTORTE) {
    for (let i = 0; i < betriebe.length; i += CHUNK) {
      const chunk = betriebe.slice(i, i + CHUNK);
      const body = {
        origins: [
          {
            waypoint: {
              location: {
                latLng: { latitude: start.lat, longitude: start.lng },
              },
            },
          },
        ],
        destinations: chunk.map((b) => ({
          waypoint: {
            location: {
              latLng: {
                latitude: Number(b.latitude),
                longitude: Number(b.longitude),
              },
            },
          },
        })),
        travelMode: "DRIVE",
        // Ohne Verkehr — reproduzierbare Standardzeiten (Wunsch Daniel).
        routingPreference: "TRAFFIC_UNAWARE",
      };

      const res = await fetch(
        "https://routes.googleapis.com/distanceMatrix/v2:computeRouteMatrix",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-Goog-Api-Key": apiKey,
            "X-Goog-FieldMask":
              "originIndex,destinationIndex,duration,distanceMeters,condition",
          },
          body: JSON.stringify(body),
        },
      );
      if (!res.ok) {
        const text = await res.text();
        fehler.push(`${start.key} chunk ${i}: HTTP ${res.status} ${text.slice(0, 900)}`);
        continue;
      }

      const elemente = (await res.json()) as Array<{
        destinationIndex: number;
        duration?: string;
        distanceMeters?: number;
        condition?: string;
      }>;

      const zeilen: Record<string, unknown>[] = [];
      for (const e of elemente) {
        if (e.condition !== "ROUTE_EXISTS" || !e.duration) continue;
        const sek = parseInt(String(e.duration).replace("s", ""), 10);
        if (!Number.isFinite(sek) || sek <= 0) continue;
        const betrieb = chunk[e.destinationIndex];
        if (!betrieb) continue;
        zeilen.push({
          user_id: userId,
          startort: start.key,
          betrieb_id: betrieb.id,
          minuten_google: Math.max(1, Math.round(sek / 60)),
          distanz_km_google: e.distanceMeters != null
            ? Math.round(e.distanceMeters / 100) / 10
            : null,
        });
      }

      if (zeilen.length) {
        const { error: upErr } = await supabase
          .from("anfahrtszeiten")
          .upsert(zeilen, { onConflict: "user_id,startort,betrieb_id" });
        if (upErr) {
          fehler.push(`${start.key} chunk ${i}: upsert ${upErr.message}`);
        } else {
          geschrieben += zeilen.length;
        }
      }
    }
  }

  return json({
    geschrieben,
    osrmGeschrieben,
    betriebe: betriebe.length,
    naechsterOffset,
    fehler,
  });
});

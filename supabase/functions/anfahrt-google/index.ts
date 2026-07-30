// Anfahrtszeiten von den festen Startorten zu Betrieben.
//
// Zwei Quellen (Wunsch Daniel: «2 Werte sind besser als einer»): Google
// Routes API (computeRouteMatrix, TRAFFIC_UNAWARE = Standardzeiten ohne
// Verkehr) und OSRM als kostenloser Rückfall. Die Tabelle `anfahrtszeiten`
// hält beide Werte nebeneinander; `minuten` bevorzugt Google (Migration 157).
//
// Zwei Betriebsarten:
//   POST {}                    -> alle Betriebe mit GPS (Einmal-Lauf)
//   POST {"betriebId": "..."}  -> nur dieser Betrieb (neuer Betrieb aus dem
//                                 Formular, direkt nach «aus Google übernehmen»)
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

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
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
  if (req.method !== "POST") return json({ error: "POST erwartet" }, 405);

  const apiKey = Deno.env.get("GOOGLE_PLACES_KEY");

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Optionaler Einzelbetrieb (Aufruf aus dem Betriebs-Formular).
  let nurBetriebId: string | null = null;
  try {
    const body = await req.json();
    if (typeof body?.betriebId === "string") nurBetriebId = body.betriebId;
  } catch (_) {
    // leerer Body = Voll-Lauf
  }

  let query = supabase
    .from("betriebe")
    .select("id, latitude, longitude")
    .not("latitude", "is", null)
    .not("longitude", "is", null);
  if (nurBetriebId) query = query.eq("id", nurBetriebId);

  const { data: betriebe, error } = await query;
  if (error) return json({ error: error.message }, 500);
  if (!betriebe?.length) return json({ error: "keine Betriebe mit GPS" }, 400);

  // user_id für die Zeilen: derselbe Nutzer wie die bestehenden Einträge.
  const { data: vorhanden } = await supabase
    .from("anfahrtszeiten")
    .select("user_id")
    .limit(1);
  const userId = vorhanden?.[0]?.user_id;
  if (!userId) return json({ error: "keine user_id ermittelbar" }, 400);

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
    fehler,
  });
});

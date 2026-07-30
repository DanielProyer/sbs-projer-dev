// Anfahrtszeiten von den festen Startorten zu allen Betrieben via Google
// Routes API (computeRouteMatrix, TRAFFIC_UNAWARE = Standardzeiten ohne
// Verkehr/Baustellen — Wunsch Daniel 31.07.2026).
//
// Zweite Meinung neben OSRM: die Tabelle `anfahrtszeiten` hält beide Werte,
// `minuten` bevorzugt automatisch Google (Migration 157).
//
// Einmal-Lauf, kein Client-Aufruf: POST ohne Body startet den Durchlauf.
// Secret: GOOGLE_PLACES_KEY (derselbe Key wie betrieb-google-lookup — die
// Routes API muss im Google-Cloud-Projekt aktiviert sein).

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

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "POST erwartet" }, 405);

  const apiKey = Deno.env.get("GOOGLE_PLACES_KEY");
  if (!apiKey) return json({ error: "GOOGLE_PLACES_KEY fehlt" }, 500);

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: betriebe, error } = await supabase
    .from("betriebe")
    .select("id, latitude, longitude")
    .not("latitude", "is", null)
    .not("longitude", "is", null);
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
  const fehler: string[] = [];

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
        fehler.push(`${start.key} chunk ${i}: HTTP ${res.status} ${text.slice(0, 300)}`);
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

  return json({ geschrieben, betriebe: betriebe.length, fehler });
});

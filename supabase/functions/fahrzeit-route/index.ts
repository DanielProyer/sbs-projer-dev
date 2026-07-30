// Supabase Edge Function: fahrzeit-route
// Liefert die Fahrzeit (Minuten) zwischen zwei Betrieben fuer den
// Tourenplan (Spec "Tourenplan-Zeitachse", Task 2).
//
// Kaskaden-Einordnung:
//   1. Cache-Lookup in Tabelle `fahrzeiten` -- erst die gespeicherte
//      Richtung, dann die Gegenrichtung. Enthaelt sowohl aus der
//      Reinigungshistorie beobachtete ('beobachtet') als auch zuvor per
//      Route berechnete ('route') Fahrzeiten und ist damit der schnellste,
//      verlaesslichste Weg.
//   2. Kein Cache-Treffer: Route via OSRM anhand der Betriebs-Koordinaten
//      berechnen und das Ergebnis als quelle='route' cachen, damit derselbe
//      Betriebspfad kuenftig direkt aus dem Cache kommt.
//   3. Schlaegt auch das fehl (keine Koordinaten, OSRM nicht erreichbar,
//      Timeout, keine Route gefunden): Function liefert ok:false mit
//      Fehlercode -- die App faellt dann auf ihre eigene Heuristik
//      (Luftlinie x Faktor) zurueck. Das ist erwuenschtes Verhalten, kein
//      Fehlerfall der Function.
//
// Warum der OSRM-Demo-Server (router.project-osrm.org): kostenlos, kein
// API-Key noetig. Dank des Caches in `fahrzeiten` wird er pro Betriebspaar
// nur EINMAL angefragt -- die Fair-Use-Grenzen des Demo-Servers werden
// dadurch praktisch nie erreicht. Sollte das doch noetig werden, ist der
// Wechsel auf einen Anbieter mit API-Key (z.B. OpenRouteService) auf diese
// Datei begrenzt.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// deno-lint-ignore no-explicit-any
type Any = any;

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface FahrzeitRow {
  minuten: number;
  quelle: "beobachtet" | "route";
}

interface BetriebRow {
  id: string;
  latitude: number | null;
  longitude: number | null;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });

  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
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
    if (!user) return json({ ok: false, error: "unauthorized" }, 401);

    let body: Any;
    try {
      body = await req.json();
    } catch {
      body = {};
    }
    const vonBetriebId = body?.vonBetriebId;
    const nachBetriebId = body?.nachBetriebId;
    if (
      typeof vonBetriebId !== "string" || typeof nachBetriebId !== "string" ||
      vonBetriebId.length === 0 || nachBetriebId.length === 0 ||
      vonBetriebId === nachBetriebId
    ) {
      return json({ ok: false, error: "bad_request" }, 400);
    }

    // 1) Cache-Lookup: erst gespeicherte Richtung, dann Gegenrichtung.
    const cached = await cacheLookup(
      admin,
      user.id,
      vonBetriebId,
      nachBetriebId,
    );
    if (cached) {
      return json({ ok: true, minuten: cached.minuten, quelle: cached.quelle });
    }

    // 2) Koordinaten beider Betriebe laden.
    const { data: betriebeData, error: betriebeError } = await admin
      .from("betriebe")
      .select("id, latitude, longitude")
      .eq("user_id", user.id)
      .in("id", [vonBetriebId, nachBetriebId]);
    if (betriebeError) {
      console.error("fahrzeit-route betriebe", betriebeError);
      return json({ ok: false, error: "db_error" }, 500);
    }
    const betriebe = (betriebeData ?? []) as BetriebRow[];
    const von = betriebe.find((b) => b.id === vonBetriebId);
    const nach = betriebe.find((b) => b.id === nachBetriebId);
    if (
      !von || !nach || von.latitude == null || von.longitude == null ||
      nach.latitude == null || nach.longitude == null
    ) {
      return json({ ok: false, error: "no_gps" });
    }

    // 3) OSRM-Demo-Server abfragen.
    const url = `https://router.project-osrm.org/route/v1/driving/` +
      `${von.longitude},${von.latitude};${nach.longitude},${nach.latitude}` +
      `?overview=false`;
    let osrmData: Any;
    try {
      const res = await fetch(url, { signal: AbortSignal.timeout(8000) });
      if (!res.ok) return json({ ok: false, error: "osrm_http_error" });
      osrmData = await res.json();
    } catch (e) {
      console.error("fahrzeit-route osrm", e);
      return json({ ok: false, error: "osrm_unreachable" });
    }
    const durationSec = osrmData?.routes?.[0]?.duration;
    if (typeof durationSec !== "number") {
      return json({ ok: false, error: "osrm_no_route" });
    }

    // 4) Ergebnis cachen. Bei Konflikt (z.B. inzwischen von der App als
    // 'beobachtet' eingetragen) NICHT ueberschreiben -- eine echte
    // Beobachtung ist wertvoller als eine berechnete Route.
    const minuten = Math.max(1, Math.round(durationSec / 60));
    const { error: upsertError } = await admin.from("fahrzeiten").upsert(
      {
        user_id: user.id,
        von_betrieb_id: vonBetriebId,
        nach_betrieb_id: nachBetriebId,
        minuten,
        quelle: "route",
        anzahl: 1,
        // Referenzwert (Migration 158): Massstab fuer die
        // Plausibilitaetspruefung beim Lernen. Anders als `minuten` wird er
        // von Beobachtungen NIE ueberschrieben.
        referenz_minuten: minuten,
        referenz_quelle: "osrm",
        updated_at: new Date().toISOString(),
      },
      {
        onConflict: "user_id,von_betrieb_id,nach_betrieb_id",
        ignoreDuplicates: true,
      },
    );
    // Referenz auch dann setzen, wenn die Zeile schon existiert (der upsert
    // oben laesst sie wegen ignoreDuplicates unangetastet) — sonst bekaeme
    // ein Paar, das bereits eine Beobachtung hat, nie seinen Massstab.
    await admin
      .from("fahrzeiten")
      .update({ referenz_minuten: minuten, referenz_quelle: "osrm" })
      .eq("user_id", user.id)
      .eq("von_betrieb_id", vonBetriebId)
      .eq("nach_betrieb_id", nachBetriebId)
      .is("referenz_minuten", null);
    if (upsertError) {
      // Nur loggen: Die Route wurde erfolgreich berechnet, die Antwort an
      // die App bleibt gueltig -- nur der Cache wird evtl. nicht befuellt.
      console.error("fahrzeit-route upsert", upsertError);
    }

    return json({ ok: true, minuten, quelle: "route" });
  } catch (e) {
    console.error("fahrzeit-route", e);
    return json(
      { ok: false, error: e instanceof Error ? e.message : "unknown" },
      500,
    );
  }
});

async function cacheLookup(
  admin: Any,
  userId: string,
  vonBetriebId: string,
  nachBetriebId: string,
): Promise<FahrzeitRow | null> {
  const { data: hin } = await admin.from("fahrzeiten")
    .select("minuten, quelle")
    .eq("user_id", userId)
    .eq("von_betrieb_id", vonBetriebId)
    .eq("nach_betrieb_id", nachBetriebId)
    .maybeSingle();
  if (hin) return hin as FahrzeitRow;

  const { data: rueck } = await admin.from("fahrzeiten")
    .select("minuten, quelle")
    .eq("user_id", userId)
    .eq("von_betrieb_id", nachBetriebId)
    .eq("nach_betrieb_id", vonBetriebId)
    .maybeSingle();
  return rueck ? (rueck as FahrzeitRow) : null;
}

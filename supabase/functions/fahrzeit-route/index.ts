// Supabase Edge Function: fahrzeit-route
// Liefert die Fahrzeit (Minuten) zwischen zwei Betrieben fuer den
// Tourenplan (Spec "Tourenplan-Zeitachse", Task 2) und seit Migration 210
// auch die Strecke (km) fuer die Fahrtenerkennung ("Fahrten aus der Kette").
// Seit Migration 213 (29.09.2026) routet sie auch zwischen PUNKTEN.
//
// Body (anfrage.ts):
//   { von: RoutenEnde, nach: RoutenEnde }
//   RoutenEnde = { betriebId } | { lat, lng }   -- entweder oder
//   Alt (weiter gueltig): { vonBetriebId, nachBetriebId }
//
// Zwei Pfade:
//   A) Beide Enden Betrieb -> Betriebspfad (unten, Schritte 1-4), Cache in
//      `fahrzeiten`. Unveraendert seit 210.
//   B) Mindestens ein Ende ist ein Punkt (GPS-Position von Arbeitsbeginn/
//      Feierabend unterwegs, Startort Domat/Ems oder Chur) -> Punktpfad
//      (`punktPfad`), Cache in `routen_punkte`: Schluessel 'b:<uuid>' bzw.
//      'p:<lat>,<lng>' (4 Nachkommastellen, keys.ts -- die App rechnet
//      dieselben). Kaskade: Cache (Richtung, dann Gegenrichtung) -> OSRM ->
//      Insert (ignoreDuplicates). Antwort wie Pfad A, distanzKm immer
//      gesetzt.
//      WARUM eigene Tabelle: `fahrzeiten` hat auf beiden Seiten einen FK auf
//      `betriebe`, und ihre Minuten lernen aus Beobachtungen (Tourenplan).
//      Ein GPS-Punkt ist kein Betrieb und kehrt kaum je genau wieder;
//      Pseudo-Betriebe dafuer haetten Stammdaten und Tourenplan verschmutzt.
//      WARUM ueberhaupt: Seit v0.152.0 zeigt "Fahrten aus der Kette" keine
//      Luftlinie mehr -- ohne Route hat eine Fahrt keine km. Anfahrt und
//      Heimweg von/zu einer GPS-Position, Domat/Ems <-> Chur und Startort <->
//      Betrieb ohne Eintrag in `anfahrtszeiten` blieben so dauerhaft leer.
//
// Kaskaden-Einordnung (Pfad A):
//   1. Cache-Lookup in Tabelle `fahrzeiten` -- erst die gespeicherte
//      Richtung, dann die Gegenrichtung. Enthaelt sowohl aus der
//      Reinigungshistorie beobachtete ('beobachtet') als auch zuvor per
//      Route berechnete ('route') Fahrzeiten und ist damit der schnellste,
//      verlaesslichste Weg.
//      Fehlt der gefundenen Zeile noch die Distanz (alle Zeilen von vor
//      Migration 210), wird OSRM EINMAL nach der Strecke gefragt und die
//      Zeile ergaenzt. Die Minuten bleiben dabei die gespeicherten -- eine
//      Beobachtung wird nie durch die Route ersetzt. Scheitert das Routing,
//      kommt der Cache-Treffer wie bisher zurueck (distanzKm: null).
//   2. Kein Cache-Treffer: Route via OSRM anhand der Betriebs-Koordinaten
//      berechnen und das Ergebnis als quelle='route' cachen (samt Distanz),
//      damit derselbe Betriebspfad kuenftig direkt aus dem Cache kommt.
//   3. Schlaegt auch das fehl (keine Koordinaten, OSRM nicht erreichbar,
//      Timeout, keine Route gefunden): Function liefert ok:false mit
//      Fehlercode (beide Pfade gleich: no_gps, osrm_http_error,
//      osrm_unreachable, osrm_no_route). Der Tourenplan faellt dann fuer die
//      Minuten auf seine Heuristik (Luftlinie x Faktor) zurueck; die
//      Fahrten-Auswertung zeigt die Fahrt ohne km (keine Schaetzung). Das
//      ist erwuenschtes Verhalten, kein Fehlerfall der Function.
//
// Warum der OSRM-Demo-Server (router.project-osrm.org): kostenlos, kein
// API-Key noetig. Dank der Caches (`fahrzeiten`, `routen_punkte`) wird er
// pro Paar nur EINMAL angefragt (bei Altzeilen in `fahrzeiten` ein zweites
// Mal fuer die Strecke) -- die Fair-Use-Grenzen des Demo-Servers werden
// dadurch praktisch nie erreicht; die App drosselt zusaetzlich (eine
// Anfrage je 1,1 s, gedeckelt je Lauf und Sitzung). Sollte ein Wechsel auf
// einen Anbieter mit API-Key (z.B. OpenRouteService) noetig werden, ist er
// auf diese Datei begrenzt (Schritt 3 im Betriebspfad und `osrmRoute`).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { type Anfrage, anfrageLesen, type Ende } from "./anfrage.ts";
import { betriebKey, punktKey } from "./keys.ts";

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
  // numeric(6,1) -- kann je nach Client als Zahl oder String ankommen.
  distanz_km: number | string | null;
  // Richtung der GEFUNDENEN Zeile (bei Treffer in der Gegenrichtung die
  // umgekehrte der Anfrage) -- die Distanz wird genau dort nachgetragen.
  von_betrieb_id: string;
  nach_betrieb_id: string;
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
    const anfrage = anfrageLesen(body);
    if (anfrage == null) {
      return json({ ok: false, error: "bad_request" }, 400);
    }
    // Pfad B: mindestens ein Ende ist ein Punkt (Migration 213).
    if (anfrage.von.art !== "betrieb" || anfrage.nach.art !== "betrieb") {
      const antwort = await punktPfad(admin, user.id, anfrage);
      return json(antwort.body, antwort.status);
    }
    // Pfad A: Betrieb -> Betrieb, unveraendert seit Migration 210.
    const vonBetriebId = anfrage.von.betriebId;
    const nachBetriebId = anfrage.nach.betriebId;

    // 1) Cache-Lookup: erst gespeicherte Richtung, dann Gegenrichtung.
    const cached = await cacheLookup(
      admin,
      user.id,
      vonBetriebId,
      nachBetriebId,
    );
    const cachedDistanz = cached ? zahlOderNull(cached.distanz_km) : null;
    if (cached && cachedDistanz != null) {
      return json({
        ok: true,
        minuten: cached.minuten,
        quelle: cached.quelle,
        distanzKm: cachedDistanz,
      });
    }
    // Cache-Treffer ohne Distanz: Jeder Fehlschlag beim Nachholen der
    // Strecke liefert den Treffer wie vor Migration 210 (ok:true).
    const nurCache = (c: FahrzeitRow) =>
      json({ ok: true, minuten: c.minuten, quelle: c.quelle, distanzKm: null });

    // Richtung fuers Routing: bei Altzeile die der Zeile, sonst die Anfrage.
    const routeVonId = cached ? cached.von_betrieb_id : vonBetriebId;
    const routeNachId = cached ? cached.nach_betrieb_id : nachBetriebId;

    // 2) Koordinaten beider Betriebe laden.
    const { data: betriebeData, error: betriebeError } = await admin
      .from("betriebe")
      .select("id, latitude, longitude")
      .eq("user_id", user.id)
      .in("id", [vonBetriebId, nachBetriebId]);
    if (betriebeError) {
      console.error("fahrzeit-route betriebe", betriebeError);
      if (cached) return nurCache(cached);
      return json({ ok: false, error: "db_error" }, 500);
    }
    const betriebe = (betriebeData ?? []) as BetriebRow[];
    const von = betriebe.find((b) => b.id === routeVonId);
    const nach = betriebe.find((b) => b.id === routeNachId);
    if (
      !von || !nach || von.latitude == null || von.longitude == null ||
      nach.latitude == null || nach.longitude == null
    ) {
      if (cached) return nurCache(cached);
      return json({ ok: false, error: "no_gps" });
    }

    // 3) OSRM-Demo-Server abfragen.
    const url = `https://router.project-osrm.org/route/v1/driving/` +
      `${von.longitude},${von.latitude};${nach.longitude},${nach.latitude}` +
      `?overview=false`;
    let osrmData: Any;
    try {
      const res = await fetch(url, { signal: AbortSignal.timeout(8000) });
      if (!res.ok) {
        if (cached) return nurCache(cached);
        return json({ ok: false, error: "osrm_http_error" });
      }
      osrmData = await res.json();
    } catch (e) {
      console.error("fahrzeit-route osrm", e);
      if (cached) return nurCache(cached);
      return json({ ok: false, error: "osrm_unreachable" });
    }
    const durationSec = osrmData?.routes?.[0]?.duration;
    const distanceM = osrmData?.routes?.[0]?.distance;
    // Meter -> km mit einer Nachkommastelle (Spalte numeric(6,1)).
    const distanzKm = typeof distanceM === "number"
      ? Math.round(distanceM / 100) / 10
      : null;

    // 3a) Altzeile ohne Distanz: NUR die Strecke nachtragen. Minuten,
    // Quelle und Referenz bleiben unangetastet (Beobachtung > Route).
    if (cached) {
      if (distanzKm != null) {
        const { error: distanzError } = await admin
          .from("fahrzeiten")
          .update({ distanz_km: distanzKm, distanz_quelle: "osrm" })
          .eq("user_id", user.id)
          .eq("von_betrieb_id", cached.von_betrieb_id)
          .eq("nach_betrieb_id", cached.nach_betrieb_id)
          .is("distanz_km", null);
        if (distanzError) {
          console.error("fahrzeit-route distanz nachtragen", distanzError);
        }
      }
      return json({
        ok: true,
        minuten: cached.minuten,
        quelle: cached.quelle,
        distanzKm,
      });
    }

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
        // Strecke (Migration 210) fuer die Fahrtenerkennung.
        distanz_km: distanzKm,
        distanz_quelle: distanzKm != null ? "osrm" : null,
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
    // Gleiches fuer die Strecke (Migration 210): nur wo sie noch fehlt.
    if (distanzKm != null) {
      await admin
        .from("fahrzeiten")
        .update({ distanz_km: distanzKm, distanz_quelle: "osrm" })
        .eq("user_id", user.id)
        .eq("von_betrieb_id", vonBetriebId)
        .eq("nach_betrieb_id", nachBetriebId)
        .is("distanz_km", null);
    }
    if (upsertError) {
      // Nur loggen: Die Route wurde erfolgreich berechnet, die Antwort an
      // die App bleibt gueltig -- nur der Cache wird evtl. nicht befuellt.
      console.error("fahrzeit-route upsert", upsertError);
    }

    return json({ ok: true, minuten, quelle: "route", distanzKm });
  } catch (e) {
    console.error("fahrzeit-route", e);
    return json(
      { ok: false, error: e instanceof Error ? e.message : "unknown" },
      500,
    );
  }
});

// numeric-Spalte (Zahl oder String) -> Zahl; null/unlesbar -> null.
function zahlOderNull(v: number | string | null | undefined): number | null {
  if (v == null) return null;
  const n = typeof v === "number" ? v : Number(v);
  return Number.isFinite(n) ? n : null;
}

async function cacheLookup(
  admin: Any,
  userId: string,
  vonBetriebId: string,
  nachBetriebId: string,
): Promise<FahrzeitRow | null> {
  const spalten =
    "minuten, quelle, distanz_km, von_betrieb_id, nach_betrieb_id";
  const { data: hin } = await admin.from("fahrzeiten")
    .select(spalten)
    .eq("user_id", userId)
    .eq("von_betrieb_id", vonBetriebId)
    .eq("nach_betrieb_id", nachBetriebId)
    .maybeSingle();
  if (hin) return hin as FahrzeitRow;

  const { data: rueck } = await admin.from("fahrzeiten")
    .select(spalten)
    .eq("user_id", userId)
    .eq("von_betrieb_id", nachBetriebId)
    .eq("nach_betrieb_id", vonBetriebId)
    .maybeSingle();
  return rueck ? (rueck as FahrzeitRow) : null;
}

// ── Pfad B: Punkte (Migration 213) ──────────────────────────────────────

interface PunktRouteRow {
  minuten: number;
  // numeric(6,1) -- kann je nach Client als Zahl oder String ankommen.
  distanz_km: number | string;
}

type Antwort = { status: number; body: unknown };

/** Schluessel eines Endes im Cache `routen_punkte` (keys.ts). */
function endeKey(e: Ende): string {
  return e.art === "betrieb" ? betriebKey(e.betriebId) : punktKey(e.lat, e.lng);
}

/**
 * Mindestens ein Ende ist ein Punkt: Cache `routen_punkte` (Richtung, dann
 * Gegenrichtung) -> Koordinaten aufloesen -> OSRM -> Insert. Anders als im
 * Betriebspfad gibt es hier nichts nachzutragen: Jede Zeile hat Minuten UND
 * Strecke (distanz_km NOT NULL), sonst wird sie gar nicht geschrieben.
 */
async function punktPfad(
  admin: Any,
  userId: string,
  anfrage: Anfrage,
): Promise<Antwort> {
  const ok = (body: unknown): Antwort => ({ status: 200, body });
  const vonKey = endeKey(anfrage.von);
  const nachKey = endeKey(anfrage.nach);

  // 1) Cache -- fuer Betriebs-Enden braucht der Schluessel keine
  // Koordinaten, der Treffer kommt also ohne Stammdaten-Abfrage.
  const cached = await punktCacheLookup(admin, userId, vonKey, nachKey);
  const cachedKm = cached ? zahlOderNull(cached.distanz_km) : null;
  if (cached && cachedKm != null) {
    return ok({
      ok: true,
      minuten: cached.minuten,
      quelle: "osrm",
      distanzKm: cachedKm,
    });
  }

  // 2) Koordinaten: Punkt aus dem Body, Betrieb aus den Stammdaten des Users.
  const betriebIds: string[] = [];
  for (const e of [anfrage.von, anfrage.nach]) {
    if (e.art === "betrieb") betriebIds.push(e.betriebId);
  }
  let betriebe: BetriebRow[] = [];
  if (betriebIds.length > 0) {
    const { data, error } = await admin
      .from("betriebe")
      .select("id, latitude, longitude")
      .eq("user_id", userId)
      .in("id", betriebIds);
    if (error) {
      console.error("fahrzeit-route punkt betriebe", error);
      return { status: 500, body: { ok: false, error: "db_error" } };
    }
    betriebe = (data ?? []) as BetriebRow[];
  }
  const ort = (e: Ende): { lat: number; lng: number } | null => {
    if (e.art === "punkt") return { lat: e.lat, lng: e.lng };
    const b = betriebe.find((x) => x.id === e.betriebId);
    return b && b.latitude != null && b.longitude != null
      ? { lat: b.latitude, lng: b.longitude }
      : null;
  };
  const von = ort(anfrage.von);
  const nach = ort(anfrage.nach);
  if (!von || !nach) return ok({ ok: false, error: "no_gps" });

  // 3) OSRM.
  const route = await osrmRoute(von, nach);
  if ("error" in route) return ok({ ok: false, error: route.error });

  // 4) Cachen. ignoreDuplicates: Eine parallele Anfrage fuer dasselbe Paar
  // hat evtl. schon geschrieben -- deren Zeile bleibt, die Antwort hier ist
  // trotzdem gueltig.
  const { error: insertError } = await admin.from("routen_punkte").upsert(
    {
      user_id: userId,
      von_key: vonKey,
      nach_key: nachKey,
      distanz_km: route.distanzKm,
      minuten: route.minuten,
      quelle: "osrm",
    },
    { onConflict: "user_id,von_key,nach_key", ignoreDuplicates: true },
  );
  if (insertError) {
    // Nur loggen: Die Route ist berechnet, nur der Cache fehlt evtl.
    console.error("fahrzeit-route punkt insert", insertError);
  }

  return ok({
    ok: true,
    minuten: route.minuten,
    quelle: "route",
    distanzKm: route.distanzKm,
  });
}

async function punktCacheLookup(
  admin: Any,
  userId: string,
  vonKey: string,
  nachKey: string,
): Promise<PunktRouteRow | null> {
  const spalten = "minuten, distanz_km";
  const { data: hin } = await admin.from("routen_punkte")
    .select(spalten)
    .eq("user_id", userId)
    .eq("von_key", vonKey)
    .eq("nach_key", nachKey)
    .maybeSingle();
  if (hin) return hin as PunktRouteRow;

  const { data: rueck } = await admin.from("routen_punkte")
    .select(spalten)
    .eq("user_id", userId)
    .eq("von_key", nachKey)
    .eq("nach_key", vonKey)
    .maybeSingle();
  return rueck ? (rueck as PunktRouteRow) : null;
}

/**
 * Eine Route beim OSRM-Demo-Server (gleiche URL und gleicher Timeout wie im
 * Betriebspfad). Liefert Minuten (>= 1) und km (eine Nachkommastelle) oder
 * einen Fehlercode. Ohne Dauer ODER ohne Strecke `osrm_no_route` -- der
 * Punkt-Cache speichert nur vollstaendige Routen.
 */
async function osrmRoute(
  von: { lat: number; lng: number },
  nach: { lat: number; lng: number },
): Promise<{ minuten: number; distanzKm: number } | { error: string }> {
  const url = `https://router.project-osrm.org/route/v1/driving/` +
    `${von.lng},${von.lat};${nach.lng},${nach.lat}` +
    `?overview=false`;
  let osrmData: Any;
  try {
    const res = await fetch(url, { signal: AbortSignal.timeout(8000) });
    if (!res.ok) return { error: "osrm_http_error" };
    osrmData = await res.json();
  } catch (e) {
    console.error("fahrzeit-route punkt osrm", e);
    return { error: "osrm_unreachable" };
  }
  const durationSec = osrmData?.routes?.[0]?.duration;
  const distanceM = osrmData?.routes?.[0]?.distance;
  if (typeof durationSec !== "number" || typeof distanceM !== "number") {
    return { error: "osrm_no_route" };
  }
  return {
    minuten: Math.max(1, Math.round(durationSec / 60)),
    // Meter -> km mit einer Nachkommastelle (Spalte numeric(6,1)).
    distanzKm: Math.round(distanceM / 100) / 10,
  };
}

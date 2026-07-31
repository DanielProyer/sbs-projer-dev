// Supabase Edge Function: betrieb-google-abgleich
// Liest die Google-Daten EINES Betriebs (Oeffnungszeiten, Ruhetage,
// Geschaeftsstatus) und gibt sie im selben Format zurueck wie
// parse-oeffnungszeiten. Schreibt NICHTS in die Betriebs-Stammdaten ausser
// der einmaligen google_place_id (rein technische Kopplung) -- Vorschlaege
// entstehen erst im Orchestrator `betriebsdaten-abgleich`.
//
// Aufruf:
//   POST {"betriebId": "..."}                          -> laedt den Betrieb,
//        nutzt/ermittelt place_id, speichert sie am Betrieb
//   POST {"name": "...", "adresse": "...", "placeId"?}  -> Ad-hoc-Abfrage
//        ohne DB-Schreibzugriff (z.B. fuer manuelle Tests)
//
// Deploy: supabase functions deploy betrieb-google-abgleich --no-verify-jwt
// Secrets: GOOGLE_PLACES_KEY (wie betrieb-google-lookup),
//          SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (Standard-Secrets der Edge
//          Function Runtime, kein manuelles Setzen noetig)

import { createClient } from "jsr:@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const SEARCH_FIELD_MASK = [
  "places.id",
  "places.displayName",
  "places.formattedAddress",
].join(",");

const DETAILS_FIELD_MASK = [
  "regularOpeningHours",
  "currentOpeningHours",
  "businessStatus",
].join(",");

// Google: 0=Sonntag .. 6=Samstag. Unsere Kuerzel sind Mo-first, darum eigene
// Umrechnungstabelle statt der App-ueblichen ["Mo",...,"So"].
const GOOGLE_TAG_KUERZEL = ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"];
const WOCHENTAGE = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"];

type Slot = { von: string; bis: string };
type Oeffnungszeiten = Record<string, Slot[]>;

interface GoogleZeitpunkt {
  day?: number;
  hour?: number;
  minute?: number;
}
interface GooglePeriod {
  open?: GoogleZeitpunkt;
  close?: GoogleZeitpunkt;
}
interface GoogleOpeningHours {
  periods?: GooglePeriod[];
}
interface GooglePlace {
  id?: string;
  businessStatus?: string;
  regularOpeningHours?: GoogleOpeningHours;
  currentOpeningHours?: GoogleOpeningHours;
}

function pad2(n: number): string {
  return String(n).padStart(2, "0");
}

function zeitStr(z?: GoogleZeitpunkt): string | null {
  if (!z) return null;
  return `${pad2(z.hour ?? 0)}:${pad2(z.minute ?? 0)}`;
}

function leereOeffnungszeiten(): Oeffnungszeiten {
  const out: Oeffnungszeiten = {};
  for (const tag of WOCHENTAGE) out[tag] = [];
  return out;
}

/// Rechnet Google-`periods` in unser Format {"Mo":[{"von","bis"}], ...} um.
/// `null`, wenn Google keinerlei Oeffnungszeiten-Info fuer den Ort hat --
/// dann darf der Aufrufer NICHT auf Ruhetage schliessen (leer != geprueft).
function periodenUmrechnen(
  periods: GooglePeriod[] | undefined,
): { oeffnungszeiten: Oeffnungszeiten; ruhetage: string[] } | null {
  if (!periods || periods.length === 0) return null;

  // Sonderfall 24/7: Google liefert dafuer oft nur EINE Periode ohne
  // `close` (open So 00:00). Ohne Sonderbehandlung wuerden Mo-Sa faelschlich
  // als Ruhetage erscheinen, obwohl der Betrieb durchgehend offen hat.
  if (
    periods.length === 1 &&
    periods[0].open?.day === 0 &&
    (periods[0].open?.hour ?? 0) === 0 &&
    (periods[0].open?.minute ?? 0) === 0 &&
    !periods[0].close
  ) {
    const oeffnungszeiten = leereOeffnungszeiten();
    for (const tag of WOCHENTAGE) oeffnungszeiten[tag] = [{ von: "00:00", bis: "23:59" }];
    return { oeffnungszeiten, ruhetage: [] };
  }

  const oeffnungszeiten = leereOeffnungszeiten();

  for (const period of periods) {
    const openDay = period.open?.day;
    const von = zeitStr(period.open);
    if (openDay == null || !von) continue;
    const kuerzel = GOOGLE_TAG_KUERZEL[openDay];
    if (!kuerzel) continue;

    let bis: string;
    if (!period.close) {
      // Kein close-Objekt = durchgehend offen bis Mitternacht.
      bis = "23:59";
    } else {
      const closeDay = period.close.day;
      const closeZeit = zeitStr(period.close);
      if (closeDay === openDay && closeZeit && closeZeit > von) {
        bis = closeZeit;
      } else {
        // Laeuft ueber Mitternacht (oder Sonderfall gleicher Tag mit
        // Ende <= Start) -> am Ende des Oeffnungstags kappen, analog
        // parse-oeffnungszeiten ("23:59" statt "24:00"/Folgetag).
        bis = "23:59";
      }
    }
    oeffnungszeiten[kuerzel].push({ von, bis });
  }

  const ruhetage = WOCHENTAGE.filter((tag) => oeffnungszeiten[tag].length === 0);
  return { oeffnungszeiten, ruhetage };
}

function buildAdresse(
  b: { strasse?: string | null; nr?: string | null; plz?: string | null; ort?: string | null },
): string {
  const strasseNr = [b.strasse, b.nr].filter(Boolean).join(" ");
  const plzOrt = [b.plz, b.ort].filter(Boolean).join(" ");
  return [strasseNr, plzOrt].filter((s) => s.trim().length > 0).join(", ");
}

async function fetchMitTimeout(
  url: string,
  init: RequestInit,
  timeoutMs = 12000,
): Promise<Response> {
  const controller = new AbortController();
  const t = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, { ...init, signal: controller.signal });
  } finally {
    clearTimeout(t);
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });

  try {
    const apiKey = Deno.env.get("GOOGLE_PLACES_KEY");
    if (!apiKey) return json({ error: "GOOGLE_PLACES_KEY not configured" }, 500);

    const body = await req.json().catch(() => ({}));
    const { betriebId, name: nameInput, adresse: adresseInput, placeId: placeIdInput } = body as {
      betriebId?: string;
      name?: string;
      adresse?: string;
      placeId?: string;
    };

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const supabase = supabaseUrl && serviceKey ? createClient(supabaseUrl, serviceKey) : null;

    let queryName: string;
    let queryAdresse: string;
    let placeId: string | null = placeIdInput ?? null;

    if (betriebId) {
      if (!supabase) {
        return json({ error: "SUPABASE_URL/SUPABASE_SERVICE_ROLE_KEY fehlen" }, 500);
      }
      const { data: betrieb, error: selErr } = await supabase
        .from("betriebe")
        .select("id, name, strasse, nr, plz, ort, google_place_id")
        .eq("id", betriebId)
        .maybeSingle();
      if (selErr) return json({ error: selErr.message }, 500);
      if (!betrieb) return json({ error: "Betrieb nicht gefunden" }, 404);

      queryName = betrieb.name;
      queryAdresse = buildAdresse(betrieb);
      placeId = betrieb.google_place_id ?? placeId;
    } else if (nameInput && nameInput.trim().length > 0) {
      queryName = nameInput.trim();
      queryAdresse = adresseInput ?? "";
    } else {
      return json({ error: "betriebId oder name ist erforderlich" }, 400);
    }

    // Place-ID einmalig ermitteln (Textsuche), am Betrieb speichern.
    if (!placeId) {
      const textQuery = [queryName, queryAdresse].filter((s) => s && s.trim().length > 0).join(
        ", ",
      );
      const searchRes = await fetchMitTimeout(
        "https://places.googleapis.com/v1/places:searchText",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-Goog-Api-Key": apiKey,
            "X-Goog-FieldMask": SEARCH_FIELD_MASK,
          },
          body: JSON.stringify({ textQuery, languageCode: "de", regionCode: "CH" }),
        },
      );
      if (!searchRes.ok) {
        const details = await searchRes.text();
        console.error(`Places searchText error ${searchRes.status}: ${details}`);
        return json({ error: `Places API error: ${searchRes.status}`, details }, 502);
      }
      const searchData = await searchRes.json();
      const place = Array.isArray(searchData.places) ? searchData.places[0] : null;
      if (!place?.id) return json({ error: "no_result" }, 200);
      placeId = place.id;

      if (betriebId && supabase) {
        const { error: updErr } = await supabase
          .from("betriebe")
          .update({ google_place_id: placeId })
          .eq("id", betriebId);
        // Speicherfehler soll den Abgleich selbst nicht verhindern -- der
        // naechste Lauf sucht einfach erneut.
        if (updErr) console.error(`google_place_id nicht gespeichert: ${updErr.message}`);
      }
    }

    const detailsRes = await fetchMitTimeout(
      `https://places.googleapis.com/v1/places/${placeId}`,
      {
        method: "GET",
        headers: {
          "X-Goog-Api-Key": apiKey,
          "X-Goog-FieldMask": DETAILS_FIELD_MASK,
        },
      },
    );
    if (!detailsRes.ok) {
      const details = await detailsRes.text();
      console.error(`Places details error ${detailsRes.status}: ${details}`);
      return json(
        { error: `Places API error: ${detailsRes.status}`, details, placeId },
        502,
      );
    }
    const place = (await detailsRes.json()) as GooglePlace;

    // regularOpeningHours ist die reguläre Woche; currentOpeningHours nur
    // als Rueckfall, falls Google fuer diesen Ort keine regulaeren Zeiten
    // fuehrt (currentOpeningHours kann Sonderzeiten enthalten, ist aber
    // besser als gar keine Angabe).
    const quelle = place.regularOpeningHours ?? place.currentOpeningHours ?? null;
    const umgerechnet = periodenUmrechnen(quelle?.periods);

    return json({
      oeffnungszeiten: umgerechnet?.oeffnungszeiten ?? null,
      ruhetage: umgerechnet?.ruhetage ?? [],
      businessStatus: place.businessStatus ?? null,
      placeId,
    });
  } catch (error) {
    const msg = (error as Error).message;
    console.error("Function error:", msg);
    const isTimeout = msg.includes("abort");
    return json(
      { error: isTimeout ? "Timeout bei der Google-Anfrage." : `Fehler: ${msg}` },
      isTimeout ? 504 : 500,
    );
  }
});

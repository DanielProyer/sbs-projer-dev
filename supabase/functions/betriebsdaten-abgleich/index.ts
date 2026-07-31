// Supabase Edge Function: betriebsdaten-abgleich
// Orchestrator fuer den taeglichen Datenpflege-Lauf (Spec
// docs/superpowers/specs/2026-07-31-betriebsdaten-aktuell-halten-design.md).
// Prueft je Betrieb Google (betrieb-google-abgleich) UND die Website
// (parse-oeffnungszeiten) und legt Aenderungsvorschlaege in
// `betrieb_vorschlaege` ab. Schreibt NIE direkt in die Betriebs-Stammdaten
// -- eine still uebernommene falsche Angabe waere schlimmer als gar keine.
//
// Aufruf:
//   POST {}                       -> die 10 am laengsten nicht geprueften
//                                     aktiven Betriebe (Vorgabe: limit=10)
//   POST {"limit": 25}            -> abweichende Anzahl
//   POST {"betriebIds": ["..."]}  -> genau diese Betriebe (z.B. manueller Test)
//
// Deploy: supabase functions deploy betriebsdaten-abgleich --no-verify-jwt
// Secrets: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (Standard-Secrets der
//          Edge-Function-Runtime), GOOGLE_PLACES_KEY + ANTHROPIC_API_KEY
//          (werden von den aufgerufenen Functions betrieb-google-abgleich
//          und parse-oeffnungszeiten benoetigt, nicht direkt von hier)
//
// Ablauf je Betrieb (sequenziell, NICHT parallel -- Rate-Limits Google/
// Anthropic):
//   1. Google- und Website-Ergebnis holen (je eigener try/catch, ein
//      Fehler bei einer Quelle darf die andere nicht verhindern)
//   2. Je Feld (ruhetage, oeffnungszeiten, ferien, saison, status) mit dem
//      Ist-Zustand vergleichen; nur bei echter Abweichung + Konfidenz >= 0.6
//      einen Vorschlag anlegen. Sind sich Google und Website einig, wird
//      daraus EIN Vorschlag mit quelle='google_website'.
//   3. oeffnungszeiten_geprueft_am IMMER setzen (auch bei Fehlern) --
//      sonst blockiert ein dauerhaft fehlerhafter Betrieb (z.B. tote
//      Website) fuer immer den Kopf der Warteschlange.

import { createClient } from "jsr:@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const DEFAULT_LIMIT = 10;
const MIN_KONFIDENZ = 0.6;
// Google Places liefert keine eigene Konfidenz -- die Daten sind strukturiert
// und nicht LLM-geraten, darum ein fixer, hoher Wert.
const GOOGLE_KONFIDENZ = 0.85;
// businessStatus ist ein direktes Signal von Google (kein Textverstehen),
// darum ebenfalls fix und hoch.
const STATUS_KONFIDENZ = 0.9;

const WOCHENTAGE = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"];

type Slot = { von: string; bis: string };
type Oeffnungszeiten = Record<string, Slot[]>;
type FerienPeriode = { von: string; bis: string };
type SaisonFenster = {
  von_tag: number;
  von_monat: number;
  bis_tag: number;
  bis_monat: number;
};

interface BetriebRow {
  id: string;
  user_id: string;
  name: string;
  strasse: string | null;
  nr: string | null;
  plz: string | null;
  ort: string | null;
  website: string | null;
  status: string;
  ruhetage: string[] | null;
  oeffnungszeiten: Oeffnungszeiten | null;
  google_place_id: string | null;
  keine_betriebsferien: boolean | null;
  ist_saisonbetrieb: boolean | null;
  sommer_saison_aktiv: boolean | null;
  sommer_start_datum: string | null;
  sommer_ende_datum: string | null;
  winter_saison_aktiv: boolean | null;
  winter_start_datum: string | null;
  winter_ende_datum: string | null;
}

interface GoogleErgebnis {
  oeffnungszeiten: Oeffnungszeiten | null;
  ruhetage: string[];
  businessStatus?: string | null;
  placeId?: string;
  error?: string;
}

interface WebsiteErgebnis {
  oeffnungszeiten?: Oeffnungszeiten;
  ruhetage?: string[];
  konfidenz?: number;
  ferien?: FerienPeriode[];
  ferien_konfidenz?: number;
  saison?: { sommer: SaisonFenster | null; winter: SaisonFenster | null };
  saison_konfidenz?: number;
  error?: string;
}

// ── Normalisierung (fuer stabile Vergleiche UND stabile jsonb-Ablage) ──

function normRuhetage(arr?: string[] | null): string[] {
  return Array.from(new Set((arr ?? []).filter(Boolean))).sort();
}

function normSlots(slots?: Slot[] | null): Slot[] {
  return (slots ?? [])
    .map((s) => ({ von: s.von, bis: s.bis }))
    .sort((a, b) => (a.von === b.von ? a.bis.localeCompare(b.bis) : a.von.localeCompare(b.von)));
}

function normOeffnungszeiten(map?: Oeffnungszeiten | null): Oeffnungszeiten {
  const out: Oeffnungszeiten = {};
  for (const tag of WOCHENTAGE) out[tag] = normSlots(map?.[tag]);
  return out;
}

function normFerien(list?: FerienPeriode[] | null): FerienPeriode[] {
  // Abgelaufene Zeitraeume fliegen raus. Auf Gastro-Websites bleiben alte
  // Ferienmeldungen oft jahrelang stehen (Fund im ersten Testlauf: eine
  // Meldung von November 2024). Ein Vorschlag fuer vergangene Ferien ist
  // wertlos und verstopft nur die Pruefliste.
  const heute = new Date().toISOString().slice(0, 10);
  return (list ?? [])
    .filter((f) => f?.von && f?.bis && f.bis >= heute)
    .map((f) => ({ von: f.von, bis: f.bis }))
    .sort((a, b) => a.von.localeCompare(b.von));
}

function normFenster(f?: SaisonFenster | null): SaisonFenster | null {
  if (!f) return null;
  // Immer in fester Reihenfolge neu aufbauen -- macht den Vergleich
  // unabhaengig von der Schluessel-Reihenfolge im geparsten JSON.
  return { von_tag: f.von_tag, von_monat: f.von_monat, bis_tag: f.bis_tag, bis_monat: f.bis_monat };
}

function tagMonatAusDatum(iso?: string | null): { tag: number; monat: number } | null {
  if (!iso) return null;
  const [, m, d] = iso.split("-").map(Number);
  if (!m || !d) return null;
  return { tag: d, monat: m };
}

function gleich(a: unknown, b: unknown): boolean {
  return JSON.stringify(a) === JSON.stringify(b);
}

// ── Quelle-Merge: aus je einem optionalen Google- und Website-Kandidaten
// werden 0, 1 oder 2 Vorschlagszeilen. Wird fuer alle fuenf Felder
// wiederverwendet (bei status/ferien/saison ist eine der beiden Seiten
// immer `null`, weil nur eine Quelle das Feld liefern kann). ──

interface Kandidat {
  wert: unknown;
  konfidenz: number;
}
interface VorschlagZeile {
  quelle: "google" | "website" | "google_website";
  neuWert: unknown;
  konfidenz: number;
}

function vorschlaegeFuerFeld(
  ist: unknown,
  google: Kandidat | null,
  website: Kandidat | null,
): VorschlagZeile[] {
  const g = google && !gleich(google.wert, ist) ? google : null;
  const w = website && !gleich(website.wert, ist) ? website : null;

  if (g && w) {
    if (gleich(g.wert, w.wert)) {
      return [{ quelle: "google_website", neuWert: g.wert, konfidenz: Math.max(g.konfidenz, w.konfidenz) }];
    }
    return [
      { quelle: "google", neuWert: g.wert, konfidenz: g.konfidenz },
      { quelle: "website", neuWert: w.wert, konfidenz: w.konfidenz },
    ];
  }
  if (g) return [{ quelle: "google", neuWert: g.wert, konfidenz: g.konfidenz }];
  if (w) return [{ quelle: "website", neuWert: w.wert, konfidenz: w.konfidenz }];
  return [];
}

// ── HTTP-Aufrufe der beiden Quell-Functions, mit Zeitlimit ──

async function rufeFunctionAuf<T>(
  url: string,
  body: unknown,
  headers: Record<string, string>,
  timeoutMs = 25000,
): Promise<T> {
  const controller = new AbortController();
  const t = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, {
      method: "POST",
      headers,
      body: JSON.stringify(body),
      signal: controller.signal,
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      throw new Error(`HTTP ${res.status}: ${JSON.stringify(data).slice(0, 300)}`);
    }
    return data as T;
  } finally {
    clearTimeout(t);
  }
}

// ── Kernlogik je Betrieb ──

interface VerarbeitungsErgebnis {
  vorschlaege: number;
  fehler: string[];
}

// deno-lint-ignore no-explicit-any
async function verarbeiteBetrieb(
  supabase: any,
  supabaseUrl: string,
  serviceKey: string,
  betrieb: BetriebRow,
): Promise<VerarbeitungsErgebnis> {
  const fehler: string[] = [];
  const authHeaders = {
    "Content-Type": "application/json",
    Authorization: `Bearer ${serviceKey}`,
    apikey: serviceKey,
  };

  // ── Google-Quelle ──
  let google: GoogleErgebnis | null = null;
  try {
    const res = await rufeFunctionAuf<GoogleErgebnis>(
      `${supabaseUrl}/functions/v1/betrieb-google-abgleich`,
      { betriebId: betrieb.id },
      authHeaders,
    );
    if (res.error) {
      // "no_result" o.ae. ist kein Fehler im Sinne von "Lauf schlaegt fehl",
      // sondern schlicht "keine Google-Daten fuer diesen Betrieb".
      if (res.error !== "no_result") fehler.push(`google: ${res.error}`);
    } else {
      google = res;
    }
  } catch (e) {
    fehler.push(`google: ${(e as Error).message}`);
  }

  // ── Website-Quelle (nur wenn eine Website hinterlegt ist) ──
  let website: WebsiteErgebnis | null = null;
  if (betrieb.website && betrieb.website.trim().length > 0) {
    try {
      const res = await rufeFunctionAuf<WebsiteErgebnis>(
        `${supabaseUrl}/functions/v1/parse-oeffnungszeiten`,
        { url: betrieb.website, name: betrieb.name },
        authHeaders,
      );
      if (res.error) {
        fehler.push(`website: ${res.error}`);
      } else {
        website = res;
      }
    } catch (e) {
      fehler.push(`website: ${(e as Error).message}`);
    }
  }

  // ── Kandidaten je Feld bauen ──
  // Google liefert oeffnungszeiten=null, wenn es dafuer keinerlei Angabe
  // hat -- dann darf weder ruhetage noch oeffnungszeiten als Kandidat
  // gelten (leer != geprueft-und-offen).
  const googleHatOeffnungszeiten = google != null && google.oeffnungszeiten != null;
  const websiteKonfidenzOk = website != null && (website.konfidenz ?? 0) >= MIN_KONFIDENZ;

  const kandidaten: {
    feld: "ruhetage" | "oeffnungszeiten" | "ferien" | "saison" | "status";
    ist: unknown;
    google: Kandidat | null;
    website: Kandidat | null;
  }[] = [];

  kandidaten.push({
    feld: "ruhetage",
    ist: normRuhetage(betrieb.ruhetage),
    google: googleHatOeffnungszeiten
      ? { wert: normRuhetage(google!.ruhetage), konfidenz: GOOGLE_KONFIDENZ }
      : null,
    website: websiteKonfidenzOk && website!.ruhetage
      ? { wert: normRuhetage(website!.ruhetage), konfidenz: website!.konfidenz! }
      : null,
  });

  kandidaten.push({
    feld: "oeffnungszeiten",
    ist: normOeffnungszeiten(betrieb.oeffnungszeiten),
    google: googleHatOeffnungszeiten
      ? { wert: normOeffnungszeiten(google!.oeffnungszeiten), konfidenz: GOOGLE_KONFIDENZ }
      : null,
    website: websiteKonfidenzOk && website!.oeffnungszeiten
      ? { wert: normOeffnungszeiten(website!.oeffnungszeiten), konfidenz: website!.konfidenz! }
      : null,
  });

  // Ferien: NUR die Website liefert das Feld (Google-Places kennt kein
  // Ferienfeld). Ist-Zustand kommt aus betrieb_ferien (aktuelle/kuenftige
  // Perioden), nicht aus den veralteten Slot-Spalten auf betriebe.
  const { data: bestehendeFerien, error: ferienSelErr } = await supabase
    .from("betrieb_ferien")
    .select("von, bis")
    .eq("betrieb_id", betrieb.id)
    .gte("bis", new Date().toISOString().slice(0, 10))
    .order("von", { ascending: true });
  if (ferienSelErr) fehler.push(`ferien lesen: ${ferienSelErr.message}`);

  const istFerien = normFerien(bestehendeFerien ?? []);
  const websiteFerienOk = website != null &&
    (website.ferien_konfidenz ?? 0) >= MIN_KONFIDENZ &&
    (website.ferien?.length ?? 0) > 0;
  kandidaten.push({
    feld: "ferien",
    ist: istFerien,
    google: null,
    website: websiteFerienOk
      ? { wert: normFerien(website!.ferien), konfidenz: website!.ferien_konfidenz! }
      : null,
  });

  // Saison: ebenfalls nur die Website (Places API kennt kein Saisonfeld).
  const istSommer: SaisonFenster | null = betrieb.sommer_saison_aktiv &&
      betrieb.sommer_start_datum && betrieb.sommer_ende_datum
    ? {
      von_tag: tagMonatAusDatum(betrieb.sommer_start_datum)!.tag,
      von_monat: tagMonatAusDatum(betrieb.sommer_start_datum)!.monat,
      bis_tag: tagMonatAusDatum(betrieb.sommer_ende_datum)!.tag,
      bis_monat: tagMonatAusDatum(betrieb.sommer_ende_datum)!.monat,
    }
    : null;
  const istWinter: SaisonFenster | null = betrieb.winter_saison_aktiv &&
      betrieb.winter_start_datum && betrieb.winter_ende_datum
    ? {
      von_tag: tagMonatAusDatum(betrieb.winter_start_datum)!.tag,
      von_monat: tagMonatAusDatum(betrieb.winter_start_datum)!.monat,
      bis_tag: tagMonatAusDatum(betrieb.winter_ende_datum)!.tag,
      bis_monat: tagMonatAusDatum(betrieb.winter_ende_datum)!.monat,
    }
    : null;
  const istSaison = { sommer: normFenster(istSommer), winter: normFenster(istWinter) };

  // Nur bei Saisonbetrieben. Bei allen anderen bleibt die Saisonpruefung in
  // der App wirkungslos (`istInAktiverSaison` gibt fuer Nicht-Saisonbetriebe
  // immer true zurueck) — ein Vorschlag dort waere reine Ablenkung. Fund aus
  // dem ersten Testlauf: Das Modell deutete eine Sommerpause im Fliesstext
  // als Saisonfenster eines ganzjaehrig offenen Betriebs.
  const websiteSaisonOk = website != null && betrieb.ist_saisonbetrieb === true &&
    (website.saison_konfidenz ?? 0) >= MIN_KONFIDENZ &&
    (website.saison?.sommer != null || website.saison?.winter != null);
  kandidaten.push({
    feld: "saison",
    ist: istSaison,
    google: null,
    website: websiteSaisonOk
      ? {
        wert: {
          sommer: normFenster(website!.saison!.sommer),
          winter: normFenster(website!.saison!.winter),
        },
        konfidenz: website!.saison_konfidenz!,
      }
      : null,
  });

  // Status: nur Google (businessStatus). "Voruebergehend geschlossen" ist
  // ein starkes Signal, dass Ferien anstehen oder der Betrieb inaktiv ist.
  // ist/neu_wert tragen den rohen Google-businessStatus-Wert unter einem
  // "status"-Schluessel (Format wie von der App-Seite erwartet, siehe
  // lib/core/util/vorschlag_anzeige.dart::_formatStatus) -- NICHT unseren
  // eigenen betriebe.status-Wortschatz ("aktiv"/"inaktiv").
  kandidaten.push({
    feld: "status",
    ist: { status: betrieb.status },
    google: google?.businessStatus === "CLOSED_TEMPORARILY" && betrieb.status !== "inaktiv"
      ? { wert: { status: google!.businessStatus }, konfidenz: STATUS_KONFIDENZ }
      : null,
    website: null,
  });

  // ── Vorschlaege schreiben ──
  // alt_wert/neu_wert werden UNVERPACKT abgelegt -- also z.B. direkt die
  // Liste ["Di","Mi"] fuer ruhetage, nicht {"ruhetage":["Di","Mi"]}. Das
  // entspricht dem bereits vorhandenen App-seitigen Format in
  // lib/data/models/betrieb_vorschlag.dart / vorschlag_anzeige.dart:
  //   ruhetage         -> List<String>
  //   oeffnungszeiten  -> Map<Wochentag, List<{von,bis}>>
  //   ferien           -> List<{von,bis}>
  //   status           -> {"status": <roher Google-businessStatus>}
  //   saison           -> {"sommer": {...}|null, "winter": {...}|null}
  //                        mit Tag/Monat OHNE Jahr (Spec-Vorgabe) -- die
  //                        App-seitige _formatSaison() erwartet aktuell
  //                        stattdessen sommer_start_datum/-ende_datum als
  //                        volle ISO-Daten. Diese Diskrepanz besteht bereits
  //                        im parallel entstehenden App-Code (Stand
  //                        31.07.2026) und muss dort abgeglichen werden --
  //                        siehe Abschlussbericht.
  let anzahl = 0;
  for (const k of kandidaten) {
    const zeilen = vorschlaegeFuerFeld(k.ist, k.google, k.website);
    for (const zeile of zeilen) {
      if (zeile.konfidenz < MIN_KONFIDENZ) continue; // Sicherheitsnetz
      try {
        await schreibeVorschlag(supabase, {
          betriebId: betrieb.id,
          feld: k.feld,
          altWert: k.ist,
          neuWert: zeile.neuWert,
          quelle: zeile.quelle,
          konfidenz: zeile.konfidenz,
          userId: betrieb.user_id,
        });
        anzahl++;
      } catch (e) {
        fehler.push(`vorschlag ${k.feld}/${zeile.quelle}: ${(e as Error).message}`);
      }
    }
  }

  return { vorschlaege: anzahl, fehler };
}

// deno-lint-ignore no-explicit-any
async function schreibeVorschlag(
  supabase: any,
  args: {
    betriebId: string;
    feld: string;
    altWert: unknown;
    neuWert: unknown;
    quelle: string;
    konfidenz: number;
    userId: string;
  },
): Promise<void> {
  // Teilindex erlaubt nur einen OFFENEN Vorschlag je (Betrieb, Feld,
  // Quelle) -- alten offenen Eintrag vor dem Einfuegen entfernen, statt
  // Dubletten zu haeufen.
  const { error: delErr } = await supabase
    .from("betrieb_vorschlaege")
    .delete()
    .eq("betrieb_id", args.betriebId)
    .eq("feld", args.feld)
    .eq("quelle", args.quelle)
    .eq("status", "offen");
  if (delErr) throw new Error(`delete: ${delErr.message}`);

  const { error: insErr } = await supabase.from("betrieb_vorschlaege").insert({
    betrieb_id: args.betriebId,
    feld: args.feld,
    alt_wert: args.altWert,
    neu_wert: args.neuWert,
    quelle: args.quelle,
    konfidenz: args.konfidenz,
    user_id: args.userId,
  });
  if (insErr) throw new Error(`insert: ${insErr.message}`);
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
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceKey) {
      return json({ error: "SUPABASE_URL/SUPABASE_SERVICE_ROLE_KEY fehlen" }, 500);
    }
    const supabase = createClient(supabaseUrl, serviceKey);

    // deno-lint-ignore no-explicit-any
    let body: any = {};
    try {
      body = await req.json();
    } catch (_) {
      // leerer Body = Standardlauf (limit=10)
    }
    const limit = typeof body.limit === "number" && body.limit > 0
      ? Math.floor(body.limit)
      : DEFAULT_LIMIT;
    const betriebIds: string[] | null = Array.isArray(body.betriebIds) && body.betriebIds.length > 0
      ? body.betriebIds
      : null;

    const spalten = "id, user_id, name, strasse, nr, plz, ort, website, status, ruhetage, " +
      "oeffnungszeiten, google_place_id, keine_betriebsferien, ist_saisonbetrieb, " +
      "sommer_saison_aktiv, sommer_start_datum, sommer_ende_datum, " +
      "winter_saison_aktiv, winter_start_datum, winter_ende_datum";

    let query = supabase.from("betriebe").select(spalten);
    if (betriebIds) {
      query = query.in("id", betriebIds);
    } else {
      query = query
        .eq("status", "aktiv")
        .order("oeffnungszeiten_geprueft_am", { ascending: true, nullsFirst: true })
        .limit(limit);
    }

    const { data: betriebe, error: selErr } = await query;
    if (selErr) return json({ error: selErr.message }, 500);
    if (!betriebe || betriebe.length === 0) {
      return json({ geprueft: 0, vorschlaege: 0, fehler: [] });
    }

    let vorschlaegeGesamt = 0;
    const fehlerGesamt: string[] = [];

    // Sequenziell, nicht parallel -- Rate-Limits von Google Places und der
    // Anthropic API. Ein Fehler bei einem Betrieb bricht den Lauf nicht ab.
    for (const betrieb of betriebe as BetriebRow[]) {
      let ergebnis: VerarbeitungsErgebnis;
      try {
        ergebnis = await verarbeiteBetrieb(supabase, supabaseUrl, serviceKey, betrieb);
      } catch (e) {
        ergebnis = { vorschlaege: 0, fehler: [`unerwarteter Fehler: ${(e as Error).message}`] };
      }
      vorschlaegeGesamt += ergebnis.vorschlaege;
      for (const f of ergebnis.fehler) fehlerGesamt.push(`${betrieb.name} (${betrieb.id}): ${f}`);

      // IMMER setzen, auch bei Fehlern oder wenn nichts abwich -- sonst
      // bleibt ein dauerhaft fehlerhafter Betrieb fuer immer "der aelteste"
      // und blockiert die Rotation durch den gesamten Bestand.
      const { error: updErr } = await supabase
        .from("betriebe")
        .update({ oeffnungszeiten_geprueft_am: new Date().toISOString() })
        .eq("id", betrieb.id);
      if (updErr) {
        fehlerGesamt.push(`${betrieb.name} (${betrieb.id}): geprueft_am nicht gesetzt: ${updErr.message}`);
      }
    }

    return json({ geprueft: betriebe.length, vorschlaege: vorschlaegeGesamt, fehler: fehlerGesamt });
  } catch (error) {
    const msg = (error as Error).message;
    console.error("Function error:", msg);
    return json({ error: `Fehler: ${msg}` }, 500);
  }
});

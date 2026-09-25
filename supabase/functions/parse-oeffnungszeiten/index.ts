// Supabase Edge Function: parse-oeffnungszeiten
// Liest die Website eines Betriebs (Startseite + Kontakt-/Öffnungszeiten-Unterseiten)
// und extrahiert via Claude die Öffnungszeiten + Ruhetage im App-Format.
// Deploy: supabase functions deploy parse-oeffnungszeiten (verify_jwt=true via config.toml)
// Secrets: ANTHROPIC_API_KEY, CRON_SECRET (für den internen Aufruf aus
//          betriebsdaten-abgleich), SUPABASE_URL/SUPABASE_ANON_KEY (Standard)
//
// Zugang (seit 25.09.2026, Analyse R11): angemeldeter Benutzer ODER interner
// Aufruf mit `x-cron-secret`. Vorher war das ein offener Claude-Proxy auf
// Daniels Key plus SSRF: die `url` aus dem Body wurde ohne Host-Prüfung
// geladen. Jetzt prüft `pruefeUrl` Schema, Länge und Host — auch für jede
// Weiterleitung und jede Unterseite.

import { pruefeUrl } from "./url_pruefung.ts";

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

/** Interner Aufruf (Orchestrator): Header x-cron-secret == CRON_SECRET. */
function cronSecretGueltig(req: Request): boolean {
  const erwartet = Deno.env.get("CRON_SECRET") ?? "";
  const erhalten = req.headers.get("x-cron-secret") ?? "";
  if (erwartet.length < 16 || erhalten.length !== erwartet.length) return false;
  let diff = 0;
  for (let i = 0; i < erwartet.length; i++) {
    diff |= erwartet.charCodeAt(i) ^ erhalten.charCodeAt(i);
  }
  return diff === 0;
}

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const UA =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36";

const LINK_KEYWORDS = [
  "kontakt",
  "contact",
  "oeffnung",
  "öffnung",
  "offnung",
  "opening",
  "hours",
  "standort",
  "anfahrt",
  "reservation",
  "reservier",
  "info",
];

const MAX_WEITERLEITUNGEN = 3;

/**
 * Lädt eine Seite als Text. Weiterleitungen werden von Hand verfolgt, damit
 * jedes Ziel dieselbe Host-Prüfung durchläuft (sonst leitet eine öffentliche
 * Seite einfach auf 127.0.0.1 oder 169.254.169.254 weiter).
 */
async function fetchText(url: string, timeoutMs = 12000): Promise<string> {
  const controller = new AbortController();
  const t = setTimeout(() => controller.abort(), timeoutMs);
  try {
    let ziel: string | null = pruefeUrl(url);
    for (let hop = 0; ziel && hop <= MAX_WEITERLEITUNGEN; hop++) {
      const res = await fetch(ziel, {
        headers: { "User-Agent": UA, "Accept-Language": "de,en" },
        signal: controller.signal,
        redirect: "manual",
      });
      if (res.status >= 300 && res.status < 400) {
        const location = res.headers.get("location");
        await res.body?.cancel();
        if (!location) return "";
        ziel = pruefeUrl(new URL(location, ziel).toString());
        continue;
      }
      if (!res.ok) return "";
      const ct = res.headers.get("content-type") ?? "";
      if (!ct.includes("text/html") && !ct.includes("text/")) return "";
      return await res.text();
    }
    return "";
  } catch (_) {
    return "";
  } finally {
    clearTimeout(t);
  }
}

function stripHtml(html: string): string {
  return html
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<!--[\s\S]*?-->/g, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&auml;/gi, "ä").replace(/&ouml;/gi, "ö").replace(/&uuml;/gi, "ü")
    .replace(/&Auml;/gi, "Ä").replace(/&Ouml;/gi, "Ö").replace(/&Uuml;/gi, "Ü")
    .replace(/&szlig;/gi, "ß")
    .replace(/&[a-z]+;/gi, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function findCandidateLinks(html: string, baseUrl: string): string[] {
  const base = new URL(baseUrl);
  const out = new Set<string>();
  const re = /<a\b[^>]*href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi;
  let m: RegExpExecArray | null;
  while ((m = re.exec(html)) !== null) {
    const href = m[1];
    const text = m[2].toLowerCase();
    const hay = (href + " " + text).toLowerCase();
    if (!LINK_KEYWORDS.some((k) => hay.includes(k))) continue;
    try {
      const abs = new URL(href, baseUrl);
      if (abs.host !== base.host) continue;
      abs.hash = "";
      const geprueft = pruefeUrl(abs.toString());
      if (geprueft) out.add(geprueft);
    } catch (_) {
      // ignore malformed href
    }
    if (out.size >= 3) break;
  }
  return Array.from(out);
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
    if (!cronSecretGueltig(req)) {
      const userId = await ermittleUserId(req);
      if (!userId) return json({ error: "unauthorized" }, 401);
    }

    const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
    if (!apiKey) return json({ error: "ANTHROPIC_API_KEY not configured" }, 500);

    const { url, name } = await req.json();
    if (!url || typeof url !== "string" || url.trim().length === 0) {
      return json({ error: "url is required" }, 400);
    }
    const startUrl = pruefeUrl(url);
    if (!startUrl) {
      return json({ error: "url nicht erlaubt (nur http/https, öffentlicher Host, max. 2000 Zeichen)" }, 400);
    }
    // Der Name landet im Prompt — Länge begrenzen.
    const betriebName = typeof name === "string" ? name.slice(0, 200) : "";

    const homepage = await fetchText(startUrl);
    if (!homepage) {
      return json({ error: "Website nicht erreichbar." }, 502);
    }
    const parts: string[] = [stripHtml(homepage).slice(0, 8000)];
    for (const link of findCandidateLinks(homepage, startUrl)) {
      const sub = await fetchText(link);
      if (sub) parts.push(stripHtml(sub).slice(0, 8000));
    }
    const text = parts.join("\n\n---\n\n").slice(0, 18000);

    const prompt =
      `Du erhältst den Textinhalt der Website eines Gastronomiebetriebs${
        betriebName ? ` ("${betriebName}")` : ""
      } (Startseite + evtl. Kontakt-/Öffnungszeiten-Unterseiten). Extrahiere die regulären ÖFFNUNGSZEITEN und die RUHETAGE (geschlossene Wochentage).

Antworte NUR mit validem JSON (kein Markdown, keine Erklärung) in genau diesem Format:
{
  "oeffnungszeiten": {
    "Mo": [{"von":"HH:MM","bis":"HH:MM"}],
    "Di": [],
    "Mi": [],
    "Do": [],
    "Fr": [],
    "Sa": [],
    "So": []
  },
  "ruhetage": ["Di","Mi"],
  "konfidenz": 0.0,
  "ferien": [{"von":"YYYY-MM-DD","bis":"YYYY-MM-DD"}],
  "ferien_konfidenz": 0.0,
  "saison": {
    "sommer": {"von_tag":15,"von_monat":6,"bis_tag":20,"bis_monat":10},
    "winter": null
  },
  "saison_konfidenz": 0.0
}

Regeln Öffnungszeiten:
- Zeiten im 24h-Format HH:MM. Mittagspausen als ZWEI Slots (z.B. 11:30-14:00 und 18:00-23:00).
- Statt "24:00" oder "durchgehend bis Mitternacht" verwende "23:59".
- "ruhetage": Liste der geschlossenen Wochentage (Mo/Di/Mi/Do/Fr/Sa/So). Ein Tag ohne Zeiten, der klar als Ruhetag genannt ist, gehört hierhin.
- Wochentags-Kürzel exakt: Mo, Di, Mi, Do, Fr, Sa, So.
- Wenn für einen Tag keine Info vorhanden ist: leeres Array, und NICHT als Ruhetag markieren.
- Ignoriere Feiertags-Sonderzeiten und Küchenschluss; nimm die regulären Öffnungszeiten des Lokals.

Regeln BETRIEBSFERIEN ("ferien"):
- Erkenne Formulierungen wie "Betriebsferien", "Ferien vom … bis …", "wir sind zurück ab …", "geschlossen vom … bis …".
- Ein Jahr NUR übernehmen, wenn es dasteht. Fehlt es, nimm das laufende Jahr und senke "ferien_konfidenz" deutlich.
- Ferien sind eine Unterbrechung INNERHALB der Saison, typisch ein bis vier Wochen.
- Keine Ferienangabe gefunden: leeres Array und ferien_konfidenz 0.

Regeln SAISON ("saison"):
- Erkenne Angaben über Monate hinweg: "Sommersaison", "Winteröffnung", "geöffnet von Mitte Juni bis Oktober".
- Gib NUR Tag und Monat an, NIEMALS ein Jahr — die Jahreszuordnung macht die App, weil Winterfenster über den Jahreswechsel laufen.
- Ist nur ein Monat genannt ("ab Mitte Dezember"), nimm Tag 15 bzw. bei "Anfang" 1 und bei "Ende" 28, und senke die Konfidenz.
- Kein Saisonbetrieb erkennbar (ganzjährig offen): beide Felder null, saison_konfidenz 0.
- Verwechsle Saison und Ferien nicht: Die Saison umfasst Monate, Ferien sind kurze Unterbrechungen darin.

NICHTS erfinden. Im Zweifel lieber leer und Konfidenz 0 — ein falscher Wert ist schlimmer als ein fehlender, weil er die Tourenplanung in die Irre führt.

Website-Text:
${text}`;

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 60000);
    const response = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
      },
      signal: controller.signal,
      body: JSON.stringify({
        // Haiku genuegt: reine Extraktion aus vorgegebenem Text, kein
        // Ermessen. Beim taeglichen Lauf ueber ~260 Websites im Monat macht
        // das den Unterschied zwischen Rappen und Franken.
        model: "claude-haiku-4-5-20251001",
        max_tokens: 1500,
        temperature: 0,
        messages: [{ role: "user", content: [{ type: "text", text: prompt }] }],
      }),
    });
    clearTimeout(timeout);

    if (!response.ok) {
      const details = await response.text();
      console.error(`Claude API error ${response.status}: ${details}`);
      return json({ error: `Claude API error: ${response.status}`, details }, 502);
    }

    const claude = await response.json();
    const textContent = claude.content?.find(
      (c: { type: string }) => c.type === "text",
    );
    if (!textContent?.text) return json({ error: "No text response from Claude" }, 502);

    let jsonText = textContent.text.trim();
    const match = jsonText.match(/```(?:json)?\s*([\s\S]*?)```/);
    if (match) jsonText = match[1].trim();
    const parsed = JSON.parse(jsonText);

    return json(parsed);
  } catch (error) {
    const msg = (error as Error).message;
    console.error("Function error:", msg);
    const isTimeout = msg.includes("abort");
    return json(
      { error: isTimeout ? "Timeout beim Auslesen der Website." : `Fehler: ${msg}` },
      isTimeout ? 504 : 500,
    );
  }
});

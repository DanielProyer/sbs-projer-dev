// Supabase Edge Function: parse-oeffnungszeiten
// Liest die Website eines Betriebs (Startseite + Kontakt-/Öffnungszeiten-Unterseiten)
// und extrahiert via Claude die Öffnungszeiten + Ruhetage im App-Format.
// Deploy: supabase functions deploy parse-oeffnungszeiten --no-verify-jwt
// Secret: supabase secrets set ANTHROPIC_API_KEY=sk-ant-...

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

function normalizeUrl(u: string): string {
  let s = u.trim();
  if (!/^https?:\/\//i.test(s)) s = "https://" + s;
  return s;
}

async function fetchText(url: string, timeoutMs = 12000): Promise<string> {
  const controller = new AbortController();
  const t = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, {
      headers: { "User-Agent": UA, "Accept-Language": "de,en" },
      signal: controller.signal,
    });
    if (!res.ok) return "";
    const ct = res.headers.get("content-type") ?? "";
    if (!ct.includes("text/html") && !ct.includes("text/")) return "";
    return await res.text();
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
      out.add(abs.toString());
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
    const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
    if (!apiKey) return json({ error: "ANTHROPIC_API_KEY not configured" }, 500);

    const { url, name } = await req.json();
    if (!url || typeof url !== "string" || url.trim().length === 0) {
      return json({ error: "url is required" }, 400);
    }
    const startUrl = normalizeUrl(url);

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
        name ? ` ("${name}")` : ""
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
  "konfidenz": 0.0
}

Regeln:
- Zeiten im 24h-Format HH:MM. Mittagspausen als ZWEI Slots (z.B. 11:30-14:00 und 18:00-23:00).
- Statt "24:00" oder "durchgehend bis Mitternacht" verwende "23:59".
- "ruhetage": Liste der geschlossenen Wochentage (Mo/Di/Mi/Do/Fr/Sa/So). Ein Tag ohne Zeiten, der klar als Ruhetag genannt ist, gehört hierhin.
- Wochentags-Kürzel exakt: Mo, Di, Mi, Do, Fr, Sa, So.
- Wenn für einen Tag keine Info vorhanden ist: leeres Array, und NICHT als Ruhetag markieren.
- NICHTS erfinden. Wenn gar keine Öffnungszeiten auffindbar sind: alle Arrays leer, ruhetage leer, konfidenz 0.
- Ignoriere Feiertags-Sonderzeiten und Küchenschluss; nimm die regulären Öffnungszeiten des Lokals.

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
        model: "claude-sonnet-4-5-20250929",
        max_tokens: 1024,
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

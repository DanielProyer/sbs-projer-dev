// Supabase Edge Function: typenschild-lesen
// Liest ein Foto eines Geraete-Typenschilds (Kuehler, Pumpe, ...) via Claude
// Sonnet 5 aus und liefert Hersteller/Typ/Seriennummer/Baujahr strukturiert
// zurueck. Port aus Projekt Heineken (foto-erkennen, Bildart "typenschild"),
// hier aber im request/response-Muster von parse-beleg gehalten (kein
// Storage-Bucket, kein foto_id — die App schickt das Bild direkt).
// Deploy: supabase functions deploy typenschild-lesen (verify_jwt=true via config.toml)
// Secret: ANTHROPIC_API_KEY ist bereits fuer parse-beleg gesetzt.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const MODELL = "claude-sonnet-5";

// Anthropic lehnt zu grosse Bilder ab; hier hart begrenzt, bevor ueberhaupt
// bezahlt wird. 5 MB roh entsprechen rund 6.7 MB Base64.
const BILD_ROHGRENZE = 5_000_000;

const WERKZEUG = {
  name: "typenschild_auswerten",
  description: "Haelt fest, was auf dem Geraete-Typenschild tatsaechlich lesbar ist.",
  input_schema: {
    type: "object",
    properties: {
      hersteller: { type: ["string", "null"] },
      typ_bezeichnung: {
        type: ["string", "null"],
        description: "Die Modell-/Typenbezeichnung auf dem Schild.",
      },
      seriennummer: { type: ["string", "null"] },
      baujahr: {
        type: ["integer", "null"],
        description: "Vierstellig, nur wenn wirklich aufgedruckt.",
      },
      unsicher_bei: {
        type: "array",
        items: { type: "string" },
        description:
          "Namen ALLER Felder, bei denen du nicht sicher bist. Lieber eines "
          + "zu viel nennen als eines zu wenig.",
      },
      sicherheit: {
        type: "string",
        enum: ["hoch", "mittel", "tief"],
        description: "Gesamteinschaetzung. \"tief\", wenn geraten wurde.",
      },
    },
    required: [
      "hersteller",
      "typ_bezeichnung",
      "seriennummer",
      "baujahr",
      "unsicher_bei",
      "sicherheit",
    ],
  },
};

const ANWEISUNG =
  "Du liest ein Foto eines Typenschilds an einem Geraet im Bier-Offenausschank "
  + "(Kuehler, Pumpe o.ae., Schweizer Gastro-/Event-Umfeld) aus. Lies NUR ab, "
  + "was wirklich auf dem Schild steht — nichts erraten, nichts aus "
  + "Plausibilitaet ergaenzen. typ_bezeichnung ist die Modell-/Typenbezeichnung "
  + "auf dem Schild. Was du nicht sicher entziffern kannst: null setzen UND "
  + "das Feld in unsicher_bei nennen. Ein gemeldeter Zweifel ist wertvoll, ein "
  + "stiller Fehler ist teuer. Rufe typenschild_auswerten auf.";

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  // CORS Preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    // Nur echte eingeloggte User duerfen die KI ausloesen (Credit-Schutz).
    const userClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } },
    );
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) {
      return json({ error: "unauthorized" }, 401);
    }

    const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
    if (!apiKey) {
      return json({ error: "ANTHROPIC_API_KEY not configured" }, 500);
    }

    const { image_base64, media_type } = await req.json();

    if (!image_base64 || !media_type) {
      return json({ error: "image_base64 and media_type are required" }, 400);
    }

    // Groessen-Guard: verhindert teure/unnoetige Anthropic-Aufrufe mit
    // ueberdimensionierten Bildern, bevor ueberhaupt gefetcht wird.
    const rohGroesse = Math.floor((image_base64.length * 3) / 4);
    if (rohGroesse > BILD_ROHGRENZE) {
      return json(
        { error: "Bild zu gross (max. 5 MB). Bitte ein kleineres Foto verwenden." },
        400,
      );
    }

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 90_000);

    let response: Response;
    try {
      response = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": apiKey,
          "anthropic-version": "2023-06-01",
        },
        signal: controller.signal,
        body: JSON.stringify({
          model: MODELL,
          max_tokens: 1200,
          tools: [WERKZEUG],
          tool_choice: { type: "tool", name: "typenschild_auswerten" },
          system: ANWEISUNG,
          messages: [
            {
              role: "user",
              content: [
                {
                  type: "image",
                  source: {
                    type: "base64",
                    media_type: media_type,
                    data: image_base64,
                  },
                },
                { type: "text", text: "Bitte das Typenschild auf diesem Foto auswerten." },
              ],
            },
          ],
        }),
      });
    } finally {
      clearTimeout(timeout);
    }

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`Claude API error ${response.status}: ${errorText}`);
      return json(
        { error: `Claude API error: ${response.status}`, details: errorText.slice(0, 300) },
        502,
      );
    }

    const claudeResponse = await response.json();
    const aufruf = claudeResponse.content?.find(
      (b: { type: string }) => b.type === "tool_use",
    );
    if (!aufruf) {
      console.error("Keine Auswertung erhalten:", JSON.stringify(claudeResponse));
      return json({ error: "Keine Auswertung erhalten" }, 502);
    }

    console.log(
      `Typenschild gelesen: ${aufruf.input?.hersteller} ${aufruf.input?.typ_bezeichnung}, `
        + `sicherheit: ${aufruf.input?.sicherheit}`,
    );

    return json({ ...aufruf.input, verbrauch: claudeResponse.usage ?? null });
  } catch (error) {
    const msg = (error as Error).message;
    console.error("Function error:", msg);
    const isTimeout = msg.includes("abort");
    return json(
      {
        error: isTimeout
          ? "Timeout: Typenschild-Analyse dauerte zu lange. Versuche ein kleineres Bild."
          : `Fehler: ${msg}`,
      },
      isTimeout ? 504 : 500,
    );
  }
});

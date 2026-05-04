// Supabase Edge Function: parse-protokoll
// Analysiert fotografierte Reinigungsprotokolle via Claude Sonnet 4.5 und extrahiert Positionen + Preis.
// Deploy: supabase functions deploy parse-protokoll --no-verify-jwt
// Secret: supabase secrets set ANTHROPIC_API_KEY=sk-ant-...

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req: Request) => {
  // CORS Preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: "ANTHROPIC_API_KEY not configured" }),
        { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    const { image_base64, media_type } = await req.json();

    if (!image_base64 || !media_type) {
      return new Response(
        JSON.stringify({ error: "image_base64 and media_type are required" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    const imageSizeKB = Math.round((image_base64.length * 3) / 4 / 1024);
    console.log(`Protokoll image size: ~${imageSizeKB} KB, type: ${media_type}`);

    // Claude API Call mit Timeout (90s – Sonnet braucht etwas länger)
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 90000);

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
              {
                type: "text",
                text: `Du siehst ein fotografiertes Heineken "Reinigungsprotokoll Quittung/Faktura" (A4-Formular FOR 1220).

WICHTIG: Das Foto ist fast immer um 90° GEDREHT! Erkenne die Orientierung anhand des Heineken-Logos und des gedruckten Texts.

Das Formular hat unten eine Preistabelle mit 10 Zeilen. Du musst NUR erkennen:
1. WELCHE Zeilen handschriftlich ausgefüllt sind (Menge und/oder Preis eingetragen)
2. Die MENGE (Anzahl) bei den Hähne-Zeilen
3. Die ZAHLUNGSART (Auf Rechnung / Auf Barzahlung — eines ist angekreuzt)

Die 10 Zeilen sind:
1. "Reinigung Bier" (Art. 38457) — Menge ist fast immer 1
2. "Grundtarif Reinigung Orion Bier" (Art. 28001)
3. "Service Offenausschank Heigenie" (Art. 6000) — vorgedruckt "Gem.Leihvertrag"
4. "Grundtarif Reinigung fremd" (Art. 28001)
5. "Zusätzlicher Hahnen Orion" (Art. 28001) — MENGE = Anzahl Hähne
6. "Zusätzlicher Hahnen fremd" (Art. 28001) — MENGE = Anzahl Hähne
7. "Grundtarif Wein" (Art. 28001)
8. "Zusätzlicher Hahn Wein" (Art. 28001) — MENGE = Anzahl Hähne
9. "Zusätzl. Hahn zweite Anlage anderer Standort" (Art. 28001) — MENGE = Anzahl Hähne
10. "Weitere zusätzliche Leitungen" (Art. 28001) — MENGE = Anzahl

Ganz unten: "Auf Rechnung: O" / "Auf Barzahlung: O" (eines mit X angekreuzt).

Antworte NUR mit validem JSON (kein Markdown):
{
  "reinigung_bier": true,
  "reinigung_orion": false,
  "heigenie": false,
  "reinigung_fremd": false,
  "hahnen_orion": 0,
  "hahnen_fremd": 0,
  "wein": false,
  "hahn_wein": 0,
  "anderer_standort": 0,
  "zusaetzliche_leitungen": 0,
  "zahlungsart": "rechnung",
  "konfidenz": 0.95
}

Regeln:
- Grundtarif-Zeilen (1-4, 7): true wenn ausgefüllt, false wenn leer
- Hähne-Zeilen (5, 6, 8, 9, 10): Die MENGE als Zahl (0 wenn leer)
- zahlungsart: "rechnung" oder "barzahlung"
- konfidenz: 0.0-1.0
- Menge ist eine einzelne Ziffer (1-9), Verwechslungsgefahr: 1↔7, 4↔9
- Bei Zeile 1 "Reinigung Bier": fast immer ausgefüllt mit Menge 1
- Ignoriere die handschriftlichen Preise und das Total — die App berechnet das selbst`,
              },
            ],
          },
        ],
      }),
    });

    clearTimeout(timeout);

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`Claude API error ${response.status}: ${errorText}`);
      return new Response(
        JSON.stringify({ error: `Claude API error: ${response.status}`, details: errorText }),
        { status: 502, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    const claudeResponse = await response.json();
    const textContent = claudeResponse.content?.find(
      (c: { type: string }) => c.type === "text"
    );

    if (!textContent?.text) {
      console.error("No text in Claude response:", JSON.stringify(claudeResponse));
      return new Response(
        JSON.stringify({ error: "No text response from Claude" }),
        { status: 502, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // JSON aus der Antwort extrahieren
    let jsonText = textContent.text.trim();
    const jsonMatch = jsonText.match(/```(?:json)?\s*([\s\S]*?)```/);
    if (jsonMatch) {
      jsonText = jsonMatch[1].trim();
    }

    const parsed = JSON.parse(jsonText);
    console.log(`Parsed protokoll: total=${parsed.total} CHF, konfidenz=${parsed.konfidenz}, zahlungsart=${parsed.zahlungsart}`);

    return new Response(JSON.stringify(parsed), {
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  } catch (error) {
    const msg = (error as Error).message;
    console.error("Function error:", msg);
    const isTimeout = msg.includes("abort");
    return new Response(
      JSON.stringify({
        error: isTimeout
          ? "Timeout: Protokoll-Analyse dauerte zu lange. Versuche ein kleineres Bild."
          : `Fehler: ${msg}`,
      }),
      { status: isTimeout ? 504 : 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  }
});

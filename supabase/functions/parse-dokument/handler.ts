// parse-dokument: Request-Handler ohne Netz- und Supabase-Abhängigkeit.
// index.ts gibt die echten Abhängigkeiten hinein (Benutzerprüfung über
// auth.getUser, API-Key aus dem Secret, fetch an die Messages API);
// handler_test.ts prüft Statuscodes mit eingespeisten.
import {
  ergebnisNormalisieren,
  groesseErlaubt,
  jsonAusText,
  katalogLesen,
  MEDIA_TYPEN,
  promptBauen,
} from "./antwort.ts";

export interface Deps {
  /** Eingeloggter Benutzer zum Authorization-Header, sonst null. */
  benutzer: (authorization: string) => Promise<{ id: string } | null>;
  /** Secret ANTHROPIC_API_KEY (undefined = nicht gesetzt). */
  apiKey: string | undefined;
  /** POST an die Messages API; [signal] bricht nach dem Timeout ab. */
  anthropic: (body: unknown, signal: AbortSignal) => Promise<Response>;
  /** Timeout der Modellanfrage (Vorgabe 55 s, Gateway-Grenze ~60 s). */
  timeoutMs?: number;
}

export const MODELL = "claude-sonnet-4-6";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function antwort(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

function fehler(error: string, status: number): Response {
  return antwort({ ok: false, error }, status);
}

export async function handle(req: Request, deps: Deps): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    // Nur echte eingeloggte User dürfen die KI auslösen (Credit-Schutz).
    const user = await deps.benutzer(req.headers.get("Authorization") ?? "");
    if (!user) return fehler("unauthorized", 401);

    if (!deps.apiKey) return fehler("ANTHROPIC_API_KEY not configured", 500);

    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch (_) {
      return fehler("Body ist kein JSON", 400);
    }
    const dateiBase64 = body?.datei_base64;
    const mediaType = body?.media_type;
    if (typeof dateiBase64 !== "string" || !dateiBase64) {
      return fehler("datei_base64 fehlt", 400);
    }
    if (typeof mediaType !== "string" || !MEDIA_TYPEN.includes(mediaType)) {
      return fehler(`media_type muss ${MEDIA_TYPEN.join(" | ")} sein`, 400);
    }
    if (!groesseErlaubt(mediaType, dateiBase64.length)) {
      return fehler("Datei zu gross für die Erkennung", 413);
    }
    const katalog = katalogLesen(body);
    if (!katalog) {
      return fehler("bereiche/typen/kategorien fehlen oder sind ungültig", 400);
    }
    const vorgabe = typeof body.bereich_vorgabe === "string"
      ? body.bereich_vorgabe
      : null;

    const sizeKB = Math.round((dateiBase64.length * 3) / 4 / 1024);
    console.log(
      `parse-dokument: ~${sizeKB} KB, type: ${mediaType}, vorgabe: ${vorgabe}`,
    );

    // PDF -> document-Block, Bild -> image-Block (wie parse-rechnung)
    const quelle = mediaType === "application/pdf"
      ? {
        type: "document",
        source: {
          type: "base64",
          media_type: "application/pdf",
          data: dateiBase64,
        },
      }
      : {
        type: "image",
        source: { type: "base64", media_type: mediaType, data: dateiBase64 },
      };

    const controller = new AbortController();
    const timeout = setTimeout(
      () => controller.abort(),
      deps.timeoutMs ?? 55000,
    );
    let response: Response;
    try {
      response = await deps.anthropic({
        model: MODELL,
        max_tokens: 1500,
        messages: [
          {
            role: "user",
            content: [
              quelle,
              { type: "text", text: promptBauen(katalog, vorgabe) },
            ],
          },
        ],
      }, controller.signal);
    } finally {
      clearTimeout(timeout);
    }

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`Claude API error ${response.status}: ${errorText}`);
      return fehler(`Claude API error: ${response.status}`, 502);
    }

    const claudeResponse = await response.json();
    const textContent = claudeResponse.content?.find(
      (c: { type: string }) => c.type === "text",
    );
    if (!textContent?.text) {
      console.error(
        "No text in Claude response:",
        JSON.stringify(claudeResponse),
      );
      return fehler("Keine Textantwort vom Modell", 502);
    }

    const roh = jsonAusText(textContent.text);
    if (!roh) {
      console.error(
        "Kein JSON in der Antwort:",
        textContent.text.slice(0, 500),
      );
      return fehler("Antwort des Modells war kein JSON", 502);
    }
    const ergebnis = ergebnisNormalisieren(roh, katalog, mediaType);

    console.log(
      `parse-dokument: ${ergebnis.bereich}/${ergebnis.typ}/${ergebnis.kategorie}, ` +
        `jahr=${ergebnis.jahr}, datei=${ergebnis.dateiname}, ` +
        `zuversicht=${ergebnis.zuversicht}`,
    );
    return antwort({ ok: true, ergebnis });
  } catch (error) {
    const msg = (error as Error).message ?? String(error);
    console.error("Function error:", msg);
    const isTimeout = (error as Error).name === "AbortError" ||
      msg.includes("abort");
    return fehler(
      isTimeout
        ? "Timeout: Erkennung dauerte zu lange. Versuche eine kleinere Datei."
        : `Fehler: ${msg}`,
      isTimeout ? 504 : 500,
    );
  }
}

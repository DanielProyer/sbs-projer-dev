// Supabase Edge Function: parse-dokument (29.09.2026)
// Ordnet ein hochgeladenes Dokument (PDF oder Bild) für die Dokumente-Ablage
// ein: Bereich, Typ, Kategorie, Jahr, Datum, Betrag, Referenz, Titel und ein
// sprechender Dateiname; beim Zins-/Kapitalausweis zusätzlich Saldo, Zins
// brutto, Verrechnungssteuer, Zins netto. Speichert NICHTS — die App füllt
// damit den Upload-Dialog vor, Daniel bestätigt, die App lädt hoch.
//
// Body: { datei_base64, media_type, bereiche, typen, kategorien?, labels?,
//         bereich_vorgabe? } — die erlaubten Werte schickt die App mit
//         (siehe antwort.ts).
// Antwort: { ok: true, ergebnis } | { ok: false, error }
// Deploy: supabase functions deploy parse-dokument (verify_jwt=true via
//         config.toml); Secret ANTHROPIC_API_KEY (bereits gesetzt).
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  ergebnisNormalisieren,
  jsonAusText,
  katalogLesen,
  MEDIA_TYPEN,
  promptBauen,
} from "./antwort.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// ~22 MB Datei. Die Messages API nimmt höchstens 32 MB je Anfrage; die App
// schickt ohnehin nur Dateien bis 15 MB zur Erkennung.
const MAX_BASE64 = 30_000_000;

function antwort(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

function fehler(error: string, status: number): Response {
  return antwort({ ok: false, error }, status);
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    // Nur echte eingeloggte User dürfen die KI auslösen (Credit-Schutz).
    const userClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      {
        global: {
          headers: { Authorization: req.headers.get("Authorization") ?? "" },
        },
      },
    );
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return fehler("unauthorized", 401);

    const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
    if (!apiKey) return fehler("ANTHROPIC_API_KEY not configured", 500);

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
    if (dateiBase64.length > MAX_BASE64) {
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
    const timeout = setTimeout(() => controller.abort(), 55000);
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
          model: "claude-sonnet-4-6",
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
        }),
      });
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
    const msg = (error as Error).message;
    console.error("Function error:", msg);
    const isTimeout = msg.includes("abort");
    return fehler(
      isTimeout
        ? "Timeout: Erkennung dauerte zu lange. Versuche eine kleinere Datei."
        : `Fehler: ${msg}`,
      isTimeout ? 504 : 500,
    );
  }
});

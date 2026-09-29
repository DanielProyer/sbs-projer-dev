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
// Logik: handler.ts (testbar); hier nur die echten Abhängigkeiten.
// Deploy: supabase functions deploy parse-dokument (verify_jwt=true via
//         config.toml); Secret ANTHROPIC_API_KEY (bereits gesetzt).
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { handle } from "./handler.ts";

Deno.serve((req: Request) => {
  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  return handle(req, {
    // Nur echte eingeloggte User dürfen die KI auslösen (Credit-Schutz) —
    // verify_jwt am Gateway lässt auch den öffentlichen Anon-Key durch.
    benutzer: async (authorization) => {
      const userClient = createClient(
        Deno.env.get("SUPABASE_URL")!,
        Deno.env.get("SUPABASE_ANON_KEY")!,
        { global: { headers: { Authorization: authorization } } },
      );
      const { data: { user } } = await userClient.auth.getUser();
      return user;
    },
    apiKey,
    anthropic: (body, signal) =>
      fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": apiKey ?? "",
          "anthropic-version": "2023-06-01",
        },
        signal,
        body: JSON.stringify(body),
      }),
  });
});

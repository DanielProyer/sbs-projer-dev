// Supabase Edge Function: parse-rechnung
// Analysiert Schweizer EINGANGSRECHNUNGEN / Geschäftspost (PDF oder Bild) via Claude
// Haiku 4.5 und extrahiert strukturierte Daten für die Kreditoren-Buchhaltung.
// Liest die im QR-Zahlteil GEDRUCKTEN Felder (Klartext) — dekodiert NICHT den QR-Code.
// Deploy: supabase functions deploy parse-rechnung --no-verify-jwt
// Secret: ANTHROPIC_API_KEY (bereits gesetzt für parse-beleg)

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const PROMPT = `Du bist ein Schweizer Eingangsrechnungs- und Belegspezialist. Analysiere dieses Dokument und extrahiere strukturierte Daten für die Kreditoren-Buchhaltung. Es kann eine Rechnung, Mahnung, Akonto-/Schlussrechnung, Prämienrechnung, Gutschrift ODER ein reines Info-Dokument sein.

SCHRITT 1 — KLASSIFIZIEREN:
- ist_rechnung = true NUR wenn ein zu zahlender Betrag an einen Lieferanten/Aussteller gefordert wird (Rechnung, Akonto, Schluss, Mahnung mit Betrag, Versicherungsprämie mit Einzahlungsschein).
- ist_nur_info = true (und ist_rechnung = false) bei reinen Info-Dokumenten OHNE Zahlungsaufforderung, z.B.: Vorsorge-/PK-Ausweis, Lohnausweis, Versicherungspolice ohne Einzahlungsschein, Sozialversicherungssätze/Beitragsübersicht, Veranlagungs-/Steuerverfügung ohne Zahlteil, Lohndeklaration, Schadenbericht, Kontoauszug, allgemeine Mitteilung.
- dok_typ: genau einer von: rechnung | akontorechnung | schlussrechnung | mahnung | gutschrift | info.

SCHRITT 2 — ZAHLDATEN aus dem QR-Zahlteil / Einzahlungsschein (unten auf Schweizer Rechnungen). Die Felder stehen dort auch als KLARTEXT — lies sie von dort, NICHT aus dem QR-Code-Bild:
- empfaenger_iban: die IBAN unter "Konto / Zahlbar an" (CH.. oder LI.., 21 Zeichen). Eine QR-IBAN erkennst du an den Stellen 5-9 (IID) im Bereich 30000-31999.
- referenz: die "Referenz" aus dem Zahlteil (Ziffern oder RF...).
- referenz_typ: "QRR" wenn 27-stellige reine Zahlenreferenz; "SCOR" wenn sie mit "RF" beginnt; "NON" wenn keine Referenz vorhanden (nur Mitteilung / "Zusätzliche Informationen").
- betrag_zahlbar: der "Betrag" aus dem Zahlteil = der tatsächlich zu zahlende Betrag (Total/Saldo "zu zahlen"). NICHT eine einzelne Position. Bei Mahnung inkl. Gebühren.
- waehrung: i.d.R. CHF.

SCHRITT 3 — WEITERE FELDER:
- aussteller_name: Rechnungssteller/Lieferant (Firma oben bzw. "Zahlbar an").
- aussteller_uid: MWST-/UID-Nummer im Format CHE-123.456.789 falls vorhanden, sonst null.
- rechnungsnummer; rechnungsdatum (YYYY-MM-DD); faelligkeit (YYYY-MM-DD; "zahlbar bis"/"Fälligkeit"; null falls fehlend).
- mwst_satz: ausgewiesener MWST-Satz in Prozent. Schweiz aktuell: 8.1 (normal), 2.6 (reduziert), 3.8 (Beherbergung); historisch 7.7/2.5/3.7. Bei mehreren den dominanten; wenn keiner ausgewiesen 0.
- mwst_pflichtig: false (und mwst_satz 0) bei hoheitlichen / MWST-FREIEN Forderungen: Feuerwehrersatzabgabe, Gemeinde-Gebühren/Fahrbewilligung, Bussen, Sozialversicherungsbeiträge (SVA/AHV/SUVA/BVG/Pensionskasse), Steuern, Versicherungsprämien (Stempelsteuer ist KEINE MWST). Bei normalen Waren/Dienstleistungen true.
- konfidenz: 0..1, sei streng und ehrlich. Unscharf, abgeschnitten oder unsicher gelesen -> niedrig (< 0.85).

WICHTIGE REGELN:
- "Betrag zu zahlen" / Saldo schlägt die Brutto-Summe einzelner Positionen.
- Ein handschriftlicher "bezahlt"-Vermerk ist nur ein Hinweis und ändert die Extraktion NICHT.
- Bei ist_nur_info=true die Zahlungs-Felder (empfaenger_iban, referenz, betrag_zahlbar) auf null setzen.
- Antworte AUSSCHLIESSLICH mit validem JSON, ohne erklärenden Text.

JSON-Format:
{
  "ist_rechnung": true,
  "dok_typ": "rechnung",
  "ist_nur_info": false,
  "aussteller_name": "Heineken Switzerland AG",
  "aussteller_uid": "CHE-488.708.502",
  "empfaenger_iban": "CH3408686001085747001",
  "referenz": "210000000003139471430009017",
  "referenz_typ": "QRR",
  "rechnungsnummer": "R-2026-0001",
  "rechnungsdatum": "2026-06-01",
  "faelligkeit": "2026-07-01",
  "betrag_zahlbar": 3772.70,
  "waehrung": "CHF",
  "mwst_satz": 8.1,
  "mwst_pflichtig": true,
  "konfidenz": 0.93
}`;

Deno.serve(async (req: Request) => {
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

    const { file_base64, media_type } = await req.json();
    if (!file_base64 || !media_type) {
      return new Response(
        JSON.stringify({ error: "file_base64 and media_type are required" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    const sizeKB = Math.round((file_base64.length * 3) / 4 / 1024);
    console.log(`parse-rechnung: ~${sizeKB} KB, type: ${media_type}`);

    // PDF -> document-Block, Bild -> image-Block
    const isPdf = media_type === "application/pdf";
    const sourceBlock = isPdf
      ? { type: "document", source: { type: "base64", media_type: "application/pdf", data: file_base64 } }
      : { type: "image", source: { type: "base64", media_type, data: file_base64 } };

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 55000);

    const response = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
      },
      signal: controller.signal,
      body: JSON.stringify({
        model: "claude-haiku-4-5-20251001",
        max_tokens: 1500,
        messages: [
          { role: "user", content: [sourceBlock, { type: "text", text: PROMPT }] },
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

    let jsonText = textContent.text.trim();
    const jsonMatch = jsonText.match(/```(?:json)?\s*([\s\S]*?)```/);
    if (jsonMatch) jsonText = jsonMatch[1].trim();

    const parsed = JSON.parse(jsonText);
    console.log(
      `parse-rechnung: ${parsed.aussteller_name}, ${parsed.betrag_zahlbar} ${parsed.waehrung}, typ=${parsed.dok_typ}, info=${parsed.ist_nur_info}, ref=${parsed.referenz_typ}`
    );

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
          ? "Timeout: Analyse dauerte zu lange. Versuche ein kleineres Dokument."
          : `Fehler: ${msg}`,
      }),
      { status: isTimeout ? 504 : 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  }
});

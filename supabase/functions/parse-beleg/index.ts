// Supabase Edge Function: parse-beleg
// Analysiert Kassenzettel-Bilder via Claude Haiku 4.5 und extrahiert Beleg-Daten.
// Deploy: supabase functions deploy parse-beleg --no-verify-jwt
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

    // Log image size for debugging
    const imageSizeKB = Math.round((image_base64.length * 3) / 4 / 1024);
    console.log(`Image size: ~${imageSizeKB} KB, type: ${media_type}`);

    // Claude Haiku 4.5 API Call mit AbortController Timeout (50s)
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 50000);

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
        max_tokens: 1024,
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
                text: `Du bist ein Schweizer Kassenzettel-Spezialist. Analysiere diesen Beleg und extrahiere die Daten.

WICHTIGSTE REGEL - MwSt-Zusammenfassung verwenden:
Schweizer Belege haben fast immer eine MwSt-Zusammenfassung/Aufschlüsselung am ENDE des Belegs (Tabelle mit Satz/Netto/MwSt/Brutto pro MwSt-Code). Diese Tabelle ist die PRIMÄRE QUELLE für die Beträge!
- NICHT einzelne Artikelzeilen als Positionen verwenden
- Stattdessen die aggregierten Brutto-Beträge aus der MwSt-Tabelle übernehmen
- Die Artikel-Codes (z.B. "C", "D", "B" oder Code-Spalte: 1=2.6%, 2=8.1%) ordnen Artikel den MwSt-Sätzen zu
- ACHTUNG: Ein Beleg kann MEHRERE MwSt-Tabellen haben (z.B. Tankstelle + Shop als separate Firmen auf einem Beleg)

Schweizer MwSt-Sätze: 2.6% (reduziert, Lebensmittel), 8.1% (normal, Getränke/Non-Food/Benzin)
Datum-Formate: DD.MM.YYYY oder DD.MM.YY
Beträge in CHF

KATEGORIE-ERKENNUNG - ZUERST Artikel prüfen, DANN gruppieren:
1. Jeden Artikel einer Kategorie zuordnen:
   - "benzin" wenn Artikel enthält: Diesel, Benzin, Bleifrei, Tankzeit, AdBlue, Treibstoff, Fuel, Zapfsäule, Liter-Angabe bei Kraftstoff
   - "essen" für alles andere: Lebensmittel, Getränke, Snacks, Sandwiches, Kaffee, Shop-Artikel etc.
2. Dann gruppieren nach EINZIGARTIGER Kombination von (kategorie + mwst_satz)
3. Pro Gruppe: Beträge summieren → eine Position

GRUPPIERUNGS-REGELN:
- Eine Position pro EINZIGARTIGER (kategorie + mwst_satz) Kombination
- Benzin 8.1% und Essen 8.1% sind VERSCHIEDENE Gruppen → NIEMALS zusammenfassen!
- Essen 2.6% und Essen 8.1% sind VERSCHIEDENE Gruppen → getrennt
- Mehrere Essen-Artikel mit gleichem MwSt-Satz → zusammenfassen in eine Position

Beispiel 1 - migrolino (nur Essen, 2 MwSt-Sätze → 2 Positionen):
  Artikel: Kaffee 3.60 (2.6%), Brötchen 1.95 (2.6%), Öl 5.00 (8.1%), Filter 20.20 (8.1%)
  → Gruppe 1: essen+2.6% = 5.55 | Gruppe 2: essen+8.1% = 25.20
  → 2 Positionen: [{kategorie:"essen", mwst_satz:2.6, betrag_brutto:5.55}, {kategorie:"essen", mwst_satz:8.1, betrag_brutto:25.20}]

Beispiel 2 - Coop Pronto Tankstelle (Diesel + Shop → 3 Positionen):
  Artikel: Diesel 92.92 (8.1%), Salat 7.95 (2.6%), Radler 4.20 (8.1%)
  → Gruppe 1: benzin+8.1% = 92.92 | Gruppe 2: essen+2.6% = 7.95 | Gruppe 3: essen+8.1% = 4.20
  → 3 Positionen: [{kategorie:"benzin", mwst_satz:8.1, betrag_brutto:92.92}, {kategorie:"essen", mwst_satz:2.6, betrag_brutto:7.95}, {kategorie:"essen", mwst_satz:8.1, betrag_brutto:4.20}]
  WICHTIG: Diesel (benzin) und Radler (essen) haben BEIDE 8.1% aber VERSCHIEDENE Kategorien → 2 getrennte Positionen!

ZAHLUNGSMETHODE erkennen:
- Auf dem Beleg steht oft die Zahlungsmethode (z.B. "TWINT", "Bargeld", "BAR", "Maestro", "Visa", "Mastercard", "EC", "Debit", "Kreditkarte")
- "twint" wenn TWINT erkannt wird
- "bar" wenn Bargeld/BAR/Wechselgeld erkannt wird
- "karte" wenn Maestro/Visa/Mastercard/EC/Debit/Kreditkarte erkannt wird
- null wenn nicht erkennbar

Antworte NUR mit validem JSON in diesem Format:
{
  "geschaeft": "Name des Geschäfts",
  "datum": "YYYY-MM-DD",
  "zahlungsmethode": "twint",
  "positionen": [
    {
      "mwst_satz": 8.1,
      "betrag_brutto": 92.92,
      "beschreibung": "Diesel",
      "kategorie": "benzin"
    },
    {
      "mwst_satz": 2.6,
      "betrag_brutto": 7.95,
      "beschreibung": "Lebensmittel (Salat)",
      "kategorie": "essen"
    },
    {
      "mwst_satz": 8.1,
      "betrag_brutto": 4.20,
      "beschreibung": "Getränke (Radler)",
      "kategorie": "essen"
    }
  ],
  "total_brutto": 105.07,
  "konfidenz": 0.95
}

PLAUSIBILITÄTS-PRÜFUNG (MUSS stimmen):
- total_brutto MUSS = Summe aller positionen.betrag_brutto sein (auf 5 Rappen gerundet)
- Vergleiche dein total_brutto mit dem "Total"/"Gesamt"/"TOTAL CHF"-Wert auf dem Beleg
- Wenn die Summe nicht stimmt: Prüfe nochmal die MwSt-Tabelle und korrigiere

KONFIDENZ-REGELN (sei ehrlich und streng):
- 0.95-1.0: Alle Werte klar lesbar, MwSt-Tabelle vorhanden, Total stimmt
- 0.85-0.95: Die meisten Werte lesbar, leichte Unschärfe aber plausibel
- 0.70-0.85: Einige Werte schwer lesbar, musste raten
- unter 0.70: Beleg kaum lesbar, starke Unschärfe/Schatten
- Bei unscharfen/abgeschnittenen Belegen IMMER niedrige Konfidenz setzen!
- Wenn du bei einem Betrag unsicher bist: konfidenz unter 0.85 setzen

Weitere Regeln:
- beschreibung: Artikelnamen kommasepariert auflisten (z.B. "Lebensmittel (Kaffee, Brötchen)")
- Benzin/Diesel: immer 8.1% MwSt und kategorie "benzin"
- Wenn kein MwSt-Satz erkennbar: 8.1% als Default
- Datum: Wenn Jahr zweistellig, ergänze 20xx`,
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

    // JSON aus der Antwort extrahieren (Claude gibt manchmal Markdown-Codeblocks zurück)
    let jsonText = textContent.text.trim();
    const jsonMatch = jsonText.match(/```(?:json)?\s*([\s\S]*?)```/);
    if (jsonMatch) {
      jsonText = jsonMatch[1].trim();
    }

    const parsed = JSON.parse(jsonText);
    console.log(`Parsed: ${parsed.geschaeft}, ${parsed.total_brutto} CHF, ${parsed.positionen?.length} pos, zahlung: ${parsed.zahlungsmethode}`);

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
          ? "Timeout: Beleg-Analyse dauerte zu lange. Versuche ein kleineres Bild."
          : `Fehler: ${msg}`,
      }),
      { status: isTimeout ? 504 : 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  }
});

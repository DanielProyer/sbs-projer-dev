// Supabase Edge Function: parse-beleg
// Analysiert Kassenzettel-Bilder via Claude Sonnet 4.6 und extrahiert Beleg-Daten.
// Deploy: supabase functions deploy parse-beleg (verify_jwt=true via config.toml)
// Secret: supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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
    // Nur echte eingeloggte User dürfen die KI auslösen (Credit-Schutz).
    const userClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } },
    );
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) {
      return new Response(
        JSON.stringify({ error: "unauthorized" }),
        { status: 401, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

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

    // Claude Sonnet 4.6 API Call mit AbortController Timeout (55s).
    // Modellwechsel 26.07.2026: Haiku 4.5 las auf Thermo-Kassenzetteln das
    // Kleingedruckte (Datum, MwSt-Tabelle, Zahlungsart) zu unzuverlaessig —
    // gleiche Begruendung wie bei parse-rechnung (Ziffern-/Layout-Genauigkeit).
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
        model: "claude-sonnet-4-6",
        max_tokens: 2000,
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
1. Jeden Artikel einer Kategorie zuordnen (Reihenfolge beachten, erste
   passende Regel gewinnt):
   - "privat": ALLE Tabakwaren — Zigaretten (jede Marke, z.B. Brunette,
     Marlboro, Parisienne, Winston), Zigarillos, Zigarren, Drehtabak,
     Feinschnitt, Schnupftabak, Snus, Filter/Blättchen, sowie Belegtexte
     wie "Tabakwaren", "Rauchwaren", "Tabak", "Zig.", "Rauchw."
     Das ist ein Privatkauf und KEIN Geschäftsaufwand.
   - "benzin": Diesel, Benzin, Bleifrei, Tankzeit, AdBlue, Treibstoff, Fuel,
     Zapfsäule, Liter-Angabe bei Kraftstoff
   - "parkgebuehren": Parkhaus, Parking, Parkplatz, Parkuhr, Parkgebühr,
     Parkschein, Tiefgarage
   - "berufskleider": Arbeitshandschuhe, Sicherheitsschuhe, Arbeitshose,
     Arbeitsjacke, Schutzbrille, Gehörschutz, Helm, Warnweste, Knieschoner
   - "entsorgung": Deponie, Entsorgung, Kehrichtsack, Gebührenmarke,
     Recycling, Sondermüll, Altöl-Entsorgung
   - "material": ALLES Handwerks-/Baumaterial und Werkzeug — z.B. Schrauben,
     Dübel, Muttern, Dichtungen, Schläuche, Rohre, Kabel, Klebeband,
     Silikon, Farbe, Holz, Bleche, Bohrer, Sägeblätter, Zangen, Schlüssel,
     Messgeräte, Batterien, Leuchtmittel, Putzmittel/Reinigungsmittel,
     Lappen, Kabelbinder, Schleifpapier
   - "essen" NUR für tatsächliche Verpflegung: Lebensmittel, Getränke,
     Snacks, Sandwiches, Kaffee, Menü, Restaurant
2. GESCHÄFTS-HINWEIS nutzen: In einem Baumarkt/Fachhandel (Bauhaus, Jumbo,
   Hornbach, Obi, Coop Bau+Hobby, Landi, Migros Do it, Hagebau, Würth,
   Elektro-/Sanitär-/Eisenwarenhandlung) ist praktisch ALLES "material" —
   ausser eindeutiger Verpflegung (z.B. Getränk an der Kasse) oder klarer
   Schutzausrüstung ("berufskleider"). Ein unklarer Artikel in einem
   Baumarkt ist "material", NIEMALS "essen".
3. Dann gruppieren nach EINZIGARTIGER Kombination von (kategorie + mwst_satz)
4. BETRÄGE AUS DER MwSt-TABELLE HOLEN, NICHT AUS DEN ARTIKELZEILEN:
   - Gehört ein MwSt-Satz zu GENAU EINER Kategorie (Normalfall), dann nimm
     den Brutto-Wert für diesen Satz DIREKT aus der MwSt-Tabelle. Summiere
     NICHT die Artikelpreise — eine einzige verlesene oder übersehene Zeile
     verfälscht sonst die ganze Position (real passiert: 18.30 statt 18.40,
     Landi 06.08.2026).
   - Verteilt sich ein Satz auf MEHRERE Kategorien (z.B. Diesel 8.1% und
     Getränke 8.1%), dann teile über die Artikelzeilen auf — aber die Summe
     dieser Positionen MUSS den Brutto-Wert dieses Satzes aus der MwSt-Tabelle
     exakt treffen. Trifft sie ihn nicht, hast du eine Zeile falsch gelesen
     oder übersehen: lies die Artikelzeilen dieses Satzes nochmals.

GRUPPIERUNGS-REGELN:
- Eine Position pro EINZIGARTIGER (kategorie + mwst_satz) Kombination
- Benzin 8.1% und Essen 8.1% sind VERSCHIEDENE Gruppen → NIEMALS zusammenfassen!
- Essen 2.6% und Essen 8.1% sind VERSCHIEDENE Gruppen → getrennt
- Mehrere Essen-Artikel mit gleichem MwSt-Satz → zusammenfassen in eine Position

Beispiel 1 - migrolino (nur Essen, 2 MwSt-Sätze → 2 Positionen):
  Artikel: Kaffee 3.60 (2.6%), Brötchen 1.95 (2.6%), Öl 5.00 (8.1%), Filter 20.20 (8.1%)
  → Gruppe 1: essen+2.6% = 5.55 | Gruppe 2: essen+8.1% = 25.20
  → 2 Positionen: [{kategorie:"essen", mwst_satz:2.6, betrag_brutto:5.55}, {kategorie:"essen", mwst_satz:8.1, betrag_brutto:25.20}]

Beispiel 2 - Coop Pronto Tankstelle (Diesel + Shop + Zigaretten → 4 Positionen):
  Artikel: Diesel 92.92 (8.1%), Salat 7.95 (2.6%), Radler 4.20 (8.1%),
           Brunette Doppel-Filter 10.10 (8.1%)
  → Gruppe 1: benzin+8.1% = 92.92 | Gruppe 2: essen+2.6% = 7.95
  → Gruppe 3: essen+8.1% = 4.20 | Gruppe 4: privat+8.1% = 10.10
  → 4 Positionen: [{kategorie:"benzin", mwst_satz:8.1, betrag_brutto:92.92}, {kategorie:"essen", mwst_satz:2.6, betrag_brutto:7.95}, {kategorie:"essen", mwst_satz:8.1, betrag_brutto:4.20}, {kategorie:"privat", mwst_satz:8.1, betrag_brutto:10.10}]
  WICHTIG: Diesel (benzin), Radler (essen) und Zigaretten (privat) haben ALLE
  8.1% aber VERSCHIEDENE Kategorien → 3 getrennte Positionen!

Beispiel 3 - Bauhaus (Baumarkt → material, NICHT essen!):
  Artikel: Dichtungsring 4.90, Schlauchschelle 3.20, Silikon 12.50,
           Arbeitshandschuhe 14.90, Mineralwasser 2.50
  → Gruppe 1: material+8.1% = 20.60 (Dichtung, Schelle, Silikon)
  → Gruppe 2: berufskleider+8.1% = 14.90 (Handschuhe)
  → Gruppe 3: essen+2.6% = 2.50 (Mineralwasser)
  WICHTIG: Im Baumarkt ist der Normalfall "material" — Verpflegung ist die
  Ausnahme und muss klar erkennbar sein. NIEMALS Baumaterial als "essen"!

ZAHLUNGSMETHODE erkennen:
- Auf dem Beleg steht oft die Zahlungsmethode (z.B. "TWINT", "Bargeld", "BAR", "Maestro", "Visa", "Mastercard", "EC", "Debit", "Kreditkarte")
- "twint" wenn TWINT erkannt wird
- "bar" wenn Bargeld/BAR/Wechselgeld erkannt wird
- "karte" wenn Maestro/Visa/Mastercard/EC/Debit/Kreditkarte erkannt wird
- null wenn nicht erkennbar

Antworte NUR mit validem JSON in diesem Format:
{
  "bild_drehung": 0,
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

BILD-AUSRICHTUNG (bild_drehung):
Um wie viele Grad muss das BILD im Uhrzeigersinn gedreht werden, damit der
Belegtext aufrecht und von links nach rechts lesbar ist?
- 0   = Text steht bereits aufrecht (Normalfall)
- 90  = Beleg liegt auf der linken Seite (Text läuft von unten nach oben)
- 180 = Beleg steht auf dem Kopf
- 270 = Beleg liegt auf der rechten Seite (Text läuft von oben nach unten)
Beurteile das am gedruckten Text, nicht an der Form des Belegs. Im Zweifel 0.

SCHLUSSKONTROLLE — RECHNE DAS AUS, BEVOR DU ANTWORTEST:
Diese Prüfung ist nicht optional. Gib niemals ein Ergebnis aus, das sie nicht besteht.
1. Je MwSt-Satz: Addiere alle deine Positionen mit diesem Satz. Das Ergebnis
   MUSS dem Brutto-Wert dieses Satzes in der MwSt-Tabelle entsprechen.
2. Gesamt: Addiere ALLE deine Positionen. Das Ergebnis MUSS dem gedruckten
   "Total"/"Gesamt"/"TOTAL CHF" auf dem Beleg entsprechen, und total_brutto
   MUSS genau dieser Wert sein.
3. Stimmt etwas nicht, ist der GEDRUCKTE Beleg massgebend, nicht deine Summe:
   Geh zurück zur MwSt-Tabelle und zu den Artikelzeilen des betroffenen Satzes
   und finde den falsch gelesenen Betrag. Typische Ursachen: eine übersehene
   Artikelzeile, eine verlesene Ziffer (3.60 als 3.00), ein nicht beachteter
   Rabatt/Bon oder eine Depot-/Pfandzeile.
4. Erst wenn beide Proben aufgehen, gibst du das JSON aus.

KONFIDENZ-REGELN (bewerte, was du GELESEN hast — nicht wie der Beleg aussieht):
- 0.95-1.0: Datum, Geschäft und alle Beträge klar lesbar UND deine
  Positionssumme entspricht dem gedruckten Total. Das ist der Normalfall.
- 0.85-0.95: Alles gelesen, aber ein Detail war schwach (z.B. Datum blass)
- 0.70-0.85: Du musstest einen Betrag oder das Datum RATEN
- unter 0.70: Beleg kaum lesbar, mehrere Werte geraten
WICHTIG - diese Dinge senken die Konfidenz NICHT:
- fehlende MwSt-Tabelle (viele kleine Quittungen haben keine)
- Knicke, Schatten, schräge Aufnahme oder Thermopapier-Grauschleier
- ein knapp angeschnittener Rand, solange alle Werte lesbar sind
Entscheidend ist nur: Konntest du die Werte ablesen und geht die Rechnung
auf? Wenn deine Positionssumme dem gedruckten Total entspricht, hast du
richtig gelesen — dann gehört die Konfidenz über 0.95. Setze nur dann unter
0.85, wenn du bei einem konkreten Wert tatsächlich geraten hast.

Weitere Regeln:
- beschreibung: Artikelnamen kommasepariert auflisten (z.B. "Lebensmittel (Kaffee, Brötchen)")
- Benzin/Diesel: immer 8.1% MwSt und kategorie "benzin"
- Wenn kein MwSt-Satz erkennbar: 8.1% als Default
- Datum: Wenn Jahr zweistellig, ergänze 20xx
- kategorie MUSS einer dieser Werte sein: "privat", "benzin", "material",
  "berufskleider", "parkgebuehren", "entsorgung", "essen"
- Handwerks-/Baumaterial und Werkzeug gehören IMMER zu "material" —
  "essen" ist ausschliesslich für Verpflegung
- Tabakwaren sind IMMER "privat" (nie "essen"), auch wenn sie zusammen mit
  Verpflegung auf demselben Beleg stehen. total_brutto enthält sie trotzdem,
  weil es der tatsächlich bezahlte Beleg-Betrag ist.`,
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

    let parsed = JSON.parse(jsonText);

    // Deterministische Gegenprobe: Der Prompt verlangt, dass die Positionen
    // das gedruckte Total ergeben — verlassen kann man sich darauf nicht.
    // Geht die Rechnung nicht auf, bekommt das Modell die Abweichung EINMAL
    // beziffert zurück. Das trifft nur den Ausnahmefall (1 von ~40 Belegen,
    // Landi 06.08.2026: 122.88 statt 122.98) und kostet sonst nichts.
    const summeVon = (p: { positionen?: { betrag_brutto?: number }[] }) =>
      Math.round(
        (p.positionen ?? []).reduce((s, x) => s + (x.betrag_brutto ?? 0), 0) * 100,
      ) / 100;

    const summe = summeVon(parsed);
    const total = parsed.total_brutto ?? 0;
    const abweichung = Math.round((total - summe) * 100) / 100;

    if (Math.abs(abweichung) > 0.05) {
      console.warn(
        `Positionen ${summe} != Total ${total} (${abweichung}) — Nachfrage ans Modell`,
      );
      try {
        const nachControl = new AbortController();
        const nachTimeout = setTimeout(() => nachControl.abort(), 30000);
        const nachfrage = await fetch("https://api.anthropic.com/v1/messages", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-api-key": apiKey,
            "anthropic-version": "2023-06-01",
          },
          signal: nachControl.signal,
          body: JSON.stringify({
            model: "claude-sonnet-4-6",
            max_tokens: 2000,
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
                    text:
                      `Deine Erfassung dieses Belegs geht nicht auf:\n\n` +
                      `${JSON.stringify(parsed, null, 2)}\n\n` +
                      `Deine Positionen ergeben ${summe.toFixed(2)}, ` +
                      `total_brutto sagt ${Number(total).toFixed(2)} — ` +
                      `Abweichung ${abweichung.toFixed(2)} CHF.\n\n` +
                      `Lies die MwSt-Tabelle und die Artikelzeilen des betroffenen ` +
                      `MwSt-Satzes nochmals genau. Es fehlt oder stimmt ein Betrag ` +
                      `nicht — typisch sind eine übersehene Artikelzeile, eine ` +
                      `verlesene Ziffer, ein Rabatt/Bon oder eine Depot-/Pfandzeile.\n` +
                      `Der GEDRUCKTE Beleg ist massgebend, nicht deine bisherige Summe.\n\n` +
                      `Gib dasselbe JSON nochmals aus, mit korrigierten Beträgen, ` +
                      `sodass die Summe der Positionen exakt total_brutto ergibt. ` +
                      `Nur das JSON, keine Erklärung.`,
                  },
                ],
              },
            ],
          }),
        });
        clearTimeout(nachTimeout);

        if (nachfrage.ok) {
          const nachJson = await nachfrage.json();
          const nachText = nachJson.content?.find(
            (c: { type: string }) => c.type === "text",
          )?.text;
          if (nachText) {
            let t = nachText.trim();
            const m = t.match(/```(?:json)?\s*([\s\S]*?)```/);
            if (m) t = m[1].trim();
            const korrigiert = JSON.parse(t);
            const neueAbweichung =
              Math.round(((korrigiert.total_brutto ?? 0) - summeVon(korrigiert)) * 100) / 100;
            // Nur übernehmen, wenn es wirklich besser wurde — nie verschlimmern.
            if (Math.abs(neueAbweichung) < Math.abs(abweichung)) {
              console.log(
                `Nachfrage half: Abweichung ${abweichung} -> ${neueAbweichung}`,
              );
              parsed = korrigiert;
            } else {
              console.warn(
                `Nachfrage brachte nichts (${neueAbweichung}) — erste Antwort behalten`,
              );
            }
          }
        }
      } catch (e) {
        // Die Nachfrage ist Kür: schlägt sie fehl, liefern wir die erste
        // Antwort aus. Die App zeigt die Abweichung ohnehin rot an.
        console.error("Nachfrage fehlgeschlagen:", (e as Error).message);
      }
    }
    // bild_drehung mitloggen: Bei quer gespeicherten Belegen ist das der
    // einzige Weg zu sehen, ob das Modell die Drehung erkannt hat oder ob
    // die App sie falsch anwendet (Daniel 28.07.2026).
    console.log(
      `Parsed: ${parsed.geschaeft}, ${parsed.total_brutto} CHF, ` +
      `${parsed.positionen?.length} pos, zahlung: ${parsed.zahlungsmethode}, ` +
      `konfidenz: ${parsed.konfidenz}, bild_drehung: ${parsed.bild_drehung}`,
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
          ? "Timeout: Beleg-Analyse dauerte zu lange. Versuche ein kleineres Bild."
          : `Fehler: ${msg}`,
      }),
      { status: isTimeout ? 504 : 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  }
});

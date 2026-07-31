// Supabase Edge Function: parse-einsatz
// Versteht einen diktierten Satz (Android-Tastatur-Diktat, KEINE eigene
// Spracherkennung) und macht daraus einen strukturierten Einsatz-Vorschlag,
// den Daniel in der App nur noch bestätigen muss.
// Deploy: supabase functions deploy parse-einsatz (verify_jwt=true via config.toml)
// Secret: supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface BetriebKurz {
  id: string;
  name: string;
  ort?: string;
}

Deno.serve(async (req: Request) => {
  // CORS Preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });

  try {
    // Nur echte eingeloggte User dürfen die KI auslösen (Credit-Schutz).
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

    const { text, heute, betriebe } = await req.json();

    if (!text || typeof text !== "string" || text.trim().length === 0) {
      return json({ error: "text is required" }, 400);
    }

    // heute muss von der App mitgegeben werden, weil die Function den
    // aktuellen Tag des Nutzers (Zeitzone!) nicht selbst kennt. Fehlt es
    // trotzdem, weichen wir auf das Server-Datum (UTC) aus, damit die
    // Function nicht hart scheitert — relative Angaben werden dann aber
    // ungenauer, deshalb wird das geloggt.
    let heuteDatum: string = typeof heute === "string" ? heute.trim() : "";
    if (!/^\d{4}-\d{2}-\d{2}$/.test(heuteDatum)) {
      console.warn(`parse-einsatz: "heute" fehlt oder ungültig ("${heute}") — verwende Server-Datum`);
      heuteDatum = new Date().toISOString().slice(0, 10);
    }

    const betriebsListe: BetriebKurz[] = Array.isArray(betriebe)
      ? betriebe
          .filter((b: unknown): b is BetriebKurz =>
            !!b && typeof b === "object" && typeof (b as BetriebKurz).id === "string" &&
            typeof (b as BetriebKurz).name === "string"
          )
          .map((b: BetriebKurz) => ({ id: b.id, name: b.name, ort: b.ort ?? "" }))
      : [];

    console.log(
      `parse-einsatz: heute=${heuteDatum}, betriebe=${betriebsListe.length}, text="${text.slice(0, 200)}"`,
    );

    const betriebsListeText = betriebsListe.length > 0
      ? betriebsListe.map((b) => `${b.id}\t${b.name}${b.ort ? ` (${b.ort})` : ""}`).join("\n")
      : "(keine Betriebsliste mitgegeben — keine Zuordnung möglich)";

    const prompt = `Du hilfst einem Schweizer Zapfanlagen-Servicetechniker (SBS Projer GmbH). Er diktiert unterwegs über das Mikrofon seiner Android-Tastatur einen kurzen Satz in ein Textfeld. Die Spracherkennung selbst hat bereits stattgefunden — du bekommst NUR den fertigen Text. Deine Aufgabe: aus diesem einen Satz einen strukturierten Einsatz-Vorschlag extrahieren, den er anschliessend in der App bestätigt oder korrigiert.

HEUTIGES DATUM (für relative Angaben): ${heuteDatum}

DIKTIERTER TEXT:
"${text.trim()}"

BEKANNTE BETRIEBE (id [TAB] Name [Ort]), zur Zuordnung von Ortsnamen im Text:
${betriebsListeText}

Antworte NUR mit validem JSON (kein Markdown, keine Erklärung) in genau diesem Format:
{
  "art": "stoerung",
  "betrieb_id": "uuid oder null",
  "betrieb_name_erkannt": "Sunset",
  "betrieb_kandidaten": [{"id":"…","name":"…"}],
  "geplant_am": "2026-08-02",
  "geplant_zeit": "14:00",
  "geplant_dauer_min": 45,
  "beschreibung": "Zapfhahn tropft",
  "konfidenz": 0.85,
  "rueckfrage": "Meintest du Sunset Seehotel Eich oder Sunset Bar Chur?",
  "betrieb_neu_name": "Restaurant Adler",
  "betrieb_neu_ort": "Chur",
  "anlagen_typ": "heigenie|david|konventionell|orion oder null",
  "ist_mein_kunde": true
}
Die vier letzten Felder ("betrieb_neu_name", "betrieb_neu_ort", "anlagen_typ", "ist_mein_kunde") sind NUR bei "art": "neuer_betrieb" relevant — in allen anderen Fällen bleiben sie null.

REGEL — DATUM ("geplant_am"):
- Löse relative Angaben anhand von HEUTIGES DATUM auf:
  - "heute" → HEUTIGES DATUM selbst
  - "morgen" → HEUTIGES DATUM + 1 Tag
  - "übermorgen" → HEUTIGES DATUM + 2 Tage
  - "nächsten <Wochentag>" (z.B. "nächsten Dienstag") → das nächste Vorkommen dieses Wochentags NACH heute. Fällt HEUTIGES DATUM selbst auf diesen Wochentag, ist damit NICHT heute gemeint, sondern der gleiche Wochentag in der Folgewoche (+7 Tage).
  - "am <Tag>. <Monat>" (z.B. "am 15. August") → nächstes Vorkommen dieses Datums ab heute; liegt der Tag/Monat in diesem Jahr bereits in der Vergangenheit (vor HEUTIGES DATUM), nimm das nächste Jahr, sonst das laufende Jahr.
  - "in einer Woche" / "in zwei Wochen" → HEUTIGES DATUM + 7 bzw. + 14 Tage
- Format immer "YYYY-MM-DD".
- Wird KEIN Datum oder keine relative Zeitangabe genannt, bleibt "geplant_am" null — rate kein Datum.

REGEL — UHRZEIT ("geplant_zeit"):
- "um vierzehn Uhr" / "um 14 Uhr" → "14:00"
- "halb drei" → "14:30" (Servicetermine liegen praktisch immer zwischen 06:00 und 20:00 — interpretiere Halb-/Viertel-Angaben ohne "morgens"/"abends" im Rahmen üblicher Arbeitszeiten, im Zweifel nachmittags)
- "viertel nach neun" → "09:15", "viertel vor zehn" → "09:45"
- vage Angaben wie "am Vormittag", "gegen Mittag", "am Nachmittag" ergeben KEINE feste Uhrzeit → "geplant_zeit" bleibt null, aber die Angabe gehört in "beschreibung" (z.B. "Vormittag").
- Keine Zeitangabe im Text → "geplant_zeit" null (Einsatz gilt als ganztägig, keine feste Uhrzeit raten).

REGEL — DAUER ("geplant_dauer_min"):
- Nur setzen, wenn explizit genannt: "zwei Stunden" → 120, "eine halbe Stunde" → 30, "45 Minuten" → 45.
- Nicht genannt → null. NICHT aus der Art des Einsatzes schätzen.

REGEL — ART ("art", genau einer dieser 6 Werte):
- "stoerung": Defekt, Reparatur, Ausfall — Formulierungen wie "geht nicht", "tropft", "kein Druck", "kaputt", "defekt", "funktioniert nicht", "Schaden"
- "montage": neue Anlage, Umbau, Demontage, Rebranding, Neuanschluss, Installation einer Zapfanlage
- "eroeffnungsreinigung": Reinigung zum Saisonbeginn/Saisonöffnung
- "endreinigung": Reinigung zum Saisonende/Saisonschluss
- "neuer_betrieb": Daniel will einen neuen Kunden/Betrieb anlegen — Auslöser wie "neuer Betrieb", "neuen Kunden erfassen", "Betrieb anlegen", "neu aufnehmen". Siehe eigener Regelblock unten.
- "aufgabe": alles andere, das keiner der obigen Kategorien eindeutig zuzuordnen ist (Default/Fallback)
- Erkenne die Art an den tatsächlich genannten Wörtern, nicht durch Vermutung.

REGEL — NEUER BETRIEB (nur bei "art": "neuer_betrieb"):
- "betrieb_neu_name": Name und Ort im Text trennen. "Restaurant Adler in Chur" → Name "Restaurant Adler", Ort "Chur". Ist kein Ort erkennbar, bleibt "betrieb_neu_ort" null und der ganze Rest gilt als Name.
- "anlagen_typ": erkenne den genannten Anlagentyp — "Heigenie"/"HeiGenie" → "heigenie", "David" → "david", "konventionell"/"normal" → "konventionell", "Orion" → "orion". Die Spracherkennung verhört sich bei diesen Produktnamen häufig (z.B. "Hei Genie", "Heigeni", "Heikeni", "Davit") — sei hier grosszügig und ordne solche Verhörer trotzdem zu. Kein Anlagentyp genannt → null.
- "ist_mein_kunde": "mein Kunde"/"eigener Kunde" → true. "Heineken"/"Heineken-Kunde"/"nicht mein Kunde" → false. Nicht genannt → null (die App fragt dann selbst nach).
- "betrieb_id", "geplant_am", "geplant_zeit", "geplant_dauer_min" bleiben bei dieser Art immer null — es geht ums Anlegen eines Betriebs, nicht ums Planen eines Termins. Adresse, Telefon, Website und Koordinaten holt die App später selbst bei Google, dazu wird hier nichts erfasst.
- Enthält der Satz zusätzlich noch einen Einsatz für den neuen Betrieb (z.B. "…und morgen um 10 Uhr Störung dort"), bleibt "art" trotzdem "neuer_betrieb" (Betrieb zuerst, das ist die natürliche Reihenfolge) — der Einsatz-Teil kommt dann einfach in "beschreibung", "geplant_am"/"geplant_zeit" bleiben trotzdem null.

REGEL — BETRIEB ZUORDNEN ("betrieb_id", "betrieb_name_erkannt", "betrieb_kandidaten", Teil von "rueckfrage"):
- "betrieb_name_erkannt": der Namens-/Ortsfragment, den du im diktierten Text als Betriebsnamen identifiziert hast — so wie er im Text vorkommt (nicht der offizielle Name aus der Liste). Kein Name im Text erkennbar → null.
- Diktate enthalten oft nur einen Namensteil (z.B. "Sunset" statt "Sunset Seehotel Eich") und die Spracherkennung verhört sich häufig bei Eigennamen (Tippfehler, Lautverwechslung, Ortsname statt Betriebsname o.ä.) — sei bei der Zuordnung entsprechend grosszügig mit Fuzzy-Matching, aber NIE übermütig.
- Setze "betrieb_id" NUR, wenn GENAU EIN Betrieb aus der Liste eindeutig als gemeint erkennbar ist (Name passt klar, ggf. bestätigt durch genannten Ort).
- Gibt es MEHRERE plausible Treffer (z.B. mehrere Betriebe mit ähnlichem Namen) oder ist die Zuordnung unsicher: "betrieb_id" bleibt null, gib bis zu 3 plausible Kandidaten in "betrieb_kandidaten" zurück ({id, name}) und formuliere in "rueckfrage" eine kurze, konkrete Rückfrage, die die Kandidaten nennt (z.B. "Meintest du X oder Y?").
- Ist die Betriebsliste leer oder wurde kein Betriebsname im Text erkannt: "betrieb_id" null, "betrieb_kandidaten" leeres Array — das ist dann KEIN Grund für eine "rueckfrage", ausser eine Rückfrage ist aus anderem Grund nötig.
- Kein Treffer in der Liste trotz erkanntem Namen: "betrieb_id" null, "betrieb_kandidaten" leeres Array, "betrieb_name_erkannt" trotzdem setzen.

REGEL — BESCHREIBUNG ("beschreibung"):
- Kurze Zusammenfassung dessen, was diktiert wurde, OHNE die bereits strukturiert erfassten Teile (Datum, Uhrzeit, Betriebsname) zu wiederholen — der eigentliche Grund/Inhalt des Einsatzes (z.B. "Zapfhahn tropft", "neue Anlage").
- Vage Zeitangaben ohne feste Uhrzeit (z.B. "Vormittag") gehören hier rein, siehe oben.
- Nichts hinzuerfinden, was nicht gesagt wurde.

REGEL — KONFIDENZ ("konfidenz", 0.0–1.0):
- Hoch (>0.9): Art, Datum (falls genannt) und Betrieb (falls im Text erwähnt) sind eindeutig und ohne Zweifel erkannt.
- Mittel (0.6–0.9): einzelne Teile unsicher (z.B. Betrieb nicht eindeutig zuordenbar, Uhrzeit vage) — dann meist zusätzlich eine "rueckfrage" nötig.
- Niedrig (<0.6): der Satz ist insgesamt schwer verständlich oder widersprüchlich.

WICHTIGSTE REGEL — NICHTS ERFINDEN:
Was im Text nicht gesagt wurde, bleibt null (Datum, Uhrzeit, Dauer, Betrieb). Formuliere lieber eine "rueckfrage" als eine geratene Annahme zu treffen — ein falsch verstandener Termin bedeutet für den Techniker eine unnötige Anfahrt. "rueckfrage" ist null, wenn keine Rückfrage nötig ist.

BEISPIELE (nur zur Veranschaulichung, nicht wörtlich übernehmen):
1. "Morgen um vierzehn Uhr Störung beim Sunset Seehotel, Zapfhahn tropft"
   → art="stoerung", geplant_am=morgen, geplant_zeit="14:00", geplant_dauer_min=null,
     betrieb_name_erkannt="Sunset Seehotel", beschreibung="Zapfhahn tropft"
2. "Nächsten Dienstag Montage im Rössli, neue Anlage, zwei Stunden"
   → art="montage", geplant_am=nächster Dienstag ab heute, geplant_zeit=null,
     geplant_dauer_min=120, betrieb_name_erkannt="Rössli", beschreibung="neue Anlage"
3. "Am 15. August Eröffnungsreinigung Berggasthaus Arflina"
   → art="eroeffnungsreinigung", geplant_am="<Jahr>-08-15" (nächstes Vorkommen ab heute),
     geplant_zeit=null, geplant_dauer_min=null, betrieb_name_erkannt="Berggasthaus Arflina",
     beschreibung=null oder leer (kein zusätzlicher Grund genannt)
4. "Übermorgen Endreinigung Piz Piz"
   → art="endreinigung", geplant_am=heute+2 Tage, geplant_zeit=null, geplant_dauer_min=null,
     betrieb_name_erkannt="Piz Piz", beschreibung=null oder leer
5. "Neuer Betrieb Restaurant Adler in Chur, Heigenie-Anlage, mein Kunde"
   → art="neuer_betrieb", betrieb_neu_name="Restaurant Adler", betrieb_neu_ort="Chur",
     anlagen_typ="heigenie", ist_mein_kunde=true, betrieb_id=null, geplant_am=null, geplant_zeit=null
6. "Neuen Kunden erfassen: Pizzeria Bellavista Landquart, konventionell, Heineken-Kunde"
   → art="neuer_betrieb", betrieb_neu_name="Pizzeria Bellavista", betrieb_neu_ort="Landquart",
     anlagen_typ="konventionell", ist_mein_kunde=false, betrieb_id=null, geplant_am=null, geplant_zeit=null
7. "Betrieb anlegen Bar Nautilus in Davos, David-Anlage, und morgen um 10 Uhr Störung dort"
   → art="neuer_betrieb" (Betrieb geht vor), betrieb_neu_name="Bar Nautilus", betrieb_neu_ort="Davos",
     anlagen_typ="david", ist_mein_kunde=null, geplant_am=null, geplant_zeit=null,
     beschreibung="morgen um 10 Uhr Störung"

Antworte ausschliesslich mit dem JSON-Objekt.`;

    // Claude Haiku 4.5 API Call mit Timeout (30s) — reine Textextraktion aus
    // einem kurzen diktierten Satz, kein Bild, sollte schnell sein.
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 30000);

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
        temperature: 0,
        messages: [{ role: "user", content: [{ type: "text", text: prompt }] }],
      }),
    });

    clearTimeout(timeout);

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`Claude API error ${response.status}: ${errorText}`);
      return json({ error: `Claude API error: ${response.status}`, details: errorText }, 502);
    }

    const claudeResponse = await response.json();
    const textContent = claudeResponse.content?.find(
      (c: { type: string }) => c.type === "text",
    );

    if (!textContent?.text) {
      console.error("No text in Claude response:", JSON.stringify(claudeResponse));
      return json({ error: "No text response from Claude" }, 502);
    }

    // JSON aus der Antwort extrahieren (Claude gibt manchmal Markdown-Codeblocks zurück)
    let jsonText = textContent.text.trim();
    const jsonMatch = jsonText.match(/```(?:json)?\s*([\s\S]*?)```/);
    if (jsonMatch) {
      jsonText = jsonMatch[1].trim();
    }

    const parsed = JSON.parse(jsonText);

    console.log(
      `Parsed Einsatz: art=${parsed.art}, betrieb_id=${parsed.betrieb_id}, ` +
      `geplant_am=${parsed.geplant_am}, geplant_zeit=${parsed.geplant_zeit}, ` +
      `konfidenz=${parsed.konfidenz}, kandidaten=${parsed.betrieb_kandidaten?.length ?? 0}`,
    );

    return json(parsed);
  } catch (error) {
    const msg = (error as Error).message;
    console.error("Function error:", msg);
    const isTimeout = msg.includes("abort");
    return json(
      {
        error: isTimeout
          ? "Timeout: Diktat-Analyse dauerte zu lange. Versuche es nochmal."
          : `Fehler: ${msg}`,
      },
      isTimeout ? 504 : 500,
    );
  }
});

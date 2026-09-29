// parse-dokument: Katalog lesen, Prompt bauen, Modellantwort prüfen
// (reine Funktionen, `deno test` in antwort_test.ts) — 29.09.2026.
//
// Die App schickt die erlaubten Werte (Bereiche, Typen je Bereich, feste
// Kategorien je Bereich, Labels) bei jedem Aufruf mit. So kennt die Function
// keine App-Konstanten, und eine neue Typ-Art in `dokument_pfad.dart` braucht
// keinen Function-Deploy. Alles, was das Modell zurückgibt, wird hier gegen
// diesen Katalog geprüft: ein erfundener Typ wird «sonstiges», ein erfundener
// Bereich null — der Dialog übernimmt nur, was in seinen Listen steht.

export const MEDIA_TYPEN = ["application/pdf", "image/jpeg", "image/png"];

export interface Katalog {
  bereiche: string[];
  typen: Record<string, string[]>;
  kategorien: Record<string, string[]>;
  labels: Record<string, string>;
}

export interface Ergebnis {
  bereich: string | null;
  typ: string | null;
  kategorie: string | null;
  jahr: number | null;
  dokument_datum: string | null;
  betrag: number | null;
  referenz: string | null;
  titel: string | null;
  dateiname: string;
  zuversicht: number;
  felder: Record<string, string | number | boolean | null>;
  hinweis: string | null;
}

const SCHLUESSEL = /^[a-z0-9_]{1,40}$/;
const MAX_EINTRAEGE = 60;
const MAX_LABEL = 80;

function istObjekt(v: unknown): v is Record<string, unknown> {
  return v != null && typeof v === "object" && !Array.isArray(v);
}

function schluesselListe(v: unknown): string[] | null {
  if (!Array.isArray(v) || v.length === 0 || v.length > MAX_EINTRAEGE) {
    return null;
  }
  const liste: string[] = [];
  for (const s of v) {
    if (typeof s !== "string" || !SCHLUESSEL.test(s)) return null;
    if (!liste.includes(s)) liste.push(s);
  }
  return liste;
}

/**
 * Katalog aus dem Request-Body. `null` = unbrauchbar (400). Kategorien und
 * Labels sind optional; Typen braucht jeder Bereich.
 */
export function katalogLesen(body: unknown): Katalog | null {
  if (!istObjekt(body)) return null;
  const bereiche = schluesselListe(body.bereiche);
  if (!bereiche || !istObjekt(body.typen)) return null;

  const typen: Record<string, string[]> = {};
  for (const b of bereiche) {
    const liste = schluesselListe(body.typen[b]);
    if (!liste) return null;
    typen[b] = liste;
  }

  const kategorien: Record<string, string[]> = {};
  if (body.kategorien != null) {
    if (!istObjekt(body.kategorien)) return null;
    for (const [b, roh] of Object.entries(body.kategorien)) {
      if (!bereiche.includes(b)) continue;
      const liste = schluesselListe(roh);
      if (!liste) return null;
      kategorien[b] = liste;
    }
  }

  const labels: Record<string, string> = {};
  if (istObjekt(body.labels)) {
    for (const [k, v] of Object.entries(body.labels)) {
      if (!SCHLUESSEL.test(k) || typeof v !== "string") continue;
      const t = v.replace(/\s+/g, " ").trim().slice(0, MAX_LABEL);
      if (t) labels[k] = t;
    }
  }
  return { bereiche, typen, kategorien, labels };
}

function mitLabel(schluessel: string, labels: Record<string, string>): string {
  const l = labels[schluessel];
  return l && l !== schluessel ? `${schluessel} («${l}»)` : schluessel;
}

/** Prompt für die Einordnung — deutsch, mit dem Katalog der App. */
export function promptBauen(
  katalog: Katalog,
  bereichVorgabe: string | null,
): string {
  const zeilen = katalog.bereiche.map((b) => {
    const typen = katalog.typen[b].map((t) => mitLabel(t, katalog.labels));
    const kat = katalog.kategorien[b];
    return `- ${mitLabel(b, katalog.labels)}\n    typ: ${typen.join(", ")}` +
      (kat
        ? `\n    kategorie: ${
          kat.map((k) => mitLabel(k, katalog.labels)).join(", ")
        }`
        : "\n    kategorie: null");
  });
  const vorgabe = bereichVorgabe && katalog.bereiche.includes(bereichVorgabe)
    ? `\nDer Nutzer lädt aus dem Bereich «${bereichVorgabe}» hoch. Das ist nur ein Hinweis: passt das Dokument gleich gut in mehrere Bereiche, nimm diesen; passt es klar anderswohin, nimm den passenden.\n`
    : "";

  return `Du ordnest ein Dokument für die Ablage der SBS Projer GmbH ein (Schweizer GmbH, Domat/Ems GR, Service für Zapfanlagen). Typische Absender: Steuerverwaltung Graubünden, ESTV (Bund, MWST), SVA/AHV-Ausgleichskasse Graubünden, SUVA, AXA (Pensionskasse, Krankentaggeld, Haftpflicht), GKB (Graubündner Kantonalbank), Gemeinden, Heineken Switzerland AG.

ERLAUBTE WERTE — verwende AUSSCHLIESSLICH diese Schlüssel (links, ohne die Beschriftung in «»):
${zeilen.join("\n")}
${vorgabe}
REGELN
- bereich: der Absender-/Themenkreis. Ein Zins- und Kapitalausweis (Bank, per 31.12.) gehört zu «steuern» mit typ «zinsausweis», weil er ins Steuerdossier des Jahres gehört — ausser «steuern» steht oben nicht zur Wahl.
- typ: muss in der typ-Liste GENAU DIESES Bereichs stehen. Passt nichts, typ = "sonstiges" und begründe es kurz in "hinweis".
- kategorie: nur ein Schlüssel aus der kategorie-Liste des gewählten Bereichs; steht dort null, ist kategorie null. Steuern: bund = direkte Bundessteuer, kanton = Kantons-/Gemeindesteuer, mwst = ESTV Mehrwertsteuer, busse = Ordnungsbusse.
- jahr: das Steuer-, Geschäfts- oder Beitragsjahr, auf das sich das Dokument BEZIEHT — nicht das Druckdatum. Zinsausweis per 31.12.2025 → 2025. Schlussrechnung/Verfügung für 2024, verschickt 2025 → 2024. Provisorische Rechnung 2026 → 2026. Mahnung → Jahr der gemahnten Forderung. Police → erstes Gültigkeitsjahr. Brief ohne Bezugsjahr → Jahr des Briefdatums.
- dokument_datum: Ausstellungsdatum (YYYY-MM-DD). Bei Ausweisen/Auszügen «per <Stichtag>» der Stichtag.
- betrag: der zu zahlende Betrag in CHF (Total bzw. Saldo «zu bezahlen»), als Zahl. Guthaben/Rückerstattung NEGATIV. Ausweise, Policen, Briefe und Verfügungen ohne Zahlungsforderung → null.
- referenz: Rechnungs-, Verfügungs-, Policen- oder Abrechnungsnummer (in dieser Reihenfolge), sonst Kundennummer, sonst null. NICHT die 27-stellige QR-Referenz, NICHT die UID.
- titel: kurz und sprechend, deutsch, höchstens 80 Zeichen: Dokumentart, Absender, Bezugsjahr bzw. Stichtag. Beispiele: "Zins- und Kapitalausweis GKB per 31.12.2025", "Verfügung Verzugszinsen Schlussrechnung 2024", "Veranlagungsverfügung Kanton 2024", "Prämienrechnung SUVA provisorisch 2026".
- dateiname: Vorschlag OHNE Endung nach dem Muster <jahr>_<Absender>_<Dokumentart>[_<Referenz>], nur ASCII (ä→ae, ö→oe, ü→ue), keine Leerzeichen, Wörter mit Bindestrich. Beispiele: "2025_GKB_Zins-Kapitalausweis", "2024_SVA_Verfuegung-Verzugszinsen", "2023_Bund_Mahnung-1_Rg13985321".
- zuversicht: 0 bis 1, wie sicher bereich, typ und jahr stimmen. Klar lesbares Dokument mit eindeutiger Art → 0.9 oder mehr. Geraten → unter 0.6.
- felder: typspezifische Zahlen/Texte. Beim typ «zinsausweis» IMMER: saldo_31_12 (Kapital/Saldo per Stichtag, Zahl), zins_brutto (Zahl), verrechnungssteuer (Zahl, 0 wenn keine), zins_netto (Zahl), konto (Konto-/IBAN-Nummer gekürzt auf die letzten 4 Ziffern, z. B. "…0601"). Sonst höchstens 6 wichtige Werte (z. B. faellig_am, steuerbarer_gewinn) oder {}.
- hinweis: ein kurzer Satz, wenn etwas unsicher ist; sonst null.

Antworte AUSSCHLIESSLICH mit einem JSON-Objekt, ohne Erklärung:
{
  "bereich": "steuern",
  "typ": "zinsausweis",
  "kategorie": null,
  "jahr": 2025,
  "dokument_datum": "2025-12-31",
  "betrag": null,
  "referenz": null,
  "titel": "Zins- und Kapitalausweis GKB per 31.12.2025",
  "dateiname": "2025_GKB_Zins-Kapitalausweis",
  "zuversicht": 0.95,
  "felder": {"saldo_31_12": 10869.26, "zins_brutto": 0, "verrechnungssteuer": 0, "zins_netto": 0, "konto": "…0601"},
  "hinweis": null
}`;
}

/**
 * JSON-Objekt aus der Modellantwort: roh, im ```json-Block oder mitten im
 * Fliesstext (erstes ausgewogenes {…}). `null`, wenn keines lesbar ist.
 */
export function jsonAusText(text: string): Record<string, unknown> | null {
  const versuche: string[] = [text.trim()];
  const block = text.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (block) versuche.push(block[1].trim());
  const start = text.indexOf("{");
  if (start !== -1) {
    const ende = ausgewogenesEnde(text, start);
    if (ende !== -1) versuche.push(text.slice(start, ende + 1));
  }
  for (const v of versuche) {
    try {
      const o = JSON.parse(v);
      if (istObjekt(o)) return o;
    } catch (_) {
      // nächster Versuch
    }
  }
  return null;
}

/** Index der schliessenden Klammer zu `{` an [start], Strings beachtet. */
function ausgewogenesEnde(text: string, start: number): number {
  let tiefe = 0;
  let imString = false;
  let escape = false;
  for (let i = start; i < text.length; i++) {
    const c = text[i];
    if (imString) {
      if (escape) escape = false;
      else if (c === "\\") escape = true;
      else if (c === '"') imString = false;
      continue;
    }
    if (c === '"') imString = true;
    else if (c === "{") tiefe++;
    else if (c === "}") {
      tiefe--;
      if (tiefe === 0) return i;
    }
  }
  return -1;
}

export function endung(mediaType: string): string {
  if (mediaType === "application/pdf") return "pdf";
  if (mediaType === "image/png") return "png";
  return "jpg";
}

function text(v: unknown, max: number): string | null {
  if (typeof v !== "string") return null;
  const t = v.replace(/\s+/g, " ").trim();
  return t ? t.slice(0, max) : null;
}

/** Zahl aus Zahl oder Text («10'869.26», «1 234,50», «-434.20»). */
export function zahl(v: unknown): number | null {
  if (typeof v === "number") return Number.isFinite(v) ? runde(v) : null;
  if (typeof v !== "string") return null;
  const t = v.replace(/['’\s]/g, "").replace(/^CHF/i, "").replace(",", ".");
  if (!/^-?\d+(\.\d+)?$/.test(t)) return null;
  return runde(Number(t));
}

function runde(v: number): number {
  return Math.round(v * 100) / 100;
}

function jahrLesen(v: unknown): number | null {
  const j = typeof v === "string" ? Number(v.trim()) : v;
  return typeof j === "number" && Number.isInteger(j) && j >= 1990 &&
      j <= 2100
    ? j
    : null;
}

/** ISO-Datum (YYYY-MM-DD) oder dd.mm.yyyy → ISO; sonst null. */
export function datumLesen(v: unknown): string | null {
  if (typeof v !== "string") return null;
  const s = v.trim();
  let m = s.match(/^(\d{4})-(\d{2})-(\d{2})/);
  let [j, mo, t] = m ? [m[1], m[2], m[3]] : ["", "", ""];
  if (!m) {
    m = s.match(/^(\d{1,2})\.(\d{1,2})\.(\d{4})$/);
    if (!m) return null;
    [j, mo, t] = [m[3], m[2].padStart(2, "0"), m[1].padStart(2, "0")];
  }
  const d = new Date(`${j}-${mo}-${t}T00:00:00Z`);
  if (
    isNaN(d.getTime()) || d.getUTCFullYear() !== Number(j) ||
    d.getUTCMonth() + 1 !== Number(mo) || d.getUTCDate() !== Number(t)
  ) {
    return null;
  }
  return `${j}-${mo}-${t}`;
}

const UMLAUTE: Record<string, string> = {
  "ä": "ae",
  "ö": "oe",
  "ü": "ue",
  "Ä": "Ae",
  "Ö": "Oe",
  "Ü": "Ue",
  "ß": "ss",
};

/**
 * Dateiname auf ASCII ohne Leerzeichen bringen und die Endung aus dem
 * Media-Type setzen (eine vom Modell mitgelieferte Endung fällt weg).
 * `null`, wenn nach dem Bereinigen nichts übrig bleibt.
 */
export function dateinameBereinigen(
  roh: unknown,
  mediaType: string,
): string | null {
  if (typeof roh !== "string") return null;
  const basis = roh
    .trim()
    .replace(/\.(pdf|jpe?g|png)$/i, "")
    .replace(/[äöüÄÖÜß]/g, (c) => UMLAUTE[c])
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .replace(/\s+/g, "_")
    .replace(/[^A-Za-z0-9._-]/g, "")
    .replace(/_{2,}/g, "_")
    .replace(/-{2,}/g, "-")
    .replace(/^[._-]+|[._-]+$/g, "")
    .slice(0, 120)
    .replace(/[._-]+$/g, "");
  return basis ? `${basis}.${endung(mediaType)}` : null;
}

/** Ersatzname `<jahr>_<bereich>_<typ>[_<referenz>]`, falls das Modell keinen brauchbaren liefert. */
export function dateinameErsatz(
  e: Pick<Ergebnis, "jahr" | "bereich" | "typ" | "referenz">,
  mediaType: string,
): string {
  const teile = [
    e.jahr != null ? String(e.jahr) : "ohne-jahr",
    e.bereich ?? "dokument",
    e.typ ?? "sonstiges",
  ];
  if (e.referenz) teile.push(e.referenz);
  return dateinameBereinigen(teile.join("_"), mediaType) ??
    `dokument.${endung(mediaType)}`;
}

const ZINS_ZAHLEN = [
  "saldo_31_12",
  "zins_brutto",
  "verrechnungssteuer",
  "zins_netto",
];

function felderLesen(
  v: unknown,
): Record<string, string | number | boolean | null> {
  const felder: Record<string, string | number | boolean | null> = {};
  if (!istObjekt(v)) return felder;
  for (const [k, w] of Object.entries(v)) {
    if (Object.keys(felder).length >= 12) break;
    if (!SCHLUESSEL.test(k)) continue;
    if (ZINS_ZAHLEN.includes(k)) {
      felder[k] = zahl(w);
    } else if (typeof w === "number") {
      if (Number.isFinite(w)) felder[k] = w;
    } else if (typeof w === "string") {
      felder[k] = w.trim().slice(0, 120);
    } else if (typeof w === "boolean" || w === null) {
      felder[k] = w;
    }
  }
  return felder;
}

function wahl(v: unknown): string | null {
  return typeof v === "string" ? v.trim().toLowerCase() : null;
}

/**
 * Modellantwort gegen den Katalog prüfen. Unbekannter Bereich → null (der
 * Dialog behält seinen), unbekannter Typ → "sonstiges", Kategorie nur aus der
 * festen Liste des Bereichs.
 */
export function ergebnisNormalisieren(
  roh: Record<string, unknown>,
  katalog: Katalog,
  mediaType: string,
): Ergebnis {
  const hinweise: string[] = [];
  const hinweisModell = text(roh.hinweis, 200);
  if (hinweisModell) hinweise.push(hinweisModell);

  const bereichRoh = wahl(roh.bereich);
  const bereich = bereichRoh && katalog.bereiche.includes(bereichRoh)
    ? bereichRoh
    : null;
  if (bereichRoh && !bereich) {
    hinweise.push(`Unbekannter Bereich «${bereichRoh}» verworfen.`);
  }

  const erlaubteTypen = bereich
    ? katalog.typen[bereich]
    : [...new Set(Object.values(katalog.typen).flat())];
  const typRoh = wahl(roh.typ);
  let typ: string | null = typRoh && erlaubteTypen.includes(typRoh)
    ? typRoh
    : null;
  if (!typ) {
    typ = erlaubteTypen.includes("sonstiges") ? "sonstiges" : null;
    if (typRoh && typRoh !== "sonstiges") {
      hinweise.push(
        `Typ «${typRoh}» passt nicht, als «sonstiges» eingeordnet.`,
      );
    }
  }

  const katRoh = wahl(roh.kategorie);
  const katListe = bereich ? katalog.kategorien[bereich] : undefined;
  const kategorie = katRoh && katListe?.includes(katRoh) ? katRoh : null;

  let zuversicht = typeof roh.zuversicht === "number"
    ? roh.zuversicht
    : zahl(roh.zuversicht) ?? 0;
  if (zuversicht > 1 && zuversicht <= 100) zuversicht /= 100;
  zuversicht = Math.min(1, Math.max(0, zuversicht));

  const basis = {
    bereich,
    typ,
    kategorie,
    jahr: jahrLesen(roh.jahr),
    dokument_datum: datumLesen(roh.dokument_datum),
    betrag: zahl(roh.betrag),
    referenz: text(roh.referenz, 80),
    titel: text(roh.titel, 160),
  };
  return {
    ...basis,
    dateiname: dateinameBereinigen(roh.dateiname, mediaType) ??
      dateinameErsatz(basis, mediaType),
    zuversicht: Math.round(zuversicht * 100) / 100,
    felder: felderLesen(roh.felder),
    hinweis: hinweise.length ? hinweise.join(" ") : null,
  };
}

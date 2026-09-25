// Reine Hilfsfunktionen für send-rechnung-mail — ausgelagert, damit sie mit
// `deno test` ohne laufenden Server geprüft werden können (gleiches Muster
// wie google-contacts-sync/mapping.ts).

/**
 * Prüft einen Zusatz-PDF-Pfad STRENG, bevor er aus dem Storage geladen wird
 * (Review 23.09.2026, Punkt 7).
 *
 * Regeln:
 * - Erstes Pfadsegment muss EXAKT `userId` sein.
 * - Jedes Segment muss `^[A-Za-z0-9_-][A-Za-z0-9._-]*$` erfüllen (kein
 *   führender Punkt/Bindestrich-Sonderfall nötig, aber kein Segment, das nur
 *   aus Punkten besteht).
 * - Kein Segment darf `.` oder `..` sein (Verzeichnis-Ausbruch).
 * - Kein `%` (verhindert Doppel-Kodierungstricks), kein `\`, kein führender
 *   `/`, keine leeren Segmente (z. B. durch `//`).
 *
 * Seit v24 (25.09.2026) kommt `userId` aus dem geprüften JWT
 * (`ermittleUserId` in index.ts), nicht mehr aus dem Body. Diese Prüfung
 * verhindert zusätzlich, dass ein Pfad aus dem eigenen Benutzer-Ordner
 * ausbricht oder sich als fremder Pfad tarnt.
 */
export function zusatzPdfPfadErlaubt(pfad: unknown, userId: string): pfad is string {
  if (typeof pfad !== "string" || pfad.length === 0) return false;
  if (pfad.includes("\\") || pfad.includes("%") || pfad.startsWith("/")) {
    return false;
  }
  const segmente = pfad.split("/");
  if (segmente.length < 2) return false;
  if (segmente.some((s) => s.length === 0)) return false;
  if (segmente[0] !== userId) return false;

  const gueltig = /^[A-Za-z0-9_-][A-Za-z0-9._-]*$/;
  for (const s of segmente) {
    if (s === "." || s === "..") return false;
    if (!gueltig.test(s)) return false;
  }
  return true;
}

/**
 * UUID (v4-artig, wie Supabase sie vergibt) — für `rechnungId`/`bestellungId`,
 * die direkt in einen Storage-Pfad eingebaut werden (v24: vorher ungeprüft).
 */
export function istUuid(wert: unknown): wert is string {
  return typeof wert === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(wert);
}

/**
 * Dateiname des Rechnungs-/Mahnungs-PDFs (`pdfPath`): genau EIN Segment,
 * `.pdf`, nur `[A-Za-z0-9_-]` davor — kein `/`, kein `..`, kein `%`.
 * Erlaubt damit `rechnung.pdf` und `mahnung_1.pdf`, nichts, was den Ordner
 * `<userId>/<rechnungId>/` verlässt.
 */
export function pdfDateinameErlaubt(wert: unknown): wert is string {
  return typeof wert === "string" && /^[A-Za-z0-9_-]{1,80}\.pdf$/.test(wert);
}

/**
 * Pfad des Protokoll-Fotos im Bucket `reinigung-fotos`: gleiche Regeln wie
 * [zusatzPdfPfadErlaubt] (erstes Segment = userId), zusätzlich muss die
 * Endung eine der bekannten sein — sonst würde ein beliebiger Bucket-Inhalt
 * als «Reinigungsprotokoll» verschickt.
 */
export function protokollPfadErlaubt(pfad: unknown, userId: string): pfad is string {
  if (!zusatzPdfPfadErlaubt(pfad, userId)) return false;
  return /\.(pdf|jpe?g|png|webp)$/i.test(pfad);
}

/**
 * Kodiert einen Storage-Pfad segmentweise für die REST-URL — `encodeURIComponent`
 * je Segment, wieder mit `/` verbunden (nicht den ganzen Pfad auf einmal, das
 * würde auch die trennenden `/` kodieren).
 *
 * Bestehende Pfade (`${userId}/${rechnungId}/rechnung.pdf`, Protokoll- und
 * Bestellungs-Pfade) bestehen nur aus UUIDs/Dateinamen mit gewöhnlichen
 * Zeichen — für sie ist das Kodieren ein No-op. Für Pfade mit Leerzeichen
 * oder Umlauten (z. B. ein Protokoll-Dateiname) macht es den Storage-Aufruf
 * erst korrekt.
 */
export function kodierePfad(pfad: string): string {
  return pfad
    .split("/")
    .map((segment) => encodeURIComponent(segment))
    .join("/");
}

/**
 * Bereinigt einen (potenziell benutzer- oder datenbankgesteuerten) Dateinamen
 * für den MIME-`Content-Disposition`-Header (Review 23.09.2026, Punkt 9):
 * nur `[A-Za-z0-9._ -]`, Umlaute transkribiert, maximal 80 Zeichen, Endung
 * `.pdf` erzwungen.
 */
export function bereinigeDateiname(name: string): string {
  let s = (name || "Dokument.pdf")
    .replace(/ä/g, "ae")
    .replace(/ö/g, "oe")
    .replace(/ü/g, "ue")
    .replace(/Ä/g, "Ae")
    .replace(/Ö/g, "Oe")
    .replace(/Ü/g, "Ue")
    .replace(/ß/g, "ss");
  s = s.replace(/[^A-Za-z0-9._ -]/g, "_").trim();
  if (s.length === 0) s = "Dokument";

  if (!s.toLowerCase().endsWith(".pdf")) {
    // Eine andere Endung (falls vorhanden) entfernen, dann .pdf anhängen —
    // nie zwei Endungen aneinanderhängen.
    s = s.replace(/\.[A-Za-z0-9]{1,5}$/, "");
    s = `${s}.pdf`;
  }

  if (s.length > 80) {
    s = `${s.slice(0, 80 - 4)}.pdf`;
  }
  return s;
}

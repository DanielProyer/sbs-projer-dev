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
 * WICHTIG — was das NICHT ist: Diese Function läuft ohne JWT-Prüfung,
 * `userId` kommt ungeprüft aus dem Request-Body. Diese Prüfung verhindert
 * NUR, dass ein Pfad aus dem eigenen Benutzer-Ordner ausbricht oder sich als
 * fremder Pfad tarnt — sie ersetzt KEINE Authentifizierung. Mittelfristig
 * bräuchte diese Function eine echte JWT-Prüfung (`Authorization`-Header
 * gegen Supabase Auth verifizieren); das ist hier bewusst NICHT umgesetzt.
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

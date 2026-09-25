// Reine Prüffunktionen für send-raster-mail — ausgelagert, damit `deno test`
// sie ohne laufenden Server prüfen kann (Muster send-rechnung-mail).

/** Kein CR/LF in Header-Feldern (Header-Injection). */
export function headerSicher(wert: unknown): wert is string {
  return typeof wert === "string" && wert.length > 0 && wert.length <= 500 && !/[\r\n]/.test(wert);
}

/** Pfad streng: <userId>/<datei>.pdf, Segmente nur [A-Za-z0-9._-], kein .., %, \. */
export function rasterPfadErlaubt(pfad: unknown, userId: string): pfad is string {
  if (typeof pfad !== "string" || pfad.length === 0 || pfad.length > 300) return false;
  if (pfad.includes("\\") || pfad.includes("%") || pfad.startsWith("/")) return false;
  const seg = pfad.split("/");
  if (seg.length < 2 || seg.some((s) => s.length === 0 || s === "." || s === "..")) return false;
  if (seg[0] !== userId) return false;
  if (!seg.every((s) => /^[A-Za-z0-9_-][A-Za-z0-9._-]*$/.test(s))) return false;
  return /\.pdf$/i.test(pfad);
}

/** Dateiname für Content-Disposition: nur [A-Za-z0-9._ -], .pdf erzwungen, max. 80. */
export function bereinigeDateiname(name: unknown): string {
  let s = (typeof name === "string" ? name : "Raster.pdf")
    .replace(/ä/g, "ae").replace(/ö/g, "oe").replace(/ü/g, "ue")
    .replace(/Ä/g, "Ae").replace(/Ö/g, "Oe").replace(/Ü/g, "Ue").replace(/ß/g, "ss")
    .replace(/[^A-Za-z0-9._ -]/g, "_").trim();
  if (s.length === 0) s = "Raster";
  if (!s.toLowerCase().endsWith(".pdf")) s = `${s.replace(/\.[A-Za-z0-9]{1,5}$/, "")}.pdf`;
  if (s.length > 80) s = `${s.slice(0, 76)}.pdf`;
  return s;
}

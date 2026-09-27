// Titel und Ort eines Aufgaben-Kalendereintrags (Migration 198 + 212).
//
// Eigenes Modul, damit es ohne Deno.serve testbar ist (wie ferien_keys.ts).
// Push (pushOne) und Vollabgleich (reconcile -> pushOne) bauen den Eintrag
// beide ueber loadEntity -> buildEvent -> hier; eine zweite Fassung darf es
// nicht geben, sonst wechselt der Eintrag bei jedem Lauf hin und her
// (content_hash in google_calendar_events).

/** Felder, die loadEntity aus `betriebe` an die Aufgaben-Zeile haengt. */
export interface AufgabeZeile {
  titel?: string | null;
  betrieb_name?: string | null;
  betrieb_strasse?: string | null;
  betrieb_nr?: string | null;
  betrieb_plz?: string | null;
  betrieb_ort?: string | null;
}

function teil(...werte: (string | null | undefined)[]): string {
  return werte.map((w) => String(w ?? "").trim()).filter((w) => w.length > 0).join(" ");
}

/**
 * «SBS · Aufgabe: <titel>» plus « · <Betrieb>», wenn die Aufgabe einen
 * Betrieb traegt; `location` = «Name, Strasse Nr, PLZ Ort» (nur die
 * vorhandenen Teile). Ohne Betrieb bleibt `location` undefined — der
 * Eintrag serialisiert dann exakt wie vor Migration 212 (gleicher Hash,
 * kein unnoetiges PUT fuer bestehende Aufgaben).
 */
export function aufgabeTexte(row: AufgabeZeile): { summary: string; location?: string } {
  const name = teil(row.betrieb_name);
  const summary = "SBS · Aufgabe: " + (row.titel ?? "") + (name ? ` · ${name}` : "");
  const adresse = [
    name,
    teil(row.betrieb_strasse, row.betrieb_nr),
    teil(row.betrieb_plz, row.betrieb_ort),
  ].filter((s) => s.length > 0).join(", ");
  return { summary, location: adresse || undefined };
}

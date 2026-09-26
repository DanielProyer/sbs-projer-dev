// Reine Filterfunktion fuer das Aufraeumen der Ferien-Reinigungen
// (entity_type "betrieb_reinigung", entity_id "<betriebId>:ferien…").
//
// WARUM: Bis v0.141.0 hiessen die Schluessel "ferien1_endreinigung" nach dem
// Index der Periode. Seit die Ferien aus der Tabelle betrieb_ferien kommen,
// verschob jede neue fruehere oder geloeschte Periode den Index — Eintraege
// wurden doppelt angelegt oder blieben verwaist (Review R7, 26.09.2026).
// Neu tragen die Schluessel den Ferienbeginn ("ferien_2026-10-11_…"), und
// die App schickt alle aktuell gueltigen Schluessel mit; was nicht darin
// steht, gehoert weg. Eigene Datei, damit der Test index.ts (Deno.serve,
// Netz) nicht importieren muss.

/**
 * Welche Zuordnungen dieses Betriebs muessen weg?
 *
 * @param betriebId  Server-UUID des Betriebs
 * @param entityIds  entity_ids der vorhandenen betrieb_reinigung-Zuordnungen
 * @param alleKeys   alle gueltigen Ferien-Schluessel (ohne "<betriebId>:")
 * @returns die entity_ids von Ferien-Zuordnungen, die in alleKeys fehlen.
 *          Saison-Schluessel (sommer_/winter_) und fremde Betriebe bleiben
 *          unangetastet.
 */
export function veralteteFerienZuordnungen(
  betriebId: string,
  entityIds: string[],
  alleKeys: string[],
): string[] {
  const praefix = `${betriebId}:`;
  const gueltig = new Set(alleKeys);
  return entityIds.filter((id) => {
    if (!id.startsWith(praefix)) return false;
    const key = id.substring(praefix.length);
    if (!key.startsWith("ferien")) return false;
    return !gueltig.has(key);
  });
}

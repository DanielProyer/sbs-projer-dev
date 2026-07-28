-- ============================================================================
-- Zusatzanlagen - die 24 Restfaelle (28.07.2026)
-- ============================================================================
-- Regeln von Daniel:
--   * Steht im Excel 'Zusaetzliche Anlage', ist das massgebend fuer die
--     RECHNUNG - die Leistung wird beim anderen Betrieb/der anderen Anlage
--     verrechnet, diese Zeile also mit 0.00.
--   * Die REINIGUNG soll trotzdem bei beiden Anlagen/Betrieben ersichtlich
--     bleiben - sie wird deshalb nicht geloescht.
--
-- Daraus zwei Gruppen:
--
-- A) Blue Cinema Chur (5x): Die Hauptanlage _01 war ausser Betrieb, die
--    Rechnung haengt an _02 (Rechnung Mail, 184.85) - _03 ist die
--    Zusatzanlage am selben Tag. Wie die 198 zuvor: Anlage in anlage_ids der
--    Hauptzeile uebernehmen, Zusatzzeile loeschen.
--
-- B) 19 Zeilen bleiben bestehen, bekommen aber Preis 0.00:
--    - 16 Einzelreinigungen (_01) bei Vieri Bar, Strela, Frosch Sportclub,
--      Roessli, Jamies: zwei Betriebe in einem Haus, frueher zwei Rechnungen,
--      auf Kundenwunsch zusammengelegt.
--    - 3 Zeilen Robinson Club Arosa vom 26.02.2025: eigene Arbeitstage
--      (Hauptreinigung war am 24.02.), nur nicht separat verrechnet.
--
-- Preis-Trigger ausgesetzt - er wuerde sonst wieder Grundtarif + Haehne
-- rechnen.
--
-- Aufruf:
--   npx supabase db query --linked --file Datenbank/wartung/zusatzanlagen_rest_2026_07_28.sql
-- ============================================================================

BEGIN;

DROP TABLE IF EXISTS snapshot_zusatzanlagen.rest_vorher;
CREATE TABLE snapshot_zusatzanlagen.rest_vorher AS
SELECT r.* FROM reinigungen r
JOIN import.einzahlung_excel e ON e.extern_id = r.extern_id
WHERE e.rechnungsart = 'Zusätzliche Anlage';

ALTER TABLE reinigungen DISABLE TRIGGER reinigung_preis_berechnung;

-- ---------------------------------------------------------------- Gruppe A
CREATE TEMP TABLE paare_a AS
SELECT z.id AS zusatz_id, z.anlage_id AS zusatz_anlage, h.id AS haupt_id
FROM reinigungen z
JOIN import.einzahlung_excel e ON e.extern_id = z.extern_id
JOIN reinigungen h ON h.betrieb_id = z.betrieb_id AND h.datum = z.datum AND h.id <> z.id
JOIN import.einzahlung_excel eh ON eh.extern_id = h.extern_id
                               AND eh.rechnungsart <> 'Zusätzliche Anlage'
WHERE e.rechnungsart = 'Zusätzliche Anlage'
  AND NOT EXISTS (SELECT 1 FROM rechnungs_positionen p WHERE p.service_id = z.id);

WITH neu AS (
  SELECT haupt_id, jsonb_agg(DISTINCT zusatz_anlage::text) AS anlagen
  FROM paare_a WHERE zusatz_anlage IS NOT NULL GROUP BY haupt_id)
UPDATE reinigungen h
SET anlage_ids = (
      SELECT jsonb_agg(DISTINCT wert) FROM (
        SELECT jsonb_array_elements_text(
                 CASE WHEN h.anlage_ids IS NULL OR h.anlage_ids::text IN ('null','[]')
                      THEN CASE WHEN h.anlage_id IS NULL THEN '[]'::jsonb
                                ELSE jsonb_build_array(h.anlage_id::text) END
                      ELSE h.anlage_ids END) AS wert
        UNION SELECT jsonb_array_elements_text(neu.anlagen)) x),
    updated_at = now()
FROM neu WHERE h.id = neu.haupt_id;

DELETE FROM reinigungen WHERE id IN (SELECT zusatz_id FROM paare_a);

-- ---------------------------------------------------------------- Gruppe B
UPDATE reinigungen r
SET preis_grundtarif = 0, preis_zusatz_haehne = 0,
    preis_netto = 0, preis_mwst = 0, preis_brutto = 0,
    notizen = coalesce(nullif(r.notizen,'')||' | ','')
              ||'Zusatzanlage - wird beim anderen Betrieb verrechnet (Excel 28.07.2026)',
    updated_at = now()
FROM import.einzahlung_excel e
WHERE e.extern_id = r.extern_id
  AND e.rechnungsart = 'Zusätzliche Anlage'
  AND r.preis_brutto <> 0
  AND NOT EXISTS (SELECT 1 FROM rechnungs_positionen p WHERE p.service_id = r.id);

ALTER TABLE reinigungen ENABLE TRIGGER reinigung_preis_berechnung;

COMMIT;

-- ============================================================================
-- Zusatzanlagen mit der Hauptreinigung zusammenfuehren (28.07.2026)
-- ============================================================================
-- Gemeldet von Daniel: Lindemann's Over Time, 31.07.2025 - die App zeigt zwei
-- Reinigungen, es war aber EINE Reinigung an ZWEI Anlagen.
--
-- Im Excel bekommt jede weitere Anlage derselben Reinigung eine eigene Zeile
-- mit Rechnungsart 'Zusaetzliche Anlage' und Total 0.00 (Suffix _02, _03 ...).
-- Der Import vom 19.06.2026 hat 222 davon als eigenstaendige Reinigung
-- angelegt (die uebrigen 1'307 korrekterweise nicht) - und ihnen ueber den
-- Preis-Trigger sogar einen Betrag gegeben (220 Stueck, zusammen CHF
-- 16'571.63), obwohl im Excel 0.00 steht.
--
-- Bereinigung: Die Anlage der Zusatzzeile wandert in anlage_ids der
-- Hauptreinigung (so bildet die App mehrere Anlagen ab), danach wird die
-- Zusatzzeile geloescht.
--
-- NICHT angefasst werden:
--   * die 16 Zeilen mit Suffix _01 - das sind echte Einzelreinigungen
--     (Vieri Bar, Strela, Frosch Sportclub, Roessli), die im Excel nur die
--     Rechnungsart 'Zusaetzliche Anlage' tragen. Warum, muss Daniel klaeren.
--   * Zeilen mit Rechnungsposition oder Buchung (keine vorhanden ausser dem
--     bekannten Jamies-Doppeleintrag, der ein _01 ist).
--
-- Der Preis-Trigger wird ausgesetzt: Wir aendern nur die Anlagenliste, die
-- eben korrigierten Betraege sollen unveraendert bleiben.
--
-- Aufruf:
--   npx supabase db query --linked --file Datenbank/wartung/zusatzanlagen_zusammenfuehren_2026_07_28.sql
-- ============================================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS snapshot_zusatzanlagen;
DROP TABLE IF EXISTS snapshot_zusatzanlagen.geloescht;
DROP TABLE IF EXISTS snapshot_zusatzanlagen.haupt_vorher;

-- Zusatzzeilen mit ihrer Hauptreinigung
CREATE TEMP TABLE paare AS
SELECT z.id AS zusatz_id, z.anlage_id AS zusatz_anlage, h.id AS haupt_id
FROM reinigungen z
JOIN import.einzahlung_excel e ON e.extern_id = z.extern_id
JOIN reinigungen h ON h.betrieb_id = z.betrieb_id AND h.datum = z.datum AND h.id <> z.id
                  AND h.extern_id = left(z.extern_id, length(z.extern_id) - 3) || '_01'
WHERE e.rechnungsart = 'Zusätzliche Anlage'
  AND right(z.extern_id, 3) <> '_01'
  AND NOT EXISTS (SELECT 1 FROM rechnungs_positionen p WHERE p.service_id = z.id);

CREATE TABLE snapshot_zusatzanlagen.geloescht AS
SELECT r.* FROM reinigungen r WHERE r.id IN (SELECT zusatz_id FROM paare);
CREATE TABLE snapshot_zusatzanlagen.haupt_vorher AS
SELECT r.id, r.anlage_ids, r.updated_at FROM reinigungen r WHERE r.id IN (SELECT haupt_id FROM paare);

ALTER TABLE reinigungen DISABLE TRIGGER reinigung_preis_berechnung;

-- Anlagen der Zusatzzeilen in die Hauptreinigung uebernehmen (je Hauptzeile
-- aggregiert, damit auch mehrere Zusatzanlagen ankommen)
WITH neu AS (
  SELECT haupt_id, jsonb_agg(DISTINCT zusatz_anlage::text) AS anlagen
  FROM paare WHERE zusatz_anlage IS NOT NULL GROUP BY haupt_id)
UPDATE reinigungen h
SET anlage_ids = (
      SELECT jsonb_agg(DISTINCT wert)
      FROM (
        SELECT jsonb_array_elements_text(
                 CASE WHEN h.anlage_ids IS NULL OR h.anlage_ids::text IN ('null','[]')
                      THEN CASE WHEN h.anlage_id IS NULL THEN '[]'::jsonb
                                ELSE jsonb_build_array(h.anlage_id::text) END
                      ELSE h.anlage_ids END) AS wert
        UNION
        SELECT jsonb_array_elements_text(neu.anlagen)
      ) x),
    updated_at = now()
FROM neu WHERE h.id = neu.haupt_id;

DELETE FROM reinigungen WHERE id IN (SELECT zusatz_id FROM paare);

ALTER TABLE reinigungen ENABLE TRIGGER reinigung_preis_berechnung;

COMMIT;

-- ============================================================================
-- Korrektur der Betriebszuordnung ueber heineken_nr (28.07.2026)
-- ============================================================================
-- Nachtraeglicher Fund: betriebe.heineken_nr traegt die Excel-Betriebsnummer.
-- Damit laesst sich jede Zuordnung des Entwirrens unabhaengig pruefen.
--
-- Ergebnis der Pruefung: 13 Zuordnungen exakt bestaetigt, drei falsch -
-- dort war ein Betrieb neu angelegt worden, obwohl er unter anderem Namen
-- laengst existierte. Diese drei sind hier korrigiert.
--
-- Das Skript ist bereits ausgefuehrt und dient der Nachvollziehbarkeit.
-- ============================================================================

-- 1) Mapping auf die per heineken_nr belegten Betriebe umstellen
UPDATE import.betrieb_mapping m
SET ziel_id = h.id, bemerkung = h.name || ' [' || h.ort || '] (per heineken_nr korrigiert)'
FROM betriebe h
WHERE h.heineken_nr = m.nr AND m.nr IN ('0146', '0727', '0730');
--   0146 -> Hotel Sport [Klosters]        (war: neuer Betrieb Sport Klosters-Serneus)
--   0727 -> Blue Sushi Garden [Gettnau]   (war: neuer Betrieb Grill-Haus Hayoz)
--   0730 -> Gasthof Loewen [Grossdietwil] (war: neuer Betrieb Gasthaus Loewen)

-- 2) Reinigungen und Rechnungen dorthin
UPDATE reinigungen r
SET betrieb_id = m.ziel_id,
    anlage_id  = (SELECT a.id FROM anlagen a WHERE a.betrieb_id = m.ziel_id
                    AND (SELECT count(*) FROM anlagen a2 WHERE a2.betrieb_id = m.ziel_id) = 1 LIMIT 1),
    updated_at = now()
FROM import.betrieb_mapping m
WHERE r.extern_id IS NOT NULL AND split_part(r.extern_id, '_', 4) = m.nr
  AND m.nr IN ('0146', '0727', '0730') AND r.betrieb_id IS DISTINCT FROM m.ziel_id;

UPDATE rechnungen r
SET betrieb_id = m.ziel_id, updated_at = now()
FROM import.betrieb_mapping m
WHERE r.rechnungsnummer ~ '^011_[0-9]{4}_' AND split_part(r.rechnungsnummer, '_', 5) = m.nr
  AND m.nr IN ('0146', '0727', '0730') AND r.betrieb_id IS DISTINCT FROM m.ziel_id;

-- 3) Die drei ueberfluessigen Betriebe entfernen (nur wenn leer)
DELETE FROM betriebe b
WHERE b.id IN ('a2000000-0000-4000-8000-000000000146',
               'a1000000-0000-4000-8000-000000000727',
               'a1000000-0000-4000-8000-000000000730')
  AND NOT EXISTS (SELECT 1 FROM reinigungen x WHERE x.betrieb_id = b.id)
  AND NOT EXISTS (SELECT 1 FROM rechnungen x WHERE x.betrieb_id = b.id);

-- 4) heineken_nr an den neu angelegten Betrieben dokumentieren
UPDATE betriebe b SET heineken_nr = m.nr
FROM import.betrieb_mapping m
WHERE b.id = m.ziel_id AND b.heineken_nr IS NULL
  AND (b.id::text LIKE 'a1000000%' OR b.id::text LIKE 'a2000000%');

-- 5) Halli Galli: alter Standort traegt 0011, der heutige Betrieb 0616 (Los)
UPDATE betriebe SET heineken_nr = '0616'
WHERE name = 'Halli Galli + Los Bar' AND ort = 'Arosa';

-- Kontrolle: jede Nummer im Mapping muss auf den Betrieb mit gleicher
-- heineken_nr zeigen (Ausnahme 0011, siehe oben - dort ist die Nummer am
-- Nachfolgebetrieb haengengeblieben).
SELECT m.nr, m.bemerkung,
       (SELECT z.name || ' [' || coalesce(z.ort, '?') || ']' FROM betriebe z WHERE z.id = m.ziel_id) AS ziel,
       EXISTS (SELECT 1 FROM betriebe h WHERE h.heineken_nr = m.nr AND h.id = m.ziel_id) AS bestaetigt
FROM import.betrieb_mapping m ORDER BY 4, m.nr;

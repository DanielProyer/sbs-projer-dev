-- ============================================================================
-- heineken_nr normalisieren + eine Doppelvergabe aufloesen (28.07.2026)
-- ============================================================================
-- betriebe.heineken_nr traegt die Excel-Betriebsnummer und ist der Schluessel
-- fuer jede Kontrolle gegen das Buchhaltungs-Excel. Zwei Betriebe hatten sie
-- ohne fuehrende Null gespeichert, dadurch schlug der Abgleich dort fehl.
--
-- Ausserdem trugen zwei verschiedene Betriebe dieselbe Nummer 0723. Das Excel
-- belegt eindeutig: 0723 gehoert zu Panorama [Schlierbach] (dessen Reinigungen
-- tragen 0723), die Schlagerbar Oberkirch laeuft unter 0725.
--
-- Das Skript ist bereits ausgefuehrt und dient der Nachvollziehbarkeit.
-- ============================================================================

-- 1) Fuehrende Nullen ergaenzen (Piz Piz 105 -> 0105, Vereina 511 -> 0511)
UPDATE betriebe SET heineken_nr = lpad(heineken_nr, 4, '0'), updated_at = now()
WHERE heineken_nr IS NOT NULL AND heineken_nr ~ '^[0-9]+$' AND length(heineken_nr) <> 4;

-- 2) Doppelvergabe 0723 aufloesen
UPDATE betriebe SET heineken_nr = '0725', updated_at = now()
WHERE name LIKE 'Silvia Kaufmann%' AND ort = 'Oberkirch';

-- Kontrolle: keine Doppelvergabe, keine unnormierte Nummer, keine Reinigung
-- an einem Betrieb, waehrend ein anderer die Nummer traegt.
WITH rein AS (SELECT r.betrieb_id, split_part(r.extern_id, '_', 4) AS nr
              FROM reinigungen r WHERE r.extern_id IS NOT NULL)
SELECT (SELECT count(*) FROM (SELECT heineken_nr FROM betriebe
          WHERE heineken_nr IS NOT NULL GROUP BY 1 HAVING count(*) > 1) x) AS nummer_doppelt,
       (SELECT count(*) FROM betriebe
          WHERE heineken_nr ~ '^[0-9]+$' AND length(heineken_nr) <> 4) AS unnormiert,
       count(*) FILTER (WHERE EXISTS (SELECT 1 FROM betriebe h
          WHERE h.heineken_nr = rein.nr AND h.id = rein.betrieb_id)) AS bestaetigt,
       count(*) FILTER (WHERE EXISTS (SELECT 1 FROM betriebe h WHERE h.heineken_nr = rein.nr AND h.id <> rein.betrieb_id)
                          AND NOT EXISTS (SELECT 1 FROM betriebe h WHERE h.heineken_nr = rein.nr AND h.id = rein.betrieb_id)) AS falsch
FROM rein;

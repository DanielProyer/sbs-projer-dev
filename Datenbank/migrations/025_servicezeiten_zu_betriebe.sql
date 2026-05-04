-- Migration 025: Servicezeiten von anlagen zu betriebe verschieben
-- Ausführen im Supabase SQL Editor

-- 1. Neue Spalten auf betriebe
ALTER TABLE betriebe ADD COLUMN IF NOT EXISTS servicezeit_morgen_ab TEXT;
ALTER TABLE betriebe ADD COLUMN IF NOT EXISTS servicezeit_morgen_bis TEXT;
ALTER TABLE betriebe ADD COLUMN IF NOT EXISTS servicezeit_nachmittag_ab TEXT;
ALTER TABLE betriebe ADD COLUMN IF NOT EXISTS servicezeit_nachmittag_bis TEXT;

-- 2. Daten migrieren (pro Betrieb die Servicezeiten der ersten Anlage übernehmen)
UPDATE betriebe b SET
  servicezeit_morgen_ab = a.servicezeit_morgen_ab,
  servicezeit_morgen_bis = a.servicezeit_morgen_bis,
  servicezeit_nachmittag_ab = a.servicezeit_nachmittag_ab,
  servicezeit_nachmittag_bis = a.servicezeit_nachmittag_bis
FROM (
  SELECT DISTINCT ON (betrieb_id)
    betrieb_id, servicezeit_morgen_ab, servicezeit_morgen_bis,
    servicezeit_nachmittag_ab, servicezeit_nachmittag_bis
  FROM anlagen
  WHERE servicezeit_morgen_ab IS NOT NULL OR servicezeit_nachmittag_ab IS NOT NULL
  ORDER BY betrieb_id, created_at ASC
) a
WHERE b.id = a.betrieb_id;

-- 3. Alte Spalten von anlagen entfernen
ALTER TABLE anlagen DROP COLUMN IF EXISTS servicezeit_morgen_ab;
ALTER TABLE anlagen DROP COLUMN IF EXISTS servicezeit_morgen_bis;
ALTER TABLE anlagen DROP COLUMN IF EXISTS servicezeit_nachmittag_ab;
ALTER TABLE anlagen DROP COLUMN IF EXISTS servicezeit_nachmittag_bis;

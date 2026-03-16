-- Migration: Mehrere Betriebsferien-Perioden ermöglichen
-- Aktuell: ferien_start / ferien_ende (1 Periode)
-- Neu: ferien2_start / ferien2_ende, ferien3_start / ferien3_ende

ALTER TABLE betriebe ADD COLUMN IF NOT EXISTS ferien2_start DATE;
ALTER TABLE betriebe ADD COLUMN IF NOT EXISTS ferien2_ende DATE;
ALTER TABLE betriebe ADD COLUMN IF NOT EXISTS ferien3_start DATE;
ALTER TABLE betriebe ADD COLUMN IF NOT EXISTS ferien3_ende DATE;

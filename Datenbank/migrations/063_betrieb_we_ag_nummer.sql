-- Migration 063: WE-Nummer und AG-Nummer für Heineken-Raster
ALTER TABLE betriebe ADD COLUMN IF NOT EXISTS we_nummer TEXT;
ALTER TABLE betriebe ADD COLUMN IF NOT EXISTS ag_nummer TEXT;

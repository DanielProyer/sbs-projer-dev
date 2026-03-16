-- Migration 020: keine_betriebsferien Boolean
-- Unterscheidet "keine Ferien" von "noch nicht ausgefüllt"

ALTER TABLE betriebe ADD COLUMN keine_betriebsferien BOOLEAN DEFAULT false;

-- Migration 048: Hahn-Temperaturen bei Reinigungen
-- Datum: 2026-04-20
-- JSONB-Feld für Temperaturmessungen pro Hahn/Bierleitung

ALTER TABLE reinigungen ADD COLUMN IF NOT EXISTS hahn_temperaturen JSONB DEFAULT NULL;

COMMENT ON COLUMN reinigungen.hahn_temperaturen IS
  'Array von Temperaturmessungen pro Hahn: [{bierleitung_id, anlage_id, leitungs_nummer, biersorte, hahn_typ, temperatur}]';

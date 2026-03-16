-- Migration 018: Saison-Felder von Monat (Integer) auf Datum (Date) umstellen
-- Bestehende Monatswerte werden auf den 1. des Monats im Jahr 2026 gesetzt

-- Neue DATE-Spalten hinzufügen
ALTER TABLE betriebe ADD COLUMN winter_start_datum DATE;
ALTER TABLE betriebe ADD COLUMN winter_ende_datum DATE;
ALTER TABLE betriebe ADD COLUMN sommer_start_datum DATE;
ALTER TABLE betriebe ADD COLUMN sommer_ende_datum DATE;

-- Bestehende Monatswerte migrieren (1. des Monats)
UPDATE betriebe SET winter_start_datum = MAKE_DATE(2026, winter_start_monat, 1) WHERE winter_start_monat IS NOT NULL;
UPDATE betriebe SET winter_ende_datum = MAKE_DATE(2026, winter_ende_monat, 1) WHERE winter_ende_monat IS NOT NULL;
UPDATE betriebe SET sommer_start_datum = MAKE_DATE(2026, sommer_start_monat, 1) WHERE sommer_start_monat IS NOT NULL;
UPDATE betriebe SET sommer_ende_datum = MAKE_DATE(2026, sommer_ende_monat, 1) WHERE sommer_ende_monat IS NOT NULL;

-- Alte INTEGER-Spalten entfernen
ALTER TABLE betriebe DROP COLUMN winter_start_monat;
ALTER TABLE betriebe DROP COLUMN winter_ende_monat;
ALTER TABLE betriebe DROP COLUMN sommer_start_monat;
ALTER TABLE betriebe DROP COLUMN sommer_ende_monat;

-- Migration 054: Störungen vereinfachen
-- - stoerungsnummer nullable (wird nicht mehr generiert)
-- - status default 'behoben' (alle Störungen gelten als behoben)
-- - status CHECK anpassen

ALTER TABLE stoerungen ALTER COLUMN stoerungsnummer DROP NOT NULL;
ALTER TABLE stoerungen ALTER COLUMN status SET DEFAULT 'behoben';

-- Bestehende offene Störungen auf behoben setzen
UPDATE stoerungen SET status = 'behoben' WHERE status != 'behoben';

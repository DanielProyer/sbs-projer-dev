-- Bierleitung aktiv/inaktiv Status
ALTER TABLE bierleitungen ADD COLUMN IF NOT EXISTS ist_aktiv BOOLEAN DEFAULT TRUE;

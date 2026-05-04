-- Bierleitung: Gekoppelt-Option hinzufügen
-- Bei gekoppelten Leitungen können zwei Tanks an eine Leitung angeschlossen werden
ALTER TABLE bierleitungen ADD COLUMN IF NOT EXISTS ist_gekoppelt BOOLEAN DEFAULT FALSE;

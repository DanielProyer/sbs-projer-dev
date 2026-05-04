-- Kontakt: Sie/Du Anrede-Option
ALTER TABLE betrieb_kontakte ADD COLUMN IF NOT EXISTS ist_du_anrede BOOLEAN DEFAULT FALSE;

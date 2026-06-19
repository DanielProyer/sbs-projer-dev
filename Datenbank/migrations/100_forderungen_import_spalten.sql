-- 100_forderungen_import_spalten.sql
-- Spalten für den historischen Reinigungen-/Forderungs-Import (reversibel via quelle).
ALTER TABLE reinigungen ADD COLUMN IF NOT EXISTS quelle text;
ALTER TABLE reinigungen ADD COLUMN IF NOT EXISTS extern_id text;
ALTER TABLE rechnungen  ADD COLUMN IF NOT EXISTS quelle text;
ALTER TABLE rechnungen  ADD COLUMN IF NOT EXISTS extern_beleg text;
ALTER TABLE rechnungen  ADD COLUMN IF NOT EXISTS einzahlungsbeleg text;
ALTER TABLE rechnungen  ADD COLUMN IF NOT EXISTS zahlung_beleg_pfad text;
ALTER TABLE betriebe    ADD COLUMN IF NOT EXISTS quelle text;
CREATE INDEX IF NOT EXISTS idx_reinigungen_extern_id ON reinigungen(extern_id);
CREATE INDEX IF NOT EXISTS idx_rechnungen_einzahlungsbeleg ON rechnungen(einzahlungsbeleg);

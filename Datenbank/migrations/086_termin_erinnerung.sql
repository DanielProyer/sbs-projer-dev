-- 086_termin_erinnerung.sql
-- Erinnerungsfunktion für Termine: aktivierbar pro Termin + Vorlaufzeit in Minuten.
ALTER TABLE termine
  ADD COLUMN IF NOT EXISTS erinnerung_aktiv boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS erinnerung_vorlauf_minuten integer NOT NULL DEFAULT 1440;

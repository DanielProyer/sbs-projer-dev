-- HeiGenie-Service über Montagen: Neue Felder für Hahn-basierte Preisberechnung und Protokoll-Scan
-- 2026-04-28

ALTER TABLE montagen ADD COLUMN IF NOT EXISTS anzahl_haehne integer;
ALTER TABLE montagen ADD COLUMN IF NOT EXISTS protokoll_foto_pfad text;
ALTER TABLE montagen ADD COLUMN IF NOT EXISTS ist_bergkunde boolean DEFAULT false;

ALTER TABLE preise ADD COLUMN IF NOT EXISTS heineken_mail_rsl text;

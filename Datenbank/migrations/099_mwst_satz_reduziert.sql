-- 099_mwst_satz_reduziert.sql
-- Reduzierten MWST-Satz datumsabhängig ergänzen.
ALTER TABLE mwst_satz ADD COLUMN IF NOT EXISTS satz_reduziert numeric;
UPDATE mwst_satz SET satz_reduziert = 2.50 WHERE gueltig_ab < '2024-01-01' AND satz_reduziert IS NULL;
UPDATE mwst_satz SET satz_reduziert = 2.60 WHERE gueltig_ab >= '2024-01-01' AND satz_reduziert IS NULL;

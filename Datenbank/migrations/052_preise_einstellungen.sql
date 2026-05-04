-- Migration 052: Preise-Tabelle um Einstellungs-Felder erweitern
-- Neue Spalten: mwst_satz_reduziert, heineken_po_nummer, heineken_mail_rechnung, heineken_mail_raster

ALTER TABLE preise ADD COLUMN IF NOT EXISTS mwst_satz_reduziert DECIMAL(4,2) DEFAULT 2.60;
ALTER TABLE preise ADD COLUMN IF NOT EXISTS heineken_po_nummer TEXT DEFAULT '6100259429';
ALTER TABLE preise ADD COLUMN IF NOT EXISTS heineken_mail_rechnung TEXT;
ALTER TABLE preise ADD COLUMN IF NOT EXISTS heineken_mail_raster TEXT;

-- Bestehende Zeilen mit aktuellen Werten aktualisieren
UPDATE preise SET
  mwst_satz_reduziert = 2.60,
  heineken_po_nummer = '6100259429'
WHERE mwst_satz_reduziert IS NULL OR heineken_po_nummer IS NULL;

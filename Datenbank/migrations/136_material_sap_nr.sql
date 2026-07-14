-- 136: SAP-Nummer für Material-Artikel (Heineken-Umstellung 09.06.2026)
-- Die Heineken-Verknüpfung läuft weiterhin über die alte DBO-Nummer (dbo_nr).
-- sap_nr ist die neue Bestellnummer für die Materialbestellung.

ALTER TABLE material ADD COLUMN IF NOT EXISTS sap_nr text;

CREATE INDEX IF NOT EXISTS idx_material_sap_nr
  ON material (sap_nr) WHERE sap_nr IS NOT NULL;

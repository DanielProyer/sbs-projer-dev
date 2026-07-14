-- 137: SAP-Nummer in Lager (denormalisiert wie dbo_nr) + Bestellpositionen,
-- damit die SAP-Nr in der Materialbestellung + PDF erscheint.
-- Verknüpfung Heineken-Artikel läuft weiterhin über dbo_nr.

ALTER TABLE lager ADD COLUMN IF NOT EXISTS sap_nr text;
ALTER TABLE material_bestellpositionen ADD COLUMN IF NOT EXISTS sap_nr text;

-- Backfill Lager-SAP aus Material (primär via material_id, sonst via dbo_nr).
UPDATE lager l SET sap_nr = m.sap_nr
FROM material m
WHERE m.sap_nr IS NOT NULL
  AND (
    l.material_id = m.id
    OR (l.material_id IS NULL AND l.dbo_nr = m.dbo_nr AND m.user_id = l.user_id)
  );

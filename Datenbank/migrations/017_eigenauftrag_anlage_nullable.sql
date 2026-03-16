-- Migration 017: Eigenauftrag anlage_id nullable machen
-- Eigenaufträge werden direkt über Betrieb zugeordnet (wie Störungen nach Entkopplung)

ALTER TABLE eigenauftraege ALTER COLUMN anlage_id DROP NOT NULL;

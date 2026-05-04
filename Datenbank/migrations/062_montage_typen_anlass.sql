-- Migration 062: Montage-Typen vereinfachen + Anlass-Konzept
-- Neue Typen: neumontage, demontage, abaenderung, heigenie_service, anlass, spesen, aufwandsentschaedigung

-- 1. Bestehende Einträge migrieren
UPDATE montagen SET montage_typ = 'neumontage' WHERE montage_typ IN ('neu_installation', 'montage', 'mehraufwand', 'sonstiges');
UPDATE montagen SET montage_typ = 'demontage' WHERE montage_typ = 'abbau';
UPDATE montagen SET montage_typ = 'abaenderung' WHERE montage_typ IN ('umbau', 'erweiterung');
UPDATE montagen SET montage_typ = 'anlass' WHERE montage_typ = 'anlass_mitarbeit';

-- 2. CHECK Constraint aktualisieren
ALTER TABLE montagen DROP CONSTRAINT IF EXISTS montagen_montage_typ_check;
ALTER TABLE montagen ADD CONSTRAINT montagen_montage_typ_check
  CHECK (montage_typ IN (
    'neumontage', 'demontage', 'abaenderung',
    'heigenie_service', 'anlass', 'spesen', 'aufwandsentschaedigung'
  ));

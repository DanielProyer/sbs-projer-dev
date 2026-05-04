-- Migration 032: OT Dry Cooler zu Durchlaufkühler CHECK Constraint hinzufügen
-- Datum: 2026-03-19
-- Update 2026-03-21: OT Dry Cooler → OT-Dry Cooler, OT-Fest hinzugefügt
-- Update 2026-03-22: OT-Berg hinzugefügt

-- Constraint zuerst droppen, damit UPDATE nicht blockiert wird
ALTER TABLE anlagen DROP CONSTRAINT IF EXISTS anlagen_durchlaufkuehler_check;

-- Bestehende Daten umbenennen
UPDATE anlagen SET durchlaufkuehler = 'OT-Dry Cooler' WHERE durchlaufkuehler = 'OT Dry Cooler';

ALTER TABLE anlagen ADD CONSTRAINT anlagen_durchlaufkuehler_check
  CHECK (durchlaufkuehler IN (
    'H60', 'H75', 'H100', 'H120', 'H150', 'H200',
    'Orion',
    'OT-Lux',
    'OT-Dry Cooler',
    'OT-Berg',
    'OT-Fest',
    'V100',
    'Gamko liegend', 'Gamko stehend', 'Gamko Sat.',
    'Safari',
    'Fremdkühler', 'Fremdkühler Sat.',
    'keiner'
  ));

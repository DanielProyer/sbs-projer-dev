-- Migration 035: CR5 und Coca Cola zu Durchlaufkühler CHECK Constraint hinzufügen
-- Datum: 2026-03-29

ALTER TABLE anlagen DROP CONSTRAINT IF EXISTS anlagen_durchlaufkuehler_check;

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
    'CR5',
    'Coca Cola',
    'keiner'
  ));

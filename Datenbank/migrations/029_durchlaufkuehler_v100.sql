-- Migration 029: V100 zu Durchlaufkühler CHECK Constraint hinzufügen
-- Datum: 2026-03-18

ALTER TABLE anlagen DROP CONSTRAINT IF EXISTS anlagen_durchlaufkuehler_check;

ALTER TABLE anlagen ADD CONSTRAINT anlagen_durchlaufkuehler_check
  CHECK (durchlaufkuehler IN (
    'H60', 'H75', 'H100', 'H120', 'H150', 'H200',
    'Orion',
    'OT-Lux',
    'V100',
    'Gamko liegend', 'Gamko stehend', 'Gamko Sat.',
    'Safari',
    'Fremdkühler', 'Fremdkühler Sat.',
    'keiner'
  ));

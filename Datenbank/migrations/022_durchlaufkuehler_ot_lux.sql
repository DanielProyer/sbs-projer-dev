-- Migration: Durchlaufkühler um OT-Lux, Gamko, Safari ergänzen
ALTER TABLE anlagen DROP CONSTRAINT IF EXISTS anlagen_durchlaufkuehler_check;
ALTER TABLE anlagen ADD CONSTRAINT anlagen_durchlaufkuehler_check
  CHECK (durchlaufkuehler IN (
    'H60', 'H75', 'H100', 'H120', 'H150', 'H200',
    'OT-Lux', 'Gamko liegend', 'Gamko stehend', 'Gamko Sat.',
    'Safari', 'Fremdkühler', 'Fremdkühler Sat.', 'keiner'
  ));

-- Migration: Säulen-Typ Constraint an alle Dropdown-Werte anpassen
ALTER TABLE anlagen DROP CONSTRAINT IF EXISTS anlagen_typ_saeule_check;
ALTER TABLE anlagen ADD CONSTRAINT anlagen_typ_saeule_check
  CHECK (typ_saeule IN (
    'Keine',
    'Europe 1-Way', 'Europe 2-Way', 'Europe 3-Way', 'Europe 4-Way',
    'HeiTube 1-Way', 'Arrow 1-Way', 'Cobra 1-Way',
    'Fountain 1-Way', 'Fountain Extra Cold 1-Way',
    'Falco 2-Way',
    'Keramik 1-Way', 'Keramik 2-Way',
    'Adimat', 'BuyToSell', 'Fremdsäule', 'Spezial'
  ));

-- Migration 031: Aligal1 zu Gas-Typ CHECK Constraints hinzufügen
-- Datum: 2026-03-19

ALTER TABLE anlagen DROP CONSTRAINT IF EXISTS anlagen_gas_typ_1_check;
ALTER TABLE anlagen DROP CONSTRAINT IF EXISTS anlagen_gas_typ_2_check;

ALTER TABLE anlagen ADD CONSTRAINT anlagen_gas_typ_1_check
  CHECK (gas_typ_1 IN ('Aligal1', 'Aligal2', 'Aligal13', 'Kompressor'));

ALTER TABLE anlagen ADD CONSTRAINT anlagen_gas_typ_2_check
  CHECK (gas_typ_2 IN ('Aligal1', 'Aligal2', 'Aligal13', 'Kompressor'));

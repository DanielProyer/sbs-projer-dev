-- Reinigungen: abgerechnet + abrechnungs_monat für Heineken-Monatsrechnung
-- Analog zu stoerungen, eigenauftraege, montagen etc.
ALTER TABLE reinigungen ADD COLUMN IF NOT EXISTS abgerechnet BOOLEAN DEFAULT false;
ALTER TABLE reinigungen ADD COLUMN IF NOT EXISTS abrechnungs_monat DATE;

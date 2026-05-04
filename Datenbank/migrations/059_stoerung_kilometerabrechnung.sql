-- Kilometerabrechnung als Störungs-Typ
-- Heineken verrechnet längere Anfahrten (z.B. Innerschweiz) als Störungen ohne Störungsnummer
ALTER TABLE stoerungen ADD COLUMN IF NOT EXISTS ist_kilometerabrechnung BOOLEAN DEFAULT false;

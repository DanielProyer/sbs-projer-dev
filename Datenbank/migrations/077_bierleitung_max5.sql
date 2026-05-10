-- Migration 077: Bierleitungen maximal 5 statt 4 (für H100/V100 Kühler)
ALTER TABLE bierleitungen
  DROP CONSTRAINT IF EXISTS bierleitungen_leitungs_nummer_check;

ALTER TABLE bierleitungen
  ADD CONSTRAINT bierleitungen_leitungs_nummer_check
  CHECK (leitungs_nummer BETWEEN 1 AND 5);

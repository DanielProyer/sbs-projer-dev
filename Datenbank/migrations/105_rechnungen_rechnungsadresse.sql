-- Migration 105: Pro-Rechnung-Rechnungsadresse (Override/Snapshot).
-- Erlaubt, für EINE bereits gestellte Rechnung eine abweichende Rechnungsadresse
-- zu hinterlegen, ohne die Stamm-Adresse des Betriebs (und damit künftige
-- Rechnungen) zu verändern. NULL = es gilt wie bisher die Betriebs-Rechnungsadresse.
-- Inhalt (JSONB): firma, vorname, nachname, strasse, nr, plz, ort, email.
ALTER TABLE rechnungen ADD COLUMN IF NOT EXISTS rechnungsadresse jsonb;

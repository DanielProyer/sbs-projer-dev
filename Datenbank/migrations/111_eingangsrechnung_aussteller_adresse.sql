-- Migration 111: Strukturierte Lieferanten-(Creditor-)Adresse auf eingangsrechnung.
-- Fuer pain.001.001.09 (ISO-2019) ist Cdtr/PstlAdr strukturiert noetig (min. Ort+Land).
-- Quelle: Swiss-QR-Payload (Cdtr-Adressfelder), beim Upload gespeichert.
ALTER TABLE eingangsrechnung ADD COLUMN IF NOT EXISTS aussteller_strasse text;
ALTER TABLE eingangsrechnung ADD COLUMN IF NOT EXISTS aussteller_hausnr text;
ALTER TABLE eingangsrechnung ADD COLUMN IF NOT EXISTS aussteller_plz text;
ALTER TABLE eingangsrechnung ADD COLUMN IF NOT EXISTS aussteller_ort text;
ALTER TABLE eingangsrechnung ADD COLUMN IF NOT EXISTS aussteller_land text;

-- Migration 108: QR-Code-Abgleich auf eingangsrechnung.
-- qr_gelesen   = true, wenn der Swiss-QR-Code erfolgreich dekodiert wurde
--                (IBAN/Referenz/Betrag dann aus dem QR = exakt, Prüfziffer-gesichert).
-- qr_abweichungen = menschenlesbare Beschreibung der Abweichungen QR vs. Texterkennung
--                (null = keine Abweichung bzw. kein QR gelesen).
ALTER TABLE eingangsrechnung ADD COLUMN IF NOT EXISTS qr_gelesen bool NOT NULL DEFAULT false;
ALTER TABLE eingangsrechnung ADD COLUMN IF NOT EXISTS qr_abweichungen text;

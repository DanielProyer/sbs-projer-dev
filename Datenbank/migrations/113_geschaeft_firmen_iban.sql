-- Migration 113: Firmen-IBAN zentral in geschaeft_einstellungen (Dbtr-Konto fuer
-- das GKB-Zahlungsfile). Bisher nur in rechnung_pdf_service.dart hartcodiert.
ALTER TABLE geschaeft_einstellungen ADD COLUMN IF NOT EXISTS firmen_iban text;
UPDATE geschaeft_einstellungen
   SET firmen_iban = 'CH6600774010376550601'
 WHERE firmen_iban IS NULL;

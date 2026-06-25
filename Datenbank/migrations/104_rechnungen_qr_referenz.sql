-- Migration 104: SCOR-Referenz (ISO 11649) für Kundenrechnungen (TP-C).
-- Wird bei der Rechnungserstellung vergeben, in den QR-Code/Zahlteil eingebettet
-- und beim camt-Abgleich als deterministische Matching-Stufe 1 genutzt.
-- Altbestand bleibt NULL; UNIQUE erlaubt mehrere NULL in Postgres.
ALTER TABLE rechnungen ADD COLUMN IF NOT EXISTS qr_referenz text;
CREATE UNIQUE INDEX IF NOT EXISTS rechnungen_qr_referenz_key
  ON rechnungen (qr_referenz) WHERE qr_referenz IS NOT NULL;

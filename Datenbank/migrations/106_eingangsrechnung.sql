-- Migration 106: Eingangsrechnungen (Scan -> Kreditoren -> camt-Abschluss)
-- Teil von TP-0 (Spec docs/superpowers/specs/2026-06-25-eingangsrechnungen-design.md)
CREATE TABLE IF NOT EXISTS eingangsrechnung (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  aussteller_name text,
  aussteller_uid text,
  lieferant_iban text,
  qr_referenz text,
  referenz_typ text,                  -- 'QRR' | 'SCOR' | 'NON'
  betrag_brutto numeric,
  mwst_satz numeric,
  vorsteuer_konto int,
  mwst_pflichtig bool NOT NULL DEFAULT true,
  rechnungsnummer text,
  rechnungsdatum date,
  faelligkeit date,
  aufwandskonto int,
  geschaeftsfall_id text,
  ist_nur_info bool NOT NULL DEFAULT false,
  dok_typ text,                       -- 'rechnung'|'mahnung'|'akontorechnung'|'schlussrechnung'|'gutschrift'|'info'
  status text NOT NULL DEFAULT 'erkannt',
  gebucht_am timestamptz,
  zahlung_vorgemerkt bool NOT NULL DEFAULT false,
  zahlungsfile_id uuid,
  exportiert_am timestamptz,
  bezahlt_am date,
  buchung_stufe1_id uuid,
  buchung_stufe2_id uuid,
  camt_tx_key text,
  konfidenz numeric,
  beleg_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE eingangsrechnung ENABLE ROW LEVEL SECURITY;

CREATE POLICY eingangsrechnung_user_isolation ON eingangsrechnung
  FOR ALL USING (user_id = auth.uid());

CREATE INDEX IF NOT EXISTS eingangsrechnung_status_idx
  ON eingangsrechnung (user_id, status);
CREATE INDEX IF NOT EXISTS eingangsrechnung_camtkey_idx
  ON eingangsrechnung (camt_tx_key) WHERE camt_tx_key IS NOT NULL;

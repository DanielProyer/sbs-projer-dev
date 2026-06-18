-- 096_geschaeft_einstellungen.sql
-- Firmen-Stammdaten (eine Zeile pro User). Speist Lohn, Report-Mail, PDF-Firmendaten.
CREATE TABLE IF NOT EXISTS geschaeft_einstellungen (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE,
  firma_name text,
  strasse text,
  plz_ort text,
  gf_vorname text,
  gf_name text,
  telefon text,
  mail_geschaeft text,
  mail_privat text,
  mwst_nummer text,
  uid_nummer text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE geschaeft_einstellungen ENABLE ROW LEVEL SECURITY;

CREATE POLICY geschaeft_einstellungen_user ON geschaeft_einstellungen
  FOR ALL USING (auth.uid() = user_id);

-- Default-Zeile = heutige fix codierte Werte (Verhalten bleibt identisch)
INSERT INTO geschaeft_einstellungen
  (user_id, firma_name, strasse, plz_ort, gf_vorname, gf_name, telefon,
   mail_geschaeft, mail_privat, mwst_nummer, uid_nummer)
VALUES
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 'SBS Projer GmbH', 'Via Rezia 8',
   '7013 Domat/Ems', 'Daniel', 'Projer', '076 566 58 06',
   'sbs.projer@gmail.com', 'dani.proyer@gmail.com', '', '')
ON CONFLICT (user_id) DO NOTHING;

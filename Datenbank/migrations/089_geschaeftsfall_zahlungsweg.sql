-- 089_geschaeftsfall_zahlungsweg.sql
-- Phase 0a: Geschäftsfall + Zahlungsweg, datumsabhängige MWST, Kontenrahmen-Ergänzung

-- 1) buchungs_vorlagen → Geschäftsfall-Felder
ALTER TABLE buchungs_vorlagen
  ADD COLUMN IF NOT EXISTS art TEXT NOT NULL DEFAULT 'fix'
    CHECK (art IN ('ausgabe', 'einnahme', 'fix')),
  ADD COLUMN IF NOT EXISTS hauptkonto INTEGER,
  ADD COLUMN IF NOT EXISTS mwst_pflichtig BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS erlaubte_zahlungswege TEXT[] NOT NULL DEFAULT '{}';

-- soll/haben künftig nur für art='fix' nötig → nullable machen
ALTER TABLE buchungs_vorlagen ALTER COLUMN soll_konto DROP NOT NULL;
ALTER TABLE buchungs_vorlagen ALTER COLUMN haben_konto DROP NOT NULL;

-- alte UNIQUE(user_id, geschaeftsfall_id, zahlungsweg) entfernen (Variante wandert in erlaubte_zahlungswege)
ALTER TABLE buchungs_vorlagen DROP CONSTRAINT IF EXISTS buchungs_vorlagen_user_id_geschaeftsfall_id_zahlungsweg_key;
CREATE UNIQUE INDEX IF NOT EXISTS buchungs_vorlagen_user_gf_uidx
  ON buchungs_vorlagen (user_id, geschaeftsfall_id);

-- buchungen: zahlungsweg um 'kreditor' und 'debitor' erweitern
-- WICHTIG: bestehende Werte 'rechnung'/'intern' bleiben erlaubt (518 Bestandsbuchungen nutzen 'rechnung')
ALTER TABLE buchungen DROP CONSTRAINT IF EXISTS buchungen_zahlungsweg_check;
ALTER TABLE buchungen ADD CONSTRAINT buchungen_zahlungsweg_check
  CHECK (zahlungsweg IS NULL OR zahlungsweg IN ('kasse','bank','privat','rechnung','intern','kreditor','debitor'));

-- 2) MWST-Satz-Tabelle (datumsabhängig)
CREATE TABLE IF NOT EXISTS mwst_satz (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  gueltig_ab DATE NOT NULL,
  satz DECIMAL(4,2) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id, gueltig_ab)
);
ALTER TABLE mwst_satz ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS mwst_satz_own ON mwst_satz;
CREATE POLICY mwst_satz_own ON mwst_satz
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- 3) Fehlende Konten ergänzen (Delkredere + Debitorenverluste)
--    (idempotent: nur einfügen, wenn Kontonummer für den User fehlt)
INSERT INTO konten (id, user_id, kontonummer, bezeichnung, kategorie)
SELECT gen_random_uuid(), u.user_id, v.kontonummer, v.bezeichnung, v.kategorie
FROM (SELECT DISTINCT user_id FROM konten) u
CROSS JOIN (VALUES
  (1109, 'Delkredere (Wertberichtigung Forderungen)', 'Umlaufvermögen'),
  (3805, 'Debitorenverluste',                          'Betriebsertrag')
) AS v(kontonummer, bezeichnung, kategorie)
WHERE NOT EXISTS (
  SELECT 1 FROM konten k WHERE k.user_id = u.user_id AND k.kontonummer = v.kontonummer
);

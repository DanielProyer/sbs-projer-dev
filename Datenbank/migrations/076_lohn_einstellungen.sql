-- Lohn-Einstellungen (pro User, pro Jahr)
CREATE TABLE IF NOT EXISTS lohn_einstellungen (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  jahr INT NOT NULL,
  bruttolohn_monatlich NUMERIC(10,2) NOT NULL DEFAULT 0,
  geburtsjahr INT NOT NULL DEFAULT 1990,
  -- AHV/IV/EO
  ahv_iv_eo_an_satz NUMERIC(5,2) NOT NULL DEFAULT 5.30,
  ahv_iv_eo_ag_satz NUMERIC(5,2) NOT NULL DEFAULT 5.30,
  -- ALV
  alv_an_satz NUMERIC(5,2) NOT NULL DEFAULT 1.10,
  alv_ag_satz NUMERIC(5,2) NOT NULL DEFAULT 1.10,
  -- NBU (100% AN)
  nbu_an_satz NUMERIC(5,2) NOT NULL DEFAULT 1.40,
  -- BU (100% AG)
  bu_ag_satz NUMERIC(5,2) NOT NULL DEFAULT 0.70,
  -- BVG (Fixbeträge pro Monat, von Pensionskasse)
  bvg_an_betrag NUMERIC(10,2) NOT NULL DEFAULT 0,
  bvg_ag_betrag NUMERIC(10,2) NOT NULL DEFAULT 0,
  -- FAK (100% AG, Kanton LU)
  fak_ag_satz NUMERIC(5,2) NOT NULL DEFAULT 1.35,
  -- KTG (optional)
  ktg_an_satz NUMERIC(5,2) NOT NULL DEFAULT 0,
  ktg_ag_satz NUMERIC(5,2) NOT NULL DEFAULT 0,
  -- Lohnausweis-Daten
  arbeitnehmer_name TEXT,
  arbeitnehmer_vorname TEXT,
  arbeitnehmer_adresse TEXT,
  arbeitnehmer_plz_ort TEXT,
  arbeitnehmer_ahv_nr TEXT,
  arbeitnehmer_geburtsdatum DATE,
  arbeitgeber_name TEXT DEFAULT 'SBS Projer GmbH',
  arbeitgeber_adresse TEXT,
  arbeitgeber_plz_ort TEXT,
  -- Meta
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, jahr)
);

-- Lohn-Abrechnungen (mehrere pro Monat möglich)
CREATE TABLE IF NOT EXISTS lohn_abrechnungen (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  jahr INT NOT NULL,
  monat INT NOT NULL CHECK (monat BETWEEN 1 AND 12),
  datum DATE NOT NULL,
  bruttolohn NUMERIC(10,2) NOT NULL,
  -- AN-Abzüge
  ahv_iv_eo_an NUMERIC(10,2) NOT NULL DEFAULT 0,
  alv_an NUMERIC(10,2) NOT NULL DEFAULT 0,
  nbu_an NUMERIC(10,2) NOT NULL DEFAULT 0,
  bvg_an NUMERIC(10,2) NOT NULL DEFAULT 0,
  ktg_an NUMERIC(10,2) NOT NULL DEFAULT 0,
  nettolohn NUMERIC(10,2) NOT NULL DEFAULT 0,
  -- AG-Beiträge
  ahv_iv_eo_ag NUMERIC(10,2) NOT NULL DEFAULT 0,
  alv_ag NUMERIC(10,2) NOT NULL DEFAULT 0,
  bu_ag NUMERIC(10,2) NOT NULL DEFAULT 0,
  fak_ag NUMERIC(10,2) NOT NULL DEFAULT 0,
  bvg_ag NUMERIC(10,2) NOT NULL DEFAULT 0,
  ktg_ag NUMERIC(10,2) NOT NULL DEFAULT 0,
  -- Status
  ist_gebucht BOOLEAN NOT NULL DEFAULT FALSE,
  ist_ausbezahlt BOOLEAN NOT NULL DEFAULT FALSE,
  -- Meta
  created_at TIMESTAMPTZ DEFAULT now()
);

-- RLS
ALTER TABLE lohn_einstellungen ENABLE ROW LEVEL SECURITY;
ALTER TABLE lohn_abrechnungen ENABLE ROW LEVEL SECURITY;

CREATE POLICY "lohn_einstellungen_user" ON lohn_einstellungen
  FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "lohn_abrechnungen_user" ON lohn_abrechnungen
  FOR ALL USING (auth.uid() = user_id);

-- Fehlende Konten für Lohnbuchhaltung (kontenklasse ist GENERATED)
INSERT INTO konten (kontonummer, bezeichnung, kategorie, user_id)
SELECT 5710, 'FAK / Familienausgleichskasse', 'aufwand', user_id
FROM konten WHERE kontonummer = 5000
ON CONFLICT DO NOTHING;

INSERT INTO konten (kontonummer, bezeichnung, kategorie, user_id)
SELECT 5720, 'BVG / Pensionskasse AG', 'aufwand', user_id
FROM konten WHERE kontonummer = 5000
ON CONFLICT DO NOTHING;

INSERT INTO konten (kontonummer, bezeichnung, kategorie, user_id)
SELECT 5730, 'UVG / Unfallversicherung AG', 'aufwand', user_id
FROM konten WHERE kontonummer = 5000
ON CONFLICT DO NOTHING;

INSERT INTO konten (kontonummer, bezeichnung, kategorie, user_id)
SELECT 5740, 'KTG / Krankentaggeld AG', 'aufwand', user_id
FROM konten WHERE kontonummer = 5000
ON CONFLICT DO NOTHING;

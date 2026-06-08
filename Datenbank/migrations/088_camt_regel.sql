-- camt-Auto-Buchung Phase 2: Ausgaben-Regelwerk
-- Tabelle camt_regel (Empfänger-Muster → Buchungsvorlage) + 4 neue Vorlagen + Startregeln.

CREATE TABLE IF NOT EXISTS camt_regel (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  bezeichnung TEXT NOT NULL,
  match_name TEXT,         -- Substring (case-insensitive) in Name + Zusatzinfo
  match_iban TEXT,         -- exakte Gegenpartei-IBAN
  buchungs_vorlage_id UUID NOT NULL REFERENCES buchungs_vorlagen(id),
  prioritaet INT NOT NULL DEFAULT 0,
  ist_aktiv BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE camt_regel ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own rows" ON camt_regel
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 4 neue Buchungsvorlagen (direkte Aufwandsbuchung gegen Bank, keine MwSt)
INSERT INTO buchungs_vorlagen (user_id, geschaeftsfall_id, bezeichnung, soll_konto, haben_konto, ist_aktiv)
VALUES
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2','30.1','Sozialversicherung AHV (Ausgleichskasse)',5700,1020,true),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2','30.2','BVG / Pensionskasse',5720,1020,true),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2','30.3','Unfallversicherung Suva',5730,1020,true),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2','30.4','Direkte Steuern Kanton',8900,1020,true)
ON CONFLICT DO NOTHING;

-- Startregeln (match_name lowercase; Vorlage via bezeichnung + user_id)
INSERT INTO camt_regel (user_id, bezeichnung, match_name, buchungs_vorlage_id, prioritaet)
SELECT '1e1ec2dd-7836-4d8e-8256-c5649d994ee2', r.bez, r.mn, v.id, r.prio
FROM (VALUES
  ('Heineken Franchise','heineken','Franchisegebühr Heineken Zahlung',10),
  ('GF-Lohn Daniel','daniel proyer','Nettolohn auszahlen',10),
  ('MwSt ESTV','eidgenössische steuerverwaltung','MWST-Zahlung an Bund',10),
  ('Swisscom','swisscom','Internetabo Dauerauftrag',10),
  ('Sunrise','sunrise','Internetabo Dauerauftrag',10),
  ('AXA Sachversicherung','axa versicherungen','Haftpflichtversicherung',10),
  ('AXA BVG','axa stiftung','BVG / Pensionskasse',20),
  ('Ausgleichskasse AHV','ausgleichskasse','Sozialversicherung AHV (Ausgleichskasse)',10),
  ('Suva','suva','Unfallversicherung Suva',10),
  ('Steuerverwaltung GR','steuerverwaltung kanton','Direkte Steuern Kanton',10),
  ('Bargeld-Automat','geldautomaten','Zahlungseingang bar',10),
  ('Posteinzahlung','posteinzahlung','Zahlungseingang bar',10),
  ('Bank-Abschluss','abschluss','Bankgebühren',10)
) AS r(bez, mn, vbez, prio)
JOIN buchungs_vorlagen v
  ON v.bezeichnung = r.vbez
 AND v.user_id = '1e1ec2dd-7836-4d8e-8256-c5649d994ee2';

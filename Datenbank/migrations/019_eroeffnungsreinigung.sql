-- Migration 019: Eröffnung/Endreinigung Tabelle
CREATE TABLE eroeffnungsreinigungen (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  betrieb_id UUID REFERENCES betriebe(id),
  stoerungsnummer TEXT NOT NULL,
  datum DATE NOT NULL DEFAULT CURRENT_DATE,
  ist_bergkunde BOOLEAN DEFAULT FALSE,
  preis DECIMAL(10,2),
  abrechnungs_monat DATE,
  abgerechnet BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE eroeffnungsreinigungen ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own eroeffnungsreinigungen"
  ON eroeffnungsreinigungen FOR ALL
  USING (auth.uid() = user_id);

-- Eröffnungsreinigung: Art (Eröffnung oder Endreinigung)
ALTER TABLE eroeffnungsreinigungen
  ADD COLUMN IF NOT EXISTS art text NOT NULL DEFAULT 'eroeffnung'
  CHECK (art IN ('eroeffnung', 'endreinigung'));

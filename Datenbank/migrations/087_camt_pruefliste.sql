-- camt-Auto-Buchung Phase 1: Dedup-Schlüssel + Prüfliste
-- Rein additiv: neue Spalte auf buchungen + neue Tabelle camt_pruefliste.

ALTER TABLE buchungen ADD COLUMN IF NOT EXISTS camt_tx_key TEXT;
CREATE INDEX IF NOT EXISTS idx_buchungen_camt_tx_key ON buchungen(camt_tx_key);

CREATE TABLE IF NOT EXISTS camt_pruefliste (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  tx_key TEXT NOT NULL,
  booking_datum DATE NOT NULL,
  betrag NUMERIC(12,2) NOT NULL,
  ist_gutschrift BOOLEAN NOT NULL,
  partei_name TEXT,
  referenz TEXT,
  kategorie TEXT NOT NULL,
  vorschlag_json JSONB,
  status TEXT NOT NULL DEFAULT 'offen'
    CHECK (status IN ('offen','erledigt','ignoriert')),
  fehlertext TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id, tx_key)
);

ALTER TABLE camt_pruefliste ENABLE ROW LEVEL SECURITY;

CREATE POLICY "own rows" ON camt_pruefliste
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

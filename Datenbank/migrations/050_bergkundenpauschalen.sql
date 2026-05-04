-- Neue Tabelle für Bergkundenpauschalen (bisher in Reinigung eingebettet)
CREATE TABLE IF NOT EXISTS bergkundenpauschalen (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  betrieb_id UUID NOT NULL REFERENCES betriebe(id),
  reinigung_id UUID REFERENCES reinigungen(id),
  datum DATE NOT NULL,
  betrag DECIMAL(10,2) NOT NULL DEFAULT 180.00,
  notizen TEXT,
  abgerechnet BOOLEAN NOT NULL DEFAULT false,
  abrechnungs_monat DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX idx_bergkundenpauschalen_user ON bergkundenpauschalen(user_id);
CREATE INDEX idx_bergkundenpauschalen_betrieb ON bergkundenpauschalen(betrieb_id);
CREATE INDEX idx_bergkundenpauschalen_datum ON bergkundenpauschalen(datum);
CREATE INDEX idx_bergkundenpauschalen_reinigung ON bergkundenpauschalen(reinigung_id);

-- RLS
ALTER TABLE bergkundenpauschalen ENABLE ROW LEVEL SECURITY;
CREATE POLICY bergkundenpauschalen_user_policy ON bergkundenpauschalen
  FOR ALL USING (auth.uid() = user_id);

-- Trigger für updated_at
CREATE TRIGGER set_updated_at_bergkundenpauschalen
  BEFORE UPDATE ON bergkundenpauschalen
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

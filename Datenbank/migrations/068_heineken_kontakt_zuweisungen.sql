-- Migration 068: Heineken Kontakt-Zuweisungen
-- Zuordnung welcher Heineken-Kontakt für welche Geschäftsfunktion zuständig ist

CREATE TABLE heineken_kontakt_zuweisungen (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  funktion TEXT NOT NULL,
  kontakt_id UUID NOT NULL REFERENCES kontakte(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT heineken_zuweisung_funktion_check
    CHECK (funktion IN ('monatsrechnung', 'raster', 'heigenie_service', 'materialbestellung')),
  UNIQUE(user_id, funktion)
);

CREATE INDEX idx_heineken_zuweisungen_user ON heineken_kontakt_zuweisungen(user_id);

ALTER TABLE heineken_kontakt_zuweisungen ENABLE ROW LEVEL SECURITY;

CREATE POLICY heineken_zuweisungen_user_policy ON heineken_kontakt_zuweisungen
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE TRIGGER update_heineken_zuweisungen_updated_at BEFORE UPDATE ON heineken_kontakt_zuweisungen
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

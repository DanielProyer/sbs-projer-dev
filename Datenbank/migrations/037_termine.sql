-- 037: Termine-Kalender für Saisonplanung und Erinnerungen
-- Termine werden aus Betrieb-Saison/Ferien-Daten vorgeschlagen und manuell erstellt

CREATE TABLE termine (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  betrieb_id UUID NOT NULL REFERENCES betriebe(id) ON DELETE CASCADE,
  datum DATE NOT NULL,
  uhrzeit_von TIME,
  uhrzeit_bis TIME,
  typ TEXT NOT NULL DEFAULT 'sonstiges'
    CHECK (typ IN ('eroeffnungsreinigung', 'endreinigung', 'sonstiges')),
  anlass TEXT NOT NULL DEFAULT 'manuell'
    CHECK (anlass IN ('saisonstart', 'saisonende', 'ferien', 'zwischensaison', 'manuell')),
  titel TEXT NOT NULL,
  notizen TEXT,
  status TEXT NOT NULL DEFAULT 'geplant'
    CHECK (status IN ('vorgeschlagen', 'geplant', 'erledigt', 'abgesagt')),
  erinnerung_tage INTEGER DEFAULT 3,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_termine_user ON termine(user_id);
CREATE INDEX idx_termine_betrieb ON termine(betrieb_id);
CREATE INDEX idx_termine_datum ON termine(datum);
CREATE INDEX idx_termine_status ON termine(status);

ALTER TABLE termine ENABLE ROW LEVEL SECURITY;
CREATE POLICY termine_user_isolation ON termine
  FOR ALL USING (user_id = auth.uid());

CREATE TRIGGER set_termine_updated_at
  BEFORE UPDATE ON termine
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

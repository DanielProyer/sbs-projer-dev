-- Migration 066: Heineken Kontakte als eigene Tabelle
-- Ersetzt die flachen heineken_mail_* Felder in preise

CREATE TABLE heineken_kontakte (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  vorname TEXT NOT NULL,
  nachname TEXT,
  telefon TEXT,
  email TEXT,
  anrede TEXT NOT NULL DEFAULT 'sie' CHECK (anrede IN ('du', 'sie')),
  rolle TEXT NOT NULL CHECK (rolle IN ('rsl', 'buero')),
  notizen TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Index für schnellen Zugriff nach User + Rolle
CREATE INDEX idx_heineken_kontakte_user_rolle ON heineken_kontakte(user_id, rolle);

-- RLS aktivieren
ALTER TABLE heineken_kontakte ENABLE ROW LEVEL SECURITY;

-- RLS Policy: User sieht nur eigene Kontakte
CREATE POLICY heineken_kontakte_user_policy ON heineken_kontakte
  FOR ALL USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- updated_at Trigger
CREATE TRIGGER update_heineken_kontakte_updated_at
  BEFORE UPDATE ON heineken_kontakte
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

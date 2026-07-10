-- ============================================================
-- Migration 123: Events E4 — Zeit-/Spesenerfassung (event_aufwand)
-- Projekt: SBS Projer App
-- Stand: 10.07.2026
-- ============================================================

CREATE TABLE event_aufwand (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  datum date NOT NULL,
  kategorie text NOT NULL CHECK (kategorie IN ('anfahrt','inbetriebnahme','pikett','spesen')),
  notiz text,
  stunden numeric NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
ALTER TABLE event_aufwand ENABLE ROW LEVEL SECURITY;
CREATE POLICY event_aufwand_user_policy ON event_aufwand
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE TRIGGER update_event_aufwand_updated_at BEFORE UPDATE ON event_aufwand
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE INDEX idx_event_aufwand_event ON event_aufwand(user_id, event_id);

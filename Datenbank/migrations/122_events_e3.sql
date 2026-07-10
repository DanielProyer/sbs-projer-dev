-- ============================================================
-- Migration 122: Events E3 — GPS, Inbetriebnahme, Einsaetze
-- Projekt: SBS Projer App
-- Stand: 10.07.2026
-- ============================================================

-- Stand-GPS
ALTER TABLE event_staende
  ADD COLUMN IF NOT EXISTS latitude double precision,
  ADD COLUMN IF NOT EXISTS longitude double precision;

-- Inbetriebnahme pro Anlage
ALTER TABLE event_stand_anlagen
  ADD COLUMN IF NOT EXISTS in_betrieb boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS in_betrieb_am timestamptz;

-- Pikett-Einsaetze
CREATE TABLE event_einsaetze (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  stand_id uuid REFERENCES event_staende(id) ON DELETE SET NULL,
  zeitpunkt timestamptz NOT NULL DEFAULT now(),
  beschreibung text NOT NULL,
  material text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
ALTER TABLE event_einsaetze ENABLE ROW LEVEL SECURITY;
CREATE POLICY event_einsaetze_user_policy ON event_einsaetze
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE TRIGGER update_event_einsaetze_updated_at BEFORE UPDATE ON event_einsaetze
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE INDEX idx_event_einsaetze_event ON event_einsaetze(user_id, event_id);

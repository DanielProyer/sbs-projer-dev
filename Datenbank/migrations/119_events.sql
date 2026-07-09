-- ============================================================
-- Migration 119: Events-Modul E1 — events + event_kontakte
-- Projekt: SBS Projer App
-- Stand: 09.07.2026
-- ============================================================

CREATE TABLE events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  betrieb_id uuid NOT NULL REFERENCES betriebe(id) ON DELETE CASCADE,
  jahr int NOT NULL,
  termin_von date,
  termin_bis date,
  notizen text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE (user_id, betrieb_id, jahr)
);

ALTER TABLE events ENABLE ROW LEVEL SECURITY;
CREATE POLICY events_user_policy ON events
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE TRIGGER update_events_updated_at BEFORE UPDATE ON events
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE INDEX idx_events_user_jahr ON events(user_id, jahr);

CREATE TABLE event_kontakte (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  kontakt_id uuid NOT NULL REFERENCES kontakte(id) ON DELETE CASCADE,
  rolle text NOT NULL CHECK (rolle IN (
    'ok', 'bau', 'stand', 'event_heineken', 'rsl', 'monteur', 'stardrinks', 'sonstige'
  )),
  bemerkung text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE (event_id, kontakt_id, rolle)
);

ALTER TABLE event_kontakte ENABLE ROW LEVEL SECURITY;
CREATE POLICY event_kontakte_user_policy ON event_kontakte
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE TRIGGER update_event_kontakte_updated_at BEFORE UPDATE ON event_kontakte
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE INDEX idx_event_kontakte_event ON event_kontakte(user_id, event_id);

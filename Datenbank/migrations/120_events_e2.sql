-- ============================================================
-- Migration 120: Events E2 — Dokumente, Staende, Stand-Anlagen
-- Projekt: SBS Projer App
-- Stand: 10.07.2026
-- ============================================================

-- ── event_dokumente ──
CREATE TABLE event_dokumente (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  bezeichnung text NOT NULL,
  datei_pfad text NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
ALTER TABLE event_dokumente ENABLE ROW LEVEL SECURITY;
CREATE POLICY event_dokumente_user_policy ON event_dokumente
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE TRIGGER update_event_dokumente_updated_at BEFORE UPDATE ON event_dokumente
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE INDEX idx_event_dokumente_event ON event_dokumente(user_id, event_id);

-- ── event_staende ──
CREATE TABLE event_staende (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  name text NOT NULL,
  standnummer text,
  sortierung int NOT NULL DEFAULT 0,
  notizen text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
ALTER TABLE event_staende ENABLE ROW LEVEL SECURITY;
CREATE POLICY event_staende_user_policy ON event_staende
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE TRIGGER update_event_staende_updated_at BEFORE UPDATE ON event_staende
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE INDEX idx_event_staende_event ON event_staende(user_id, event_id);

-- ── event_stand_anlagen ──
CREATE TABLE event_stand_anlagen (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  stand_id uuid NOT NULL REFERENCES event_staende(id) ON DELETE CASCADE,
  typ text NOT NULL CHECK (typ IN (
    'oberthekengeraet', 'hollandbuffet', 'ausschankwagen', 'sonstige'
  )),
  bezeichnung text,
  anzahl int NOT NULL DEFAULT 1,
  sortierung int NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
ALTER TABLE event_stand_anlagen ENABLE ROW LEVEL SECURITY;
CREATE POLICY event_stand_anlagen_user_policy ON event_stand_anlagen
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE TRIGGER update_event_stand_anlagen_updated_at BEFORE UPDATE ON event_stand_anlagen
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE INDEX idx_event_stand_anlagen_stand ON event_stand_anlagen(user_id, stand_id);

-- ── Storage-Bucket event-dokumente (privat, 20MB, nur PDF) ──
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('event-dokumente', 'event-dokumente', false, 20971520, ARRAY['application/pdf'])
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Users upload own event docs" ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'event-dokumente' AND (storage.foldername(name))[1] = auth.uid()::text);
CREATE POLICY "Users read own event docs" ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'event-dokumente' AND (storage.foldername(name))[1] = auth.uid()::text);
CREATE POLICY "Users update own event docs" ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'event-dokumente' AND (storage.foldername(name))[1] = auth.uid()::text);
CREATE POLICY "Users delete own event docs" ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'event-dokumente' AND (storage.foldername(name))[1] = auth.uid()::text);

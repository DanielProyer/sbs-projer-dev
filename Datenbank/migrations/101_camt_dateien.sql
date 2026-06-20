-- 101_camt_dateien.sql — Archiv hochgeladener camt-Dateien + erfasste Zeiträume
CREATE TABLE IF NOT EXISTS camt_dateien (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  dateiname text NOT NULL,
  hochgeladen_am timestamptz NOT NULL DEFAULT now(),
  zeitraum_von date,
  zeitraum_bis date,
  iban text,
  anzahl_eintraege int DEFAULT 0,
  anzahl_gutschriften int DEFAULT 0,
  storage_pfad text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE camt_dateien ENABLE ROW LEVEL SECURITY;
CREATE POLICY camt_dateien_owner ON camt_dateien
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE INDEX IF NOT EXISTS idx_camt_dateien_zeitraum ON camt_dateien(user_id, zeitraum_von);

-- Storage-Bucket (privat) fuer die archivierten XML-Dateien
INSERT INTO storage.buckets (id, name, public)
VALUES ('camt-dateien', 'camt-dateien', false)
ON CONFLICT (id) DO NOTHING;

-- RLS auf storage.objects: jeder User sieht/verwaltet nur seinen eigenen Ordner (<uid>/...)
CREATE POLICY camt_dateien_storage_select ON storage.objects
  FOR SELECT USING (bucket_id = 'camt-dateien' AND (storage.foldername(name))[1] = (auth.uid())::text);
CREATE POLICY camt_dateien_storage_insert ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'camt-dateien' AND (storage.foldername(name))[1] = (auth.uid())::text);
CREATE POLICY camt_dateien_storage_update ON storage.objects
  FOR UPDATE USING (bucket_id = 'camt-dateien' AND (storage.foldername(name))[1] = (auth.uid())::text);
CREATE POLICY camt_dateien_storage_delete ON storage.objects
  FOR DELETE USING (bucket_id = 'camt-dateien' AND (storage.foldername(name))[1] = (auth.uid())::text);

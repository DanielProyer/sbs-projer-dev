-- Migration 080: Material-Manuals (PDF-Upload für Artikel)
-- Ausgeführt am: 16.05.2026

ALTER TABLE lager ADD COLUMN IF NOT EXISTS manual_storage_path TEXT;

-- Storage Bucket
INSERT INTO storage.buckets (id, name, public) VALUES ('material-manuals', 'material-manuals', false) ON CONFLICT (id) DO NOTHING;

-- RLS Policies
CREATE POLICY "Users can upload manuals" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'material-manuals' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "Users can read own manuals" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'material-manuals' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "Users can update own manuals" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'material-manuals' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "Users can delete own manuals" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'material-manuals' AND (storage.foldername(name))[1] = auth.uid()::text);

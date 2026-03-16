-- Migration 012: Storage Bucket für Material-/Artikelfotos
-- Pfad-Pattern: {user_id}/{material_id}.jpg

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('material-fotos', 'material-fotos', false, 5242880, ARRAY['image/jpeg', 'image/png'])
ON CONFLICT (id) DO NOTHING;

-- RLS: User kann eigene Fotos hochladen
CREATE POLICY "Users upload own material fotos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'material-fotos'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- RLS: User kann eigene Fotos lesen
CREATE POLICY "Users read own material fotos"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'material-fotos'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- RLS: User kann eigene Fotos überschreiben
CREATE POLICY "Users update own material fotos"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'material-fotos'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- RLS: User kann eigene Fotos löschen
CREATE POLICY "Users delete own material fotos"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'material-fotos'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

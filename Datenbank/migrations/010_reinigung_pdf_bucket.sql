-- Migration 010: Storage Bucket für Reinigungsprotokolle (PDFs)
-- Alternativ: Im Supabase Dashboard unter Storage → New Bucket erstellen
-- Name: reinigung-pdfs, Private, 10MB Limit, nur application/pdf

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('reinigung-pdfs', 'reinigung-pdfs', false, 10485760, ARRAY['application/pdf'])
ON CONFLICT (id) DO NOTHING;

-- RLS: User kann eigene PDFs hochladen
CREATE POLICY "Users upload own reinigung PDFs"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'reinigung-pdfs'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- RLS: User kann eigene PDFs lesen
CREATE POLICY "Users read own reinigung PDFs"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'reinigung-pdfs'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- RLS: User kann eigene PDFs überschreiben
CREATE POLICY "Users update own reinigung PDFs"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'reinigung-pdfs'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- RLS: User kann eigene PDFs löschen
CREATE POLICY "Users delete own reinigung PDFs"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'reinigung-pdfs'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

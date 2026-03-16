-- Migration 011: Storage Bucket für Kundenrechnungen (PDFs)
-- Alternativ: Im Supabase Dashboard unter Storage → New Bucket erstellen
-- Name: rechnung-pdfs, Private, 10MB Limit, nur application/pdf

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('rechnung-pdfs', 'rechnung-pdfs', false, 10485760, ARRAY['application/pdf'])
ON CONFLICT (id) DO NOTHING;

-- RLS: User kann eigene Rechnungs-PDFs hochladen
CREATE POLICY "Users upload own rechnung PDFs"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'rechnung-pdfs'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- RLS: User kann eigene Rechnungs-PDFs lesen
CREATE POLICY "Users read own rechnung PDFs"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'rechnung-pdfs'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- RLS: User kann eigene Rechnungs-PDFs überschreiben
CREATE POLICY "Users update own rechnung PDFs"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'rechnung-pdfs'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- RLS: User kann eigene Rechnungs-PDFs löschen
CREATE POLICY "Users delete own rechnung PDFs"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'rechnung-pdfs'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

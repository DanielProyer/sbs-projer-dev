-- 101b: Storage-Policies für den Bucket camt-dateien (Server 20.06.2026,
-- Name auf dem Server: camt_dateien_storage_policies).
-- Rekonstruiert am 26.09.2026 aus supabase_migrations.schema_migrations —
-- die Migration wurde damals direkt angewendet, ohne lokale Datei.
-- Jeder Nutzer sieht/schreibt nur Objekte in seinem eigenen Ordner (auth.uid()).

CREATE POLICY camt_dateien_storage_select ON storage.objects
  FOR SELECT USING (bucket_id = 'camt-dateien' AND (storage.foldername(name))[1] = (auth.uid())::text);
CREATE POLICY camt_dateien_storage_insert ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'camt-dateien' AND (storage.foldername(name))[1] = (auth.uid())::text);
CREATE POLICY camt_dateien_storage_update ON storage.objects
  FOR UPDATE USING (bucket_id = 'camt-dateien' AND (storage.foldername(name))[1] = (auth.uid())::text);
CREATE POLICY camt_dateien_storage_delete ON storage.objects
  FOR DELETE USING (bucket_id = 'camt-dateien' AND (storage.foldername(name))[1] = (auth.uid())::text);

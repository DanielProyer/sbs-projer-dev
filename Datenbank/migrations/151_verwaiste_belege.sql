-- Migration 151: Verwaiste Beleg-Dateien im Storage finden
--
-- Hintergrund (28.07.2026): Nach dem Spesen-Scanner-Testlauf blieben 66 Dateien
-- im Bucket 'buchungs-belege' liegen, deren Buchung geloescht wurde. Insgesamt
-- lagen 217 solcher Waisen (77.7 MB) seit Ende Maerz im Bucket.
--
-- Die App kann storage.objects nicht direkt abfragen (kein Client-Zugriff auf
-- das storage-Schema). Diese Funktion liefert die verwaisten Pfade des
-- aufrufenden Users; geloescht wird anschliessend ueber die Storage-API der
-- App (DELETE-Policy buchungs_belege_storage_delete deckt den eigenen Ordner).
--
-- Schutz: nur Dateien im eigenen Ordner (erstes Pfadsegment = auth.uid()) und
-- nur solche, die aelter als eine Stunde sind — damit ein laufender Upload,
-- dessen DB-Eintrag noch fehlt, nicht faelschlich als Waise gilt.

CREATE OR REPLACE FUNCTION public.verwaiste_belege()
RETURNS TABLE (
  storage_pfad text,
  groesse      bigint,
  hochgeladen  timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, storage
AS $$
  SELECT o.name,
         COALESCE((o.metadata->>'size')::bigint, 0),
         o.created_at
  FROM storage.objects o
  WHERE o.bucket_id = 'buchungs-belege'
    AND (string_to_array(o.name, '/'))[1] = (auth.uid())::text
    AND o.created_at < now() - interval '1 hour'
    AND NOT EXISTS (
      SELECT 1 FROM public.buchungs_belege bb WHERE bb.storage_pfad = o.name
    )
  ORDER BY o.created_at;
$$;

REVOKE ALL ON FUNCTION public.verwaiste_belege() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.verwaiste_belege() TO authenticated;

COMMENT ON FUNCTION public.verwaiste_belege() IS
  'Beleg-Dateien im eigenen Storage-Ordner ohne zugehoerigen buchungs_belege-Eintrag (aelter als 1h).';

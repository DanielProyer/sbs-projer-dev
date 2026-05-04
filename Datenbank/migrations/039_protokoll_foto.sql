-- Migration 039: Protokoll-Foto für Reinigungen
-- Neues Feld für Foto-Pfad (Papier-Protokoll wird fotografiert statt digital ausgefüllt)

ALTER TABLE reinigungen ADD COLUMN IF NOT EXISTS protokoll_foto_pfad TEXT;

-- Storage Bucket für Reinigung-Fotos
INSERT INTO storage.buckets (id, name, public)
VALUES ('reinigung-fotos', 'reinigung-fotos', false)
ON CONFLICT (id) DO NOTHING;

-- RLS Policies für den Bucket (idempotent)
DROP POLICY IF EXISTS "Authenticated users can upload reinigung fotos" ON storage.objects;
CREATE POLICY "Authenticated users can upload reinigung fotos"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'reinigung-fotos');

DROP POLICY IF EXISTS "Authenticated users can read reinigung fotos" ON storage.objects;
CREATE POLICY "Authenticated users can read reinigung fotos"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'reinigung-fotos');

DROP POLICY IF EXISTS "Authenticated users can update reinigung fotos" ON storage.objects;
CREATE POLICY "Authenticated users can update reinigung fotos"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'reinigung-fotos');

DROP POLICY IF EXISTS "Authenticated users can delete reinigung fotos" ON storage.objects;
CREATE POLICY "Authenticated users can delete reinigung fotos"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'reinigung-fotos');

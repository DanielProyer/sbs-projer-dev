-- Migration 033: Buchungs-Belege (Dateien zu Buchungen)
-- Ermöglicht das Anhängen von Belegen (PDFs, Fotos) an Buchungen

-- Tabelle für Beleg-Metadaten
CREATE TABLE IF NOT EXISTS buchungs_belege (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id),
    buchung_id UUID NOT NULL REFERENCES buchungen(id) ON DELETE CASCADE,
    dateiname TEXT NOT NULL,
    dateityp TEXT NOT NULL,
    storage_pfad TEXT NOT NULL,
    beleg_quelle TEXT NOT NULL DEFAULT 'manuell'
        CHECK (beleg_quelle IN ('manuell', 'camt053', 'rechnung')),
    beschreibung TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Indices
CREATE INDEX IF NOT EXISTS idx_buchungs_belege_buchung ON buchungs_belege(buchung_id);
CREATE INDEX IF NOT EXISTS idx_buchungs_belege_user ON buchungs_belege(user_id);

-- RLS aktivieren
ALTER TABLE buchungs_belege ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "buchungs_belege_select" ON buchungs_belege
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "buchungs_belege_insert" ON buchungs_belege
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "buchungs_belege_update" ON buchungs_belege
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "buchungs_belege_delete" ON buchungs_belege
    FOR DELETE USING (auth.uid() = user_id);

-- Storage Bucket für Belege
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'buchungs-belege',
    'buchungs-belege',
    false,
    10485760,  -- 10MB
    ARRAY['application/pdf', 'image/jpeg', 'image/png']
)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS Policies
CREATE POLICY "buchungs_belege_storage_select" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'buchungs-belege'
        AND auth.uid()::text = (string_to_array(name, '/'))[1]
    );

CREATE POLICY "buchungs_belege_storage_insert" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'buchungs-belege'
        AND auth.uid()::text = (string_to_array(name, '/'))[1]
    );

CREATE POLICY "buchungs_belege_storage_update" ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'buchungs-belege'
        AND auth.uid()::text = (string_to_array(name, '/'))[1]
    );

CREATE POLICY "buchungs_belege_storage_delete" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'buchungs-belege'
        AND auth.uid()::text = (string_to_array(name, '/'))[1]
    );

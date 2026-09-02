-- 182: Generisches Dokumente-Modul (Steuern zuerst), 02.09.2026
-- Spec: docs/superpowers/specs/2026-09-02-steuern-dokumente-audit-design.md
CREATE TABLE IF NOT EXISTS dokumente (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id),
    bereich TEXT NOT NULL CHECK (bereich IN ('steuern','versicherungen','vertraege','behoerden','bank','sonstiges')),
    typ TEXT NOT NULL,
    kategorie TEXT,
    jahr INTEGER,
    dokument_datum DATE,
    betrag NUMERIC(12,2),
    referenz TEXT,
    titel TEXT NOT NULL,
    notizen TEXT,
    dateiname TEXT NOT NULL,
    dateityp TEXT NOT NULL,
    groesse_bytes INTEGER,
    seiten INTEGER,
    storage_pfad TEXT NOT NULL UNIQUE,
    buchung_id UUID REFERENCES buchungen(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_dokumente_user_bereich_jahr ON dokumente(user_id, bereich, jahr);
CREATE INDEX IF NOT EXISTS idx_dokumente_buchung ON dokumente(buchung_id);

ALTER TABLE dokumente ENABLE ROW LEVEL SECURITY;
CREATE POLICY "dokumente_select" ON dokumente FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "dokumente_insert" ON dokumente FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "dokumente_update" ON dokumente FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "dokumente_delete" ON dokumente FOR DELETE USING (auth.uid() = user_id);

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('dokumente', 'dokumente', false, 20971520, ARRAY['application/pdf','image/jpeg','image/png'])
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "dokumente_storage_select" ON storage.objects FOR SELECT
  USING (bucket_id = 'dokumente' AND auth.uid()::text = (string_to_array(name, '/'))[1]);
CREATE POLICY "dokumente_storage_insert" ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'dokumente' AND auth.uid()::text = (string_to_array(name, '/'))[1]);
CREATE POLICY "dokumente_storage_update" ON storage.objects FOR UPDATE
  USING (bucket_id = 'dokumente' AND auth.uid()::text = (string_to_array(name, '/'))[1]);
CREATE POLICY "dokumente_storage_delete" ON storage.objects FOR DELETE
  USING (bucket_id = 'dokumente' AND auth.uid()::text = (string_to_array(name, '/'))[1]);

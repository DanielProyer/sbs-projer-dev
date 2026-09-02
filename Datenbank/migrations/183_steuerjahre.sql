-- 183: Steuerjahre (Veranlagung Soll je Jahr), 02.09.2026
CREATE TABLE IF NOT EXISTS steuerjahre (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id),
    jahr INTEGER NOT NULL,
    status TEXT NOT NULL DEFAULT 'offen' CHECK (status IN ('offen','eingereicht','veranlagt','ermessen')),
    eingereicht_am DATE,
    veranlagt_am DATE,
    steuerbarer_gewinn NUMERIC(12,2),
    steuerbares_kapital NUMERIC(12,2),
    verlustvortrag_verrechnet NUMERIC(12,2),
    bund_provisorisch NUMERIC(12,2),
    bund_definitiv NUMERIC(12,2),
    kanton_provisorisch NUMERIC(12,2),
    kanton_definitiv NUMERIC(12,2),
    notizen TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (user_id, jahr)
);
ALTER TABLE steuerjahre ENABLE ROW LEVEL SECURITY;
CREATE POLICY "steuerjahre_select" ON steuerjahre FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "steuerjahre_insert" ON steuerjahre FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "steuerjahre_update" ON steuerjahre FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "steuerjahre_delete" ON steuerjahre FOR DELETE USING (auth.uid() = user_id);

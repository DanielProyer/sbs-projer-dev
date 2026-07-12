-- 135_werkstatt_extern_id.sql
-- Backfill-Infrastruktur: stabiler Import-Schlüssel + Idempotenz für die
-- 5 Werkstatt-Tabellen (analog reinigungen.extern_id/quelle).
ALTER TABLE stoerungen              ADD COLUMN IF NOT EXISTS extern_id text, ADD COLUMN IF NOT EXISTS quelle text;
ALTER TABLE montagen                ADD COLUMN IF NOT EXISTS extern_id text, ADD COLUMN IF NOT EXISTS quelle text;
ALTER TABLE eigenauftraege          ADD COLUMN IF NOT EXISTS extern_id text, ADD COLUMN IF NOT EXISTS quelle text;
ALTER TABLE eroeffnungsreinigungen  ADD COLUMN IF NOT EXISTS extern_id text, ADD COLUMN IF NOT EXISTS quelle text;
ALTER TABLE pikett_dienste          ADD COLUMN IF NOT EXISTS extern_id text, ADD COLUMN IF NOT EXISTS quelle text;

-- Partielle Unique-Indizes: Idempotenz für Import-Zeilen, Live-Zeilen (extern_id NULL) ausgenommen.
CREATE UNIQUE INDEX IF NOT EXISTS uq_stoerungen_extern     ON stoerungen             (user_id, extern_id) WHERE extern_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_montagen_extern       ON montagen               (user_id, extern_id) WHERE extern_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_eigenauftraege_extern ON eigenauftraege         (user_id, extern_id) WHERE extern_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_ee_extern             ON eroeffnungsreinigungen (user_id, extern_id) WHERE extern_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_pikett_extern         ON pikett_dienste         (user_id, extern_id) WHERE extern_id IS NOT NULL;

-- Waisen-Eigenaufträge (Betrieb nicht in App) importierbar machen (konsistent mit Schwester-Tabellen).
ALTER TABLE eigenauftraege ALTER COLUMN betrieb_id DROP NOT NULL;

-- 165b: RLS auf Wartungs-Snapshots (Server 05.08.2026, Name: rls_auf_wartungs_snapshots)
-- und 06.08.2026 (rls_snapshot_landi). Rekonstruiert am 26.09.2026 aus
-- supabase_migrations.schema_migrations — damals direkt angewendet, ohne lokale Datei.
-- Die Tabellen wurden mit Migration 176 wieder gelöscht; die Datei dokumentiert
-- nur die Zwischenstufe.

-- Wartungs-Snapshots (Rollback-Grundlagen) waren ohne RLS im Schema public
-- und damit ueber die PostgREST-API mit anon-Key lesbar. Sie enthalten
-- Betriebsnamen und Stammdatenstaende. RLS ohne Policy = kein Zugriff ueber
-- die API; die Service-Role (Migrationen, Wartungsskripte) liest weiterhin,
-- der Rueckweg bleibt also erhalten.
ALTER TABLE public.snapshot_winterfenster_2026_08_04 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.snapshot_golden_dragon_2026_08_05 ENABLE ROW LEVEL SECURITY;

-- 06.08.2026 (rls_snapshot_landi):
ALTER TABLE public.snapshot_landi_2026_08_06 ENABLE ROW LEVEL SECURITY;

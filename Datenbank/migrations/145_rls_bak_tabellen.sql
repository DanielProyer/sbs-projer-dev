-- 145: RLS auf allen Backup-Tabellen aktivieren (21.07.2026)
-- Anlass: Supabase-Sicherheitsmail 20.07.2026 "Table publicly accessible"
-- (rls_disabled_in_public). Die _bak_-Tabellen vom 14.-16.07. wurden mit
-- CREATE TABLE ... AS angelegt; dabei wird RLS NICHT automatisch aktiviert,
-- die Tabellen waren damit ueber die PostgREST-API mit dem Anon-Key lesbar.
-- Keine Policies noetig: Die App greift nie auf _bak_-Tabellen zu; RLS ohne
-- Policy blockt jeden anon-/authenticated-Zugriff, Service-Role/SQL bleiben.
-- Merke fuer kuenftige Backups: nach CREATE TABLE _bak_... AS SELECT ...
-- immer sofort ALTER TABLE ... ENABLE ROW LEVEL SECURITY;

ALTER TABLE public._bak_rundung_reinigungen_20260714 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public._bak_rundung_stoerungen_20260714 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public._bak_rundung_rechnungen_20260714 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public._bak_camt_20260715_rechnungen ENABLE ROW LEVEL SECURITY;
ALTER TABLE public._bak_camt_20260715_dateien ENABLE ROW LEVEL SECURITY;
ALTER TABLE public._bak_camt_20260715_pruefliste ENABLE ROW LEVEL SECURITY;
ALTER TABLE public._bak_camt_20260715_regel ENABLE ROW LEVEL SECURITY;
ALTER TABLE public._bak_camt_20260715_eingangsrechnung ENABLE ROW LEVEL SECURITY;
ALTER TABLE public._bak_nachtrag_20260715_rechnungen ENABLE ROW LEVEL SECURITY;
ALTER TABLE public._bak_nachtrag_20260715_positionen ENABLE ROW LEVEL SECURITY;
ALTER TABLE public._bak_ezs_korrektur_20260716 ENABLE ROW LEVEL SECURITY;

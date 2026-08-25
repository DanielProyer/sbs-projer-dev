-- 177: EXECUTE-Grant auf rls_auto_enable() entzogen
-- Angewendet am 24.08.2026 (via MCP: revoke_execute_rls_auto_enable).
--
-- ANLASS: Daniel hat am 24.08.2026 im Supabase-Dashboard den Event-Trigger
-- `ensure_rls` eingeschaltet ("Automatically enable Row Level Security on new
-- tables") -- die Praevention fuer den Vorfall aus Migration 176. Supabase legt
-- dabei die Funktion public.rls_auto_enable() an und gibt sie fuer anon UND
-- authenticated frei. Der Advisor meldete daraufhin ZWEI NEUE Befunde:
--   anon_security_definer_function_executable
--   authenticated_security_definer_function_executable
--
-- BEWERTUNG: praktisch ungefaehrlich.
--   - Die Funktion hat RETURNS event_trigger. Solche Funktionen lassen sich in
--     PostgreSQL nicht direkt aufrufen, und PostgREST kann den Typ nicht als
--     RPC exponieren.
--   - Sie setzt selbst `SET search_path TO 'pg_catalog'`.
--   - Ihr Rumpf laeuft ueber pg_event_trigger_ddl_commands(), das ausserhalb
--     eines Event-Triggers ohnehin fehlschlaegt.
-- Der Linter prueft nur die Grants, nicht die tatsaechliche Aufrufbarkeit.
--
-- Der Grant ist aber schlicht unnoetig: Event-Trigger laufen mit den Rechten
-- ihres Besitzers, nicht ueber EXECUTE fuer Anwendungsrollen.
REVOKE EXECUTE ON FUNCTION public.rls_auto_enable() FROM anon;
REVOKE EXECUTE ON FUNCTION public.rls_auto_enable() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.rls_auto_enable() FROM PUBLIC;

-- NACHGEWIESEN nach dem Revoke: Wegwerf-Tabelle ohne jede RLS-Anweisung
-- angelegt -> relrowsecurity = true. Der Trigger arbeitet unveraendert weiter.
-- Testtabellen anschliessend wieder geloescht.
--
-- OFFEN (App-Funktion, braucht Pruefung ob die App sie ruft -- NICHT blind
-- anfassen): public.verwaiste_belege() ist ebenfalls SECURITY DEFINER und
-- fuer authenticated ueber /rest/v1/rpc/verwaiste_belege aufrufbar.

-- 178: search_path aller eigenen Trigger-Funktionen fixiert
-- Angewendet am 26.08.2026 (via MCP: search_path_fixieren_trigger_funktionen).
--
-- ANLASS: Advisor-Warnung `function_search_path_mutable` fuer 20 Funktionen.
-- Ohne festen search_path bestimmt die aufrufende Rolle, in welchem Schema
-- unqualifizierte Namen aufgeloest werden -- theoretisch laesst sich so einer
-- Funktion ein untergeschobenes Objekt unterjubeln.
--
-- GEPRUEFT VOR DER AENDERUNG (das ist hier der heikle Teil, nicht das ALTER):
--   - Alle 20 sind RETURNS trigger, ohne Argumente, KEINE SECURITY DEFINER.
--   - Keine referenziert auth., storage., extensions. oder Extension-
--     Funktionen (similarity/levenshtein/soundex/net.*) -- geprueft ueber
--     pg_proc.prosrc. Sie arbeiten ausschliesslich auf public-Tabellen.
--   - pg_catalog ist immer implizit im search_path; now(), format(),
--     to_char() usw. funktionieren also unveraendert.
--   - Der bisherige effektive Pfad war '"$user", public, extensions'.
--     Da keine Funktion etwas aus `extensions` unqualifiziert nutzt, aendert
--     `public` das Verhalten nicht.
--
-- WARUM NICHT `SET search_path = ''` (was die Supabase-Doku empfiehlt):
-- Dann muesste jede Tabellenreferenz im Rumpf schema-qualifiziert werden --
-- eine Code-Aenderung mitten in Preis-, Rechnungsnummer- und Buchungslogik.
-- Der Sicherheitsgewinn waere null, das Risiko betraechtlich.
--
-- NICHT ANGEFASST: die Funktionen von pg_trgm und fuzzystrmatch (similarity,
-- levenshtein, soundex, gtrgm_* ...). Sie gehoeren den Extensions und werden
-- ueber pg_depend deptype='e' ausgeschlossen; der Advisor meldet sie nicht.

ALTER FUNCTION public.auto_buchung_rechnung_erstellt()   SET search_path = public;
ALTER FUNCTION public.auto_buchung_zahlung_eingegangen() SET search_path = public;
ALTER FUNCTION public.calculate_montage_kosten()         SET search_path = public;
ALTER FUNCTION public.calculate_naechste_reinigung()     SET search_path = public;
ALTER FUNCTION public.calculate_reinigung_preis()        SET search_path = public;
ALTER FUNCTION public.calculate_stoerung_preis()         SET search_path = public;
ALTER FUNCTION public.generate_rechnungsnummer()         SET search_path = public;
ALTER FUNCTION public.populate_reinigung_checklist()     SET search_path = public;
ALTER FUNCTION public.set_eigenauftrag_pauschale()       SET search_path = public;
ALTER FUNCTION public.set_material_auslauf_datum()       SET search_path = public;
ALTER FUNCTION public.set_pikett_pauschale()             SET search_path = public;
ALTER FUNCTION public.sync_eigenauftrag_material()       SET search_path = public;
ALTER FUNCTION public.sync_montage_material()            SET search_path = public;
ALTER FUNCTION public.sync_stoerung_material()           SET search_path = public;
ALTER FUNCTION public.update_lager_bestand_delete()      SET search_path = public;
ALTER FUNCTION public.update_lager_bestand_insert()      SET search_path = public;
ALTER FUNCTION public.update_letzte_reinigung()          SET search_path = public;
ALTER FUNCTION public.update_letzter_wasserwechsel()     SET search_path = public;
ALTER FUNCTION public.update_rechnung_summen()           SET search_path = public;
ALTER FUNCTION public.update_updated_at_column()         SET search_path = public;

-- NACHGEWIESEN nach der Aenderung: UPDATE auf betriebe ausgeloest ->
-- update_updated_at_column hat gefeuert, updated_at wurde neu gesetzt.
-- Advisor danach: alle 20 function_search_path_mutable-Warnungen weg.
--
-- FUER NEUE FUNKTIONEN: `SET search_path = public` gleich mitschreiben,
-- sonst kommt die Warnung zurueck:
--   CREATE FUNCTION public.foo() RETURNS trigger
--   LANGUAGE plpgsql SET search_path = public AS $$ ... $$;

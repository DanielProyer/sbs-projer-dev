-- 176: Sicherheitsbefund abarbeiten + Snapshot-Tabellen aufraeumen
-- Angewendet am 26.08.2026 (via MCP, zwei Migrationen:
-- enable_rls_snapshot_gampel_testdaten + drop_erledigte_snapshot_tabellen).
--
-- ANLASS: Supabase meldete am 23.08.2026 einen KRITISCHEN Befund
-- (rls_disabled_in_public, Level ERROR) fuer public.snapshot_gampel_testdaten.
-- Die Tabelle wurde am 17.08.2026 von Migration 174 als Sicherung fuer den
-- Gampel-Testdaten-Reset angelegt -- OHNE RLS. Damit war sie ueber PostgREST
-- mit dem anon-Key les- UND schreibbar, und der anon-Key steckt im
-- ausgelieferten Web-Bundle.
--
-- LEHRE FUER KUENFTIGE MIGRATIONEN: Jede neue Tabelle in `public` braucht
-- ENABLE ROW LEVEL SECURITY -- auch temporaere Hilfs- und Snapshot-Tabellen.
-- PostgREST macht ausnahmslos jede Tabelle im public-Schema erreichbar.
-- Nach DDL-Aenderungen `get_advisors` laufen lassen.
--
-- PRUEFUNG: Die Logs des gesamten offenen Zeitraums (17.-26.08.2026) wurden
-- tageweise ausgewertet -- 9978 API-Zugriffe, davon KEIN einziger auf einen
-- snapshot-Pfad. Die Luecke wurde nicht ausgenutzt.
--   17.08.  467 | 18.08.  507 | 19.08.   73 | 20.08. 1129 | 21.08.  149
--   22.08.  470 | 23.08.  453 | 24.08. 2552 | 25.08. 2395 | 26.08. 1783
-- (Der Feldname wurde vorab gegengeprueft: dieselbe Abfrage findet normale
-- Pfade wie /rest/v1/reinigungen, "keine Treffer" ist also aussagekraeftig.)
--
-- ANMERKUNG ZUR PRUEFUNG SELBST: Beim ersten Durchgang fehlten der 24. und
-- der grosse Teil des 25.08. -- die 24h-Fenster wurden von einem falschen
-- "heute" aus gerechnet. Nachgeholt am 26.08.2026, Ergebnis unveraendert.
--
-- Schritt 1 war die Sofortmassnahme (nicht-destruktiv):
ALTER TABLE IF EXISTS public.snapshot_gampel_testdaten
  ENABLE ROW LEVEL SECURITY;

-- Schritt 2 (Entscheid Daniel 26.08.2026): Alle vier Snapshot-Tabellen
-- loeschen. Es waren Rueckwege vor punktuellen Datenreparaturen, alle hatten
-- ihren Zweck erfuellt. Die Inhalte sind gesichert in
-- Datenbank/snapshot-archiv-2026-08-26.md -- besonders das Winterfenster mit
-- den 20 alten (fehlerhaften) Jahreszahlen.
DROP TABLE IF EXISTS public.snapshot_gampel_testdaten;
DROP TABLE IF EXISTS public.snapshot_golden_dragon_2026_08_05;
DROP TABLE IF EXISTS public.snapshot_landi_2026_08_06;
DROP TABLE IF EXISTS public.snapshot_winterfenster_2026_08_04;

-- Schritt 3 (Entscheid Daniel 26.08.2026, eigene Migration
-- drop_gampel_testdaten_reset_funktion): Die letzte Altlast des Resets.
-- Die Funktion schrieb in snapshot_gampel_testdaten und loeschte danach die
-- Testdaten; beides gibt es nicht mehr. Der pg_cron-Job hatte sich am
-- 17.08.2026 nach dem einmaligen Lauf planmaessig selbst entfernt.
-- Vor dem Loeschen geprueft: 0 Cron-Jobs, 0 Trigger referenzieren sie.
DROP FUNCTION IF EXISTS public.gampel_testdaten_reset();

-- Endstand nach 176: 0 snapshot-Tabellen, 0 Reset-Funktion, 1 Cron-Job
-- (betriebsdaten-abgleich, taeglich 03:20 UTC -- unberuehrt).

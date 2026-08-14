-- ============================================================
-- Migration 174: Einmaliger Testdaten-Reset Openair Gampel
-- Projekt: SBS Projer App
-- Stand: 14.08.2026
-- Auftrag Daniel (14.08.): Alles, was bis Sonntagabend 16.08. in der
-- Event-Technik UND bei den Ständen des Gampel-Events erfasst wird, sind
-- Testdaten — Montagmorgen löschen für den frischen Start.
-- Entscheid: auch Stände löschen; Kontakte/Dokumente/Aufwand bleiben.
--
-- Läuft EINMAL: Mo 17.08.2026 04:00 UTC = 06:00 Schweizer Sommerzeit
-- (pg_cron rechnet in UTC — gleiche Falle wie Migration 162).
-- Vor dem Löschen JSONB-Snapshot (destruktiv + zeitversetzt => mit Rückweg).
-- Der Job entfernt sich nach dem Lauf selbst; die Funktion bleibt stehen
-- (dokumentiert, kann nach dem Festival aufgeräumt werden).
-- ============================================================

CREATE TABLE IF NOT EXISTS snapshot_gampel_testdaten (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tabelle text NOT NULL,
  daten jsonb NOT NULL,
  erstellt_am timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE snapshot_gampel_testdaten IS
  'Sicherung der Gampel-Testdaten vor dem automatischen Reset am 17.08.2026 06:00 CH. Wiederherstellung: jsonb_populate_record je Zeile.';

CREATE OR REPLACE FUNCTION gampel_testdaten_reset() RETURNS void
LANGUAGE plpgsql AS $fn$
DECLARE
  ev uuid := '16beed13-cce9-4a49-90d1-a6a4f69093de'; -- Openair Gampel 2026
BEGIN
  -- Snapshot (nur nicht-leere Tabellen erzeugen Zeilen)
  INSERT INTO snapshot_gampel_testdaten(tabelle, daten)
  SELECT 'event_kuehler_messungen', jsonb_agg(to_jsonb(t)) FROM event_kuehler_messungen t
    WHERE t.geraet_id IN (SELECT g.id FROM event_geraete g WHERE g.event_id = ev)
    HAVING count(*) > 0;
  INSERT INTO snapshot_gampel_testdaten(tabelle, daten)
  SELECT 'event_leitungen', jsonb_agg(to_jsonb(t)) FROM event_leitungen t
    WHERE t.event_id = ev HAVING count(*) > 0;
  INSERT INTO snapshot_gampel_testdaten(tabelle, daten)
  SELECT 'event_geraete', jsonb_agg(to_jsonb(t)) FROM event_geraete t
    WHERE t.event_id = ev HAVING count(*) > 0;
  INSERT INTO snapshot_gampel_testdaten(tabelle, daten)
  SELECT 'event_stand_anlagen', jsonb_agg(to_jsonb(t)) FROM event_stand_anlagen t
    WHERE t.stand_id IN (SELECT s.id FROM event_staende s WHERE s.event_id = ev)
    HAVING count(*) > 0;
  INSERT INTO snapshot_gampel_testdaten(tabelle, daten)
  SELECT 'event_staende', jsonb_agg(to_jsonb(t)) FROM event_staende t
    WHERE t.event_id = ev HAVING count(*) > 0;

  -- Löschen in FK-Reihenfolge (CASCADE würde greifen, explizit ist klarer)
  DELETE FROM event_kuehler_messungen
    WHERE geraet_id IN (SELECT g.id FROM event_geraete g WHERE g.event_id = ev);
  DELETE FROM event_leitungen WHERE event_id = ev;
  DELETE FROM event_geraete WHERE event_id = ev;
  DELETE FROM event_stand_anlagen
    WHERE stand_id IN (SELECT s.id FROM event_staende s WHERE s.event_id = ev);
  DELETE FROM event_staende WHERE event_id = ev;

  -- Einmal-Job: sich selbst abmelden
  PERFORM cron.unschedule('gampel-testdaten-reset');
END;
$fn$;

-- Idempotent anlegen
SELECT cron.unschedule('gampel-testdaten-reset')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'gampel-testdaten-reset');

SELECT cron.schedule(
  'gampel-testdaten-reset',
  '0 4 17 8 *',  -- 17.08. 04:00 UTC = 06:00 Schweizer Sommerzeit
  $$SELECT gampel_testdaten_reset();$$
);

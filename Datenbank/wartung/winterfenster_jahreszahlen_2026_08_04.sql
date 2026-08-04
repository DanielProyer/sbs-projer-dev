-- Winterfenster mit verdrehten Jahreszahlen richten (04.08.2026)
-- Ausgeführt am 04.08.2026 via Supabase MCP.
--
-- Befund (ToDo «20 Winterbetriebe mit Jahreswechsel-Saison»): Bei 20
-- Betrieben standen Start UND Ende des Winterfensters im selben Jahr
-- (z.B. Robinson Club Arosa 01.12.2026–01.04.2026). Gemeint ist die Saison
-- über den Jahreswechsel — das Ende gehört ins Folgejahr (01.04.2027).
-- Regel identisch zu `jahreszahlenRichten()` in
-- sbs_projer_app/lib/core/util/saison_jahr.dart: bis < von → bis + 1 Jahr.
--
-- Ohne die Korrektur liefe `_imFenster()` (touren_saison.dart) nach dem
-- Winterende in eine «ewige Saison»: der Wrap-Zweig (von > bis) bleibt ab
-- dem Startdatum für immer wahr (z.B. Mai 2027 gälte noch als Wintersaison).
--
-- Betroffen: 20 aktive Betriebe (Davos/Arosa/Flims/Churwalden), nur
-- winter_ende_datum angehoben, Starts unverändert, Sommerfenster sauber.

-- 1. Snapshot (Rollback-Grundlage)
CREATE TABLE IF NOT EXISTS snapshot_winterfenster_2026_08_04 AS
SELECT id, name, ort, winter_start_datum, winter_ende_datum, now() AS snapshot_am
FROM betriebe
WHERE winter_start_datum IS NOT NULL AND winter_ende_datum IS NOT NULL
  AND winter_ende_datum < winter_start_datum;

-- 2. Korrektur: Ende + 1 Jahr
UPDATE betriebe
SET winter_ende_datum = (winter_ende_datum + interval '1 year')::date
WHERE id IN (SELECT id FROM snapshot_winterfenster_2026_08_04)
  AND winter_ende_datum < winter_start_datum;

-- 3. Kontrolle: beide müssen 0 liefern, die dritte 20
SELECT count(*) FROM betriebe
WHERE winter_start_datum IS NOT NULL AND winter_ende_datum IS NOT NULL
  AND winter_ende_datum < winter_start_datum;          -- 0
SELECT count(*) FROM betriebe
WHERE sommer_start_datum IS NOT NULL AND sommer_ende_datum IS NOT NULL
  AND sommer_ende_datum < sommer_start_datum;          -- 0
SELECT count(*) FROM betriebe b
JOIN snapshot_winterfenster_2026_08_04 s USING (id)
WHERE b.winter_ende_datum = (s.winter_ende_datum + interval '1 year')::date
  AND b.winter_start_datum = s.winter_start_datum;     -- 20

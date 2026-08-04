-- Rollback zu winterfenster_jahreszahlen_2026_08_04.sql
-- Stellt die (verdrehten) Original-Winterfenster aus dem Snapshot wieder her.

UPDATE betriebe b
SET winter_ende_datum = s.winter_ende_datum
FROM snapshot_winterfenster_2026_08_04 s
WHERE b.id = s.id;

-- Kontrolle: 20 Betriebe wieder mit winter_ende < winter_start
SELECT count(*) FROM betriebe
WHERE winter_start_datum IS NOT NULL AND winter_ende_datum IS NOT NULL
  AND winter_ende_datum < winter_start_datum;

-- Danach ggf. Snapshot entfernen:
-- DROP TABLE snapshot_winterfenster_2026_08_04;

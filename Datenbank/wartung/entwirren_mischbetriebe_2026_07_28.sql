-- ============================================================================
-- Mischbetriebe entwirren (28.07.2026)
-- ============================================================================
-- Beim Historik-Import wurden gleichnamige Betriebe zu EINEM Datensatz
-- verschmolzen (Match nur ueber den Namen, nicht ueber Name + Ort). Folge:
-- Reinigungen und Rechnungen mehrerer Haeuser haengen am selben Betrieb -
-- das verfaelscht die Faelligkeitsberechnung und den camt-Abgleich.
--
-- Dieses Skript haengt die Historie anhand der Excel-Betriebsnummer (Stelle 4
-- der extern_id bzw. der Historik-Rechnungsnummer) an den richtigen Betrieb.
-- Zuordnung von Daniel bestaetigt am 28.07.2026.
--
-- Erloschene Haeuser bekommen einen eigenen Betrieb mit status='geschlossen',
-- damit ihre Vorgeschichte am richtigen Ort steht.
--
-- Aufruf:
--   npx supabase db query --linked --file Datenbank/wartung/entwirren_mischbetriebe_2026_07_28.sql
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------- Snapshot
CREATE SCHEMA IF NOT EXISTS snapshot_mischbetriebe;
DROP TABLE IF EXISTS snapshot_mischbetriebe.reinigungen_vorher;
DROP TABLE IF EXISTS snapshot_mischbetriebe.rechnungen_vorher;
DROP TABLE IF EXISTS snapshot_mischbetriebe.betriebe_ids_vorher;

CREATE TABLE snapshot_mischbetriebe.reinigungen_vorher AS
SELECT id, betrieb_id, anlage_id, extern_id FROM reinigungen WHERE extern_id IS NOT NULL;

CREATE TABLE snapshot_mischbetriebe.rechnungen_vorher AS
SELECT id, betrieb_id, rechnungsnummer FROM rechnungen;

CREATE TABLE snapshot_mischbetriebe.betriebe_ids_vorher AS
SELECT id FROM betriebe;

-- ------------------------------------------------- Erloschene Haeuser neu
-- Feste UUIDs, damit das Mapping unten direkt darauf zeigen kann.
INSERT INTO betriebe (id, user_id, name, ort, status, ist_mein_kunde, notizen)
SELECT v.id, (SELECT user_id FROM betriebe ORDER BY created_at LIMIT 1),
       v.name, v.ort, 'geschlossen', true,
       'Aus Historik-Import getrennt (28.07.2026), Betrieb besteht nicht mehr'
FROM (VALUES
  ('a1000000-0000-4000-8000-000000000506'::uuid, 'Alpina Gitzihöll', 'Triesenberg'),
  ('a1000000-0000-4000-8000-000000000181'::uuid, 'Alte Post',        'Maladers'),
  ('a1000000-0000-4000-8000-000000000612'::uuid, 'Bistro Bahnhöfli', 'Schiers'),
  ('a1000000-0000-4000-8000-000000000157'::uuid, 'Bahnhöfli',        'Küblis'),
  ('a1000000-0000-4000-8000-000000000679'::uuid, 'Krone',            'Cham'),
  ('a1000000-0000-4000-8000-000000000040'::uuid, 'Rheinkrone',       'Chur'),
  ('a1000000-0000-4000-8000-000000000730'::uuid, 'Gasthaus Löwen',   'Grossdietwil'),
  ('a1000000-0000-4000-8000-000000000753'::uuid, 'Gasthaus Löwen',   'Sins'),
  ('a1000000-0000-4000-8000-000000000729'::uuid, 'Restaurant Eisenbahn', 'Zell'),
  ('a1000000-0000-4000-8000-000000000727'::uuid, 'Grill-Haus Hayoz', 'Gettnau')
) AS v(id, name, ort)
WHERE NOT EXISTS (SELECT 1 FROM betriebe b WHERE b.id = v.id);

-- ------------------------------------------------------------- Zuordnung
DROP TABLE IF EXISTS import.betrieb_mapping;
CREATE TABLE import.betrieb_mapping (nr text PRIMARY KEY, ziel_id uuid NOT NULL, bemerkung text);
INSERT INTO import.betrieb_mapping VALUES
  ('0195','213f0fc4-6deb-49bf-847d-9cf28b59f52d','Alpina Schiers'),
  ('0147','c22b4840-f50a-49fb-8b28-ad40feb1dd12','Seven Alpina Klosters'),
  ('0506','a1000000-0000-4000-8000-000000000506','Alpina Gitzihöll Triesenberg (neu)'),
  ('0092','5fd787d8-f215-4232-acd4-a7ae82172807','Alte Post Davos'),
  ('0181','a1000000-0000-4000-8000-000000000181','Alte Post Maladers (neu)'),
  ('0612','a1000000-0000-4000-8000-000000000612','Bistro Bahnhöfli Schiers (neu)'),
  ('0157','a1000000-0000-4000-8000-000000000157','Bahnhöfli Küblis (neu)'),
  ('0026','736f58bf-7ac4-4031-8d5f-5d3d926b5051','Calanda Chur'),
  ('0751','72ae6129-b419-4622-a497-91c9736cce7c','Hotel Central am See Weggis'),
  ('0137','8b7bdda2-184c-4bc3-a63c-0787c93e63ae','Krone Igis'),
  ('0679','a1000000-0000-4000-8000-000000000679','Krone Cham (neu)'),
  ('0040','a1000000-0000-4000-8000-000000000040','Rheinkrone Chur (neu)'),
  ('0730','a1000000-0000-4000-8000-000000000730','Gasthaus Löwen Grossdietwil (neu)'),
  ('0753','a1000000-0000-4000-8000-000000000753','Gasthaus Löwen Sins (neu)'),
  ('0189','ca4b8ec5-bff9-44f2-a7d8-439a2cf64a2d','Obertor Parpan'),
  ('0749','75bbd43b-644f-4f8b-ae93-9bee0dd54450','Villaggio Root'),
  ('0721','384113a4-4ec9-475f-a24a-b43f5487b5ee','Café Restaurant Mühle Nottwil'),
  ('0732','fccd08e4-d7ba-4060-b899-e738c49966a9','Türmli Sempach'),
  ('0729','a1000000-0000-4000-8000-000000000729','Restaurant Eisenbahn Zell (neu)'),
  ('0727','a1000000-0000-4000-8000-000000000727','Grill-Haus Hayoz Gettnau (neu)'),
  ('0045','35f8164e-628d-4eaa-99b7-ab2e81f69129','Surselva Chur');

-- ------------------------------------------------ Reinigungen umhaengen
-- Die anlage_id zeigt auf eine Anlage des FALSCHEN Betriebs. Hat der
-- Zielbetrieb genau eine Anlage, wird sie gesetzt, sonst geleert.
UPDATE reinigungen r
SET betrieb_id = m.ziel_id,
    anlage_id  = (SELECT a.id FROM anlagen a
                   WHERE a.betrieb_id = m.ziel_id
                     AND (SELECT count(*) FROM anlagen a2 WHERE a2.betrieb_id = m.ziel_id) = 1
                   LIMIT 1),
    updated_at = now()
FROM import.betrieb_mapping m
WHERE r.extern_id IS NOT NULL
  AND split_part(r.extern_id, '_', 4) = m.nr
  AND r.betrieb_id IS DISTINCT FROM m.ziel_id;

-- ------------------------------------------------- Rechnungen umhaengen
UPDATE rechnungen r
SET betrieb_id = m.ziel_id, updated_at = now()
FROM import.betrieb_mapping m
WHERE r.rechnungsnummer ~ '^011_[0-9]{4}_'
  AND split_part(r.rechnungsnummer, '_', 5) = m.nr
  AND r.betrieb_id IS DISTINCT FROM m.ziel_id;

COMMIT;

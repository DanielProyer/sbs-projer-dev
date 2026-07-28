-- ============================================================================
-- Mischbetriebe entwirren - Teil 2 (28.07.2026)
-- ============================================================================
-- Die 16 Betriebe, an denen nur noch TOTE Fremdhistorie hing (jeweils nur ein
-- Objekt bis zuletzt aktiv). Fuer den camt-Abgleich unkritisch, aber die
-- Reinigungshistorie und damit die Faelligkeit gehoert ans richtige Haus.
--
-- Regel wie in Teil 1: Die Excel-Nummer, deren Ort zum DB-Betrieb passt,
-- bleibt. Alle uebrigen wandern - an einen bestehenden Betrieb, sonst an
-- einen neu angelegten mit status='geschlossen'.
--
-- Zwei bewusste Entscheidungen:
--   * Halli Galli + Los Bar [Arosa] behaelt BEIDE Nummern (0011 Halli Galli
--     und 0616 Los) - der Betriebsname nennt beide Lokale.
--   * Arena Bar 2 [Flims] wird eigener Betrieb, obwohl am selben Ort wie
--     Arena [Flims] - im Excel sind es zwei getrennte Objekte.
--
-- Aufruf:
--   npx supabase db query --linked --file Datenbank/wartung/entwirren_mischbetriebe_teil2_2026_07_28.sql
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------- Snapshot
DROP TABLE IF EXISTS snapshot_mischbetriebe.reinigungen_vorher_t2;
DROP TABLE IF EXISTS snapshot_mischbetriebe.rechnungen_vorher_t2;
DROP TABLE IF EXISTS snapshot_mischbetriebe.betriebe_ids_vorher_t2;

CREATE TABLE snapshot_mischbetriebe.reinigungen_vorher_t2 AS
SELECT id, betrieb_id, anlage_id, extern_id FROM reinigungen WHERE extern_id IS NOT NULL;
CREATE TABLE snapshot_mischbetriebe.rechnungen_vorher_t2 AS
SELECT id, betrieb_id, rechnungsnummer FROM rechnungen;
CREATE TABLE snapshot_mischbetriebe.betriebe_ids_vorher_t2 AS
SELECT id FROM betriebe;

-- ------------------------------------------------- Erloschene Haeuser neu
INSERT INTO betriebe (id, user_id, name, ort, status, ist_mein_kunde, notizen)
SELECT v.id, (SELECT user_id FROM betriebe ORDER BY created_at LIMIT 1),
       v.name, v.ort, 'geschlossen', true,
       'Aus Historik-Import getrennt (28.07.2026, Teil 2), Betrieb besteht nicht mehr'
FROM (VALUES
  ('a2000000-0000-4000-8000-000000000371'::uuid, 'Arena Bar 2',    'Flims'),
  ('a2000000-0000-4000-8000-000000000468'::uuid, 'Arena',          'Klosters-Serneus'),
  ('a2000000-0000-4000-8000-000000000065'::uuid, 'Mühle',          'Davos'),
  ('a2000000-0000-4000-8000-000000000047'::uuid, 'Edelweiss',      'Chur'),
  ('a2000000-0000-4000-8000-000000000501'::uuid, 'Edelweiss',      'Triesenberg'),
  ('a2000000-0000-4000-8000-000000000146'::uuid, 'Sport',          'Klosters-Serneus'),
  ('a2000000-0000-4000-8000-000000000022'::uuid, 'Weisses Kreuz',  'Cazis'),
  ('a2000000-0000-4000-8000-000000000005'::uuid, 'Kulm',           'Arosa'),
  ('a2000000-0000-4000-8000-000000000174'::uuid, 'Kurhaus',        'Lenzerheide'),
  ('a2000000-0000-4000-8000-000000000042'::uuid, 'Merz Wiesental', 'Chur'),
  ('a2000000-0000-4000-8000-000000000061'::uuid, 'Parsenn',        'Conters im Prättigau'),
  ('a2000000-0000-4000-8000-000000000059'::uuid, 'Posthotel',      'Churwalden'),
  ('a2000000-0000-4000-8000-000000000699'::uuid, 'Rössli',         'Steinhausen'),
  ('a2000000-0000-4000-8000-000000000503'::uuid, 'Sonne',          'Krummenau'),
  ('a2000000-0000-4000-8000-000000000226'::uuid, 'Sonnenhalde',    'Davos'),
  ('a2000000-0000-4000-8000-000000000211'::uuid, 'Sonne',          'Thusis'),
  ('a2000000-0000-4000-8000-000000000153'::uuid, 'Sonne',          'Klosters-Serneus'),
  ('a2000000-0000-4000-8000-000000000235'::uuid, 'Waldhaus',       'Flims')
) AS v(id, name, ort)
WHERE NOT EXISTS (SELECT 1 FROM betriebe b WHERE b.id = v.id);

-- ------------------------------------------------------------- Zuordnung
INSERT INTO import.betrieb_mapping (nr, ziel_id, bemerkung) VALUES
  ('0371','a2000000-0000-4000-8000-000000000371','Arena Bar 2 Flims (neu)'),
  ('0468','a2000000-0000-4000-8000-000000000468','Arena Klosters (neu)'),
  ('0065','a2000000-0000-4000-8000-000000000065','Mühle Davos (neu)'),
  ('0047','a2000000-0000-4000-8000-000000000047','Edelweiss Chur (neu)'),
  ('0501','a2000000-0000-4000-8000-000000000501','Edelweiss Triesenberg (neu)'),
  ('0146','a2000000-0000-4000-8000-000000000146','Sport Klosters (neu)'),
  ('0022','a2000000-0000-4000-8000-000000000022','Weisses Kreuz Cazis (neu)'),
  ('0005','a2000000-0000-4000-8000-000000000005','Kulm Arosa (neu)'),
  ('0174','a2000000-0000-4000-8000-000000000174','Kurhaus Lenzerheide (neu)'),
  ('0042','a2000000-0000-4000-8000-000000000042','Merz Wiesental Chur (neu)'),
  ('0061','a2000000-0000-4000-8000-000000000061','Parsenn Conters (neu)'),
  ('0059','a2000000-0000-4000-8000-000000000059','Posthotel Churwalden (neu)'),
  ('0699','a2000000-0000-4000-8000-000000000699','Rössli Steinhausen (neu)'),
  ('0503','a2000000-0000-4000-8000-000000000503','Sonne Krummenau (neu)'),
  ('0226','a2000000-0000-4000-8000-000000000226','Sonnenhalde Davos (neu)'),
  ('0211','a2000000-0000-4000-8000-000000000211','Sonne Thusis (neu)'),
  ('0153','a2000000-0000-4000-8000-000000000153','Sonne Klosters (neu)'),
  ('0235','a2000000-0000-4000-8000-000000000235','Waldhaus Flims (neu)'),
  ('0510',(SELECT id FROM betriebe WHERE name='Gemsli' AND ort='Mels'),'Gemsli Mels (bestehend)'),
  ('0285',(SELECT id FROM betriebe WHERE name='Rätia'  AND ort='Filisur'),'Rätia Filisur (bestehend)')
ON CONFLICT (nr) DO NOTHING;

-- ------------------------------------------------ Reinigungen umhaengen
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

-- ----------------------------------------------- Anlagenbezug nachtragen
WITH rang AS (
  SELECT a.id, a.betrieb_id,
         row_number() OVER (PARTITION BY a.betrieb_id ORDER BY a.created_at, a.id) AS pos
  FROM anlagen a)
UPDATE reinigungen r
SET anlage_id = rang.id, updated_at = now()
FROM rang
WHERE r.anlage_id IS NULL AND r.extern_id IS NOT NULL
  AND rang.betrieb_id = r.betrieb_id
  AND rang.pos = nullif(split_part(r.extern_id, '_', 5), '')::int;

COMMIT;

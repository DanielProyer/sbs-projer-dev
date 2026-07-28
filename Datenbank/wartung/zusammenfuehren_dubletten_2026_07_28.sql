-- ============================================================================
-- Betriebs-Dubletten zusammenfuehren (28.07.2026)
-- ============================================================================
-- Sechs Betriebe standen doppelt in der App: einmal unter dem alten Namen aus
-- dem Excel (dort haengt die Historie), einmal unter dem heutigen Namen (dort
-- steht die heineken_nr). Von Daniel bestaetigt: jeweils derselbe Betrieb.
--
--   0113  Center da sport e cultura [Disentis/Muster]  ->  Center Fontauna [Disentis]
--   0372  WG Giovadin [Davos]                          ->  Giodavin [Davos Platz]
--   0183  Gipfelbar Setz Nair [Obersaxen]              ->  Sezner [Obersaxen Meierhof]
--   0161  Crap Sogn Gion [Laax]                        ->  Capalari [Laax]
--   0082  Vaillant Arena [Davos]                       ->  Eisstadion Davos [Davos]
--   0788  Tapas Bar [Bad Ragaz]                        ->  Paloma Vino & Tapas [Bad Ragaz]
--
-- Umgehaengt werden ALLE Verweise (nicht nur Reinigungen), danach wird der
-- alte Datensatz geloescht - aber nur, wenn wirklich nichts mehr daran haengt.
--
-- Aufruf:
--   npx supabase db query --linked --file Datenbank/wartung/zusammenfuehren_dubletten_2026_07_28.sql
-- ============================================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS snapshot_dubletten;
DROP TABLE IF EXISTS snapshot_dubletten.paare;
DROP TABLE IF EXISTS snapshot_dubletten.reinigungen_vorher;
DROP TABLE IF EXISTS snapshot_dubletten.rechnungen_vorher;
DROP TABLE IF EXISTS snapshot_dubletten.betriebe_vorher;

CREATE TABLE snapshot_dubletten.paare AS
SELECT v.nr, q.id AS quelle_id, q.name AS quelle_name, q.ort AS quelle_ort,
       q.status AS quelle_status, q.ist_mein_kunde AS quelle_kunde, q.notizen AS quelle_notizen,
       z.id AS ziel_id, z.name AS ziel_name, z.ort AS ziel_ort
FROM (VALUES
  ('0113','Center da sport e cultura','Disentis/Muster'),
  ('0372','WG Giovadin','Davos'),
  ('0183','Gipfelbar Setz Nair','Obersaxen'),
  ('0161','Crap Sogn Gion','Laax'),
  ('0082','Vaillant Arena','Davos'),
  ('0788','Tapas Bar','Bad Ragaz')
) AS v(nr, qname, qort)
JOIN betriebe q ON q.name = v.qname AND q.ort = v.qort
JOIN betriebe z ON z.heineken_nr = v.nr AND z.id <> q.id;

CREATE TABLE snapshot_dubletten.reinigungen_vorher AS
SELECT id, betrieb_id, anlage_id FROM reinigungen
WHERE betrieb_id IN (SELECT quelle_id FROM snapshot_dubletten.paare);
CREATE TABLE snapshot_dubletten.rechnungen_vorher AS
SELECT id, betrieb_id FROM rechnungen
WHERE betrieb_id IN (SELECT quelle_id FROM snapshot_dubletten.paare);
CREATE TABLE snapshot_dubletten.betriebe_vorher AS
SELECT * FROM betriebe WHERE id IN (SELECT quelle_id FROM snapshot_dubletten.paare);

-- Alle Verweise umhaengen
UPDATE anlagen                 t SET betrieb_id = p.ziel_id FROM snapshot_dubletten.paare p WHERE t.betrieb_id = p.quelle_id;
UPDATE bergkundenpauschalen    t SET betrieb_id = p.ziel_id FROM snapshot_dubletten.paare p WHERE t.betrieb_id = p.quelle_id;
UPDATE betrieb_rechnungsadressen t SET betrieb_id = p.ziel_id FROM snapshot_dubletten.paare p WHERE t.betrieb_id = p.quelle_id;
UPDATE eigenauftraege          t SET betrieb_id = p.ziel_id FROM snapshot_dubletten.paare p WHERE t.betrieb_id = p.quelle_id;
UPDATE eroeffnungsreinigungen  t SET betrieb_id = p.ziel_id FROM snapshot_dubletten.paare p WHERE t.betrieb_id = p.quelle_id;
UPDATE events                  t SET betrieb_id = p.ziel_id FROM snapshot_dubletten.paare p WHERE t.betrieb_id = p.quelle_id;
UPDATE kontakte                t SET betrieb_id = p.ziel_id FROM snapshot_dubletten.paare p WHERE t.betrieb_id = p.quelle_id;
UPDATE montagen                t SET betrieb_id = p.ziel_id FROM snapshot_dubletten.paare p WHERE t.betrieb_id = p.quelle_id;
UPDATE rechnungen              t SET betrieb_id = p.ziel_id, updated_at = now() FROM snapshot_dubletten.paare p WHERE t.betrieb_id = p.quelle_id;
UPDATE stoerungen              t SET betrieb_id = p.ziel_id FROM snapshot_dubletten.paare p WHERE t.betrieb_id = p.quelle_id;
UPDATE termine                 t SET betrieb_id = p.ziel_id FROM snapshot_dubletten.paare p WHERE t.betrieb_id = p.quelle_id;
UPDATE reinigungen             t SET betrieb_id = p.ziel_id, updated_at = now() FROM snapshot_dubletten.paare p WHERE t.betrieb_id = p.quelle_id;

-- Anlagenbezug setzen, wo das Ziel genau eine Anlage hat
UPDATE reinigungen r
SET anlage_id = (SELECT a.id FROM anlagen a WHERE a.betrieb_id = r.betrieb_id
                   AND (SELECT count(*) FROM anlagen a2 WHERE a2.betrieb_id = r.betrieb_id) = 1 LIMIT 1)
WHERE r.anlage_id IS NULL
  AND r.betrieb_id IN (SELECT ziel_id FROM snapshot_dubletten.paare);

-- Alte Datensaetze entfernen (nur wenn nichts mehr daran haengt)
DELETE FROM betriebe b
WHERE b.id IN (SELECT quelle_id FROM snapshot_dubletten.paare)
  AND NOT EXISTS (SELECT 1 FROM reinigungen x WHERE x.betrieb_id = b.id)
  AND NOT EXISTS (SELECT 1 FROM rechnungen x WHERE x.betrieb_id = b.id)
  AND NOT EXISTS (SELECT 1 FROM anlagen x WHERE x.betrieb_id = b.id)
  AND NOT EXISTS (SELECT 1 FROM stoerungen x WHERE x.betrieb_id = b.id)
  AND NOT EXISTS (SELECT 1 FROM montagen x WHERE x.betrieb_id = b.id)
  AND NOT EXISTS (SELECT 1 FROM kontakte x WHERE x.betrieb_id = b.id)
  AND NOT EXISTS (SELECT 1 FROM termine x WHERE x.betrieb_id = b.id)
  AND NOT EXISTS (SELECT 1 FROM events x WHERE x.betrieb_id = b.id)
  AND NOT EXISTS (SELECT 1 FROM eigenauftraege x WHERE x.betrieb_id = b.id)
  AND NOT EXISTS (SELECT 1 FROM eroeffnungsreinigungen x WHERE x.betrieb_id = b.id)
  AND NOT EXISTS (SELECT 1 FROM bergkundenpauschalen x WHERE x.betrieb_id = b.id)
  AND NOT EXISTS (SELECT 1 FROM betrieb_rechnungsadressen x WHERE x.betrieb_id = b.id);

COMMIT;

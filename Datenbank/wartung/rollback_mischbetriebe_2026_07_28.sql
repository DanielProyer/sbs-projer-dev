-- ============================================================================
-- ROLLBACK Mischbetriebe-Entwirrung vom 28.07.2026
-- ============================================================================
-- Setzt Reinigungen und Rechnungen auf die Betriebszuordnung von vor dem
-- Umhaengen zurueck und entfernt die zehn neu angelegten (geschlossenen)
-- Betriebe wieder - aber nur, wenn nichts mehr an ihnen haengt.
--
-- Aufruf:
--   npx supabase db query --linked --file Datenbank/wartung/rollback_mischbetriebe_2026_07_28.sql
-- ============================================================================

BEGIN;

UPDATE reinigungen r
SET betrieb_id = v.betrieb_id, anlage_id = v.anlage_id, updated_at = now()
FROM snapshot_mischbetriebe.reinigungen_vorher v
WHERE r.id = v.id
  AND (r.betrieb_id IS DISTINCT FROM v.betrieb_id OR r.anlage_id IS DISTINCT FROM v.anlage_id);

UPDATE rechnungen r
SET betrieb_id = v.betrieb_id, updated_at = now()
FROM snapshot_mischbetriebe.rechnungen_vorher v
WHERE r.id = v.id AND r.betrieb_id IS DISTINCT FROM v.betrieb_id;

-- Bergkundenpauschalen zurueck an Alpina Breil/Brigels
UPDATE bergkundenpauschalen
SET betrieb_id = (SELECT id FROM betriebe WHERE name = 'Alpina' AND ort = 'Breil/Brigels')
WHERE betrieb_id = 'a1000000-0000-4000-8000-000000000506';

-- Neu angelegte Betriebe entfernen (nur wenn leer)
DELETE FROM betriebe b
WHERE b.id NOT IN (SELECT id FROM snapshot_mischbetriebe.betriebe_ids_vorher)
  AND NOT EXISTS (SELECT 1 FROM reinigungen x WHERE x.betrieb_id = b.id)
  AND NOT EXISTS (SELECT 1 FROM rechnungen x WHERE x.betrieb_id = b.id)
  AND NOT EXISTS (SELECT 1 FROM anlagen x WHERE x.betrieb_id = b.id)
  AND NOT EXISTS (SELECT 1 FROM bergkundenpauschalen x WHERE x.betrieb_id = b.id);

COMMIT;

-- Kontrolle: muss ueberall 0 zeigen
SELECT (SELECT count(*) FROM reinigungen r JOIN snapshot_mischbetriebe.reinigungen_vorher v ON v.id = r.id
         WHERE r.betrieb_id IS DISTINCT FROM v.betrieb_id) AS reinigungen_abweichend,
       (SELECT count(*) FROM rechnungen r JOIN snapshot_mischbetriebe.rechnungen_vorher v ON v.id = r.id
         WHERE r.betrieb_id IS DISTINCT FROM v.betrieb_id) AS rechnungen_abweichend,
       (SELECT count(*) FROM betriebe WHERE id NOT IN (SELECT id FROM snapshot_mischbetriebe.betriebe_ids_vorher)) AS neue_betriebe_uebrig;

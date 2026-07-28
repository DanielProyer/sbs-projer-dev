-- ============================================================================
-- ROLLBACK Mischbetriebe-Entwirrung Teil 2 vom 28.07.2026
-- ============================================================================
-- Aufruf:
--   npx supabase db query --linked --file Datenbank/wartung/rollback_mischbetriebe_teil2_2026_07_28.sql
-- ============================================================================

BEGIN;

UPDATE reinigungen r
SET betrieb_id = v.betrieb_id, anlage_id = v.anlage_id, updated_at = now()
FROM snapshot_mischbetriebe.reinigungen_vorher_t2 v
WHERE r.id = v.id
  AND (r.betrieb_id IS DISTINCT FROM v.betrieb_id OR r.anlage_id IS DISTINCT FROM v.anlage_id);

UPDATE rechnungen r
SET betrieb_id = v.betrieb_id, updated_at = now()
FROM snapshot_mischbetriebe.rechnungen_vorher_t2 v
WHERE r.id = v.id AND r.betrieb_id IS DISTINCT FROM v.betrieb_id;

DELETE FROM import.betrieb_mapping WHERE bemerkung LIKE '%(neu)' AND nr IN
  ('0371','0468','0065','0047','0501','0146','0022','0005','0174','0042',
   '0061','0059','0699','0503','0226','0211','0153','0235');
DELETE FROM import.betrieb_mapping WHERE nr IN ('0510','0285');

DELETE FROM betriebe b
WHERE b.id NOT IN (SELECT id FROM snapshot_mischbetriebe.betriebe_ids_vorher_t2)
  AND NOT EXISTS (SELECT 1 FROM reinigungen x WHERE x.betrieb_id = b.id)
  AND NOT EXISTS (SELECT 1 FROM rechnungen x WHERE x.betrieb_id = b.id)
  AND NOT EXISTS (SELECT 1 FROM anlagen x WHERE x.betrieb_id = b.id)
  AND NOT EXISTS (SELECT 1 FROM bergkundenpauschalen x WHERE x.betrieb_id = b.id);

COMMIT;

-- Kontrolle: muss ueberall 0 zeigen
SELECT (SELECT count(*) FROM reinigungen r JOIN snapshot_mischbetriebe.reinigungen_vorher_t2 v ON v.id = r.id
         WHERE r.betrieb_id IS DISTINCT FROM v.betrieb_id) AS reinigungen_abweichend,
       (SELECT count(*) FROM rechnungen r JOIN snapshot_mischbetriebe.rechnungen_vorher_t2 v ON v.id = r.id
         WHERE r.betrieb_id IS DISTINCT FROM v.betrieb_id) AS rechnungen_abweichend,
       (SELECT count(*) FROM betriebe WHERE id NOT IN (SELECT id FROM snapshot_mischbetriebe.betriebe_ids_vorher_t2)) AS neue_betriebe_uebrig;

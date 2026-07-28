-- ============================================================================
-- ROLLBACK Nachtrag Anlagenbezug + QR-Referenzen vom 28.07.2026
-- ============================================================================
-- Aufruf:
--   npx supabase db query --linked --file Datenbank/wartung/rollback_anlagen_und_qr_2026_07_28.sql
-- ============================================================================

BEGIN;

UPDATE reinigungen r
SET anlage_id = v.anlage_id, updated_at = now()
FROM snapshot_nachtrag.reinigungen_anlage_vorher v
WHERE r.id = v.id AND r.anlage_id IS DISTINCT FROM v.anlage_id;

UPDATE rechnungen r
SET qr_referenz = v.qr_referenz, updated_at = now()
FROM snapshot_nachtrag.rechnungen_qr_vorher v
WHERE r.id = v.id AND r.qr_referenz IS DISTINCT FROM v.qr_referenz;

COMMIT;

-- Kontrolle: muss beide Male 0 zeigen
SELECT (SELECT count(*) FROM reinigungen r JOIN snapshot_nachtrag.reinigungen_anlage_vorher v ON v.id = r.id
         WHERE r.anlage_id IS NOT NULL) AS anlagen_noch_gesetzt,
       (SELECT count(*) FROM rechnungen r JOIN snapshot_nachtrag.rechnungen_qr_vorher v ON v.id = r.id
         WHERE r.qr_referenz IS NOT NULL) AS qr_noch_gesetzt;

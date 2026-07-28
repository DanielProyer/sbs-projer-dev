-- ============================================================================
-- ROLLBACK Zusammenfuehrung der Betriebs-Dubletten vom 28.07.2026
-- ============================================================================
-- Legt die sechs geloeschten Betriebe wieder an (aus dem Snapshot) und haengt
-- Reinigungen und Rechnungen zurueck. Andere Verweise (Stoerungen, Montagen)
-- muessten von Hand nachgezogen werden - sie stehen im Snapshot nicht drin.
--
-- Aufruf:
--   npx supabase db query --linked --file Datenbank/wartung/rollback_dubletten_2026_07_28.sql
-- ============================================================================

BEGIN;

INSERT INTO betriebe SELECT * FROM snapshot_dubletten.betriebe_vorher
ON CONFLICT (id) DO NOTHING;

UPDATE reinigungen r
SET betrieb_id = v.betrieb_id, anlage_id = v.anlage_id, updated_at = now()
FROM snapshot_dubletten.reinigungen_vorher v
WHERE r.id = v.id AND r.betrieb_id IS DISTINCT FROM v.betrieb_id;

UPDATE rechnungen r
SET betrieb_id = v.betrieb_id, updated_at = now()
FROM snapshot_dubletten.rechnungen_vorher v
WHERE r.id = v.id AND r.betrieb_id IS DISTINCT FROM v.betrieb_id;

COMMIT;

-- Kontrolle: muss 6 Betriebe und 0 Abweichungen zeigen
SELECT (SELECT count(*) FROM betriebe b JOIN snapshot_dubletten.paare p ON p.quelle_id = b.id) AS betriebe_zurueck,
       (SELECT count(*) FROM reinigungen r JOIN snapshot_dubletten.reinigungen_vorher v ON v.id = r.id
         WHERE r.betrieb_id IS DISTINCT FROM v.betrieb_id) AS reinigungen_abweichend,
       (SELECT count(*) FROM rechnungen r JOIN snapshot_dubletten.rechnungen_vorher v ON v.id = r.id
         WHERE r.betrieb_id IS DISTINCT FROM v.betrieb_id) AS rechnungen_abweichend;

-- ============================================================================
-- ROLLBACK Reinigungspreis-Korrektur vom 28.07.2026
-- ============================================================================
-- ACHTUNG: Auf reinigungen liegt der Trigger reinigung_preis_berechnung. Er
-- rechnet preis_netto/mwst/brutto bei jedem UPDATE neu aus Grundtarif und
-- Hahn-Anzahl. Der Rollback setzt daher zuerst die Mengen zurueck - danach
-- errechnet der Trigger wieder die alten (falschen) Betraege von selbst.
--
-- Aufruf:
--   npx supabase db query --linked --file Datenbank/wartung/rollback_reinigungspreise_2026_07_28.sql
-- ============================================================================

BEGIN;

UPDATE reinigungen r
SET anzahl_haehne_eigen            = v.anzahl_haehne_eigen,
    anzahl_haehne_fremd            = v.anzahl_haehne_fremd,
    anzahl_haehne_anderer_standort = v.anzahl_haehne_anderer_standort,
    preis_grundtarif    = v.preis_grundtarif,
    preis_zusatz_haehne = v.preis_zusatz_haehne,
    preis_netto  = v.preis_netto,
    preis_mwst   = v.preis_mwst,
    preis_brutto = v.preis_brutto,
    mwst_satz    = v.mwst_satz,
    updated_at   = v.updated_at
FROM snapshot_reinigungspreise.vorher v
WHERE r.id = v.id
  AND (r.preis_brutto IS DISTINCT FROM v.preis_brutto
    OR r.anzahl_haehne_eigen IS DISTINCT FROM v.anzahl_haehne_eigen);

COMMIT;

-- Kontrolle: muss 0 zeigen
SELECT count(*) AS abweichend
FROM reinigungen r JOIN snapshot_reinigungspreise.vorher v ON v.id = r.id
WHERE r.preis_brutto IS DISTINCT FROM v.preis_brutto;

-- ============================================================================
-- ROLLBACK camt-Test vom 28.07.2026
-- ============================================================================
-- Setzt die Buchhaltung auf den Stand VOR dem camt-Test zurueck.
-- Wiederherstellungspunkt: Schema snapshot_camt_test, Zeitmarke 28.07.2026 12:48:49 UTC.
--
-- WIRD ZURUECKGESETZT
--   * camt-Zahlungsbuchungen, die der Test erzeugt hat
--   * Zahlungsstatus / Zahlungsdaten / Mahnstufen der Rechnungen
--   * camt-Pruefliste
--   * Eingangsrechnungen (Status/Zuordnung)
--   * camt-Dateien, die der Test importiert hat
--
-- BLEIBT BEWUSST ERHALTEN (Lerneffekt, Wunsch Daniel 28.07.2026)
--   * betriebe.zahler_aliase   -- gelernte Zahlernamen
--   * camt_regel               -- gelernte Zuordnungsregeln fuer Ausgaben
--
-- ABGRENZUNG: Es werden NUR camt-bezogene Buchungen geloescht (camt_tx_key
-- gesetzt oder beleg_typ zahlung/camt053). Buchungen aus normaler Arbeit
-- waehrend des Tests - etwa ein Reinigungsabschluss - bleiben unberuehrt.
--
-- Aufruf:
--   npx supabase db query --linked --file Datenbank/wartung/rollback_camt_test_2026_07_28.sql
-- ============================================================================

BEGIN;

-- 1) Beleg-Verknuepfungen der zu loeschenden Buchungen
DELETE FROM buchungs_belege bb
WHERE bb.buchung_id IN (
  SELECT b.id FROM buchungen b
  WHERE b.id NOT IN (SELECT id FROM snapshot_camt_test.buchungen_ids_vorher)
    AND (b.camt_tx_key IS NOT NULL OR b.beleg_typ IN ('zahlung', 'camt053'))
);

-- 2) camt-Buchungen des Tests
DELETE FROM buchungen b
WHERE b.id NOT IN (SELECT id FROM snapshot_camt_test.buchungen_ids_vorher)
  AND (b.camt_tx_key IS NOT NULL OR b.beleg_typ IN ('zahlung', 'camt053'));

-- 3) Rechnungen: Zahlungs- und Mahnfelder auf den Snapshot zuruecksetzen
UPDATE rechnungen r
SET zahlungsstatus        = v.zahlungsstatus,
    zahlung_eingegangen_am = v.zahlung_eingegangen_am,
    zahlung_betrag        = v.zahlung_betrag,
    zahlung_beleg_pfad    = v.zahlung_beleg_pfad,
    mahnung_stufe         = v.mahnung_stufe,
    letzte_mahnung_am     = v.letzte_mahnung_am,
    notizen               = v.notizen,
    updated_at            = now()
FROM snapshot_camt_test.rechnungen_vorher v
WHERE r.id = v.id
  AND (r.zahlungsstatus        IS DISTINCT FROM v.zahlungsstatus
    OR r.zahlung_eingegangen_am IS DISTINCT FROM v.zahlung_eingegangen_am
    OR r.zahlung_betrag        IS DISTINCT FROM v.zahlung_betrag
    OR r.zahlung_beleg_pfad    IS DISTINCT FROM v.zahlung_beleg_pfad
    OR r.mahnung_stufe         IS DISTINCT FROM v.mahnung_stufe
    OR r.letzte_mahnung_am     IS DISTINCT FROM v.letzte_mahnung_am
    OR r.notizen               IS DISTINCT FROM v.notizen);

-- 4) camt-Pruefliste komplett auf den Snapshot zuruecksetzen
DELETE FROM camt_pruefliste;
INSERT INTO camt_pruefliste SELECT * FROM snapshot_camt_test.pruefliste_vorher;

-- 5) Eingangsrechnungen komplett auf den Snapshot zuruecksetzen
DELETE FROM eingangsrechnung;
INSERT INTO eingangsrechnung SELECT * FROM snapshot_camt_test.eingangsrechnung_vorher;

-- 6) camt-Dateien, die der Test importiert hat
--    (Storage-Dateien bleiben liegen -> Einstellungen > Speicher aufraeumen)
DELETE FROM camt_dateien
WHERE id NOT IN (SELECT id FROM snapshot_camt_test.camt_dateien_ids_vorher);

COMMIT;

-- Kontrolle: muss die Werte von vor dem Test zeigen
SELECT
  round(sum(CASE WHEN soll_konto = 1020 THEN betrag_brutto
                 WHEN haben_konto = 1020 THEN -betrag_brutto ELSE 0 END), 2) AS bank_erwartet_3322_26,
  (SELECT count(*) FROM buchungen WHERE camt_tx_key IS NOT NULL) AS camt_buchungen_erwartet_0,
  (SELECT count(*) FROM camt_pruefliste) AS pruefliste_erwartet_4,
  (SELECT count(*) FROM betriebe WHERE array_length(zahler_aliase,1) > 0) AS aliase_bleiben,
  (SELECT count(*) FROM camt_regel) AS regeln_bleiben
FROM buchungen WHERE NOT ist_storniert;

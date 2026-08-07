-- ============================================================================
-- ROLLBACK camt-Kundenzahlungs-Abgleich (eingerichtet 07.08.2026, v0.72.15)
-- ============================================================================
-- Ausgangslage bei Einrichtung: 0 Buchungen mit camt_tx_key in der ganzen DB.
-- Damit gilt: JEDE Buchung mit camt_tx_key stammt aus dem Abgleich ab dem
-- 07.08.2026 und kann gefahrlos komplett zurückgerollt werden.
--
-- Snapshot (Migration snapshot_camt_abgleich_2026_08_07):
--   snapshot_camt_abgleich.rechnungen_vorher   — Zahlfelder ALLER Rechnungen
--   snapshot_camt_abgleich.pruefliste_vorher   — camt_pruefliste komplett
--
-- Einzelfall-Korrektur (falsch zugeordnete Zahlung): NICHT dieses Skript,
-- sondern in der App: Rechnung öffnen → «Zahlung rückgängig (Bankabgleich)».
--
-- VOR dem Ausführen: Umfang ansehen!
-- ============================================================================

-- 0) Kontrolle: Was würde zurückgerollt?
SELECT COUNT(*) AS camt_buchungen, COALESCE(SUM(betrag_brutto),0) AS summe
FROM buchungen WHERE camt_tx_key IS NOT NULL;

SELECT COUNT(*) AS rechnungen_neu_bezahlt
FROM rechnungen r
JOIN snapshot_camt_abgleich.rechnungen_vorher s ON s.id = r.id
WHERE r.zahlungsstatus = 'bezahlt' AND s.zahlungsstatus <> 'bezahlt';

-- ============================================================================
-- 1) Alle Abgleich-Buchungen löschen (inkl. Differenz-/Mehrzahlungs-Zeilen —
--    auch die tragen den camt_tx_key ihrer Zahlung).
-- ============================================================================
-- DELETE FROM buchungen WHERE camt_tx_key IS NOT NULL;

-- ============================================================================
-- 2) Rechnungs-Zahlfelder auf den Snapshot-Stand zurücksetzen
--    (nur Zeilen, die sich seither geändert haben).
-- ============================================================================
-- UPDATE rechnungen r
-- SET zahlungsstatus        = s.zahlungsstatus,
--     zahlung_eingegangen_am = s.zahlung_eingegangen_am,
--     zahlung_betrag         = s.zahlung_betrag
-- FROM snapshot_camt_abgleich.rechnungen_vorher s
-- WHERE s.id = r.id
--   AND (r.zahlungsstatus IS DISTINCT FROM s.zahlungsstatus
--     OR r.zahlung_eingegangen_am IS DISTINCT FROM s.zahlung_eingegangen_am
--     OR r.zahlung_betrag IS DISTINCT FROM s.zahlung_betrag);

-- ============================================================================
-- 3) Prüfliste auf Snapshot-Stand (optional — nur wenn auch Prüflisten-
--    Aktionen zurück sollen; geparkte «Später klären»-Einträge gehen dabei
--    verloren).
-- ============================================================================
-- DELETE FROM camt_pruefliste;
-- INSERT INTO camt_pruefliste
-- SELECT id, user_id, tx_key, booking_datum, betrag, ist_gutschrift,
--        partei_name, referenz, kategorie, vorschlag_json, status, fehlertext,
--        created_at, updated_at, partei_iban, beleg_ref
-- FROM snapshot_camt_abgleich.pruefliste_vorher;

-- ============================================================================
-- 4) Verifikation nach dem Rollback
-- ============================================================================
-- SELECT COUNT(*) FROM buchungen WHERE camt_tx_key IS NOT NULL;  -- muss 0 sein
-- SELECT COUNT(*) FROM rechnungen r
-- JOIN snapshot_camt_abgleich.rechnungen_vorher s ON s.id = r.id
-- WHERE r.zahlungsstatus IS DISTINCT FROM s.zahlungsstatus;      -- muss 0 sein

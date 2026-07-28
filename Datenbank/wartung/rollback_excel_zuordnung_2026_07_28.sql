-- ============================================================================
-- ROLLBACK Excel-Zahlungszuordnung vom 28.07.2026
-- ============================================================================
-- Macht die Statussetzung der 147 Rechnungen rueckgaengig, die aus dem Sheet
-- 'Reinigung' (Spalte Einzahlungsdatum) als bezahlt uebernommen wurden.
--
-- Es wurden KEINE Buchungen erzeugt - die Geldseite stand bereits durch den
-- Excel-Delta-Import. Daher setzt der Rollback nur die Zahlungsfelder zurueck.
--
-- Aufruf:
--   npx supabase db query --linked --file Datenbank/wartung/rollback_excel_zuordnung_2026_07_28.sql
-- ============================================================================

BEGIN;

UPDATE rechnungen r
SET zahlungsstatus         = v.zahlungsstatus,
    zahlung_eingegangen_am = v.zahlung_eingegangen_am,
    zahlung_betrag         = v.zahlung_betrag,
    updated_at             = now()
FROM snapshot_excel_zuordnung.rechnungen_vorher v
WHERE r.id = v.id
  AND r.zahlungsstatus IS DISTINCT FROM v.zahlungsstatus;

COMMIT;

-- Kontrolle: muss 1581 offene Rechnungen und unveraenderte Salden zeigen
SELECT (SELECT count(*) FROM rechnungen WHERE zahlungsstatus = 'offen') AS offen_erwartet_1581,
       round((SELECT sum(CASE WHEN soll_konto = 1020 THEN betrag_brutto
                              WHEN haben_konto = 1020 THEN -betrag_brutto ELSE 0 END)
              FROM buchungen WHERE NOT ist_storniert), 2) AS bank_erwartet_3322_26,
       round((SELECT sum(CASE WHEN soll_konto = 1100 THEN betrag_brutto
                              WHEN haben_konto = 1100 THEN -betrag_brutto ELSE 0 END)
              FROM buchungen WHERE NOT ist_storniert), 2) AS debitoren_erwartet_176228_04;

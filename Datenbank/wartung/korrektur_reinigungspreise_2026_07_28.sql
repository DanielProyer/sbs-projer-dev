-- ============================================================================
-- Reinigungspreise + Hahn-Anzahl aus dem Excel korrigieren (28.07.2026)
-- ============================================================================
-- Gemeldet von Daniel: Lindemann's Over Time, Reinigung 21.11.2025 zeigt
-- CHF 74.60, das Protokoll aber 113.50. Der Betrieb hat 7 Haehne, nie weniger
-- als 3 - der Grundtarif allein kann nicht stimmen.
--
-- URSACHE (nicht die Arbeiten von heute): Der Historik-Import vom 19.06.2026
-- hat die Hahn-Spalten des Excel nie uebernommen. Alle 7'786 importierten
-- Reinigungen 2019-2025 haben anzahl_haehne = 0 und preis_zusatz_haehne = 0.
-- Fuer 2019-2024 wurde der Betrag trotzdem aus dem Excel uebernommen und ist
-- korrekt; fuer 2025 wurde er aus dem Grundtarif neu gerechnet - dort fehlen
-- die Zuschlaege (858 Reinigungen, CHF 8'542.37 zu niedrig).
--
-- Die RECHNUNGEN sind davon nicht betroffen: 458 der 459 betroffenen
-- Reinigungen mit Rechnung tragen den korrekten Excel-Betrag.
--
-- MWST: 7.7 % bis 31.12.2023, 8.1 % ab 01.01.2024 (Wechsel per 01.01.2024,
-- Hinweis Daniel). Brutto und Netto kommen beide aus dem Excel (Spalten
-- 'Total mit MwSt' / 'Total ohne MwSt'), die MwSt ist deren Differenz - so
-- bleiben auch die 89 Zeilen mit Rabatt/Sonderposition in sich stimmig.
--
-- Aufruf:
--   npx supabase db query --linked --file Datenbank/wartung/korrektur_reinigungspreise_2026_07_28.sql
-- ============================================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS snapshot_reinigungspreise;
DROP TABLE IF EXISTS snapshot_reinigungspreise.vorher;

CREATE TABLE snapshot_reinigungspreise.vorher AS
SELECT id, preis_brutto, preis_netto, preis_mwst, mwst_satz, preis_grundtarif,
       preis_zusatz_haehne, anzahl_haehne_eigen, anzahl_haehne_fremd,
       anzahl_haehne_anderer_standort, updated_at
FROM reinigungen WHERE extern_id IS NOT NULL;

UPDATE reinigungen r
SET preis_brutto = e.brutto,
    preis_netto  = e.netto,
    preis_mwst   = round(e.brutto - e.netto, 2),
    mwst_satz    = CASE WHEN r.datum < '2024-01-01' THEN 7.7 ELSE 8.1 END,
    -- Der Grundtarif wurde korrekt importiert (69.00 eigen / 92.00 fremd);
    -- der Rest des Netto ist der Hahn-Zuschlag. Deckt der Grundtarif das
    -- Netto nicht (Rabattfaelle), zaehlt das Netto als Grundtarif.
    preis_grundtarif    = CASE WHEN e.netto >= r.preis_grundtarif
                               THEN r.preis_grundtarif ELSE e.netto END,
    preis_zusatz_haehne = CASE WHEN e.netto >= r.preis_grundtarif
                               THEN round(e.netto - r.preis_grundtarif, 2) ELSE 0 END,
    anzahl_haehne_eigen            = e.hahn_eigen,
    anzahl_haehne_fremd            = e.hahn_fremd,
    anzahl_haehne_anderer_standort = e.hahn_standort,
    updated_at = now()
FROM import.einzahlung_excel e
WHERE e.extern_id = r.extern_id
  AND r.extern_id IS NOT NULL
  AND e.netto IS NOT NULL AND e.netto > 0
  AND (abs(e.brutto - r.preis_brutto) >= 0.02
    OR r.anzahl_haehne_eigen IS DISTINCT FROM e.hahn_eigen
    OR r.anzahl_haehne_fremd IS DISTINCT FROM e.hahn_fremd
    OR r.anzahl_haehne_anderer_standort IS DISTINCT FROM e.hahn_standort);

COMMIT;

-- ============================================================================
-- Nachtrag 28.07.2026: Anlagenbezug + QR-Referenzen
-- ============================================================================
-- TEIL A - Anlagenbezug der umgehaengten Reinigungen
--   Beim Entwirren der Mischbetriebe wurde anlage_id geleert, wo der
--   Zielbetrieb mehr als eine Anlage hat. Die Excel-ID traegt den
--   Anlagenindex an letzter Stelle (2024_09_26_0195_01). Eine Stichprobe
--   ueber 93 bestehende Zuordnungen zeigt: der Index entspricht in 92 von
--   93 Faellen der Reihenfolge, in der die Anlagen angelegt wurden.
--
-- TEIL B - QR-Referenz fuer offene Rechnungen ohne Referenz
--   Bis etwa Juni 2026 wurde keine SCOR-Referenz auf die Rechnung
--   geschrieben, daher greift der deterministische camt-Abgleich dort nicht.
--   Rueckwirkend hilft das nichts (auf dem versendeten Einzahlungsschein
--   stand keine Referenz), aber jede kuenftige Mahnung und jeder
--   Nachversand traegt sie dann - und solche Zahlungen matchen automatisch.
--
--   Bildungsregel wie im Repository: SCOR aus den Ziffern der
--   Rechnungsnummer. NUR fuer App-Rechnungsnummern (Format 2026-04-0125):
--   die Historik-Nummern (011_2019_05_02_0042_00006785) ergaeben eine
--   27-stellige Referenz - SCOR erlaubt hoechstens 25 Zeichen.
--
-- Aufruf:
--   npx supabase db query --linked --file Datenbank/wartung/anlagen_und_qr_nachtrag_2026_07_28.sql
-- ============================================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS snapshot_nachtrag;
DROP TABLE IF EXISTS snapshot_nachtrag.reinigungen_anlage_vorher;
DROP TABLE IF EXISTS snapshot_nachtrag.rechnungen_qr_vorher;

CREATE TABLE snapshot_nachtrag.reinigungen_anlage_vorher AS
SELECT id, anlage_id FROM reinigungen WHERE extern_id IS NOT NULL AND anlage_id IS NULL;

CREATE TABLE snapshot_nachtrag.rechnungen_qr_vorher AS
SELECT id, qr_referenz FROM rechnungen WHERE qr_referenz IS NULL OR qr_referenz = '';

-- ------------------------------------------------------ TEIL A: Anlagen
WITH rang AS (
  SELECT a.id, a.betrieb_id,
         row_number() OVER (PARTITION BY a.betrieb_id ORDER BY a.created_at, a.id) AS pos
  FROM anlagen a)
UPDATE reinigungen r
SET anlage_id = rang.id, updated_at = now()
FROM rang
WHERE r.anlage_id IS NULL
  AND r.extern_id IS NOT NULL
  AND rang.betrieb_id = r.betrieb_id
  AND rang.pos = nullif(split_part(r.extern_id, '_', 5), '')::int;

-- -------------------------------------------------- TEIL B: QR-Referenz
UPDATE rechnungen r
SET qr_referenz = 'RF'
      || lpad((98 - ((regexp_replace(r.rechnungsnummer, '\D', '', 'g') || '271500')::numeric % 97))::text, 2, '0')
      || regexp_replace(r.rechnungsnummer, '\D', '', 'g'),
    updated_at = now()
WHERE r.zahlungsstatus = 'offen'
  AND (r.qr_referenz IS NULL OR r.qr_referenz = '')
  AND r.rechnungstyp IN ('kundenrechnung', 'jahresrechnung')
  AND r.rechnungsnummer ~ '^[0-9]{4}-[0-9]{2}-[0-9]+$'   -- nur App-Nummern
  AND length(regexp_replace(r.rechnungsnummer, '\D', '', 'g')) <= 21;

COMMIT;

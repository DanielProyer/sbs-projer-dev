-- ============================================================================
-- ROLLBACK Zusatzanlagen-Zusammenfuehrung vom 28.07.2026
-- ============================================================================
-- Stellt die 198 geloeschten Zusatzzeilen wieder her und setzt anlage_ids der
-- 158 Hauptreinigungen zurueck. Der Preis-Trigger wird dabei ausgesetzt,
-- damit die wiederhergestellten Betraege exakt so zurueckkommen.
--
-- Aufruf:
--   npx supabase db query --linked --file Datenbank/wartung/rollback_zusatzanlagen_2026_07_28.sql
-- ============================================================================

BEGIN;
ALTER TABLE reinigungen DISABLE TRIGGER reinigung_preis_berechnung;

INSERT INTO reinigungen SELECT * FROM snapshot_zusatzanlagen.geloescht
ON CONFLICT (id) DO NOTHING;

UPDATE reinigungen r
SET anlage_ids = v.anlage_ids, updated_at = v.updated_at
FROM snapshot_zusatzanlagen.haupt_vorher v
WHERE r.id = v.id AND r.anlage_ids IS DISTINCT FROM v.anlage_ids;

-- Restfaelle (zweiter Lauf): Preise und Anlagenliste zurueck
INSERT INTO reinigungen SELECT * FROM snapshot_zusatzanlagen.rest_vorher
ON CONFLICT (id) DO NOTHING;

UPDATE reinigungen r
SET preis_grundtarif = v.preis_grundtarif, preis_zusatz_haehne = v.preis_zusatz_haehne,
    preis_netto = v.preis_netto, preis_mwst = v.preis_mwst, preis_brutto = v.preis_brutto,
    notizen = v.notizen, updated_at = v.updated_at
FROM snapshot_zusatzanlagen.rest_vorher v
WHERE r.id = v.id AND r.preis_brutto IS DISTINCT FROM v.preis_brutto;

ALTER TABLE reinigungen ENABLE TRIGGER reinigung_preis_berechnung;
COMMIT;

-- Kontrolle: muss 198 und 0 zeigen
SELECT (SELECT count(*) FROM reinigungen r JOIN snapshot_zusatzanlagen.geloescht g ON g.id = r.id) AS wiederhergestellt,
       (SELECT count(*) FROM reinigungen r JOIN snapshot_zusatzanlagen.haupt_vorher v ON v.id = r.id
         WHERE r.anlage_ids IS DISTINCT FROM v.anlage_ids) AS anlage_ids_abweichend;

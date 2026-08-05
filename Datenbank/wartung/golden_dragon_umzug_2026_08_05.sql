-- Anlage «Golden Dragon» von Grischa [Davos] zu Golden Dragon [Davos Platz]
-- Ausgeführt am 05.08.2026 via Supabase MCP (Auftrag Daniel: «zwei getrennte
-- Betriebe, bis jetzt falsch im Datenmodell»).
--
-- Befund vorher:
--   Grischa, Davos (0096):        3 Anlagen (Pulsa 1, Pulsa 2, Golden Dragon),
--                                 59 Reinigungen
--   Golden Dragon, Davos Pl. (0364): 0 Anlagen, 54 Reinigungen (Historik-
--                                 Import 2019–03/2026, alle ohne anlage_id)
--   An der Anlage hing genau EINE Reinigung: 04.06.2026 Eröffnungsservice
--   143.75, verbucht auf Grischa, mit Rechnung 2026-06-0660 (offen) und
--   2 Buchungen (1100/3400 + MwSt-Split, Text «… Grischa»).
--
-- Umzug (alle vier Teile nach Golden Dragon):
--   Anlage 9f214ebc, Reinigung 39959f56, Rechnung ad6cfeff,
--   Buchungstexte 73c71083 + 73c5954a (Grischa → Golden Dragon; Konten,
--   Beträge und Belege unverändert).
--
-- Preis-Trigger-Kontrolle: preis_netto/mwst/brutto nach dem Update
-- unverändert 133.00 / 10.75 / 143.75.

-- 1. Snapshot (Rollback-Grundlage)
CREATE TABLE IF NOT EXISTS snapshot_golden_dragon_2026_08_05 AS
SELECT 'anlage'::text AS art, id, betrieb_id::text AS alt_wert, now() AS snapshot_am
  FROM anlagen WHERE id = '9f214ebc-1419-499e-a862-18ee09d00c96'
UNION ALL
SELECT 'reinigung', id, betrieb_id::text, now()
  FROM reinigungen WHERE id = '39959f56-ee86-47a5-ba70-1e337f7bd613'
UNION ALL
SELECT 'reinigung_preis', id,
       preis_netto::text || '|' || preis_mwst::text || '|' || preis_brutto::text, now()
  FROM reinigungen WHERE id = '39959f56-ee86-47a5-ba70-1e337f7bd613'
UNION ALL
SELECT 'rechnung', id, betrieb_id::text, now()
  FROM rechnungen WHERE id = 'ad6cfeff-d5d4-412d-9038-bbaf7f37f924'
UNION ALL
SELECT 'buchung', id, beschreibung, now()
  FROM buchungen WHERE id IN ('73c71083-a7f3-42a1-9690-921584719619',
                              '73c5954a-a681-47b4-827b-ca394259050e');

-- 2. Umzug
UPDATE anlagen SET betrieb_id = 'fef85854-824f-4db1-942a-9ce3a00fe439'
WHERE id = '9f214ebc-1419-499e-a862-18ee09d00c96';

UPDATE reinigungen SET betrieb_id = 'fef85854-824f-4db1-942a-9ce3a00fe439'
WHERE id = '39959f56-ee86-47a5-ba70-1e337f7bd613';

UPDATE rechnungen SET betrieb_id = 'fef85854-824f-4db1-942a-9ce3a00fe439'
WHERE id = 'ad6cfeff-d5d4-412d-9038-bbaf7f37f924';

UPDATE buchungen SET beschreibung = replace(beschreibung, 'Grischa', 'Golden Dragon')
WHERE id IN ('73c71083-a7f3-42a1-9690-921584719619',
             '73c5954a-a681-47b4-827b-ca394259050e');

-- 3. Kontrolle (Ergebnis 05.08.2026):
--   Grischa 2 Anlagen / 58 Reinigungen · Golden Dragon 1 Anlage / 55 Reinigungen
--   0 Reinigungen an fremder Anlage · Preisfelder unverändert
SELECT count(*) FROM reinigungen r JOIN anlagen a ON a.id = r.anlage_id
WHERE r.betrieb_id != a.betrieb_id;   -- muss 0 sein

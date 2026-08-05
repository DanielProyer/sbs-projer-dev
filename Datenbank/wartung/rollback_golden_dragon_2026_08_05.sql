-- Rollback zu golden_dragon_umzug_2026_08_05.sql
-- Hängt Anlage/Reinigung/Rechnung zurück an Grischa und stellt die
-- Buchungstexte wieder her.

UPDATE anlagen a SET betrieb_id = s.alt_wert::uuid
FROM snapshot_golden_dragon_2026_08_05 s
WHERE s.art = 'anlage' AND a.id = s.id;

UPDATE reinigungen r SET betrieb_id = s.alt_wert::uuid
FROM snapshot_golden_dragon_2026_08_05 s
WHERE s.art = 'reinigung' AND r.id = s.id;

UPDATE rechnungen re SET betrieb_id = s.alt_wert::uuid
FROM snapshot_golden_dragon_2026_08_05 s
WHERE s.art = 'rechnung' AND re.id = s.id;

UPDATE buchungen b SET beschreibung = s.alt_wert
FROM snapshot_golden_dragon_2026_08_05 s
WHERE s.art = 'buchung' AND b.id = s.id;

-- Preis-Kontrolle gegen art='reinigung_preis' (netto|mwst|brutto), danach ggf.:
-- DROP TABLE snapshot_golden_dragon_2026_08_05;

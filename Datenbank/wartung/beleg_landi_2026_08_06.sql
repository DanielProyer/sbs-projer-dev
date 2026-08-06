-- Spesenbeleg LANDI/AGROLA Chur vom 06.08.2026 — 10 Rappen korrigiert
-- Ausgeführt am 06.08.2026 via Supabase MCP.
--
-- Befund: Die Beleg-Erkennung hat die Lebensmittel-Position (MwSt 2.6 %) mit
-- 18.30 statt 18.40 gelesen. Die Positionen ergaben damit 122.88 statt der
-- gedruckten 122.98 (Twint-Zahlung — der Betrag muss für den Abgleich mit der
-- Finanz-App exakt stimmen). Gebucht werden die Positionen, nicht das Total.
--
-- Ursache im Prompt der Edge-Function `parse-beleg`: Sie verlangte einerseits,
-- die Beträge aus der MwSt-Tabelle zu nehmen, andererseits «pro Gruppe die
-- Beträge summieren». Beim Summieren der Artikelzeilen ging eine Zeile
-- verloren. Behoben am 06.08.2026 (Prompt eindeutig + serverseitige
-- Gegenprobe mit einer Rückfrage ans Modell).
--
-- Korrektur bei 18.40 brutto / 2.6 %: netto 17.93, MwSt 0.47.

CREATE TABLE IF NOT EXISTS snapshot_landi_2026_08_06 AS
SELECT id, betrag_netto, mwst_betrag, betrag_brutto, beschreibung, now() AS snapshot_am
FROM buchungen
WHERE id IN ('3c31a995-f3ec-4f90-a65e-dc6db29da50f',
             '9f7ace96-252d-4902-bb69-49688fd5a603');
ALTER TABLE snapshot_landi_2026_08_06 ENABLE ROW LEVEL SECURITY;

UPDATE buchungen
SET betrag_netto = 17.93, mwst_betrag = 0.47, betrag_brutto = 18.40
WHERE id = '3c31a995-f3ec-4f90-a65e-dc6db29da50f';   -- Aufwand 5820

UPDATE buchungen
SET betrag_netto = 0.47, betrag_brutto = 0.47
WHERE id = '9f7ace96-252d-4902-bb69-49688fd5a603';   -- Vorsteuer-Trennbuchung

-- Kontrolle: muss 122.98 ergeben
SELECT sum(betrag_brutto) FROM buchungen
WHERE datum = '2026-08-06' AND ist_storniert = false
  AND beschreibung LIKE 'LANDI%' AND beschreibung NOT LIKE 'Vorsteuer%';

-- Rückgängig:
-- UPDATE buchungen b SET betrag_netto = s.betrag_netto,
--        mwst_betrag = s.mwst_betrag, betrag_brutto = s.betrag_brutto
-- FROM snapshot_landi_2026_08_06 s WHERE b.id = s.id;

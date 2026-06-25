-- Migration 107: Beleg-Datei-Referenz direkt auf eingangsrechnung.
-- Beim Scannen existiert noch keine Buchung -> buchungs_belege (FK auf buchungen)
-- ist hier nicht nutzbar. Wir legen die PDF im selben Bucket 'buchungs-belege'
-- unter Pfad {userId}/eingangsrechnung/{id}/{ts}_{name} ab und speichern den
-- Storage-Pfad direkt hier. (beleg_id bleibt fuer optionale spaetere
-- buchungs_belege-Verknuepfung ab TP-2.)
ALTER TABLE eingangsrechnung ADD COLUMN IF NOT EXISTS beleg_pfad text;
ALTER TABLE eingangsrechnung ADD COLUMN IF NOT EXISTS beleg_dateiname text;

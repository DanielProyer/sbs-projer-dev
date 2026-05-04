-- Migration 060: Montage-Typ 'aufwandsentschaedigung' hinzufügen
-- Für Schulungen, Einführung neuer MA, Zusatzaufwand Auto etc.

ALTER TABLE montagen DROP CONSTRAINT IF EXISTS montagen_montage_typ_check;
ALTER TABLE montagen ADD CONSTRAINT montagen_montage_typ_check
  CHECK (montage_typ IN (
    'neu_installation', 'umbau', 'erweiterung', 'abbau',
    'heigenie_service', 'anlass_mitarbeit', 'mehraufwand', 'spesen',
    'aufwandsentschaedigung', 'sonstiges'
  ));

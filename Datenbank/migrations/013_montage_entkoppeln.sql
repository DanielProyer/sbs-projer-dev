-- Migration 013: Montage von Betrieb/Anlage entkoppeln + neue Typen
-- Montagen sind eigenständige Heineken-Aufträge, nicht an Betriebe gebunden

-- betrieb_id nullable machen
ALTER TABLE montagen ALTER COLUMN betrieb_id DROP NOT NULL;

-- FK-Constraint auf SET NULL ändern (statt CASCADE)
ALTER TABLE montagen DROP CONSTRAINT IF EXISTS montagen_betrieb_id_fkey;
ALTER TABLE montagen ADD CONSTRAINT montagen_betrieb_id_fkey
  FOREIGN KEY (betrieb_id) REFERENCES betriebe(id) ON DELETE SET NULL;

-- Neue Montage-Typen: anlass_mitarbeit, mehraufwand, spesen
ALTER TABLE montagen DROP CONSTRAINT IF EXISTS montagen_montage_typ_check;
ALTER TABLE montagen ADD CONSTRAINT montagen_montage_typ_check
  CHECK (montage_typ IN (
    'neu_installation', 'umbau', 'erweiterung', 'abbau',
    'heigenie_service', 'anlass_mitarbeit', 'mehraufwand', 'spesen', 'sonstiges'
  ));

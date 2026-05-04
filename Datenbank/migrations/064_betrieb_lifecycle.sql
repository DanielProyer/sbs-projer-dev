-- Migration 064: Betrieb-Lifecycle-Management
-- Status bleibt: aktiv, inaktiv, geschlossen (CHECK war schon korrekt)
-- Neue Felder: inaktiv_seit, inaktiv_grund
-- FK-Constraints von CASCADE/SET NULL auf RESTRICT (historische Daten schützen)

-- Status-CHECK bestätigen
ALTER TABLE betriebe DROP CONSTRAINT IF EXISTS betriebe_status_check;
ALTER TABLE betriebe ADD CONSTRAINT betriebe_status_check
  CHECK (status IN ('aktiv', 'inaktiv', 'geschlossen'));

-- Lifecycle-Felder
ALTER TABLE betriebe ADD COLUMN IF NOT EXISTS inaktiv_seit DATE;
ALTER TABLE betriebe ADD COLUMN IF NOT EXISTS inaktiv_grund TEXT;

-- CASCADE/SET NULL → RESTRICT (historische Daten schützen)

-- reinigungen: CASCADE → RESTRICT
ALTER TABLE reinigungen DROP CONSTRAINT IF EXISTS reinigungen_betrieb_id_fkey;
ALTER TABLE reinigungen ADD CONSTRAINT reinigungen_betrieb_id_fkey
  FOREIGN KEY (betrieb_id) REFERENCES betriebe(id) ON DELETE RESTRICT;

-- stoerungen: SET NULL → RESTRICT
ALTER TABLE stoerungen DROP CONSTRAINT IF EXISTS stoerungen_betrieb_id_fkey;
ALTER TABLE stoerungen ADD CONSTRAINT stoerungen_betrieb_id_fkey
  FOREIGN KEY (betrieb_id) REFERENCES betriebe(id) ON DELETE RESTRICT;

-- montagen: SET NULL → RESTRICT
ALTER TABLE montagen DROP CONSTRAINT IF EXISTS montagen_betrieb_id_fkey;
ALTER TABLE montagen ADD CONSTRAINT montagen_betrieb_id_fkey
  FOREIGN KEY (betrieb_id) REFERENCES betriebe(id) ON DELETE RESTRICT;

-- eigenauftraege: CASCADE → RESTRICT
ALTER TABLE eigenauftraege DROP CONSTRAINT IF EXISTS eigenauftraege_betrieb_id_fkey;
ALTER TABLE eigenauftraege ADD CONSTRAINT eigenauftraege_betrieb_id_fkey
  FOREIGN KEY (betrieb_id) REFERENCES betriebe(id) ON DELETE RESTRICT;

-- anlagen: CASCADE → RESTRICT
ALTER TABLE anlagen DROP CONSTRAINT IF EXISTS anlagen_betrieb_id_fkey;
ALTER TABLE anlagen ADD CONSTRAINT anlagen_betrieb_id_fkey
  FOREIGN KEY (betrieb_id) REFERENCES betriebe(id) ON DELETE RESTRICT;

-- eroeffnungsreinigungen: NO ACTION → RESTRICT (explizit)
ALTER TABLE eroeffnungsreinigungen DROP CONSTRAINT IF EXISTS eroeffnungsreinigungen_betrieb_id_fkey;
ALTER TABLE eroeffnungsreinigungen ADD CONSTRAINT eroeffnungsreinigungen_betrieb_id_fkey
  FOREIGN KEY (betrieb_id) REFERENCES betriebe(id) ON DELETE RESTRICT;

-- rechnungen: SET NULL → RESTRICT
ALTER TABLE rechnungen DROP CONSTRAINT IF EXISTS rechnungen_betrieb_id_fkey;
ALTER TABLE rechnungen ADD CONSTRAINT rechnungen_betrieb_id_fkey
  FOREIGN KEY (betrieb_id) REFERENCES betriebe(id) ON DELETE RESTRICT;

-- termine: CASCADE → RESTRICT
ALTER TABLE termine DROP CONSTRAINT IF EXISTS termine_betrieb_id_fkey;
ALTER TABLE termine ADD CONSTRAINT termine_betrieb_id_fkey
  FOREIGN KEY (betrieb_id) REFERENCES betriebe(id) ON DELETE RESTRICT;

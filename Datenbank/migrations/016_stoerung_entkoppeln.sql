-- Migration 016: Störungen von Betrieb/Anlage entkoppeln
-- anlage_id und betrieb_id nullable machen (Störungen auch an fremden Anlagen möglich)

ALTER TABLE stoerungen ALTER COLUMN anlage_id DROP NOT NULL;
ALTER TABLE stoerungen ALTER COLUMN betrieb_id DROP NOT NULL;

-- FK-Constraints: ON DELETE SET NULL statt CASCADE
ALTER TABLE stoerungen DROP CONSTRAINT IF EXISTS stoerungen_anlage_id_fkey;
ALTER TABLE stoerungen ADD CONSTRAINT stoerungen_anlage_id_fkey
  FOREIGN KEY (anlage_id) REFERENCES anlagen(id) ON DELETE SET NULL;

ALTER TABLE stoerungen DROP CONSTRAINT IF EXISTS stoerungen_betrieb_id_fkey;
ALTER TABLE stoerungen ADD CONSTRAINT stoerungen_betrieb_id_fkey
  FOREIGN KEY (betrieb_id) REFERENCES betriebe(id) ON DELETE SET NULL;

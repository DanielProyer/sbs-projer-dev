-- Reinigung auf Betrieb-Ebene: anlage_id wird optional
-- (Service beinhaltet oft mehrere Anlagen desselben Betriebs)
ALTER TABLE reinigungen ALTER COLUMN anlage_id DROP NOT NULL;

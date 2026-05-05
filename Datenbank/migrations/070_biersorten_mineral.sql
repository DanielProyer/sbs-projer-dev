-- Migration 070: Biersorten - Kategorie 'orion' entfernen, 'mineral' hinzufügen
-- Orion ist ein Zapfsystem (nicht eine Bierkategorie), Mineral/Softgetränke als neue Kategorie

-- 1. Orion-Eintrag löschen (vor Constraint-Änderung)
DELETE FROM biersorten WHERE name = 'Orion' AND kategorie = 'orion';

-- 2. CHECK Constraint aktualisieren: 'orion' → 'mineral'
ALTER TABLE biersorten DROP CONSTRAINT IF EXISTS biersorten_kategorie_check;
ALTER TABLE biersorten ADD CONSTRAINT biersorten_kategorie_check
  CHECK (kategorie IN ('eigen', 'fremd', 'mineral', 'wein'));

-- 3. Valser und Passuger von 'fremd' zu 'mineral' verschieben
UPDATE biersorten SET kategorie = 'mineral', updated_at = now()
WHERE name IN ('Valser', 'Passuger');

-- 4. Neue Mineral/Softgetränke hinzufügen (für alle bestehenden User)
INSERT INTO biersorten (user_id, name, kategorie)
SELECT user_id, sorte, 'mineral'
FROM (SELECT DISTINCT user_id FROM biersorten) u
CROSS JOIN (VALUES ('Stillwasser'), ('Carbo. Wasser')) AS s(sorte)
ON CONFLICT (user_id, name) DO NOTHING;

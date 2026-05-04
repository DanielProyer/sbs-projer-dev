-- Migration 058: Biersorten-Tabelle (Eigen/Fremd/Orion/Wein Zuordnung)
-- Ersetzt hardcoded Pattern-Matching in reinigung_form_screen.dart

CREATE TABLE biersorten (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  name TEXT NOT NULL,
  kategorie TEXT NOT NULL CHECK (kategorie IN ('eigen', 'fremd', 'orion', 'wein')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, name)
);

-- RLS
ALTER TABLE biersorten ENABLE ROW LEVEL SECURITY;

CREATE POLICY "biersorten_user_policy" ON biersorten
  FOR ALL USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- updated_at Trigger
CREATE TRIGGER set_updated_at_biersorten
  BEFORE UPDATE ON biersorten
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Seed-Daten für bestehende User
INSERT INTO biersorten (user_id, name, kategorie)
SELECT u.id, b.name, b.kategorie
FROM auth.users u
CROSS JOIN (VALUES
  ('Heineken Lager', 'eigen'),
  ('Desperados', 'eigen'),
  ('Calanda Lager', 'eigen'),
  ('Calanda Edelbräu', 'eigen'),
  ('Calanda Glatsch', 'eigen'),
  ('Eichhof Hubertus', 'eigen'),
  ('Eichhof Lager', 'eigen'),
  ('Birra Moretti', 'eigen'),
  ('Erdinger', 'eigen'),
  ('Erdinger Urweisse', 'eigen'),
  ('Murphys', 'eigen'),
  ('Murphys Red', 'eigen'),
  ('Strongbow', 'eigen'),
  ('Feldschlösschen', 'fremd'),
  ('Appenzeller', 'fremd'),
  ('Chopfab', 'fremd'),
  ('Guinness', 'fremd'),
  ('Paulaner', 'fremd'),
  ('Arosabier', 'fremd'),
  ('Monsteiner Huusbier', 'fremd'),
  ('Monsteiner Heustäffel', 'fremd'),
  ('Monsteiner Wätterguoge', 'fremd'),
  ('Rotwein', 'wein'),
  ('Weisswein', 'wein'),
  ('Orion', 'orion')
) AS b(name, kategorie)
ON CONFLICT (user_id, name) DO NOTHING;

-- Tagesplaene: Gespeicherte Tourenplanung pro Tag
CREATE TABLE tagesplaene (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users NOT NULL DEFAULT auth.uid(),
  datum date NOT NULL,
  eintraege jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(user_id, datum)
);

ALTER TABLE tagesplaene ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own tagesplaene"
  ON tagesplaene FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Migration 046: Multi-Anlagen-Auswahl für Reinigungen
-- Neues JSONB-Feld anlage_ids für mehrere Anlagen pro Reinigung

-- 1. Neues Feld hinzufügen
ALTER TABLE reinigungen ADD COLUMN IF NOT EXISTS anlage_ids JSONB DEFAULT '[]'::jsonb;

-- 2. GIN-Index für containment-Queries
CREATE INDEX IF NOT EXISTS idx_reinigungen_anlage_ids ON reinigungen USING GIN (anlage_ids);

-- 3. Bestehende Daten migrieren: anlage_id → anlage_ids Array
UPDATE reinigungen
SET anlage_ids = jsonb_build_array(anlage_id)
WHERE anlage_id IS NOT NULL AND (anlage_ids IS NULL OR anlage_ids = '[]'::jsonb);

-- 4. Trigger update_letzte_reinigung anpassen: über anlage_ids iterieren
CREATE OR REPLACE FUNCTION update_letzte_reinigung() RETURNS trigger AS $$
DECLARE
  v_anlage_id UUID;
BEGIN
  -- Über alle Anlage-IDs in anlage_ids iterieren
  IF NEW.anlage_ids IS NOT NULL AND jsonb_array_length(NEW.anlage_ids) > 0 THEN
    FOR v_anlage_id IN SELECT jsonb_array_elements_text(NEW.anlage_ids)::UUID
    LOOP
      UPDATE anlagen
      SET letzte_reinigung = NEW.datum, updated_at = NOW()
      WHERE id = v_anlage_id
        AND (letzte_reinigung IS NULL OR NEW.datum > letzte_reinigung);
    END LOOP;
  -- Fallback: einzelne anlage_id (Backward-Compat)
  ELSIF NEW.anlage_id IS NOT NULL THEN
    UPDATE anlagen
    SET letzte_reinigung = NEW.datum, updated_at = NOW()
    WHERE id = NEW.anlage_id
      AND (letzte_reinigung IS NULL OR NEW.datum > letzte_reinigung);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. Trigger populate_reinigung_checklist anpassen: erste Anlage aus anlage_ids
CREATE OR REPLACE FUNCTION populate_reinigung_checklist() RETURNS trigger AS $$
DECLARE
  v_anlage anlagen%ROWTYPE;
  v_first_id UUID;
BEGIN
  -- Erste Anlage aus anlage_ids nehmen
  IF NEW.anlage_ids IS NOT NULL AND jsonb_array_length(NEW.anlage_ids) > 0 THEN
    v_first_id := (NEW.anlage_ids->>0)::UUID;
    SELECT * INTO v_anlage FROM anlagen WHERE id = v_first_id;
  ELSIF NEW.anlage_id IS NOT NULL THEN
    SELECT * INTO v_anlage FROM anlagen WHERE id = NEW.anlage_id;
  ELSE
    RETURN NEW;
  END IF;

  IF v_anlage IS NULL THEN
    RETURN NEW;
  END IF;

  NEW.hat_durchlaufkuehler := (v_anlage.durchlaufkuehler IS NOT NULL AND v_anlage.durchlaufkuehler != 'keiner');
  NEW.hat_buffetanstich    := (v_anlage.typ_anlage = 'Buffetanstich');
  NEW.hat_kuehlkeller      := (v_anlage.vorkuehler = 'Kühlzelle');
  NEW.hat_fasskuehler      := (v_anlage.vorkuehler = 'Fasskühler');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

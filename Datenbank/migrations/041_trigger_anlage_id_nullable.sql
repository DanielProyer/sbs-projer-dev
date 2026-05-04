-- Trigger-Funktionen anpassen: anlage_id kann jetzt NULL sein

CREATE OR REPLACE FUNCTION populate_reinigung_checklist() RETURNS trigger AS $$
DECLARE v_anlage anlagen%ROWTYPE;
BEGIN
  IF NEW.anlage_id IS NULL THEN
    RETURN NEW;
  END IF;
  SELECT * INTO v_anlage FROM anlagen WHERE id = NEW.anlage_id;
  NEW.hat_durchlaufkuehler := (v_anlage.durchlaufkuehler IS NOT NULL AND v_anlage.durchlaufkuehler != 'keiner');
  NEW.hat_buffetanstich    := (v_anlage.typ_anlage = 'Buffetanstich');
  NEW.hat_kuehlkeller      := (v_anlage.vorkuehler = 'Kühlzelle');
  NEW.hat_fasskuehler      := (v_anlage.vorkuehler = 'Fasskühler');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_letzte_reinigung() RETURNS trigger AS $$
BEGIN
  IF NEW.anlage_id IS NULL THEN
    RETURN NEW;
  END IF;
  UPDATE anlagen
  SET letzte_reinigung = NEW.datum, updated_at = NOW()
  WHERE id = NEW.anlage_id
    AND (letzte_reinigung IS NULL OR NEW.datum > letzte_reinigung);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

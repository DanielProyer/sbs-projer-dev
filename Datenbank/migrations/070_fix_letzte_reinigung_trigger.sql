-- Fix: letzte_reinigung Trigger - jetzt mit Neuberechnung statt nur vorwärts
-- Problem: Trigger setzte letzte_reinigung nur vorwärts (NEW.datum > letzte_reinigung)
-- Bei DELETE oder Datumsänderung wurde der Wert nie korrigiert.

CREATE OR REPLACE FUNCTION update_letzte_reinigung() RETURNS trigger AS $$
DECLARE
  v_anlage_id UUID;
  v_max_datum DATE;
  v_ids JSONB;
BEGIN
  -- Bei DELETE: OLD-Anlagen neu berechnen
  IF TG_OP = 'DELETE' THEN
    v_ids := OLD.anlage_ids;
  ELSE
    v_ids := NEW.anlage_ids;
  END IF;

  -- Alle betroffenen Anlagen: MAX(datum) neu berechnen
  IF v_ids IS NOT NULL AND jsonb_array_length(v_ids) > 0 THEN
    FOR v_anlage_id IN SELECT jsonb_array_elements_text(v_ids)::UUID
    LOOP
      SELECT MAX(r.datum) INTO v_max_datum
      FROM reinigungen r
      WHERE r.status = 'abgeschlossen'
        AND r.anlage_ids @> to_jsonb(v_anlage_id::TEXT);
      UPDATE anlagen
      SET letzte_reinigung = v_max_datum, updated_at = NOW()
      WHERE id = v_anlage_id;
    END LOOP;
  END IF;

  -- Bei UPDATE: auch OLD-Anlagen neu berechnen (falls anlage_ids geändert)
  IF TG_OP = 'UPDATE' AND OLD.anlage_ids IS DISTINCT FROM NEW.anlage_ids AND OLD.anlage_ids IS NOT NULL THEN
    FOR v_anlage_id IN SELECT jsonb_array_elements_text(OLD.anlage_ids)::UUID
    LOOP
      SELECT MAX(r.datum) INTO v_max_datum
      FROM reinigungen r
      WHERE r.status = 'abgeschlossen'
        AND r.anlage_ids @> to_jsonb(v_anlage_id::TEXT);
      UPDATE anlagen
      SET letzte_reinigung = v_max_datum, updated_at = NOW()
      WHERE id = v_anlage_id;
    END LOOP;
  END IF;

  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger neu: auch bei DELETE, Datumsänderung, anlage_ids-Änderung
DROP TRIGGER IF EXISTS reinigung_letzte_reinigung_update ON reinigungen;
CREATE TRIGGER reinigung_letzte_reinigung_update
  AFTER INSERT OR UPDATE OF status, datum, anlage_ids OR DELETE ON reinigungen
  FOR EACH ROW
  EXECUTE FUNCTION update_letzte_reinigung();

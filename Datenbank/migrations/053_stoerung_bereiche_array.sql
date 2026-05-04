-- Migration 053: stoerung_bereich (INTEGER) → stoerung_bereiche (INTEGER[])
-- Ermöglicht Mehrfachauswahl von Störungsbereichen, Preis = Summe

-- 1. Trigger + Constraint + Index entfernen (Trigger muss VOR ALTER TYPE weg)
DROP TRIGGER IF EXISTS stoerung_preis_berechnung ON stoerungen;
ALTER TABLE stoerungen DROP CONSTRAINT IF EXISTS stoerungen_stoerung_bereich_check;
DROP INDEX IF EXISTS idx_stoerungen_bereich;

-- 2. Spalte umbenennen + Typ auf Array ändern (bestehende Einzel-Werte → 1-Element-Array)
ALTER TABLE stoerungen RENAME COLUMN stoerung_bereich TO stoerung_bereiche;
ALTER TABLE stoerungen ALTER COLUMN stoerung_bereiche TYPE INTEGER[]
  USING CASE WHEN stoerung_bereiche IS NOT NULL THEN ARRAY[stoerung_bereiche] ELSE NULL END;

-- 3. GIN-Index für Array-Suche
CREATE INDEX idx_stoerungen_bereiche ON stoerungen USING GIN(stoerung_bereiche);

-- 4. Trigger-Funktion: Iteriert über Array, summiert Basis-Preise
CREATE OR REPLACE FUNCTION calculate_stoerung_preis()
RETURNS TRIGGER AS $$
DECLARE
  v_preisliste preise%ROWTYPE;
  v_betrieb betriebe%ROWTYPE;
  v_basis DECIMAL(10,2) := 0;
  v_anfahrt DECIMAL(10,2);
  v_bereich INT;
BEGIN
  IF NEW.stoerung_bereiche IS NULL OR array_length(NEW.stoerung_bereiche, 1) IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT * INTO v_preisliste FROM preise
  WHERE user_id = NEW.user_id AND gueltig_ab <= NEW.datum
    AND (gueltig_bis IS NULL OR gueltig_bis >= NEW.datum)
  ORDER BY gueltig_ab DESC LIMIT 1;

  IF v_preisliste.id IS NULL THEN
    RAISE EXCEPTION 'Keine Preisliste für Datum % gefunden', NEW.datum;
  END IF;

  SELECT * INTO v_betrieb FROM betriebe WHERE id = NEW.betrieb_id;
  NEW.preisliste_id := v_preisliste.id;
  NEW.ist_bergkunde := COALESCE(v_betrieb.ist_bergkunde, FALSE);
  NEW.mwst_satz     := v_preisliste.mwst_satz;

  -- Über alle gewählten Bereiche iterieren, Basis summieren
  FOREACH v_bereich IN ARRAY NEW.stoerung_bereiche LOOP
    v_basis := v_basis + CASE v_bereich
      WHEN 1 THEN CASE WHEN NEW.ist_bergkunde THEN v_preisliste.stoerung_1_bergkunde ELSE v_preisliste.stoerung_1_normal END
      WHEN 2 THEN CASE WHEN NEW.ist_bergkunde THEN v_preisliste.stoerung_2_bergkunde ELSE v_preisliste.stoerung_2_normal END
      WHEN 3 THEN CASE WHEN NEW.ist_bergkunde THEN v_preisliste.stoerung_3_bergkunde ELSE v_preisliste.stoerung_3_normal END
      WHEN 4 THEN CASE WHEN NEW.ist_bergkunde THEN v_preisliste.stoerung_4_bergkunde ELSE v_preisliste.stoerung_4_normal END
      WHEN 5 THEN CASE WHEN NEW.ist_bergkunde THEN v_preisliste.stoerung_5_bergkunde ELSE v_preisliste.stoerung_5_normal END
      ELSE 0
    END;
  END LOOP;
  NEW.preis_basis := v_basis;

  v_anfahrt := CASE
    WHEN COALESCE(NEW.anfahrt_km, 0) < v_preisliste.stoerung_anfahrt_km_grenze
    THEN v_preisliste.stoerung_anfahrt_pauschale
    ELSE ROUND(NEW.anfahrt_km * v_preisliste.stoerung_anfahrt_km_satz, 2)
  END;
  NEW.preis_anfahrt    := v_anfahrt;
  NEW.preis_wochenende := CASE WHEN NEW.ist_wochenende THEN v_preisliste.stoerung_wochenende_zuschlag ELSE 0.00 END;
  NEW.preis_netto      := v_basis + v_anfahrt + COALESCE(NEW.preis_wochenende, 0) + COALESCE(NEW.komplexitaet_zuschlag, 0);
  NEW.preis_mwst       := ROUND(NEW.preis_netto * (NEW.mwst_satz / 100), 2);
  NEW.preis_brutto     := NEW.preis_netto + NEW.preis_mwst;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. Trigger auf neue Spalte anpassen
DROP TRIGGER IF EXISTS stoerung_preis_berechnung ON stoerungen;
CREATE TRIGGER stoerung_preis_berechnung
  BEFORE INSERT OR UPDATE OF stoerung_bereiche, anfahrt_km, ist_wochenende, komplexitaet_zuschlag ON stoerungen
  FOR EACH ROW EXECUTE FUNCTION calculate_stoerung_preis();

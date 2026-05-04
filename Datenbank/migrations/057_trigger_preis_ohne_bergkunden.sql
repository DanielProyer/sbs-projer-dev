-- Fix 1: Bergkunden-Zuschlag NICHT in preis_netto/brutto einrechnen
-- Fix 2: Keine -1 bei Eigen/Orion Haehnen — ALLE Haehne werden berechnet
--         (erster Hahn ist NICHT im Grundtarif enthalten)

CREATE OR REPLACE FUNCTION calculate_reinigung_preis()
RETURNS TRIGGER AS $$
DECLARE
  v_preisliste preise%ROWTYPE;
  v_betrieb betriebe%ROWTYPE;
  v_grundtarif DECIMAL(10,2);
  v_preis_zusatz DECIMAL(10,2) := 0;
BEGIN
  SELECT * INTO v_preisliste FROM preise
  WHERE user_id = NEW.user_id AND gueltig_ab <= NEW.datum
    AND (gueltig_bis IS NULL OR gueltig_bis >= NEW.datum)
  ORDER BY gueltig_ab DESC LIMIT 1;

  IF v_preisliste.id IS NULL THEN RETURN NEW; END IF;

  SELECT * INTO v_betrieb FROM betriebe WHERE id = NEW.betrieb_id;
  NEW.preisliste_id := v_preisliste.id;
  NEW.ist_bergkunde := COALESCE(v_betrieb.ist_bergkunde, FALSE);
  NEW.mwst_satz     := v_preisliste.mwst_satz;

  -- Grundtarif
  v_grundtarif := CASE NEW.service_typ
    WHEN 'reinigung_bier' THEN v_preisliste.grundtarif_reinigung_bier
    WHEN 'reinigung_orion' THEN v_preisliste.grundtarif_reinigung_orion
    WHEN 'heigenie'        THEN v_preisliste.grundtarif_heigenie
    WHEN 'reinigung_fremd' THEN v_preisliste.grundtarif_reinigung_fremd
    WHEN 'wein'            THEN v_preisliste.grundtarif_wein
    ELSE 0
  END;
  NEW.preis_grundtarif := v_grundtarif;

  -- Zusatz-Haehne: ALLE Haehne berechnen (kein -1)
  v_preis_zusatz :=
    COALESCE(NEW.anzahl_haehne_eigen, 0) * v_preisliste.zusatz_hahn_eigen +
    COALESCE(NEW.anzahl_haehne_orion, 0) * v_preisliste.zusatz_hahn_orion +
    COALESCE(NEW.anzahl_haehne_fremd, 0) * v_preisliste.zusatz_hahn_fremd +
    COALESCE(NEW.anzahl_haehne_wein, 0) * v_preisliste.zusatz_hahn_wein +
    COALESCE(NEW.anzahl_haehne_anderer_standort, 0) * v_preisliste.zusatz_hahn_anderer_standort;
  NEW.preis_zusatz_haehne := v_preis_zusatz;

  -- Bergkunden-Zuschlag: nur im Feld speichern, NICHT in preis_netto/brutto
  -- Wird separat ueber bergkundenpauschalen-Tabelle an Heineken verrechnet
  NEW.bergkunden_zuschlag := CASE WHEN NEW.ist_bergkunde THEN v_preisliste.bergkunden_zuschlag ELSE 0 END;

  -- Netto, MWST, Brutto (OHNE Bergkunden-Zuschlag)
  NEW.preis_netto  := v_grundtarif + v_preis_zusatz;
  NEW.preis_mwst   := ROUND(NEW.preis_netto * (NEW.mwst_satz / 100), 2);
  NEW.preis_brutto := NEW.preis_netto + NEW.preis_mwst;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

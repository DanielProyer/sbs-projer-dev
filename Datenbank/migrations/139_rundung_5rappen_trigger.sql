-- Migration 139: Rundungs-Fix in den Preis-Triggern (Reinigung + Störung)
--
-- Bug: Die Trigger-Funktionen calculate_reinigung_preis() und calculate_stoerung_preis()
-- runden die MwSt auf 2 Dezimalen (ROUND(netto*satz, 2)) und addieren sie zum Netto.
-- Das ergibt einen NICHT auf 5 Rappen gerundeten Brutto (z. B. 74.59 statt 74.60).
-- App, PDF, QR und Buchung runden zwar on-the-fly auf 5 Rappen, aber der DB-Rohwert
-- blieb krumm — und genau den nutzt das camt-Forderungs-Matching (exakter Rappen-Abgleich),
-- weshalb Kundenzahlungen nicht sauber auto-gematcht wurden.
--
-- Fix: Brutto auf 5 Rappen runden (Schweizer Rundung), MwSt = Brutto − Netto.
-- Identisch zur Dart-Logik _roundTo5Rappen(netto * (1 + satz/100)).

CREATE OR REPLACE FUNCTION public.calculate_reinigung_preis()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
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

  -- Netto, dann Brutto auf 5 Rappen runden (Schweizer Rundung), MWST = Differenz
  -- (OHNE Bergkunden-Zuschlag)
  NEW.preis_netto  := v_grundtarif + v_preis_zusatz;
  NEW.preis_brutto := ROUND(NEW.preis_netto * (1 + NEW.mwst_satz / 100) * 20) / 20;
  NEW.preis_mwst   := NEW.preis_brutto - NEW.preis_netto;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.calculate_stoerung_preis()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
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

  -- Netto, dann Brutto auf 5 Rappen runden (Schweizer Rundung), MWST = Differenz
  NEW.preis_netto      := v_basis + v_anfahrt + COALESCE(NEW.preis_wochenende, 0) + COALESCE(NEW.komplexitaet_zuschlag, 0);
  NEW.preis_brutto     := ROUND(NEW.preis_netto * (1 + NEW.mwst_satz / 100) * 20) / 20;
  NEW.preis_mwst       := NEW.preis_brutto - NEW.preis_netto;
  RETURN NEW;
END;
$function$;

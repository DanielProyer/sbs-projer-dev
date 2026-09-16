-- 192: Kulanz-Reinigungen tragen Preis 0 (16.09.2026)
--
-- WARUM: Das Formular setzt bei «Kulanz» alle Preise auf 0, der Trigger
-- calculate_reinigung_preis rechnete sie aber bei jedem Insert/Update aus
-- service_typ wieder hoch. Napoli Stories 31.07.2026 (Neueröffnung, Aufwand
-- als Montage auf der Heineken-Rechnung) stand deshalb mit 94.05 in der DB —
-- ohne Rechnung, ohne Buchung, aber in jeder Umsatzsumme und im Spiegel der
-- v2. 2026: 4 Fälle, CHF 337.30. Der Trigger prüft ist_kulanz jetzt zuerst.
-- Alles andere (Preisliste, Mengen, 5-Rappen-Rundung) bleibt unverändert.

CREATE OR REPLACE FUNCTION public.calculate_reinigung_preis()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
  v_preisliste preise%ROWTYPE;
  v_betrieb betriebe%ROWTYPE;
  v_grundtarif DECIMAL(10,2);
  v_preis_zusatz DECIMAL(10,2) := 0;
BEGIN
  -- Kulanz: geschenkt. Mengen und service_typ bleiben als Dokumentation,
  -- der Preis ist 0 — Rechnung und Buchung entstehen ohnehin nicht.
  IF COALESCE(NEW.ist_kulanz, FALSE) THEN
    NEW.preis_grundtarif    := 0;
    NEW.preis_zusatz_haehne := 0;
    NEW.bergkunden_zuschlag := 0;
    NEW.preis_netto         := 0;
    NEW.preis_mwst          := 0;
    NEW.preis_brutto        := 0;
    RETURN NEW;
  END IF;

  SELECT * INTO v_preisliste FROM preise
  WHERE user_id = NEW.user_id AND gueltig_ab <= NEW.datum
    AND (gueltig_bis IS NULL OR gueltig_bis >= NEW.datum)
  ORDER BY gueltig_ab DESC LIMIT 1;

  IF v_preisliste.id IS NULL THEN RETURN NEW; END IF;

  SELECT * INTO v_betrieb FROM betriebe WHERE id = NEW.betrieb_id;
  NEW.preisliste_id := v_preisliste.id;
  NEW.ist_bergkunde := COALESCE(v_betrieb.ist_bergkunde, FALSE);
  NEW.mwst_satz     := v_preisliste.mwst_satz;

  v_grundtarif := CASE NEW.service_typ
    WHEN 'reinigung_bier' THEN v_preisliste.grundtarif_reinigung_bier
    WHEN 'reinigung_orion' THEN v_preisliste.grundtarif_reinigung_orion
    WHEN 'heigenie'        THEN v_preisliste.grundtarif_heigenie
    WHEN 'reinigung_fremd' THEN v_preisliste.grundtarif_reinigung_fremd
    WHEN 'wein'            THEN v_preisliste.grundtarif_wein
    ELSE 0
  END;
  NEW.preis_grundtarif := v_grundtarif;

  v_preis_zusatz :=
    COALESCE(NEW.anzahl_haehne_eigen, 0) * v_preisliste.zusatz_hahn_eigen +
    COALESCE(NEW.anzahl_haehne_orion, 0) * v_preisliste.zusatz_hahn_orion +
    COALESCE(NEW.anzahl_haehne_fremd, 0) * v_preisliste.zusatz_hahn_fremd +
    COALESCE(NEW.anzahl_haehne_wein, 0) * v_preisliste.zusatz_hahn_wein +
    COALESCE(NEW.anzahl_haehne_anderer_standort, 0) * v_preisliste.zusatz_hahn_anderer_standort;
  NEW.preis_zusatz_haehne := v_preis_zusatz;

  NEW.bergkunden_zuschlag := CASE WHEN NEW.ist_bergkunde THEN v_preisliste.bergkunden_zuschlag ELSE 0 END;

  -- Netto, dann Brutto auf 5 Rappen runden (Schweizer Rundung), MWST = Differenz
  NEW.preis_netto  := v_grundtarif + v_preis_zusatz;
  NEW.preis_brutto := ROUND(NEW.preis_netto * (1 + NEW.mwst_satz / 100) * 20) / 20;
  NEW.preis_mwst   := NEW.preis_brutto - NEW.preis_netto;
  RETURN NEW;
END;
$function$;

-- Die vier Altfälle 2026 (Clubhotel 14.01. + 13.04., Da Noi 16.01.,
-- Napoli Stories 31.07.) durch den Trigger neu rechnen lassen:
UPDATE reinigungen SET updated_at = now() WHERE ist_kulanz AND preis_brutto > 0;

-- 192b (gleicher Tag): Der Trigger feuerte nur bei service_typ und den
-- Hahn-Mengen — der Touch oben rechnete nichts neu, und ein Umschalten auf
-- Kulanz im Formular hätte den Preis ebenfalls stehen lassen. ist_kulanz
-- kommt in die Spaltenliste; die Altfälle werden darüber angestossen.
DROP TRIGGER IF EXISTS reinigung_preis_berechnung ON public.reinigungen;
CREATE TRIGGER reinigung_preis_berechnung
  BEFORE INSERT OR UPDATE OF service_typ, anzahl_haehne_eigen, anzahl_haehne_orion,
    anzahl_haehne_fremd, anzahl_haehne_wein, anzahl_haehne_anderer_standort, ist_kulanz
  ON public.reinigungen FOR EACH ROW EXECUTE FUNCTION calculate_reinigung_preis();

UPDATE reinigungen SET ist_kulanz = true WHERE ist_kulanz AND preis_brutto > 0;

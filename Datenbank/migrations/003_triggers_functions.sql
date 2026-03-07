-- ============================================================
-- Migration 003: Trigger-Funktionen & Trigger
-- Projekt: SBS Projer App
-- Stand: 12.02.2026
-- Beschreibung: Alle PostgreSQL-Funktionen und Trigger
-- Ausführen NACH: 002_rls_policies.sql
-- ============================================================

-- ============================================================
-- HELPER: updated_at für alle Tabellen
-- ============================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- updated_at Trigger für alle Tabellen
CREATE OR REPLACE TRIGGER update_user_profiles_updated_at
  BEFORE UPDATE ON user_profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER update_regionen_updated_at
  BEFORE UPDATE ON regionen
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER update_betriebe_updated_at
  BEFORE UPDATE ON betriebe
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER update_betrieb_kontakte_updated_at
  BEFORE UPDATE ON betrieb_kontakte
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER update_betrieb_rechnungsadressen_updated_at
  BEFORE UPDATE ON betrieb_rechnungsadressen
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER update_anlagen_updated_at
  BEFORE UPDATE ON anlagen
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER update_preise_updated_at
  BEFORE UPDATE ON preise
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER update_reinigungen_updated_at
  BEFORE UPDATE ON reinigungen
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER update_stoerungen_updated_at
  BEFORE UPDATE ON stoerungen
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER update_montagen_updated_at
  BEFORE UPDATE ON montagen
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER update_eigenauftraege_updated_at
  BEFORE UPDATE ON eigenauftraege
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER update_pikett_dienste_updated_at
  BEFORE UPDATE ON pikett_dienste
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER update_material_kategorien_updated_at
  BEFORE UPDATE ON material_kategorien
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER update_material_updated_at
  BEFORE UPDATE ON material
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER update_lager_updated_at
  BEFORE UPDATE ON lager
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER update_rechnungen_updated_at
  BEFORE UPDATE ON rechnungen
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER update_formulare_updated_at
  BEFORE UPDATE ON formulare
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER update_buchungen_updated_at
  BEFORE UPDATE ON buchungen
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- ANLAGEN: Nächste Reinigung berechnen
-- ============================================================

CREATE OR REPLACE FUNCTION calculate_naechste_reinigung()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.letzte_reinigung IS NOT NULL THEN
    NEW.naechste_reinigung := NEW.letzte_reinigung + (
      CASE NEW.reinigung_rhythmus
        WHEN '4-Wochen'    THEN INTERVAL '4 weeks'
        WHEN '6-Wochen'    THEN INTERVAL '6 weeks'
        WHEN '2-Monate'    THEN INTERVAL '2 months'
        WHEN '3-Monate'    THEN INTERVAL '3 months'
        WHEN '6-Monate'    THEN INTERVAL '6 months'
        WHEN 'Jährlich'    THEN INTERVAL '1 year'
        ELSE NULL
      END
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER anlagen_naechste_reinigung
  BEFORE INSERT OR UPDATE OF letzte_reinigung, reinigung_rhythmus ON anlagen
  FOR EACH ROW EXECUTE FUNCTION calculate_naechste_reinigung();

-- ============================================================
-- REINIGUNGEN: Checkliste auto-populate & Preisberechnung
-- ============================================================

CREATE OR REPLACE FUNCTION populate_reinigung_checklist()
RETURNS TRIGGER AS $$
DECLARE v_anlage anlagen%ROWTYPE;
BEGIN
  SELECT * INTO v_anlage FROM anlagen WHERE id = NEW.anlage_id;
  NEW.hat_durchlaufkuehler := (v_anlage.durchlaufkuehler IS NOT NULL AND v_anlage.durchlaufkuehler != 'keiner');
  NEW.hat_buffetanstich    := (v_anlage.typ_anlage = 'Buffetanstich');
  NEW.hat_kuehlkeller      := (v_anlage.vorkuehler = 'Kühlzelle');
  NEW.hat_fasskuehler      := (v_anlage.vorkuehler = 'Fasskühler');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER reinigung_checklist_populate
  BEFORE INSERT OR UPDATE OF anlage_id ON reinigungen
  FOR EACH ROW EXECUTE FUNCTION populate_reinigung_checklist();

CREATE OR REPLACE FUNCTION calculate_reinigung_preis()
RETURNS TRIGGER AS $$
DECLARE
  v_preisliste preise%ROWTYPE;
  v_betrieb betriebe%ROWTYPE;
  v_grundtarif DECIMAL(10,2);
  v_zusatz_haehne INTEGER;
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

  -- Zusatz-Hähne
  v_preis_zusatz :=
    COALESCE(GREATEST(NEW.anzahl_haehne_eigen - 1, 0), 0) * v_preisliste.zusatz_hahn_eigen +
    COALESCE(GREATEST(NEW.anzahl_haehne_orion - 1, 0), 0) * v_preisliste.zusatz_hahn_orion +
    COALESCE(NEW.anzahl_haehne_fremd, 0) * v_preisliste.zusatz_hahn_fremd +
    COALESCE(NEW.anzahl_haehne_wein, 0) * v_preisliste.zusatz_hahn_wein +
    COALESCE(NEW.anzahl_haehne_anderer_standort, 0) * v_preisliste.zusatz_hahn_anderer_standort;
  NEW.preis_zusatz_haehne := v_preis_zusatz;

  -- Bergkunden-Zuschlag
  NEW.bergkunden_zuschlag := CASE WHEN NEW.ist_bergkunde THEN v_preisliste.bergkunden_zuschlag ELSE 0 END;

  -- Netto, MWST, Brutto
  NEW.preis_netto  := v_grundtarif + v_preis_zusatz + NEW.bergkunden_zuschlag;
  NEW.preis_mwst   := ROUND(NEW.preis_netto * (NEW.mwst_satz / 100), 2);
  NEW.preis_brutto := NEW.preis_netto + NEW.preis_mwst;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER reinigung_preis_berechnung
  BEFORE INSERT OR UPDATE OF service_typ, anzahl_haehne_eigen, anzahl_haehne_orion,
    anzahl_haehne_fremd, anzahl_haehne_wein, anzahl_haehne_anderer_standort ON reinigungen
  FOR EACH ROW EXECUTE FUNCTION calculate_reinigung_preis();

-- letzte_reinigung in Anlagen aktualisieren
CREATE OR REPLACE FUNCTION update_letzte_reinigung()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE anlagen
  SET letzte_reinigung = NEW.datum, updated_at = NOW()
  WHERE id = NEW.anlage_id
    AND (letzte_reinigung IS NULL OR NEW.datum > letzte_reinigung);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER reinigung_letzte_reinigung_update
  AFTER INSERT OR UPDATE OF status ON reinigungen
  FOR EACH ROW WHEN (NEW.status = 'abgeschlossen')
  EXECUTE FUNCTION update_letzte_reinigung();

-- Wasserwechsel tracken
CREATE OR REPLACE FUNCTION update_letzter_wasserwechsel()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.wasser_gewechselt = TRUE AND
     (OLD.wasser_gewechselt = FALSE OR OLD.wasser_gewechselt IS NULL) THEN
    UPDATE anlagen SET letzter_wasserwechsel = NEW.datum, updated_at = NOW()
    WHERE id = NEW.anlage_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER reinigung_wasserwechsel_update
  AFTER INSERT OR UPDATE OF wasser_gewechselt ON reinigungen
  FOR EACH ROW EXECUTE FUNCTION update_letzter_wasserwechsel();

-- ============================================================
-- STÖRUNGEN: Preisberechnung
-- ============================================================

CREATE OR REPLACE FUNCTION calculate_stoerung_preis()
RETURNS TRIGGER AS $$
DECLARE
  v_preisliste preise%ROWTYPE;
  v_betrieb betriebe%ROWTYPE;
  v_basis DECIMAL(10,2);
  v_anfahrt DECIMAL(10,2);
BEGIN
  IF NEW.stoerung_bereich IS NULL THEN RETURN NEW; END IF;

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

  v_basis := CASE NEW.stoerung_bereich
    WHEN 1 THEN CASE WHEN NEW.ist_bergkunde THEN v_preisliste.stoerung_1_bergkunde ELSE v_preisliste.stoerung_1_normal END
    WHEN 2 THEN CASE WHEN NEW.ist_bergkunde THEN v_preisliste.stoerung_2_bergkunde ELSE v_preisliste.stoerung_2_normal END
    WHEN 3 THEN CASE WHEN NEW.ist_bergkunde THEN v_preisliste.stoerung_3_bergkunde ELSE v_preisliste.stoerung_3_normal END
    WHEN 4 THEN CASE WHEN NEW.ist_bergkunde THEN v_preisliste.stoerung_4_bergkunde ELSE v_preisliste.stoerung_4_normal END
    WHEN 5 THEN CASE WHEN NEW.ist_bergkunde THEN v_preisliste.stoerung_5_bergkunde ELSE v_preisliste.stoerung_5_normal END
    ELSE 0
  END;
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

CREATE OR REPLACE TRIGGER stoerung_preis_berechnung
  BEFORE INSERT OR UPDATE OF stoerung_bereich, anfahrt_km, ist_wochenende, komplexitaet_zuschlag ON stoerungen
  FOR EACH ROW EXECUTE FUNCTION calculate_stoerung_preis();

-- ============================================================
-- MATERIAL-SYNC TRIGGER (inline Slots → material_verbrauch)
-- ============================================================

-- STÖRUNGEN: 5 Material-Slots
CREATE OR REPLACE FUNCTION sync_stoerung_material()
RETURNS TRIGGER AS $$
DECLARE v_stoerung_id UUID;
BEGIN
  v_stoerung_id := NEW.id;
  DELETE FROM material_verbrauch WHERE service_typ = 'stoerung' AND service_id = v_stoerung_id;

  IF NEW.material_1_id IS NOT NULL AND COALESCE(NEW.material_1_menge, 0) > 0 THEN
    INSERT INTO material_verbrauch (user_id, lager_id, service_typ, service_id, menge, einheit, verbraucht_am)
    SELECT NEW.user_id, NEW.material_1_id, 'stoerung', v_stoerung_id, NEW.material_1_menge, l.einheit, NOW()
    FROM lager l WHERE l.id = NEW.material_1_id;
  END IF;
  IF NEW.material_2_id IS NOT NULL AND COALESCE(NEW.material_2_menge, 0) > 0 THEN
    INSERT INTO material_verbrauch (user_id, lager_id, service_typ, service_id, menge, einheit, verbraucht_am)
    SELECT NEW.user_id, NEW.material_2_id, 'stoerung', v_stoerung_id, NEW.material_2_menge, l.einheit, NOW()
    FROM lager l WHERE l.id = NEW.material_2_id;
  END IF;
  IF NEW.material_3_id IS NOT NULL AND COALESCE(NEW.material_3_menge, 0) > 0 THEN
    INSERT INTO material_verbrauch (user_id, lager_id, service_typ, service_id, menge, einheit, verbraucht_am)
    SELECT NEW.user_id, NEW.material_3_id, 'stoerung', v_stoerung_id, NEW.material_3_menge, l.einheit, NOW()
    FROM lager l WHERE l.id = NEW.material_3_id;
  END IF;
  IF NEW.material_4_id IS NOT NULL AND COALESCE(NEW.material_4_menge, 0) > 0 THEN
    INSERT INTO material_verbrauch (user_id, lager_id, service_typ, service_id, menge, einheit, verbraucht_am)
    SELECT NEW.user_id, NEW.material_4_id, 'stoerung', v_stoerung_id, NEW.material_4_menge, l.einheit, NOW()
    FROM lager l WHERE l.id = NEW.material_4_id;
  END IF;
  IF NEW.material_5_id IS NOT NULL AND COALESCE(NEW.material_5_menge, 0) > 0 THEN
    INSERT INTO material_verbrauch (user_id, lager_id, service_typ, service_id, menge, einheit, verbraucht_am)
    SELECT NEW.user_id, NEW.material_5_id, 'stoerung', v_stoerung_id, NEW.material_5_menge, l.einheit, NOW()
    FROM lager l WHERE l.id = NEW.material_5_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER stoerung_material_sync
  AFTER INSERT OR UPDATE OF
    material_1_id, material_1_menge, material_2_id, material_2_menge,
    material_3_id, material_3_menge, material_4_id, material_4_menge,
    material_5_id, material_5_menge
  ON stoerungen FOR EACH ROW EXECUTE FUNCTION sync_stoerung_material();

-- MONTAGEN: 7 Material-Slots
CREATE OR REPLACE FUNCTION sync_montage_material()
RETURNS TRIGGER AS $$
DECLARE v_montage_id UUID;
BEGIN
  v_montage_id := NEW.id;
  DELETE FROM material_verbrauch WHERE service_typ = 'montage' AND service_id = v_montage_id;

  IF NEW.material_1_id IS NOT NULL AND COALESCE(NEW.material_1_menge, 0) > 0 THEN
    INSERT INTO material_verbrauch (user_id, lager_id, service_typ, service_id, menge, einheit, verbraucht_am)
    SELECT NEW.user_id, NEW.material_1_id, 'montage', v_montage_id, NEW.material_1_menge, l.einheit, NOW()
    FROM lager l WHERE l.id = NEW.material_1_id;
  END IF;
  IF NEW.material_2_id IS NOT NULL AND COALESCE(NEW.material_2_menge, 0) > 0 THEN
    INSERT INTO material_verbrauch (user_id, lager_id, service_typ, service_id, menge, einheit, verbraucht_am)
    SELECT NEW.user_id, NEW.material_2_id, 'montage', v_montage_id, NEW.material_2_menge, l.einheit, NOW()
    FROM lager l WHERE l.id = NEW.material_2_id;
  END IF;
  IF NEW.material_3_id IS NOT NULL AND COALESCE(NEW.material_3_menge, 0) > 0 THEN
    INSERT INTO material_verbrauch (user_id, lager_id, service_typ, service_id, menge, einheit, verbraucht_am)
    SELECT NEW.user_id, NEW.material_3_id, 'montage', v_montage_id, NEW.material_3_menge, l.einheit, NOW()
    FROM lager l WHERE l.id = NEW.material_3_id;
  END IF;
  IF NEW.material_4_id IS NOT NULL AND COALESCE(NEW.material_4_menge, 0) > 0 THEN
    INSERT INTO material_verbrauch (user_id, lager_id, service_typ, service_id, menge, einheit, verbraucht_am)
    SELECT NEW.user_id, NEW.material_4_id, 'montage', v_montage_id, NEW.material_4_menge, l.einheit, NOW()
    FROM lager l WHERE l.id = NEW.material_4_id;
  END IF;
  IF NEW.material_5_id IS NOT NULL AND COALESCE(NEW.material_5_menge, 0) > 0 THEN
    INSERT INTO material_verbrauch (user_id, lager_id, service_typ, service_id, menge, einheit, verbraucht_am)
    SELECT NEW.user_id, NEW.material_5_id, 'montage', v_montage_id, NEW.material_5_menge, l.einheit, NOW()
    FROM lager l WHERE l.id = NEW.material_5_id;
  END IF;
  IF NEW.material_6_id IS NOT NULL AND COALESCE(NEW.material_6_menge, 0) > 0 THEN
    INSERT INTO material_verbrauch (user_id, lager_id, service_typ, service_id, menge, einheit, verbraucht_am)
    SELECT NEW.user_id, NEW.material_6_id, 'montage', v_montage_id, NEW.material_6_menge, l.einheit, NOW()
    FROM lager l WHERE l.id = NEW.material_6_id;
  END IF;
  IF NEW.material_7_id IS NOT NULL AND COALESCE(NEW.material_7_menge, 0) > 0 THEN
    INSERT INTO material_verbrauch (user_id, lager_id, service_typ, service_id, menge, einheit, verbraucht_am)
    SELECT NEW.user_id, NEW.material_7_id, 'montage', v_montage_id, NEW.material_7_menge, l.einheit, NOW()
    FROM lager l WHERE l.id = NEW.material_7_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER montage_material_sync
  AFTER INSERT OR UPDATE OF
    material_1_id, material_1_menge, material_2_id, material_2_menge,
    material_3_id, material_3_menge, material_4_id, material_4_menge,
    material_5_id, material_5_menge, material_6_id, material_6_menge,
    material_7_id, material_7_menge
  ON montagen FOR EACH ROW EXECUTE FUNCTION sync_montage_material();

-- EIGENAUFTRÄGE: 5 Material-Slots
CREATE OR REPLACE FUNCTION sync_eigenauftrag_material()
RETURNS TRIGGER AS $$
DECLARE v_eigenauftrag_id UUID;
BEGIN
  v_eigenauftrag_id := NEW.id;
  DELETE FROM material_verbrauch WHERE service_typ = 'eigenauftrag' AND service_id = v_eigenauftrag_id;

  IF NEW.material_1_id IS NOT NULL AND COALESCE(NEW.material_1_menge, 0) > 0 THEN
    INSERT INTO material_verbrauch (user_id, lager_id, service_typ, service_id, menge, einheit, verbraucht_am)
    SELECT NEW.user_id, NEW.material_1_id, 'eigenauftrag', v_eigenauftrag_id, NEW.material_1_menge, l.einheit, NOW()
    FROM lager l WHERE l.id = NEW.material_1_id;
  END IF;
  IF NEW.material_2_id IS NOT NULL AND COALESCE(NEW.material_2_menge, 0) > 0 THEN
    INSERT INTO material_verbrauch (user_id, lager_id, service_typ, service_id, menge, einheit, verbraucht_am)
    SELECT NEW.user_id, NEW.material_2_id, 'eigenauftrag', v_eigenauftrag_id, NEW.material_2_menge, l.einheit, NOW()
    FROM lager l WHERE l.id = NEW.material_2_id;
  END IF;
  IF NEW.material_3_id IS NOT NULL AND COALESCE(NEW.material_3_menge, 0) > 0 THEN
    INSERT INTO material_verbrauch (user_id, lager_id, service_typ, service_id, menge, einheit, verbraucht_am)
    SELECT NEW.user_id, NEW.material_3_id, 'eigenauftrag', v_eigenauftrag_id, NEW.material_3_menge, l.einheit, NOW()
    FROM lager l WHERE l.id = NEW.material_3_id;
  END IF;
  IF NEW.material_4_id IS NOT NULL AND COALESCE(NEW.material_4_menge, 0) > 0 THEN
    INSERT INTO material_verbrauch (user_id, lager_id, service_typ, service_id, menge, einheit, verbraucht_am)
    SELECT NEW.user_id, NEW.material_4_id, 'eigenauftrag', v_eigenauftrag_id, NEW.material_4_menge, l.einheit, NOW()
    FROM lager l WHERE l.id = NEW.material_4_id;
  END IF;
  IF NEW.material_5_id IS NOT NULL AND COALESCE(NEW.material_5_menge, 0) > 0 THEN
    INSERT INTO material_verbrauch (user_id, lager_id, service_typ, service_id, menge, einheit, verbraucht_am)
    SELECT NEW.user_id, NEW.material_5_id, 'eigenauftrag', v_eigenauftrag_id, NEW.material_5_menge, l.einheit, NOW()
    FROM lager l WHERE l.id = NEW.material_5_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER eigenauftrag_material_sync
  AFTER INSERT OR UPDATE OF
    material_1_id, material_1_menge, material_2_id, material_2_menge,
    material_3_id, material_3_menge, material_4_id, material_4_menge,
    material_5_id, material_5_menge
  ON eigenauftraege FOR EACH ROW EXECUTE FUNCTION sync_eigenauftrag_material();

-- ============================================================
-- LAGER: Bestand automatisch anpassen
-- ============================================================

CREATE OR REPLACE FUNCTION update_lager_bestand_insert()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE lager SET bestand_aktuell = bestand_aktuell - NEW.menge, updated_at = NOW()
  WHERE id = NEW.lager_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER material_verbrauch_bestand_reduzieren
  AFTER INSERT ON material_verbrauch
  FOR EACH ROW EXECUTE FUNCTION update_lager_bestand_insert();

CREATE OR REPLACE FUNCTION update_lager_bestand_delete()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE lager SET bestand_aktuell = bestand_aktuell + OLD.menge, updated_at = NOW()
  WHERE id = OLD.lager_id;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER material_verbrauch_bestand_wiederherstellen
  AFTER DELETE ON material_verbrauch
  FOR EACH ROW EXECUTE FUNCTION update_lager_bestand_delete();

-- ============================================================
-- MATERIAL: Auslauf-Datum automatisch setzen
-- ============================================================

CREATE OR REPLACE FUNCTION set_material_auslauf_datum()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.ist_auslaufartikel = TRUE AND OLD.ist_auslaufartikel = FALSE AND NEW.auslauf_datum IS NULL THEN
    NEW.auslauf_datum := CURRENT_DATE;
  END IF;
  IF NEW.ist_auslaufartikel = FALSE AND OLD.ist_auslaufartikel = TRUE THEN
    NEW.auslauf_datum := NULL;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER material_auslauf_datum_setzen
  BEFORE UPDATE OF ist_auslaufartikel ON material
  FOR EACH ROW EXECUTE FUNCTION set_material_auslauf_datum();

-- ============================================================
-- MONTAGEN: Stundenkosten berechnen
-- ============================================================

CREATE OR REPLACE FUNCTION calculate_montage_kosten()
RETURNS TRIGGER AS $$
DECLARE v_preisliste preise%ROWTYPE;
BEGIN
  SELECT * INTO v_preisliste FROM preise
  WHERE user_id = NEW.user_id AND gueltig_ab <= NEW.datum
    AND (gueltig_bis IS NULL OR gueltig_bis >= NEW.datum)
  ORDER BY gueltig_ab DESC LIMIT 1;

  IF v_preisliste.id IS NOT NULL THEN
    NEW.preisliste_id := v_preisliste.id;
    NEW.stundensatz   := v_preisliste.montage_stundensatz;
  END IF;
  IF NEW.dauer_stunden IS NULL AND NEW.dauer_minuten IS NOT NULL THEN
    NEW.dauer_stunden := ROUND(NEW.dauer_minuten / 60.0, 2);
  END IF;
  IF NEW.dauer_stunden IS NOT NULL AND NEW.stundensatz IS NOT NULL THEN
    NEW.kosten_arbeit := NEW.dauer_stunden * NEW.stundensatz;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER montage_kosten_berechnung
  BEFORE INSERT OR UPDATE ON montagen
  FOR EACH ROW EXECUTE FUNCTION calculate_montage_kosten();

-- ============================================================
-- EIGENAUFTRÄGE: Pauschale aus Preisliste setzen
-- ============================================================

CREATE OR REPLACE FUNCTION set_eigenauftrag_pauschale()
RETURNS TRIGGER AS $$
DECLARE v_preisliste preise%ROWTYPE;
BEGIN
  SELECT * INTO v_preisliste FROM preise
  WHERE user_id = NEW.user_id AND gueltig_ab <= NEW.datum
    AND (gueltig_bis IS NULL OR gueltig_bis >= NEW.datum)
  ORDER BY gueltig_ab DESC LIMIT 1;

  IF v_preisliste.id IS NOT NULL THEN
    NEW.preisliste_id := v_preisliste.id;
    NEW.pauschale     := v_preisliste.eigenauftrag_pauschale;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER eigenauftrag_pauschale_setzen
  BEFORE INSERT OR UPDATE ON eigenauftraege
  FOR EACH ROW EXECUTE FUNCTION set_eigenauftrag_pauschale();

-- ============================================================
-- PIKETT: Pauschale aus Preisliste setzen
-- ============================================================

CREATE OR REPLACE FUNCTION set_pikett_pauschale()
RETURNS TRIGGER AS $$
DECLARE v_preisliste preise%ROWTYPE;
BEGIN
  SELECT * INTO v_preisliste FROM preise
  WHERE user_id = NEW.user_id AND gueltig_ab <= NEW.datum_start
    AND (gueltig_bis IS NULL OR gueltig_bis >= NEW.datum_start)
  ORDER BY gueltig_ab DESC LIMIT 1;

  IF v_preisliste.id IS NOT NULL THEN
    NEW.preisliste_id    := v_preisliste.id;
    NEW.pauschale        := v_preisliste.pikett_pauschale;
    NEW.feiertag_zuschlag := COALESCE(NEW.anzahl_feiertage, 0) * v_preisliste.pikett_feiertag_zuschlag;
    NEW.pauschale_gesamt  := NEW.pauschale + NEW.feiertag_zuschlag;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER pikett_pauschale_setzen
  BEFORE INSERT OR UPDATE OF anzahl_feiertage ON pikett_dienste
  FOR EACH ROW EXECUTE FUNCTION set_pikett_pauschale();

-- ============================================================
-- RECHNUNGEN: Nummer generieren & Summen aktualisieren
-- ============================================================

CREATE OR REPLACE FUNCTION generate_rechnungsnummer()
RETURNS TRIGGER AS $$
BEGIN
  NEW.rechnungsnummer := TO_CHAR(CURRENT_DATE, 'YYYY-MM')
    || '-' || LPAD(nextval('rechnungsnummer_seq')::TEXT, 4, '0');
  IF NEW.faelligkeitsdatum IS NULL THEN
    NEW.faelligkeitsdatum := NEW.rechnungsdatum + INTERVAL '30 days';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER set_rechnungsnummer
  BEFORE INSERT ON rechnungen
  FOR EACH ROW EXECUTE FUNCTION generate_rechnungsnummer();

CREATE OR REPLACE FUNCTION update_rechnung_summen()
RETURNS TRIGGER AS $$
DECLARE v_rechnung_id UUID;
BEGIN
  v_rechnung_id := COALESCE(NEW.rechnung_id, OLD.rechnung_id);
  UPDATE rechnungen SET
    betrag_netto  = (SELECT COALESCE(SUM(betrag_netto), 0)  FROM rechnungs_positionen WHERE rechnung_id = v_rechnung_id),
    mwst_betrag   = (SELECT COALESCE(SUM(mwst_betrag), 0)   FROM rechnungs_positionen WHERE rechnung_id = v_rechnung_id),
    betrag_brutto = (SELECT COALESCE(SUM(betrag_brutto), 0) FROM rechnungs_positionen WHERE rechnung_id = v_rechnung_id),
    updated_at    = NOW()
  WHERE id = v_rechnung_id;
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER rechnung_summen_update
  AFTER INSERT OR UPDATE OR DELETE ON rechnungs_positionen
  FOR EACH ROW EXECUTE FUNCTION update_rechnung_summen();

-- ============================================================
-- BUCHUNGEN: Auto-Buchung bei Rechnungsereignissen
-- ============================================================

CREATE OR REPLACE FUNCTION auto_buchung_rechnung_erstellt()
RETURNS TRIGGER AS $$
DECLARE
  v_vorlage buchungs_vorlagen%ROWTYPE;
  v_trigger_name TEXT;
BEGIN
  IF OLD.zahlungsstatus = 'entwurf' AND NEW.zahlungsstatus = 'offen' THEN
    v_trigger_name := CASE NEW.rechnungstyp
      WHEN 'kundenrechnung' THEN 'rechnung_erstellt_kunde'
      WHEN 'heineken_monat' THEN 'rechnung_erstellt_heineken'
    END;
    SELECT * INTO v_vorlage FROM buchungs_vorlagen
    WHERE user_id = NEW.user_id AND auto_trigger = v_trigger_name LIMIT 1;

    IF v_vorlage.id IS NOT NULL THEN
      INSERT INTO buchungen (
        user_id, datum, belegnummer, vorlage_id, soll_konto, haben_konto, mwst_konto,
        betrag_netto, mwst_satz, mwst_betrag, betrag_brutto,
        beschreibung, belegordner, beleg_typ, beleg_id, geschaeftsjahr
      ) VALUES (
        NEW.user_id, NEW.rechnungsdatum, NEW.rechnungsnummer,
        v_vorlage.id, v_vorlage.soll_konto, v_vorlage.haben_konto, v_vorlage.mwst_konto,
        NEW.betrag_netto, COALESCE(v_vorlage.mwst_satz, 0), NEW.mwst_betrag, NEW.betrag_brutto,
        CASE NEW.rechnungstyp
          WHEN 'kundenrechnung' THEN 'Rechnung ' || NEW.rechnungsnummer
          WHEN 'heineken_monat' THEN 'Heineken Monatsrechnung ' || TO_CHAR(NEW.heineken_monat, 'MM/YYYY')
        END,
        v_vorlage.belegordner, 'rechnung', NEW.id,
        EXTRACT(YEAR FROM NEW.rechnungsdatum)::INTEGER
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER rechnungen_auto_buchung_erstellt
  AFTER UPDATE OF zahlungsstatus ON rechnungen
  FOR EACH ROW EXECUTE FUNCTION auto_buchung_rechnung_erstellt();

CREATE OR REPLACE FUNCTION auto_buchung_zahlung_eingegangen()
RETURNS TRIGGER AS $$
DECLARE
  v_vorlage buchungs_vorlagen%ROWTYPE;
  v_trigger_name TEXT;
BEGIN
  IF NEW.zahlungsstatus = 'bezahlt' AND OLD.zahlungsstatus != 'bezahlt' THEN
    v_trigger_name := CASE NEW.rechnungstyp
      WHEN 'kundenrechnung' THEN 'zahlung_eingegangen_kunde'
      WHEN 'heineken_monat' THEN 'zahlung_eingegangen_heineken'
    END;
    SELECT * INTO v_vorlage FROM buchungs_vorlagen
    WHERE user_id = NEW.user_id AND auto_trigger = v_trigger_name LIMIT 1;

    IF v_vorlage.id IS NOT NULL THEN
      INSERT INTO buchungen (
        user_id, datum, belegnummer, vorlage_id, soll_konto, haben_konto, mwst_konto,
        betrag_netto, mwst_satz, mwst_betrag, betrag_brutto,
        beschreibung, belegordner, beleg_typ, beleg_id, geschaeftsjahr
      ) VALUES (
        NEW.user_id, COALESCE(NEW.zahlung_eingegangen_am, CURRENT_DATE), NEW.rechnungsnummer,
        v_vorlage.id, v_vorlage.soll_konto, v_vorlage.haben_konto, NULL,
        NEW.betrag_brutto, 0, 0, NEW.betrag_brutto,
        'Zahlungseingang ' || NEW.rechnungsnummer,
        v_vorlage.belegordner, 'rechnung', NEW.id,
        EXTRACT(YEAR FROM COALESCE(NEW.zahlung_eingegangen_am, CURRENT_DATE))::INTEGER
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER rechnungen_auto_buchung_zahlung
  AFTER UPDATE OF zahlungsstatus ON rechnungen
  FOR EACH ROW EXECUTE FUNCTION auto_buchung_zahlung_eingegangen();

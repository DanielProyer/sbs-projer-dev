-- 218: 14 Excel-Reinigungen 2025 ohne Abrechnung kennzeichnen (01.10.2026,
--      Entscheid Daniel, Vorbereitung Jahresabschluss 2025).
--
-- WARUM: Der Monatsabschluss zeigte «Jede Reinigung hat ihre Ertragsbuchung»
-- rot in Januar, Februar, März, Juni, Juli, Oktober und November 2025. Die
-- 14 Reinigungen stammen aus dem Excel-Import (quelle 'excel_import'), stehen
-- auf «abgeschlossen», sind nicht abgerechnet und haben keine Buchung. Den
-- Preis 74.59 setzte der Preis-Trigger beim Import (Grundtarif 69.00 + 8.1 %);
-- in Excel war nichts verrechnet. Die Notizen sagen, warum: «Service/Eröffnung
-- durch Monteur», «Monteur», «zusammen mit Higeneie gemacht», «Kontrolle
-- Anlage», «Kontrolle und Wasser». Keine Buchung ist betroffen, der Gewinn
-- 2025 bleibt unverändert — es geht nur um die Kennzeichnung.
--
-- WAS (Entscheid Daniel 01.10.2026, Vorschlag «6 Monteur + 8 Kulanz»):
--   6 mit Notiz Monteur/Higeneie → ist_heineken_monteur = true, service_typ
--     NULL — so erfasst die App Monteur-Einsätze («nur Datum erfassen»); der
--     Preis-Trigger (UPDATE OF service_typ) rechnet damit auf 0.
--   8 mit Notiz Kontrolle oder «-» → ist_kulanz = true; der Trigger setzt den
--     Preis auf 0 (Migration 192).
-- Erkennung über extern_id (Excel-Schlüssel JJJJ_MM_TT_Betrieb_Lauf).
--
-- RÜCKWEG:
--   UPDATE reinigungen SET ist_heineken_monteur = false, service_typ = 'reinigung_bier'
--    WHERE quelle = 'excel_import' AND extern_id IN (…die sechs unten…);
--   UPDATE reinigungen SET ist_kulanz = false
--    WHERE quelle = 'excel_import' AND extern_id IN (…die acht unten…);
--   Der Trigger rechnet den Preis 74.59 wieder aus.

DO $$
DECLARE
  v_monteur TEXT[] := ARRAY[
    '2025_02_10_0695_01',  -- Seehotel Gotthard, «Eröffnung duch Monteur»
    '2025_03_20_0695_01',  -- Seehotel Gotthard, «Service durch Monteur»
    '2025_07_22_0743_01',  -- Tell's Pub, «Service durch Monteur»
    '2025_10_16_0740_01',  -- Thai-Food Curling Bistro, «Monteur»
    '2025_10_30_0788_01',  -- Paloma Vino & Tapas, «Monteur»
    '2025_11_21_0004_01'   -- Brüggli, «zusammen mit Higeneie gemacht»
  ];
  v_kulanz TEXT[] := ARRAY[
    '2025_01_16_0069_01',  -- Weissfluhgipfel, «-»
    '2025_02_05_0703_01',  -- Cafe Alexanderplatz, «-»
    '2025_03_14_0193_01',  -- Milez, «-»
    '2025_06_27_0476_01',  -- Alpenblick, «Kontrolle Anlage»
    '2025_07_07_0270_01',  -- Furt, «Kontrolle Anlage»
    '2025_07_10_0193_01',  -- Milez, «Kontrolle Anlage»
    '2025_11_27_0094_01',  -- Chalet Güggel, «Kontrolle und Wasser»
    '2025_11_27_0102_01'   -- Clavadeleralp, «Kontrolle und Wasser»
  ];
  v_n INTEGER;
  v_rest INTEGER;
BEGIN
  -- Nur Zeilen, die wirklich im gemeldeten Zustand sind: abgeschlossen, nicht
  -- abgerechnet, ohne Buchung, mit Trigger-Preis, bisher ohne Kennzeichen.
  UPDATE reinigungen r
     SET ist_heineken_monteur = true, service_typ = NULL
   WHERE r.quelle = 'excel_import' AND r.extern_id = ANY (v_monteur)
     AND r.status = 'abgeschlossen' AND NOT coalesce(r.abgerechnet, false)
     AND NOT coalesce(r.ist_kulanz, false) AND NOT coalesce(r.ist_heineken_monteur, false)
     AND NOT EXISTS (SELECT 1 FROM buchungen b WHERE b.beleg_id = r.id
                       AND NOT coalesce(b.ist_storniert, false));
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 6 THEN
    RAISE EXCEPTION '218: erwartet 6 Monteur-Reinigungen, tatsächlich % — abgebrochen', v_n;
  END IF;

  UPDATE reinigungen r
     SET ist_kulanz = true
   WHERE r.quelle = 'excel_import' AND r.extern_id = ANY (v_kulanz)
     AND r.status = 'abgeschlossen' AND NOT coalesce(r.abgerechnet, false)
     AND NOT coalesce(r.ist_kulanz, false) AND NOT coalesce(r.ist_heineken_monteur, false)
     AND NOT EXISTS (SELECT 1 FROM buchungen b WHERE b.beleg_id = r.id
                       AND NOT coalesce(b.ist_storniert, false));
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 8 THEN
    RAISE EXCEPTION '218: erwartet 8 Kulanz-Reinigungen, tatsächlich % — abgebrochen', v_n;
  END IF;

  -- Nachweis: Der Trigger hat alle 14 auf Preis 0 gerechnet.
  SELECT count(*) INTO v_rest FROM reinigungen r
   WHERE r.quelle = 'excel_import'
     AND r.extern_id = ANY (v_monteur || v_kulanz)
     AND coalesce(r.preis_brutto, 0) <> 0;
  IF v_rest <> 0 THEN
    RAISE EXCEPTION '218: % Reinigungen haben noch einen Preis — abgebrochen', v_rest;
  END IF;
  RAISE NOTICE '218: 6 Monteur + 8 Kulanz gekennzeichnet, Preis 0';
END $$;

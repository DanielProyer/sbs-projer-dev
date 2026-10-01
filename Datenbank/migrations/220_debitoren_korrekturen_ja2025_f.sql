-- 220: Jahresabschluss 2025 Schritt F — Debitoren-Korrekturen aus dem Excel-
--      Abgleich (01.10.2026, Entscheid Daniel, vier Fragen einzeln freigegeben).
--
-- Ausgangslage: Abschlussprüfung «Debitoren 1100 = offene Rechnungen» rot
-- (−4'315.85, nach Migration 219 −4'191.55). Zerlegung und Arbeitslisten:
-- docs/buchhaltung/debitoren-abgleich-excel-aera.md, Einordnung
-- docs/buchhaltung/jahresabschluss-2025.md §10a/§10b.
--
-- F1  März-2023-Lücke, bezahlte Rechnungen (27, brutto 2'383.45): Excel hat
--     vom 09. bis 27.03.2023 keine Forderung gebucht; die Zahlungen stehen auf
--     1100 (direkt verknüpft oder als Sammelzahlung), der Ertrag fehlte bis
--     heute. Je Rechnung `1100 an 8000` brutto per 31.12.2025 (periodenfremder
--     Ertrag im noch offenen Abschlussjahr), beleg_id = Rechnung.
-- F2  März-2023-Lücke, offene Rechnungen (6, brutto 630.05): dieselbe Buchung;
--     die Rechnungen bleiben offen (nie gestellt, Abschreibung mit dem
--     Jahrgang 2023 im Abschluss 2028).
-- F3  Heineken 08/2019: Excel-Forderung 4'366.16, Rechnung und Zahlung
--     4'204.61 → `8000 an 1100` 161.55 per 31.12.2025, Excel-Buchung mit der
--     Rechnung verknüpft. 05/2019 (3'237.70) und 05/2022 (4'477.63): die
--     Rechnungsbeträge werden auf die Excel-Werte gesetzt (Excel = Zahlung
--     Heineken), Buchungen verknüpft — damit sind alle 88 Heineken-Monate
--     verknüpft (Rest aus Migration 217).
-- F4  Zahlungen ohne Rechnung, Herkunft unklar (7, 1'169.15): «Einzahlungen
--     ohne Zuordnung» 2019, Schifer GmbH 2021, Rückerstattung Kehrichtgebühr
--     2021, «NOCH ABKLÄREN» 745.40 (2024) und 3 × 77.60 (2025). Geld kam, eine
--     Forderung wurde nie gebucht → je Zahlung `1100 an 8000` per 31.12.2025,
--     ohne MWST (Art der Leistung unbekannt; bei Klärung nachdeklarieren).
-- F_MWST  MWST 7.7 % auf F1+F2 (33 Rechnungen, netto 2'795.00, MWST 218.50
--     aus `rechnungen.mwst_betrag`) am Entscheidtag 01.10.2026: `8000 an 2200`
--     mit mwst_konto 2200 → erscheint als Umsatzsteuer in Q4/2026. Der Umsatz
--     (Zeile 302, 7.7 %, netto 2'795.00) ist im ESTV-Formular von Hand
--     einzutragen — die App zeigt als «Umsatz» nur Konto 3400.
-- F5  Schlussausgleich auf den verbleibenden Rest: eigene Migration 221, nach
--     Nachrechnung.
--
-- Wirkung 2025: Gewinn +4'021.10 (F1 2'383.45 + F2 630.05 − F3 161.55 + F4
-- 1'169.15), 1100 per 31.12.2025 ebenso +4'021.10; 2026: Aufwand 218.50 (MWST).
--
-- RÜCKWEG: DELETE FROM buchungen WHERE belegnummer LIKE 'JA2025_F%';
--   Heineken: UPDATE buchungen SET beleg_id = NULL, beleg_typ = NULL
--     WHERE belegordner = '012_Rechnung_Heineken' AND beschreibung = 'Heineken Rechnung'
--       AND datum IN ('2019-05-31','2019-08-31','2022-05-31');
--   Rechnungsbeträge 05/2019 und 05/2022 laut Notiz zurücksetzen.

DO $$
DECLARE
  v_user UUID;
  v_n INTEGER;
  v_sum NUMERIC;
  v_mwst NUMERIC;
  v_netto NUMERIC;
  v_rg UUID;
BEGIN
  IF EXISTS (SELECT 1 FROM buchungen WHERE belegnummer LIKE 'JA2025\_F%') THEN
    RAISE EXCEPTION '220: JA2025_F-Buchungen existieren schon';
  END IF;
  SELECT DISTINCT user_id INTO v_user FROM rechnungen WHERE rechnungstyp = 'heineken_monat';

  -- ---------------------------------------------------------------- F1 + F2
  INSERT INTO buchungen (user_id, datum, belegnummer, soll_konto, haben_konto, betrag_netto, mwst_satz, mwst_betrag,
                         betrag_brutto, beschreibung, zahlungsweg, beleg_typ, beleg_id, geschaeftsjahr, notizen)
  SELECT r.user_id, DATE '2025-12-31',
         CASE WHEN r.zahlungsstatus = 'bezahlt' THEN 'JA2025_F1' ELSE 'JA2025_F2' END,
         1100, 8000, r.betrag_brutto, 0, 0, r.betrag_brutto,
         format('Nachtrag Forderung %s %s (März-2023-Lücke, %s)', r.rechnungsnummer, b.name,
                CASE WHEN r.zahlungsstatus = 'bezahlt' THEN 'bezahlt ' || to_char(r.zahlung_eingegangen_am, 'DD.MM.YYYY') ELSE 'offen' END),
         'intern', 'abschluss', r.id, 2025,
         'Jahresabschluss 2025 Schritt F (Entscheid Daniel 01.10.2026): Excel buchte 09.–27.03.2023 keine Forderung; '
         || CASE WHEN r.zahlungsstatus = 'bezahlt' THEN 'Zahlung steht auf 1100, Ertrag fehlte.' ELSE 'Rechnung bleibt offen (nie gestellt).' END
         || ' Periodenfremder Ertrag brutto; MWST 7.7 % am Entscheidtag (JA2025_F_MWST, Q4/2026).'
  FROM rechnungen r JOIN betriebe b ON b.id = r.betrieb_id
  WHERE r.rechnungstyp <> 'heineken_monat'
    AND r.rechnungsdatum BETWEEN '2023-03-01' AND '2023-04-10'
    AND r.zahlungsstatus IN ('bezahlt', 'offen')
    AND NOT EXISTS (SELECT 1 FROM buchungen d WHERE d.soll_konto = 1100 AND d.beleg_id IS NULL
                      AND d.belegnummer = r.rechnungsnummer AND NOT coalesce(d.ist_storniert, false))
    AND NOT EXISTS (SELECT 1 FROM buchungen d WHERE d.soll_konto = 1100 AND d.beleg_id = r.id
                      AND NOT coalesce(d.ist_storniert, false));
  SELECT count(*), sum(betrag_brutto) INTO v_n, v_sum FROM buchungen WHERE belegnummer = 'JA2025_F1';
  IF v_n <> 27 OR v_sum <> 2383.45 THEN
    RAISE EXCEPTION '220 F1: erwartet 27 / 2383.45, tatsächlich % / %', v_n, v_sum;
  END IF;
  SELECT count(*), sum(betrag_brutto) INTO v_n, v_sum FROM buchungen WHERE belegnummer = 'JA2025_F2';
  IF v_n <> 6 OR v_sum <> 630.05 THEN
    RAISE EXCEPTION '220 F2: erwartet 6 / 630.05, tatsächlich % / %', v_n, v_sum;
  END IF;

  -- ---------------------------------------------------------------- F3 Heineken
  SELECT id INTO v_rg FROM rechnungen WHERE rechnungstyp = 'heineken_monat' AND heineken_monat = DATE '2019-08-01';
  IF v_rg IS NULL OR (SELECT betrag_brutto FROM rechnungen WHERE id = v_rg) <> 4204.61 THEN
    RAISE EXCEPTION '220 F3: Heineken 08/2019 nicht wie erwartet';
  END IF;
  INSERT INTO buchungen (user_id, datum, belegnummer, soll_konto, haben_konto, betrag_netto, mwst_satz, mwst_betrag,
                         betrag_brutto, beschreibung, zahlungsweg, beleg_typ, beleg_id, geschaeftsjahr, notizen)
  VALUES (v_user, DATE '2025-12-31', 'JA2025_F3', 8000, 1100, 161.55, 0, 0, 161.55,
          'Korrektur Heineken-Forderung 08/2019: Excel 4''366.16, Rechnung und Zahlung 4''204.61',
          'intern', 'abschluss', v_rg, 2025,
          'Jahresabschluss 2025 Schritt F (Entscheid Daniel 01.10.2026): Excel-Forderung um 161.55 zu hoch, nie bezahlt; periodenfremde Ertragsminderung.');
  -- Excel-Buchungen der drei abweichenden Monate verknüpfen; Rechnungsbeträge 05/2019 und 05/2022 auf Excel = Zahlung Heineken
  UPDATE buchungen b SET beleg_id = r.id, beleg_typ = 'rechnung'
    FROM rechnungen r
   WHERE b.belegordner = '012_Rechnung_Heineken' AND b.beschreibung = 'Heineken Rechnung' AND b.beleg_id IS NULL
     AND r.rechnungstyp = 'heineken_monat' AND r.heineken_monat = date_trunc('month', b.datum)::date
     AND b.datum IN ('2019-05-31', '2019-08-31', '2022-05-31');
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 3 THEN
    RAISE EXCEPTION '220 F3: erwartet 3 Heineken-Verknüpfungen, tatsächlich %', v_n;
  END IF;
  UPDATE rechnungen SET betrag_brutto = 3237.70, mwst_betrag = round(3237.70 - betrag_netto, 2),
         notizen = coalesce(notizen || E'\n', '') || 'Migration 220 (01.10.2026): Brutto 3237.68 → 3237.70 (Excel-Forderung = Zahlung Heineken).'
   WHERE rechnungstyp = 'heineken_monat' AND heineken_monat = DATE '2019-05-01' AND betrag_brutto = 3237.68;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RAISE EXCEPTION '220 F3: Heineken 05/2019 nicht angepasst'; END IF;
  UPDATE rechnungen SET betrag_brutto = 4477.63, betrag_netto = round(4477.63 / 1.077, 2), mwst_betrag = round(4477.63 - round(4477.63 / 1.077, 2), 2),
         notizen = coalesce(notizen || E'\n', '') || 'Migration 220 (01.10.2026): Brutto 4967.66 → 4477.63 (Excel-Forderung = Zahlung Heineken; Netto/MWST 7.7 % neu gerechnet).'
   WHERE rechnungstyp = 'heineken_monat' AND heineken_monat = DATE '2022-05-01' AND betrag_brutto = 4967.66;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RAISE EXCEPTION '220 F3: Heineken 05/2022 nicht angepasst'; END IF;

  -- ---------------------------------------------------------------- F4 Zahlungen ohne Rechnung
  INSERT INTO buchungen (user_id, datum, belegnummer, soll_konto, haben_konto, betrag_netto, mwst_satz, mwst_betrag,
                         betrag_brutto, beschreibung, zahlungsweg, beleg_typ, beleg_id, geschaeftsjahr, notizen)
  SELECT z.user_id, DATE '2025-12-31', 'JA2025_F4', 1100, 8000, z.betrag_brutto, 0, 0, z.betrag_brutto,
         format('Ertrag ohne Rechnung: Zahlung %s vom %s «%s»', z.belegnummer, to_char(z.datum, 'DD.MM.YYYY'), left(z.beschreibung, 60)),
         'intern', 'abschluss', NULL, 2025,
         'Jahresabschluss 2025 Schritt F (Entscheid Daniel 01.10.2026): Excel-Zahlung auf 1100 ohne Forderung/Rechnung, Herkunft unklar; periodenfremder Ertrag ohne MWST (bei Klärung nachdeklarieren).'
  FROM buchungen z
  WHERE z.haben_konto = 1100 AND z.beleg_id IS NULL AND NOT coalesce(z.ist_storniert, false) AND z.storno_von_id IS NULL
    AND z.belegnummer IN ('020_2019_05_13_0000_00006785', '020_2021_01_12__00008510', '020_2021_11_25_0000_00003800',
                          '020_2024_02_21__00074540', '020_2025_01_30__00007760', '020_2025_03_10__00007760', '020_2025_04_07__00007760');
  SELECT count(*), sum(betrag_brutto) INTO v_n, v_sum FROM buchungen WHERE belegnummer = 'JA2025_F4';
  IF v_n <> 7 OR v_sum <> 1169.15 THEN
    RAISE EXCEPTION '220 F4: erwartet 7 / 1169.15, tatsächlich % / %', v_n, v_sum;
  END IF;

  -- ---------------------------------------------------------------- F_MWST am Entscheidtag
  SELECT sum(r.mwst_betrag), sum(r.betrag_netto) INTO v_mwst, v_netto
    FROM buchungen f JOIN rechnungen r ON r.id = f.beleg_id
   WHERE f.belegnummer IN ('JA2025_F1', 'JA2025_F2');
  IF v_mwst <> 218.50 OR v_netto <> 2795.00 THEN
    RAISE EXCEPTION '220 F_MWST: erwartet 218.50 / 2795.00, tatsächlich % / %', v_mwst, v_netto;
  END IF;
  INSERT INTO buchungen (user_id, datum, belegnummer, soll_konto, haben_konto, mwst_konto, betrag_netto, mwst_satz, mwst_betrag,
                         betrag_brutto, beschreibung, zahlungsweg, beleg_typ, beleg_id, geschaeftsjahr, notizen)
  VALUES (v_user, DATE '2026-10-01', 'JA2025_F_MWST', 8000, 2200, 2200, 0, 7.7, v_mwst, v_mwst,
          format('MWST 7.7 %% auf nachgebuchten Ertrag März 2023 (33 Rg, netto %s) — Ziff. 200/Zeile 302 Q4/2026', v_netto),
          'intern', 'abschluss', NULL, 2026,
          'Jahresabschluss 2025 Schritt F (Entscheid Daniel 01.10.2026): Nachdeklaration in der laufenden Periode wie beim 2019-Muster. Umsatz 2''795.00 auf Zeile 302 von Hand eintragen (App-Umsatz = nur Konto 3400).');

  RAISE NOTICE '220: F1 27, F2 6, F3 1 (+3 Heineken verknüpft, 2 Beträge angepasst), F4 7, F_MWST %', v_mwst;
END $$;

-- 219: Excel-Zahlungen mit ihren Rechnungen verknüpfen, Zahldaten-Tippfehler
--      korrigieren, Eisstadion Davos bezahlt (01.10.2026, Entscheid Daniel).
--
-- WARUM: Beim Debitoren-Abgleich der Excel-Ära (docs/buchhaltung/
-- debitoren-abgleich-excel-aera.md) blieben 125 Excel-Zahlungen (Haben 1100,
-- Belegnummer 020_…) ohne beleg_id. 74 davon sind über `einzahlungsbeleg`
-- der Rechnungen schon zugeordnet (Sammelzahlungen, eine Zahlung für mehrere
-- Rechnungen — beleg_id kann nur eine tragen, die Zuordnung bleibt in
-- `einzahlungsbeleg`). Hier werden die eindeutigen Einzelfälle verknüpft:
--   - 4 Zahlungen, deren Betrag und Zahltag genau einer als bezahlt geführten
--     Rechnung ohne Zahlungsbuchung entsprechen;
--   - 14 Zahlungen, deren Rechnung ein verschriebenes Zahldatum trägt
--     (2002 statt 2024, 2025 statt 2024, ein Tag daneben) — gleicher Betrieb,
--     gleicher Betrag; das Zahldatum wird auf den Zahltag gesetzt;
--   - Eisstadion Davos: Zahlung 17.09.2025 «Service nicht erfasst» 124.30
--     gegen die offene Rechnung vom 11.09.2025 → bezahlt.
-- Nicht verknüpft: 020_2020_01_07_0023 85.10 ↔ 011_2020_01_02_0038 (Betriebs-
-- nummern 0023/0038 passen nicht, nur Betrag und Tag) — bleibt in Liste D.
--
-- Keine Buchung wird erzeugt oder verändert ausser beleg_id/beleg_typ; die
-- Salden ändern sich nicht. Die Abschlussprüfung «1100 = offene Rechnungen»
-- verbessert sich nur um Eisstadion (124.30).
--
-- RÜCKWEG: UPDATE buchungen SET beleg_id = NULL, beleg_typ = NULL
--   WHERE belegnummer IN (…Liste unten…) AND beleg_typ = 'zahlung';
--   Zahldaten laut Spalte «alt» zurücksetzen; Eisstadion-Rechnung
--   011_2025_09_11_0557_00012430 auf offen, zahlung_eingegangen_am NULL,
--   zahlung_betrag NULL, einzahlungsbeleg NULL.

DO $$
DECLARE
  p RECORD;
  v_bu UUID;
  v_rg UUID;
  v_status TEXT;
  v_alt DATE;
  v_n INTEGER := 0;
BEGIN
  FOR p IN
    SELECT * FROM (VALUES
      -- Zahlung (020_…)                     Rechnung (011_…)                     neues Zahldatum (NULL = unverändert)
      ('020_2020_09_30__00008510',           '011_2020_09_28_0023_00008510',      NULL::date),
      ('020_2021_10_29__00006785',           '011_2021_10_06_0499_00006785',      NULL),
      ('020_2022_01_31__00006785',           '011_2021_12_29_0490_00006785',      NULL),
      ('020_2023_10_16_109_00011875',        '011_2023_09_27_0109_00011875',      NULL),
      ('020_2022_11_25_0026_00015940',       '011_2022_10_27_0026_00015940',      DATE '2022-11-25'),  -- alt 2022-11-28
      ('020_2023_03_21_0125_00006785',       '011_2023_02_25_0125_00006785',      DATE '2023-03-21'),  -- alt 2023-03-23
      ('020_2023_05_12_0002_00007430',       '011_2023_04_27_0002_00007430',      DATE '2023-05-12'),  -- alt 2023-05-15
      ('020_2023_05_12_0045_00009370',       '011_2023_05_12_0045_00009370',      DATE '2023-05-12'),  -- alt 2023-05-15
      ('020_2023_05_12_0045_00009910',       '011_2023_05_12_0045_00009910',      DATE '2023-05-12'),  -- alt 2023-05-15
      ('020_2023_07_14_0034_00009370',       '011_2023_07_12_0034_00009370',      DATE '2023-07-14'),  -- alt 2023-07-12
      ('020_2024_01_25_0069_00007460',       '011_2024_01_25_0069_00007460',      DATE '2024-01-25'),  -- alt 2024-01-26
      ('020_2024_03_21_0629_00011890',       '011_2024_02_21_0629_00011890',      DATE '2024-03-21'),  -- alt 2002-03-21
      ('020_2024_10_30_0250_00007460',       '011_2024_10_02_0250_00007460',      DATE '2024-10-30'),  -- alt 2024-10-31
      ('020_2024_11_15_0221_00009945',       '011_2024_11_07_0221_00009945',      DATE '2024-11-15'),  -- alt 2002-11-15
      ('020_2024_12_17_0180_00012645',       '011_2024_11_04_0180_00012645',      DATE '2024-12-17'),  -- alt 2025-12-17
      ('020_2024_12_18_0703_00007460',       '011_2024_11_08_0703_00007460',      DATE '2024-12-18'),  -- alt 2025-12-18
      ('020_2024_12_24_0085_00011890',       '011_2024_12_03_0085_00011890',      DATE '2024-12-24'),  -- alt 2024-12-25
      ('020_2025_02_20_0123_00007460',       '011_2025_01_23_0123_00007460',      DATE '2025-02-20'),  -- alt 2024-02-20
      ('020_2025_09_17_0082_00012430',       '011_2025_09_11_0557_00012430',      DATE '2025-09-17')   -- Eisstadion, war offen
    ) AS t(zahlung, rechnung, zahldatum)
  LOOP
    SELECT b.id INTO v_bu FROM buchungen b
     WHERE b.belegnummer = p.zahlung AND b.haben_konto = 1100 AND b.beleg_id IS NULL
       AND NOT coalesce(b.ist_storniert, false) AND b.storno_von_id IS NULL;
    IF v_bu IS NULL THEN
      RAISE EXCEPTION '219: Zahlung % nicht (eindeutig) gefunden', p.zahlung;
    END IF;
    SELECT r.id, r.zahlungsstatus, r.zahlung_eingegangen_am INTO v_rg, v_status, v_alt
      FROM rechnungen r WHERE r.rechnungsnummer = p.rechnung;
    IF v_rg IS NULL THEN
      RAISE EXCEPTION '219: Rechnung % nicht gefunden', p.rechnung;
    END IF;
    IF EXISTS (SELECT 1 FROM buchungen x WHERE x.beleg_id = v_rg AND x.haben_konto = 1100
                 AND NOT coalesce(x.ist_storniert, false)) THEN
      RAISE EXCEPTION '219: Rechnung % hat schon eine Zahlungsbuchung', p.rechnung;
    END IF;
    IF (SELECT betrag_brutto FROM buchungen WHERE id = v_bu) <> (SELECT betrag_brutto FROM rechnungen WHERE id = v_rg) THEN
      RAISE EXCEPTION '219: Betrag passt nicht: % ↔ %', p.zahlung, p.rechnung;
    END IF;
    IF v_status = 'offen' AND p.rechnung <> '011_2025_09_11_0557_00012430' THEN
      RAISE EXCEPTION '219: Rechnung % ist offen, nur Eisstadion darf offen sein', p.rechnung;
    END IF;

    UPDATE buchungen SET beleg_id = v_rg, beleg_typ = 'zahlung' WHERE id = v_bu;
    UPDATE rechnungen
       SET zahlung_eingegangen_am = coalesce(p.zahldatum, zahlung_eingegangen_am),
           einzahlungsbeleg = CASE WHEN einzahlungsbeleg IS NULL OR einzahlungsbeleg = '-' THEN p.zahlung ELSE einzahlungsbeleg END,
           zahlungsstatus = 'bezahlt',
           zahlung_betrag = coalesce(zahlung_betrag, betrag_brutto),
           notizen = coalesce(notizen || E'\n', '') ||
             CASE WHEN v_status = 'offen' THEN 'Migration 219 (01.10.2026): Excel-Zahlung «Service nicht erfasst» vom 17.09.2025 zugeordnet, bezahlt.'
                  WHEN p.zahldatum IS NOT NULL THEN format('Migration 219 (01.10.2026): Zahldatum %s → %s (Tippfehler), Excel-Zahlung %s verknüpft.', v_alt, p.zahldatum, p.zahlung)
                  ELSE format('Migration 219 (01.10.2026): Excel-Zahlung %s verknüpft.', p.zahlung) END
     WHERE id = v_rg;
    v_n := v_n + 1;
  END LOOP;
  IF v_n <> 19 THEN
    RAISE EXCEPTION '219: erwartet 19 Verknüpfungen, tatsächlich %', v_n;
  END IF;
  RAISE NOTICE '219: % Excel-Zahlungen verknüpft', v_n;
END $$;

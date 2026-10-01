-- 221: Jahresabschluss 2025 Schritt F5 — Schlussausgleich Debitoren 1100
--      gegen die Rechnungsliste (01.10.2026, Entscheid Daniel).
--
-- Nach den Migrationen 217–220 lag 1100 heute noch 170.45 unter den offenen
-- Rechnungen (inkl. 658.35 Jahreskunden ohne Jahresrechnung), nachgerechnet
-- mit der Saldenlogik der App (MWST-Aufteilung). Der Rest besteht aus den
-- Kleinposten des Excel-Abgleichs (docs/buchhaltung/debitoren-abgleich-
-- excel-aera.md): 38 Betragspaare Forderung ↔ Rechnung (netto −106.38), zwei
-- Forderungen ohne Rechnung (Grill Aueli 85.10, BarBar 67.85), Spiga/Sunstar-
-- Preisabweichungen, vier Excel-Ausbuchungen «KEIN BELEG, Pächter abgehauen»
-- 2020 (271.40) und Rappenrundungen aus Sammelzahlungen. Entscheid Daniel:
-- ausbuchen, bis die Regel «Debitoren 1100 = offene Rechnungen (±0.50)» grün
-- ist. Eine Buchung `1100 an 8000` 170.45 per 31.12.2025, ohne MWST.
--
-- Der Block rechnet die Differenz selbst nach und bricht ab, wenn sie nicht
-- −170.45 ist (dann hat sich zwischenzeitlich etwas geändert).
--
-- RÜCKWEG: DELETE FROM buchungen WHERE belegnummer = 'JA2025_F5';

DO $$
DECLARE
  v_user UUID;
  v_diff NUMERIC;
BEGIN
  IF EXISTS (SELECT 1 FROM buchungen WHERE belegnummer = 'JA2025_F5') THEN
    RAISE EXCEPTION '221: JA2025_F5 existiert schon';
  END IF;
  SELECT DISTINCT user_id INTO v_user FROM rechnungen WHERE rechnungstyp = 'heineken_monat';

  WITH x AS (SELECT * FROM buchungen WHERE NOT coalesce(ist_storniert, false) AND storno_von_id IS NULL),
  beitraege AS (
    SELECT soll_konto AS konto, CASE WHEN coalesce(mwst_betrag, 0) = 0 OR mwst_konto IS NULL THEN betrag_brutto WHEN mwst_konto / 1000 = 1 THEN betrag_netto ELSE betrag_brutto END AS v FROM x
    UNION ALL
    SELECT haben_konto, CASE WHEN coalesce(mwst_betrag, 0) = 0 OR mwst_konto IS NULL THEN -betrag_brutto WHEN mwst_konto / 1000 = 1 THEN -betrag_brutto ELSE -betrag_netto END FROM x
    UNION ALL
    SELECT mwst_konto, CASE WHEN mwst_konto / 1000 = 1 THEN mwst_betrag ELSE -mwst_betrag END FROM x WHERE coalesce(mwst_betrag, 0) <> 0 AND mwst_konto IS NOT NULL),
  offen AS (
    SELECT r.betrag_brutto - (SELECT coalesce(sum(b.betrag_brutto), 0) FROM buchungen b WHERE b.beleg_id = r.id AND b.haben_konto = 1100
                                AND NOT coalesce(b.ist_storniert, false) AND b.storno_von_id IS NULL) AS forderung
    FROM rechnungen r WHERE r.zahlungsstatus = 'offen' AND (r.rechnungstyp <> 'heineken_monat' OR r.freigegeben_am IS NOT NULL))
  SELECT round((SELECT sum(v) FROM beitraege WHERE konto = 1100) - (SELECT sum(forderung) FROM offen) - 658.35, 2) INTO v_diff;

  IF v_diff <> -170.45 THEN
    RAISE EXCEPTION '221: erwartet Differenz −170.45, tatsächlich % — abgebrochen', v_diff;
  END IF;

  INSERT INTO buchungen (user_id, datum, belegnummer, soll_konto, haben_konto, betrag_netto, mwst_satz, mwst_betrag,
                         betrag_brutto, beschreibung, zahlungsweg, beleg_typ, beleg_id, geschaeftsjahr, notizen)
  VALUES (v_user, DATE '2025-12-31', 'JA2025_F5', 1100, 8000, 170.45, 0, 0, 170.45,
          'Schlussausgleich Debitoren 1100 auf die Rechnungsliste (Excel-Altbestand: Betragspaare, Forderungen ohne Rechnung, Rundungen)',
          'intern', 'abschluss', NULL, 2025,
          'Jahresabschluss 2025 Schritt F5 (Entscheid Daniel 01.10.2026): Rest nach F1–F4 und Migration 219; Zusammensetzung in docs/buchhaltung/debitoren-abgleich-excel-aera.md.');
  RAISE NOTICE '221: Schlussausgleich 170.45 gebucht';
END $$;

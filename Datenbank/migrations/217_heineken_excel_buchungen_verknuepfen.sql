-- 217: Heineken-Monatsrechnungen 2019–11/2025 mit ihrer Excel-Ertragsbuchung
--      verknüpfen (01.10.2026, Vorbereitung Jahresabschluss 2025).
--
-- WARUM: Der Monatsabschluss zeigte für Januar bis November 2025 die rote
-- Zeile «Monatsrechnung freigegeben — ohne Ertragsbuchung» (Regel R3,
-- `hatHeinekenErtragsbuchung`: Buchung mit beleg_id = Rechnung, beleg_typ
-- 'rechnung', Haben 3400). Der Ertrag STEHT aber im Hauptbuch: Der
-- Excel-Voll-Import (13.06.2026) brachte je Monat EINE Buchung 1100/3400
-- «Heineken Rechnung» (Belegordner 012_Rechnung_Heineken), rappengenau gleich
-- wie die am 14.07.2026 nachgetragene Monatsrechnung — nur ohne beleg_id.
-- Der Hinweis «Im Detail der Rechnung nachholen» hätte den Monatsertrag ein
-- zweites Mal gebucht (2025: 81'858.16 brutto in einem abgeschlossenen Jahr).
-- Dezember 2025 und alle Monate 2026 sind schon verknüpft (App-Freigabe).
--
-- WAS: beleg_id + beleg_typ = 'rechnung' auf den Excel-Buchungen setzen —
-- NUR bei exaktem Treffer: genau eine Excel-Buchung im Monat, Betrag brutto
-- identisch mit der Rechnung, Rechnung noch ohne Ertragsbuchung. Stand
-- 01.10.2026 sind das 76 von 79 unverknüpften Monatsrechnungen; der Block
-- bricht ab, wenn es nicht genau 76 sind. Drei bleiben bewusst offen, weil
-- Excel-Buchung und Rechnung voneinander abweichen (Entscheid Daniel offen):
--   2019-05  Rechnung 3'237.68  Excel 3'237.70  (Rundung 0.02)
--   2019-08  Rechnung 4'204.61  Excel 4'366.16  (−161.55)
--   2022-05  Rechnung 4'967.66  Excel 4'477.63  (+490.03)
-- Belegnummer (012_JJJJ_MM_TT_ReHe_…), Datum, Beträge und Konten bleiben
-- unverändert; es wird keine Buchung erzeugt oder storniert.
--
-- RÜCKWEG (die App-Buchungen tragen keinen belegordner):
--   UPDATE buchungen SET beleg_id = NULL, beleg_typ = NULL
--    WHERE belegordner = '012_Rechnung_Heineken' AND beleg_typ = 'rechnung'
--      AND beschreibung = 'Heineken Rechnung';

DO $$
DECLARE
  v_n INTEGER;
BEGIN
  WITH excel AS (
    SELECT b.id AS buchung_id, b.user_id,
           date_trunc('month', b.datum)::date AS monat, b.betrag_brutto
      FROM buchungen b
     WHERE b.belegordner = '012_Rechnung_Heineken'
       -- Im selben Ordner liegt eine Fremdrechnung (01/2023 «Ecqua
       -- Abfischen»); nur die Monatsrechnung selbst zählt.
       AND b.beschreibung = 'Heineken Rechnung'
       AND b.soll_konto = 1100 AND b.haben_konto = 3400
       AND b.beleg_id IS NULL AND b.beleg_typ IS NULL
       AND NOT coalesce(b.ist_storniert, false) AND b.storno_von_id IS NULL
  ),
  einzeln AS (
    SELECT user_id, monat FROM excel GROUP BY user_id, monat HAVING count(*) = 1
  ),
  ziel AS (
    SELECT e.buchung_id, r.id AS rechnung_id
      FROM excel e
      JOIN einzeln m ON m.user_id = e.user_id AND m.monat = e.monat
      JOIN rechnungen r ON r.user_id = e.user_id
                       AND r.rechnungstyp = 'heineken_monat'
                       AND r.heineken_monat = e.monat
                       AND r.betrag_brutto = e.betrag_brutto
     WHERE NOT EXISTS (
             SELECT 1 FROM buchungen x
              WHERE x.beleg_id = r.id AND x.haben_konto = 3400
                AND NOT coalesce(x.ist_storniert, false))
  )
  UPDATE buchungen b
     SET beleg_id = z.rechnung_id, beleg_typ = 'rechnung'
    FROM ziel z
   WHERE b.id = z.buchung_id;

  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 76 THEN
    RAISE EXCEPTION '217: erwartet 76 Verknüpfungen, tatsächlich % — abgebrochen', v_n;
  END IF;
  RAISE NOTICE '217: % Heineken-Buchungen mit ihrer Monatsrechnung verknüpft', v_n;
END $$;

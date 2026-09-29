-- 214: Mehrere Abschreibungsläufe je Geschäftsjahr (29.09.2026).
--
-- WARUM: Der Abschluss 2025 hat schon einen gebuchten Lauf (Jahrgang 2019,
-- am 02.09.2026 per SQL nachgetragen, Rücknahme nur von Hand). Entscheid
-- Daniel 29.09.2026: Jahrgang 2020 wird EBENFALLS per 31.12.2025
-- abgeschrieben (Jahresabschluss 2025 am 01.10.2026). Der Wächter «Für 2025
-- gibt es schon einen gebuchten Lauf — zuerst zurücknehmen» aus Migration 194
-- verhinderte das. Er sollte Doppelbuchungen verhindern — das tut aber schon
-- die Prüfung je Rechnung (Status «abgeschrieben» ist nicht abschreibbar).
-- Neu blockiert nur noch eine Rechnung, die in einem gebuchten Lauf schon
-- als Position steht. Ein zweiter Lauf mit anderen Rechnungen ist erlaubt.
--
-- Sonst unverändert gegenüber dem Stand in der Datenbank (194, angepasst
-- in 209/211): Buchungsdatum 31.12. des Geschäftsjahrs, netto auf 3805,
-- MWST-Rückholung 2200 an 1100, mwst_jahr/quartal = Geschäftsjahr/Q4.

CREATE OR REPLACE FUNCTION abschreibung_jahrgang_buchen(p_geschaeftsjahr INTEGER, p_rechnung_ids UUID[])
RETURNS UUID
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_datum DATE := make_date(p_geschaeftsjahr, 12, 31);
  v_grenze INTEGER := p_geschaeftsjahr - 5;   -- Art. 128 Ziff. 3 OR: fünf Jahre
  v_lauf UUID;
  v_fehler TEXT;
  v_kat TEXT;
  v_jahrgang INTEGER;
  v_satz NUMERIC;
  v_netto_id UUID;
  v_mwst_id UUID;
  v_n INTEGER := 0;
  v_netto NUMERIC := 0;
  v_mwst NUMERIC := 0;
  v_brutto NUMERIC := 0;
  r RECORD;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'Nicht angemeldet';
  END IF;
  IF p_rechnung_ids IS NULL OR cardinality(p_rechnung_ids) = 0 THEN
    RAISE EXCEPTION 'Keine Rechnungen übergeben';
  END IF;
  -- Seit 214: nicht mehr «ein Lauf je Jahr», sondern «keine Rechnung doppelt».
  SELECT string_agg(p.rechnungsnummer, ', ') INTO v_fehler
  FROM abschreibung_positionen p
  JOIN abschreibung_laeufe l ON l.id = p.lauf_id
  WHERE l.user_id = v_user AND l.status = 'gebucht'
    AND p.rechnung_id = ANY (p_rechnung_ids);
  IF v_fehler IS NOT NULL THEN
    RAISE EXCEPTION 'Schon in einem gebuchten Lauf: %', v_fehler;
  END IF;

  SELECT string_agg(coalesce(rg.rechnungsnummer, x.id::text), ', ') INTO v_fehler
  FROM unnest(p_rechnung_ids) AS x(id)
  LEFT JOIN rechnungen rg ON rg.id = x.id AND rg.user_id = v_user
  WHERE rg.id IS NULL
     OR rg.rechnungstyp <> 'kundenrechnung'
     OR rg.zahlungsstatus IN ('bezahlt', 'abgeschrieben')
     OR EXTRACT(YEAR FROM rg.rechnungsdatum) > v_grenze
     OR rg.zahlung_eingegangen_am IS NOT NULL
     OR coalesce(rg.zahlung_betrag, 0) > 0
     OR rg.betrag_brutto <= 0
     OR abs(rg.betrag_brutto - rg.betrag_netto - rg.mwst_betrag) > 0.011;
  IF v_fehler IS NOT NULL THEN
    RAISE EXCEPTION 'Nicht abschreibbar (bezahlt, abgeschrieben, jünger als % Jahre, mit Zahlung oder Summen unstimmig): %', 5, v_fehler;
  END IF;

  INSERT INTO abschreibung_laeufe (user_id, geschaeftsjahr, buchungsdatum, mwst_jahr, mwst_quartal, notizen)
  VALUES (v_user, p_geschaeftsjahr, v_datum, p_geschaeftsjahr, 4,
          format('Jahresabschluss %s Schritt A: Abschreibung verjährter Jahrgänge (App-Schritt «Jahrgang abschreiben»)', p_geschaeftsjahr))
  RETURNING id INTO v_lauf;

  FOR r IN
    SELECT rg.id, rg.rechnungsnummer, rg.rechnungsdatum, rg.betrag_netto, rg.mwst_betrag, rg.betrag_brutto,
           rg.zahlungsstatus, rg.versandart, rg.uebergeben_am, rg.versendet_am, bt.name AS betrieb
    FROM rechnungen rg
    LEFT JOIN betriebe bt ON bt.id = rg.betrieb_id
    WHERE rg.id = ANY (p_rechnung_ids) AND rg.user_id = v_user
    ORDER BY rg.rechnungsdatum, rg.id
    FOR UPDATE OF rg
  LOOP
    v_jahrgang := EXTRACT(YEAR FROM r.rechnungsdatum)::INTEGER;
    v_kat := abschreibung_kategorie(r.versandart, r.uebergeben_am, r.versendet_am);
    v_satz := CASE WHEN r.betrag_netto > 0 THEN round(r.mwst_betrag / r.betrag_netto * 100, 1) ELSE 0 END;

    INSERT INTO buchungen (user_id, datum, belegnummer, soll_konto, haben_konto, betrag_netto, mwst_satz, mwst_betrag,
                           betrag_brutto, beschreibung, zahlungsweg, beleg_typ, beleg_id, geschaeftsjahr, notizen)
    VALUES (v_user, v_datum, r.rechnungsnummer, 3805, 1100, r.betrag_netto, 0, 0, r.betrag_netto,
            format('Debitorenverlust %s %s (Abschreibung Jahrgang %s, verjährt Art. 128 OR)',
                   r.rechnungsnummer, coalesce(r.betrieb, ''), v_jahrgang),
            'intern', 'abschreibung', r.id, p_geschaeftsjahr,
            format('Jahresabschluss %s Schritt A: Abschreibung Jahrgang %s (netto)', p_geschaeftsjahr, v_jahrgang))
    RETURNING id INTO v_netto_id;

    v_mwst_id := NULL;
    IF r.mwst_betrag > 0 THEN
      INSERT INTO buchungen (user_id, datum, belegnummer, soll_konto, haben_konto, betrag_netto, mwst_satz, mwst_betrag,
                             betrag_brutto, beschreibung, zahlungsweg, beleg_typ, beleg_id, geschaeftsjahr, notizen)
      VALUES (v_user, v_datum, r.rechnungsnummer, 2200, 1100, r.mwst_betrag, 0, 0, r.mwst_betrag,
              format('MWST-Rückholung %s %s (Abschreibung Jahrgang %s, %s %%, Ziff. 235)',
                     r.rechnungsnummer, coalesce(r.betrieb, ''), v_jahrgang, v_satz),
              'intern', 'abschreibung', r.id, p_geschaeftsjahr,
              format('Jahresabschluss %s Schritt A: Abschreibung Jahrgang %s (MWST-Rückholung %s %%)', p_geschaeftsjahr, v_jahrgang, v_satz))
      RETURNING id INTO v_mwst_id;
    END IF;

    UPDATE rechnungen SET zahlungsstatus = 'abgeschrieben' WHERE id = r.id;

    INSERT INTO abschreibung_positionen (lauf_id, user_id, rechnung_id, rechnungsnummer, betrieb, jahrgang, kategorie,
                                         netto, mwst, brutto, status_vorher, buchung_netto_id, buchung_mwst_id)
    VALUES (v_lauf, v_user, r.id, r.rechnungsnummer, r.betrieb, v_jahrgang, v_kat,
            r.betrag_netto, r.mwst_betrag, r.betrag_brutto, r.zahlungsstatus, v_netto_id, v_mwst_id);

    v_n := v_n + 1;
    v_netto := v_netto + r.betrag_netto;
    v_mwst := v_mwst + r.mwst_betrag;
    v_brutto := v_brutto + r.betrag_brutto;
  END LOOP;

  UPDATE abschreibung_laeufe
     SET anzahl = v_n, netto = v_netto, mwst = v_mwst, brutto = v_brutto,
         jahrgaenge = (SELECT array_agg(DISTINCT jahrgang ORDER BY jahrgang)
                       FROM abschreibung_positionen WHERE lauf_id = v_lauf)
   WHERE id = v_lauf;
  RETURN v_lauf;
END
$$;

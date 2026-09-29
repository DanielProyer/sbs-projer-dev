-- 215: «Jahrgang abschreiben» nach dem 2019-Muster (29.09.2026).
--
-- WARUM: Bis 214 buchte der App-Schritt je Rechnung `3805 an 1100 netto` und
-- `2200 an 1100 MWST`, beide per 31.12. des Geschäftsjahrs, und legte die
-- MWST-Periode des Laufs auf Q4 dieses Jahres. Der Abschluss findet aber im
-- Folgejahr statt — Q4 ist dann in aller Regel eingereicht. Die Rückholung
-- per 31.12. erzwänge eine Korrekturabrechnung. Richtig ist die
-- Entgeltsminderung in der Periode des Entscheids (Art. 41 Abs. 2 MWSTG),
-- also das 2019-Muster (Jahrgang 2019, Abschluss 2025, JA2025_A_MWST):
--   je Rechnung      3805 an 1100  BRUTTO   per 31.12. Geschäftsjahr
--   je MWST-Satz     2200 an 3805  MWST     am Entscheidtag (Sammelbuchung)
-- Der Verlust steht brutto im Abschlussjahr; die Rückholung mindert 3805 und
-- 2200 im laufenden Quartal und gehört dort unter Ziff. 235. Ablauf und
-- Zahlen: docs/buchhaltung/jahresabschluss-2025.md §9 (Jahrgang 2020 am
-- 01.10.2026), Konzept docs/buchhaltung/abschreibungen-jahrgaenge.md §2.
-- Entscheid Daniel 29.09.2026: «Schritte in die App, damit ich das in
-- späteren Jahren direkt machen kann».
--
-- Entscheidtag = Schweizer Datum, nicht `current_date`: die Datenbank läuft
-- in UTC, zwischen 00:00 und 02:00 Schweizer Zeit wäre das noch der Vortag —
-- am Ersten eines Quartals das falsche Quartal.
--
-- Zusätzlich (nicht Kern, aber Voraussetzung für §9a am 01.10.2026): der
-- eindeutige Index `abschreibung_laeufe_ein_gebuchter` aus 194 fällt. 214
-- hat nur den RAISE-Wächter «ein Lauf je Jahr» entfernt; der Index hätte den
-- zweiten Lauf 2025 (2019 per SQL, 2020 per App) trotzdem mit «duplicate
-- key» abgewiesen (geprüft 29.09.2026: Index in der Datenbank vorhanden).
-- Sein Nebennutzen — ein Doppelklick bucht nicht zweimal — übernimmt jetzt
-- eine Sperre der Rechnungen VOR den Prüfungen: der zweite Aufruf wartet,
-- sieht danach «abgeschrieben» bzw. die Positionen und bricht ab.
--
-- Bestehende Läufe bleiben unberührt: der 2019er (per SQL) erhält
-- `buchung_mwst_ids = '{}'` und ist weiterhin nur von Hand zurücknehmbar;
-- seine Sammelbuchung JA2025_A_MWST steht in keinem Lauf.
--
-- `view_entgeltsminderung` rechnet Jahrgangsläufe neu je Satz aus den
-- Positionen statt als Mischsatz aus den Laufsummen — sonst ergäbe ein Lauf
-- über 2023 (7.7 %) und 2024 (8.1 %) einen Satz, den es im Formular nicht
-- gibt. Für den 2019er-Lauf ändert sich nichts (29 Rg, alle 7.7 %).

ALTER TABLE abschreibung_laeufe
  ADD COLUMN IF NOT EXISTS buchung_mwst_ids uuid[] NOT NULL DEFAULT '{}';
COMMENT ON COLUMN abschreibung_laeufe.buchung_mwst_ids IS
  'Seit 215: Sammelbuchungen der MWST-Rueckholung (2200 an 3805, je Satz eine, am Entscheidtag). Leer bei Laeufen vor 215.';
COMMENT ON COLUMN abschreibung_positionen.buchung_netto_id IS
  'Buchung 3805 an 1100 dieser Rechnung — seit 215 brutto (vorher netto).';
COMMENT ON COLUMN abschreibung_positionen.buchung_mwst_id IS
  'Buchung 2200 an 1100 dieser Rechnung (Laeufe vor 215). Seit 215 NULL: die Rueckholung steht als Sammelbuchung in abschreibung_laeufe.buchung_mwst_ids.';

DROP INDEX IF EXISTS abschreibung_laeufe_ein_gebuchter;

CREATE OR REPLACE FUNCTION abschreibung_jahrgang_buchen(p_geschaeftsjahr INTEGER, p_rechnung_ids UUID[])
RETURNS UUID
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_datum DATE := make_date(p_geschaeftsjahr, 12, 31);
  -- Entscheidtag: Datum der Rückholung und MWST-Periode (Ziff. 235)
  v_entscheid DATE := (now() AT TIME ZONE 'Europe/Zurich')::date;
  v_mwst_jahr INTEGER;
  v_mwst_quartal INTEGER;
  v_grenze INTEGER := p_geschaeftsjahr - 5;   -- Art. 128 Ziff. 3 OR: fünf Jahre
  v_lauf UUID;
  v_lauf_nr INTEGER;
  v_fehler TEXT;
  v_kat TEXT;
  v_jahrgang INTEGER;
  v_brutto_id UUID;
  v_mwst_id UUID;
  v_mwst_ids UUID[] := '{}';
  v_n INTEGER := 0;
  v_netto NUMERIC := 0;
  v_mwst NUMERIC := 0;
  v_brutto NUMERIC := 0;
  r RECORD;
  s RECORD;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'Nicht angemeldet';
  END IF;
  IF p_rechnung_ids IS NULL OR cardinality(p_rechnung_ids) = 0 THEN
    RAISE EXCEPTION 'Keine Rechnungen übergeben';
  END IF;
  v_mwst_jahr := EXTRACT(YEAR FROM v_entscheid)::INTEGER;
  v_mwst_quartal := EXTRACT(QUARTER FROM v_entscheid)::INTEGER;

  -- Seit 215: zuerst sperren, dann prüfen. Ein zweiter, gleichzeitiger Aufruf
  -- mit denselben Rechnungen wartet hier und sieht danach deren Positionen.
  PERFORM 1 FROM rechnungen
   WHERE id = ANY (p_rechnung_ids) AND user_id = v_user
   ORDER BY id
   FOR UPDATE;

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
  VALUES (v_user, p_geschaeftsjahr, v_datum, v_mwst_jahr, v_mwst_quartal,
          format('Jahresabschluss %s Schritt A: Abschreibung verjährter Jahrgänge (App-Schritt «Jahrgang abschreiben»): brutto auf 3805 per %s, MWST-Rückholung 2200 an 3805 am Entscheidtag %s — Ziff. 235 Q%s/%s',
                 p_geschaeftsjahr, to_char(v_datum, 'DD.MM.YYYY'), to_char(v_entscheid, 'DD.MM.YYYY'),
                 v_mwst_quartal, v_mwst_jahr))
  RETURNING id INTO v_lauf;

  -- Nummer des Laufs im Geschäftsjahr — nur für die Belegnummer, damit ein
  -- zweiter Lauf im selben Abschluss unterscheidbar bleibt (2025: L2).
  -- Zurückgenommene Läufe zählen mit (sie bleiben als Zeilen stehen): so
  -- bleibt die Nummer fortlaufend, und ein neuer Lauf nach einer Rücknahme
  -- trägt nie die Belegnummer der gelöschten Rückholung.
  SELECT count(*) INTO v_lauf_nr
  FROM abschreibung_laeufe
  WHERE user_id = v_user AND geschaeftsjahr = p_geschaeftsjahr;

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

    -- Seit 215 brutto: die MWST kommt als Sammelbuchung am Entscheidtag zurück.
    INSERT INTO buchungen (user_id, datum, belegnummer, soll_konto, haben_konto, betrag_netto, mwst_satz, mwst_betrag,
                           betrag_brutto, beschreibung, zahlungsweg, beleg_typ, beleg_id, geschaeftsjahr, notizen)
    VALUES (v_user, v_datum, r.rechnungsnummer, 3805, 1100, r.betrag_brutto, 0, 0, r.betrag_brutto,
            format('Debitorenverlust %s %s (Abschreibung Jahrgang %s, verjährt Art. 128 OR)',
                   r.rechnungsnummer, coalesce(r.betrieb, ''), v_jahrgang),
            'intern', 'abschreibung', r.id, p_geschaeftsjahr,
            format('Jahresabschluss %s Schritt A: Abschreibung Jahrgang %s (brutto)', p_geschaeftsjahr, v_jahrgang))
    RETURNING id INTO v_brutto_id;

    UPDATE rechnungen SET zahlungsstatus = 'abgeschrieben' WHERE id = r.id;

    INSERT INTO abschreibung_positionen (lauf_id, user_id, rechnung_id, rechnungsnummer, betrieb, jahrgang, kategorie,
                                         netto, mwst, brutto, status_vorher, buchung_netto_id, buchung_mwst_id)
    VALUES (v_lauf, v_user, r.id, r.rechnungsnummer, r.betrieb, v_jahrgang, v_kat,
            r.betrag_netto, r.mwst_betrag, r.betrag_brutto, r.zahlungsstatus, v_brutto_id, NULL);

    v_n := v_n + 1;
    v_netto := v_netto + r.betrag_netto;
    v_mwst := v_mwst + r.mwst_betrag;
    v_brutto := v_brutto + r.betrag_brutto;
  END LOOP;

  -- MWST-Rückholung: je Satz der Leistung (7.7 % bis 2023, 8.1 % ab 2024 —
  -- aus mwst_betrag der Rechnung, nie der Satz des Buchungstages) EINE
  -- Sammelbuchung. Ohne beleg_id: view_entgeltsminderung zählt sie über den
  -- Lauf (mwst_jahr/mwst_quartal), nicht als Einzelabschreibung.
  FOR s IN
    SELECT CASE WHEN p.netto > 0 THEN round(p.mwst / p.netto * 100, 1) ELSE 0 END AS satz,
           count(*)::int AS anzahl,
           sum(p.mwst) AS mwst,
           sum(p.brutto) AS brutto,
           array_to_string(array_agg(DISTINCT p.jahrgang ORDER BY p.jahrgang), ', ') AS jahrgaenge
    FROM abschreibung_positionen p
    WHERE p.lauf_id = v_lauf AND p.mwst > 0
    GROUP BY 1
    ORDER BY 1
  LOOP
    INSERT INTO buchungen (user_id, datum, belegnummer, soll_konto, haben_konto, betrag_netto, mwst_satz, mwst_betrag,
                           betrag_brutto, beschreibung, zahlungsweg, beleg_typ, beleg_id, geschaeftsjahr, notizen)
    VALUES (v_user, v_entscheid,
            format('JA%s_A_MWST_%s', p_geschaeftsjahr, replace(s.satz::text, '.', '_'))
              || CASE WHEN v_lauf_nr > 1 THEN format('_L%s', v_lauf_nr) ELSE '' END,
            2200, 3805, s.mwst, 0, 0, s.mwst,
            format('MwSt-Rückholung Debitorenverluste Jahrgang %s (%s Rg, brutto %s, %s %%) — Ziff. 235 Q%s/%s',
                   s.jahrgaenge, s.anzahl, replace(to_char(s.brutto, 'FM999,999,990.00'), ',', ''''),
                   s.satz, v_mwst_quartal, v_mwst_jahr),
            'intern', 'abschreibung', NULL, v_mwst_jahr,
            format('Jahresabschluss %s Schritt A: MWST-Rückholung Jahrgang(e) %s (Entscheidtag)',
                   p_geschaeftsjahr, s.jahrgaenge))
    RETURNING id INTO v_mwst_id;
    v_mwst_ids := v_mwst_ids || v_mwst_id;
  END LOOP;

  UPDATE abschreibung_laeufe
     SET anzahl = v_n, netto = v_netto, mwst = v_mwst, brutto = v_brutto,
         buchung_mwst_ids = v_mwst_ids,
         jahrgaenge = (SELECT array_agg(DISTINCT jahrgang ORDER BY jahrgang)
                       FROM abschreibung_positionen WHERE lauf_id = v_lauf)
   WHERE id = v_lauf;
  RETURN v_lauf;
END
$$;

-- Rücknahme: Stand 211 (Status 'offen', Altwert hebt die Mahnstufe), dazu
-- seit 215 die Sammelbuchungen des Laufs — auf Storno prüfen, dann löschen.
-- Läufe vor 215 haben keine (`'{}'`), dort ändert sich nichts.
CREATE OR REPLACE FUNCTION abschreibung_lauf_zuruecknehmen(p_lauf UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_user UUID := auth.uid();
  l abschreibung_laeufe%ROWTYPE;
  p RECORD;
  v_n INTEGER := 0;
BEGIN
  SELECT * INTO l FROM abschreibung_laeufe WHERE id = p_lauf AND user_id = v_user FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Lauf nicht gefunden';
  END IF;
  IF l.status <> 'gebucht' THEN
    RAISE EXCEPTION 'Lauf ist bereits zurückgenommen';
  END IF;
  IF NOT l.ruecknahme_moeglich THEN
    RAISE EXCEPTION 'Dieser Lauf wurde per SQL gebucht — Rücknahme nur von Hand (docs/buchhaltung/jahresabschluss-%.md)', l.geschaeftsjahr;
  END IF;

  IF EXISTS (SELECT 1 FROM buchungen
             WHERE (id = ANY (l.buchung_mwst_ids) AND ist_storniert)
                OR storno_von_id = ANY (l.buchung_mwst_ids)) THEN
    RAISE EXCEPTION 'MWST-Rückholung des Laufs ist storniert — Rücknahme von Hand';
  END IF;

  FOR p IN SELECT * FROM abschreibung_positionen WHERE lauf_id = p_lauf LOOP
    IF EXISTS (SELECT 1 FROM buchungen
               WHERE (id IN (p.buchung_netto_id, p.buchung_mwst_id) AND ist_storniert)
                  OR storno_von_id IN (p.buchung_netto_id, p.buchung_mwst_id)) THEN
      RAISE EXCEPTION 'Buchung zu % ist storniert — Rücknahme von Hand', p.rechnungsnummer;
    END IF;
    DELETE FROM buchungen WHERE id IN (p.buchung_netto_id, p.buchung_mwst_id) AND user_id = v_user;
    UPDATE rechnungen
       SET zahlungsstatus = 'offen',
           mahnung_stufe = greatest(coalesce(mahnung_stufe, 0), rechnung_stufe_aus_altstatus(p.status_vorher))
     WHERE id = p.rechnung_id AND user_id = v_user AND zahlungsstatus = 'abgeschrieben';
    v_n := v_n + 1;
  END LOOP;

  DELETE FROM buchungen WHERE id = ANY (l.buchung_mwst_ids) AND user_id = v_user;

  UPDATE abschreibung_laeufe SET status = 'zurueckgenommen', zurueckgenommen_am = now() WHERE id = p_lauf;
  RETURN v_n;
END
$$;

-- Ziff. 235 je Quartal und Satz. Spalten, Reihenfolge und Typen wie seit 196
-- (user_id uuid, jahr int, quartal int, satz numeric, netto numeric,
-- mwst numeric, anzahl int, text text) — sonst scheitert CREATE OR REPLACE.
-- Teil a) neu je Lauf UND Satz aus den Positionen; Teil b) unverändert (209c).
CREATE OR REPLACE VIEW view_entgeltsminderung
WITH (security_invoker = true) AS
SELECT l.user_id,
       l.mwst_jahr                         AS jahr,
       l.mwst_quartal                      AS quartal,
       round(p.mwst / p.netto * 100, 1) AS satz,
       sum(p.netto)                        AS netto,
       sum(p.mwst)                         AS mwst,
       count(*)::int                       AS anzahl,
       -- Jahrgänge DIESES Satzes, nicht des ganzen Laufs: sonst hiesse die
       -- 7.7-%-Zeile eines Laufs über 2023 und 2024 «Jahrgang 2023, 2024».
       format('Abschreibung Jahrgang %s (Abschluss %s, %s Rechnungen)',
              array_to_string(array_agg(DISTINCT p.jahrgang ORDER BY p.jahrgang), ', '),
              l.geschaeftsjahr, count(*)) AS text
FROM abschreibung_laeufe l
JOIN abschreibung_positionen p ON p.lauf_id = l.id
WHERE l.status = 'gebucht' AND p.netto > 0
GROUP BY l.id, l.user_id, l.mwst_jahr, l.mwst_quartal, l.geschaeftsjahr,
         round(p.mwst / p.netto * 100, 1)

UNION ALL

SELECT b.user_id,
       b.geschaeftsjahr AS jahr,
       b.quartal,
       round(r.mwst_betrag / r.betrag_netto * 100, 1) AS satz,
       sum((SELECT coalesce(sum(n.betrag_brutto), 0)
            FROM buchungen n
            WHERE n.beleg_id = b.beleg_id
              AND n.soll_konto = 3805 AND n.haben_konto = 1100
              AND n.beleg_typ = 'abschreibung'
              AND NOT coalesce(n.ist_storniert, false) AND n.storno_von_id IS NULL
              AND n.geschaeftsjahr = b.geschaeftsjahr AND n.quartal = b.quartal)) AS netto,
       sum(b.betrag_brutto)  AS mwst,
       count(*)::int         AS anzahl,
       format('Einzelabschreibungen (%s %s)', count(*),
              CASE WHEN count(*) = 1 THEN 'Rechnung' ELSE 'Rechnungen' END) AS text
FROM buchungen b
JOIN rechnungen r ON r.id = b.beleg_id
WHERE b.soll_konto = 2200
  AND b.beleg_typ = 'abschreibung'
  AND NOT coalesce(b.ist_storniert, false)
  AND b.storno_von_id IS NULL
  AND r.betrag_netto > 0
  AND NOT EXISTS (SELECT 1 FROM abschreibung_positionen p WHERE p.rechnung_id = b.beleg_id)
GROUP BY b.user_id, b.geschaeftsjahr, b.quartal,
         round(r.mwst_betrag / r.betrag_netto * 100, 1);

COMMENT ON VIEW view_entgeltsminderung IS
  'MWST Ziff. 235 je Quartal und Satz: Jahrgangslaeufe (seit 215 je Lauf und Satz aus abschreibung_positionen, Periode aus mwst_jahr/mwst_quartal = Quartal des Entscheidtags) plus Einzelabschreibungen (Buchung 2200 an 1100, beleg_typ abschreibung, nicht Teil eines Laufs). Formularzeile 302 = 7.7 %, 303 = 8.1 %.';

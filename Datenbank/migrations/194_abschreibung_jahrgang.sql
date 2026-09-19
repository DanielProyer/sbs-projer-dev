-- 194: «Jahrgang abschreiben» — Läufe, Positionen, atomare Buchung (19.09.2026)
--
-- WARUM eine SQL-Funktion und nicht 320 Einzel-Requests aus der App:
-- PostgREST kennt keine Transaktion über mehrere Requests. Bricht der Browser
-- nach Rechnung 80 von 160 ab (Handy weggesteckt — siehe Reinigungs-Abschluss-
-- Kette, v0.97.0), stünden 80 Rechnungen abgeschrieben und 80 offen, ohne dass
-- jemand weiss, welche. Hier läuft alles in EINER Transaktion: entweder alle
-- Buchungen, Statuswechsel und Positionen — oder nichts.
--
-- WARUM Lauf-Tabellen statt Schema-Snapshot: 2019 (Abschluss 2025) lief per
-- SQL mit `snapshot_jahresabschluss_2025`. Die App kann kein Schema anlegen,
-- braucht aber denselben Rückweg. `abschreibung_positionen` hält je Rechnung
-- den Status vorher und die IDs beider Buchungen — genug, um einen Lauf
-- vollständig zurückzunehmen (`abschreibung_lauf_zuruecknehmen`).
--
-- MWST: kommt aus `rechnungen.mwst_betrag` — der Steuer, die auf diese
-- Rechnung damals abgeliefert wurde — nicht aus dem Satz des Buchungstages
-- (7.7 % bis 2023, 8.1 % ab 2024; Konzept docs/buchhaltung/abschreibungen-
-- jahrgaenge.md, Abschnitt 3). Buchung je Rechnung:
--   3805 an 1100  netto   (Debitorenverlust)
--   2200 an 1100  MWST    (Rückholung, Ziff. 235 / Zeile 302 bzw. 303)
--
-- Der 2019er-Lauf wird nachgetragen, damit die MWST-Abrechnung Q3/2026 den
-- Ziff.-235-Wert (2'076.00 netto → 159.90) anzeigt. Er ist NICHT per App
-- zurücknehmbar (brutto auf 3805 gebucht, Rückholung als Sammelbuchung
-- JA2025_A_MWST) — Rollback wie in docs/buchhaltung/jahresabschluss-2025.md.

CREATE TABLE IF NOT EXISTS abschreibung_laeufe (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id),
    geschaeftsjahr INTEGER NOT NULL,
    jahrgaenge INTEGER[] NOT NULL DEFAULT '{}',
    buchungsdatum DATE NOT NULL,
    -- Periode, in der die Rückholung unter Ziff. 235 zu deklarieren ist
    mwst_jahr INTEGER NOT NULL,
    mwst_quartal INTEGER NOT NULL CHECK (mwst_quartal BETWEEN 1 AND 4),
    anzahl INTEGER NOT NULL DEFAULT 0,
    netto NUMERIC(12,2) NOT NULL DEFAULT 0,
    mwst NUMERIC(12,2) NOT NULL DEFAULT 0,
    brutto NUMERIC(12,2) NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'gebucht' CHECK (status IN ('gebucht', 'zurueckgenommen')),
    ruecknahme_moeglich BOOLEAN NOT NULL DEFAULT true,
    zurueckgenommen_am TIMESTAMPTZ,
    notizen TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);
COMMENT ON TABLE abschreibung_laeufe IS
  'Ein Lauf = jahrgangsweise Abschreibung verjaehrter Kundenrechnungen im Abschluss eines Geschaeftsjahres (Schritt A). Summen und MWST-Periode fuer Ziff. 235.';

-- Höchstens ein gebuchter Lauf je Geschäftsjahr — sonst Doppelklick = doppelt.
CREATE UNIQUE INDEX IF NOT EXISTS abschreibung_laeufe_ein_gebuchter
  ON abschreibung_laeufe (user_id, geschaeftsjahr) WHERE status = 'gebucht';

CREATE TABLE IF NOT EXISTS abschreibung_positionen (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lauf_id UUID NOT NULL REFERENCES abschreibung_laeufe(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id),
    rechnung_id UUID NOT NULL REFERENCES rechnungen(id),
    rechnungsnummer TEXT,
    betrieb TEXT,
    jahrgang INTEGER NOT NULL,
    kategorie TEXT NOT NULL CHECK (kategorie IN ('tresen', 'gestellt', 'nie_gestellt')),
    netto NUMERIC(12,2) NOT NULL,
    mwst NUMERIC(12,2) NOT NULL,
    brutto NUMERIC(12,2) NOT NULL,
    status_vorher TEXT NOT NULL,
    -- bewusst ohne FK: nach einer Rücknahme sind die Buchungen weg, die IDs
    -- bleiben als Spur, was gebucht war
    buchung_netto_id UUID,
    buchung_mwst_id UUID,
    created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS abschreibung_positionen_lauf ON abschreibung_positionen (lauf_id);
CREATE INDEX IF NOT EXISTS abschreibung_positionen_rechnung ON abschreibung_positionen (rechnung_id);

ALTER TABLE abschreibung_laeufe ENABLE ROW LEVEL SECURITY;
CREATE POLICY "abschreibung_laeufe_select" ON abschreibung_laeufe FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "abschreibung_laeufe_insert" ON abschreibung_laeufe FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "abschreibung_laeufe_update" ON abschreibung_laeufe FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "abschreibung_laeufe_delete" ON abschreibung_laeufe FOR DELETE USING (auth.uid() = user_id);
ALTER TABLE abschreibung_positionen ENABLE ROW LEVEL SECURITY;
CREATE POLICY "abschreibung_positionen_select" ON abschreibung_positionen FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "abschreibung_positionen_insert" ON abschreibung_positionen FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "abschreibung_positionen_update" ON abschreibung_positionen FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "abschreibung_positionen_delete" ON abschreibung_positionen FOR DELETE USING (auth.uid() = user_id);

-- Kategorie einer offenen Rechnung — dieselbe Regel wie in der App
-- (lib/services/buchhaltung/jahrgang_abschreibung.dart, `kategorieFuer`).
CREATE OR REPLACE FUNCTION abschreibung_kategorie(p_versandart TEXT, p_uebergeben_am DATE, p_versendet_am DATE)
RETURNS TEXT LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN p_versandart = 'rechnung_tresen' OR p_uebergeben_am IS NOT NULL THEN 'tresen'
    WHEN p_versendet_am IS NOT NULL THEN 'gestellt'
    ELSE 'nie_gestellt'
  END
$$;

-- Bucht die übergebenen Rechnungen als Debitorenverlust per 31.12. des
-- Geschäftsjahres. Prüft jede Rechnung nochmals selbst — die App-Vorschau
-- kann veraltet sein, wenn zwischen Anzeige und Klick eine Zahlung eintraf.
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
  IF EXISTS (SELECT 1 FROM abschreibung_laeufe
             WHERE user_id = v_user AND geschaeftsjahr = p_geschaeftsjahr AND status = 'gebucht') THEN
    RAISE EXCEPTION 'Für % gibt es schon einen gebuchten Lauf — zuerst zurücknehmen', p_geschaeftsjahr;
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

-- Nimmt einen Lauf vollständig zurück: Buchungen löschen, Rechnungen auf den
-- Status vorher. Verweigert, sobald eine der Buchungen storniert wurde —
-- dann stimmt der Rückweg nicht mehr und jemand muss hinschauen.
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

  FOR p IN SELECT * FROM abschreibung_positionen WHERE lauf_id = p_lauf LOOP
    IF EXISTS (SELECT 1 FROM buchungen
               WHERE (id IN (p.buchung_netto_id, p.buchung_mwst_id) AND ist_storniert)
                  OR storno_von_id IN (p.buchung_netto_id, p.buchung_mwst_id)) THEN
      RAISE EXCEPTION 'Buchung zu % ist storniert — Rücknahme von Hand', p.rechnungsnummer;
    END IF;
    DELETE FROM buchungen WHERE id IN (p.buchung_netto_id, p.buchung_mwst_id) AND user_id = v_user;
    UPDATE rechnungen SET zahlungsstatus = p.status_vorher
     WHERE id = p.rechnung_id AND user_id = v_user AND zahlungsstatus = 'abgeschrieben';
    v_n := v_n + 1;
  END LOOP;

  UPDATE abschreibung_laeufe SET status = 'zurueckgenommen', zurueckgenommen_am = now() WHERE id = p_lauf;
  RETURN v_n;
END
$$;

-- 2019er-Lauf nachtragen (Abschluss 2025, per SQL gebucht 02.09.2026).
INSERT INTO abschreibung_laeufe (user_id, geschaeftsjahr, jahrgaenge, buchungsdatum, mwst_jahr, mwst_quartal,
                                 anzahl, netto, mwst, brutto, ruecknahme_moeglich, notizen, created_at)
SELECT b.user_id, 2025, ARRAY[2019], DATE '2025-12-31', 2026, 3,
       count(*), sum(rg.betrag_netto), sum(rg.mwst_betrag), sum(rg.betrag_brutto), false,
       'Jahresabschluss 2025 Schritt A, per SQL gebucht 02.09.2026: brutto auf 3805; MWST-Rückholung 159.90 gesamthaft als JA2025_A_MWST (2200 an 3805, 02.09.2026) — Ziff. 235 in Q3/2026. Rücknahme nur von Hand.',
       TIMESTAMPTZ '2026-09-02 20:00:00+02'
FROM buchungen b
JOIN rechnungen rg ON rg.id = b.beleg_id
WHERE b.beleg_typ = 'abschreibung' AND b.geschaeftsjahr = 2025 AND b.soll_konto = 3805 AND b.haben_konto = 1100
  AND NOT EXISTS (SELECT 1 FROM abschreibung_laeufe WHERE geschaeftsjahr = 2025)
GROUP BY b.user_id;

INSERT INTO abschreibung_positionen (lauf_id, user_id, rechnung_id, rechnungsnummer, betrieb, jahrgang, kategorie,
                                     netto, mwst, brutto, status_vorher, buchung_netto_id, buchung_mwst_id)
SELECT l.id, b.user_id, rg.id, rg.rechnungsnummer, bt.name, 2019,
       abschreibung_kategorie(rg.versandart, rg.uebergeben_am, rg.versendet_am),
       rg.betrag_netto, rg.mwst_betrag, rg.betrag_brutto, s.zahlungsstatus, b.id, NULL
FROM buchungen b
JOIN rechnungen rg ON rg.id = b.beleg_id
LEFT JOIN betriebe bt ON bt.id = rg.betrieb_id
JOIN snapshot_jahresabschluss_2025.rechnungen_2019_vorher s ON s.id = rg.id
JOIN abschreibung_laeufe l ON l.geschaeftsjahr = 2025 AND l.user_id = b.user_id
WHERE b.beleg_typ = 'abschreibung' AND b.geschaeftsjahr = 2025 AND b.soll_konto = 3805 AND b.haben_konto = 1100
  AND NOT EXISTS (SELECT 1 FROM abschreibung_positionen WHERE lauf_id = l.id);

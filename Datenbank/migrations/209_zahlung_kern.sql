-- 209: ZahlungKern — Kundenzahlung atomar erfassen und zurücknehmen (26.09.2026)
--
-- WARUM: Bis v0.141.0 gab es sieben Wege, eine Rechnung «bezahlt» zu setzen
-- (Bank auto/manuell/Prüfliste, Bar, Guthaben-voll, Heineken Bank/Hand), mit
-- je eigener Sperrprüfung, eigenem `zahlung_betrag` und eigenem Rückweg —
-- der Bankweg setzte den Status ungeprüft, verlor beim Rückgängigmachen die
-- Mahnstufe, durfte im abgeschlossenen Jahr löschen und nahm Sammelzahlungen
-- nur halb zurück (Analyse 25.09.2026, §3 Befund E). PostgREST kennt keine
-- Transaktion über mehrere Requests: Bricht das Handy nach der 2. von 3
-- Buchungen ab, steht ein halber Zustand da. Hier läuft alles in EINER
-- Transaktion — wie `abschreibung_jahrgang_buchen` (194).
--
-- Die App plant (reine Funktion `zahlungKernPlan`, getestet), die DB prüft
-- und schreibt. Die Zeilen kommen als JSON, damit die 5-Rappen-Rundung und
-- die Guthaben-Logik an EINER Stelle (Dart) bleiben.
--
-- Hinweise zur Umsetzung (geprüft beim Schreiben):
-- * `buchungen.monat` / `quartal` sind GENERATED ALWAYS (001) — werden hier
--   bewusst NICHT gesetzt (ein Insert-Wert wäre ein Fehler). Auf `buchungen`
--   hängt sonst nur `update_buchungen_updated_at` (BEFORE UPDATE, 003) — greift
--   beim Insert nicht. Der alte Zahlungs-Trigger auf `rechnungen` ist seit 102
--   weg; `rechnungen_auto_buchung_erstellt` (003) reagiert nicht auf 'bezahlt'.
-- * `buchungen.storno_von_id` hat ON DELETE SET NULL: Löschte man ein
--   storniertes Original, würde die Storno-Buchung still zur «aktiven» Zeile.
--   Die Rücknahme verweigert deshalb, sobald eine Buchung der Gruppe
--   storniert ist (wie 194).
-- * Wie 194: LANGUAGE plpgsql + `SET search_path = public`, KEIN SECURITY
--   DEFINER, keine GRANTs — RLS greift, `auth.uid()` filtert zusätzlich.
-- * Sperre VOR der Prüfung (FOR UPDATE, dann prüfen): sonst könnte zwischen
--   Prüfung und Schreiben ein zweiter Klick dieselbe Rechnung durchlassen.

CREATE TABLE IF NOT EXISTS zahlungsgruppen (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id),
    weg TEXT NOT NULL CHECK (weg IN ('bank', 'kasse', 'verrechnung')),
    betrag NUMERIC(12,2) NOT NULL,
    datum DATE NOT NULL,
    rechnung_ids UUID[] NOT NULL,
    -- je Rechnung der Stand vor der Zahlung (Status + 6 Mahnfelder +
    -- guthaben_verrechnet), Schlüssel = Rechnungs-Id
    vorher JSONB NOT NULL DEFAULT '{}'::jsonb,
    camt_tx_keys TEXT[] NOT NULL DEFAULT '{}',
    zurueckgenommen_am TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now()
);
COMMENT ON TABLE zahlungsgruppen IS 'Eine erfasste Kundenzahlung (auch Sammelzahlung): alle Buchungen und Rechnungen, die zusammen entstanden sind. Rücknahme immer als Ganzes.';
ALTER TABLE zahlungsgruppen ENABLE ROW LEVEL SECURITY;
CREATE POLICY "zahlungsgruppen_select" ON zahlungsgruppen FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "zahlungsgruppen_insert" ON zahlungsgruppen FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "zahlungsgruppen_update" ON zahlungsgruppen FOR UPDATE USING (auth.uid() = user_id);

ALTER TABLE buchungen ADD COLUMN IF NOT EXISTS zahlung_gruppe_id UUID REFERENCES zahlungsgruppen(id);
CREATE INDEX IF NOT EXISTS buchungen_zahlung_gruppe ON buchungen (zahlung_gruppe_id) WHERE zahlung_gruppe_id IS NOT NULL;

-- Rechnung gilt als «Zahlung gebucht», wenn eine aktive Buchung mit
-- beleg_typ 'zahlung' oder eine Guthaben-Verrechnung (2030/1100) an ihr hängt.
CREATE OR REPLACE FUNCTION zahlung_gebucht(p_rechnung UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM buchungen b
    WHERE b.beleg_id = p_rechnung
      AND coalesce(b.ist_storniert, false) = false AND b.storno_von_id IS NULL
      AND (b.beleg_typ = 'zahlung'
           OR (b.soll_konto = 2030 AND b.haben_konto = 1100 AND b.beleg_typ = 'sonstiges'))
  );
$$;

-- Geschäftsjahr abgeschlossen — Regel wie BuchungNachholService.nachbuchGrenze:
-- Jahre vor dem Vorjahr sind immer abgeschlossen; das Vorjahr, sobald eine
-- Abschlussbuchung (beleg_typ 'abschluss') bis 31.12. existiert; das laufende
-- Jahr nie. (Erste Fassung prüfte «Abschlussbuchung IM Jahr» — die JA2025-
-- Buchungen liegen aber teils im Folgejahr (JA2025_C2 01.01.2026, D_U1/U2
-- April/Mai 2026), damit galt 2026 als abgeschlossen. Korrigiert beim
-- Anwenden 26.09.2026 als 209b.)
CREATE OR REPLACE FUNCTION geschaeftsjahr_abgeschlossen(p_user UUID, p_jahr INTEGER)
RETURNS BOOLEAN LANGUAGE sql STABLE
SET search_path = public
AS $$
  SELECT CASE
    WHEN p_jahr >= EXTRACT(YEAR FROM current_date)::int THEN false
    WHEN p_jahr < EXTRACT(YEAR FROM current_date)::int - 1 THEN true
    ELSE EXISTS (
      SELECT 1 FROM buchungen
      WHERE user_id = p_user AND beleg_typ = 'abschluss'
        AND datum <= make_date(p_jahr, 12, 31)
    )
  END;
$$;

-- p_buchungen: JSON-Array von Buchungszeilen (Felder wie beim Insert: datum,
--   belegnummer, soll_konto, haben_konto, betrag_netto, mwst_satz, mwst_betrag,
--   betrag_brutto, beschreibung, zahlungsweg, beleg_typ, beleg_id,
--   geschaeftsjahr, notizen, camt_tx_key). monat/quartal NICHT — generiert.
-- p_updates: JSON-Objekt {rechnung_id: {zahlung_betrag, zahlung_eingegangen_am,
--   guthaben_verrechnet?}} — der Status wird HIER auf 'bezahlt' gesetzt.
--   Schlüssel müssen GENAU p_rechnung_ids sein: die Rücknahme verlangt, dass
--   jede Rechnung der Gruppe 'bezahlt' ist — eine nicht nachgezogene Rechnung
--   machte die Gruppe sonst unrücknehmbar.
-- p_vorher: JSON-Objekt {rechnung_id: {zahlungsstatus, mahnung_stufe,
--   letzte_mahnung_am, erinnerung_am, mahnung_1_am, mahnung_2_am,
--   mahn_frist_bis, guthaben_verrechnet}} — Stand vor der Zahlung.
-- p_erwartet: JSON-Objekt {rechnung_id: 'status'} — der Status, den die App
--   gesehen hat (updateWennStatus-Semantik: weicht er ab → Abbruch).
CREATE OR REPLACE FUNCTION zahlung_erfassen(
  p_weg TEXT, p_betrag NUMERIC, p_datum DATE, p_rechnung_ids UUID[],
  p_buchungen JSONB, p_updates JSONB, p_vorher JSONB, p_erwartet JSONB,
  p_camt_tx_keys TEXT[] DEFAULT '{}'
)
RETURNS UUID
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_gruppe UUID;
  v_fehler TEXT;
  z JSONB;          -- eine Buchungszeile (FOR über eine Einspalten-Abfrage)
  r RECORD;
  v_n INTEGER;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'Nicht angemeldet'; END IF;
  IF p_rechnung_ids IS NULL OR cardinality(p_rechnung_ids) = 0 THEN
    RAISE EXCEPTION 'Keine Rechnungen übergeben';
  END IF;
  IF p_weg IS NULL OR p_weg NOT IN ('bank', 'kasse', 'verrechnung') THEN
    RAISE EXCEPTION 'Unbekannter Zahlungsweg %', p_weg;
  END IF;
  -- Ohne Buchung fände die Rücknahme keine «aktive Zahlung» → Gruppe hinge fest.
  IF p_buchungen IS NULL OR jsonb_typeof(p_buchungen) <> 'array' OR jsonb_array_length(p_buchungen) = 0 THEN
    RAISE EXCEPTION 'Keine Buchungszeilen übergeben — nichts gebucht';
  END IF;
  IF p_updates IS NULL OR jsonb_typeof(p_updates) <> 'object'
     OR (SELECT array_agg(k ORDER BY k) FROM jsonb_object_keys(p_updates) AS o(k))
        IS DISTINCT FROM (SELECT array_agg(DISTINCT u.id::text ORDER BY u.id::text) FROM unnest(p_rechnung_ids) AS u(id)) THEN
    RAISE EXCEPTION 'Rechnungsliste und Rechnungs-Updates passen nicht zusammen — nichts gebucht';
  END IF;

  -- 1. Sperren, dann prüfen — alles oder nichts.
  PERFORM 1 FROM rechnungen WHERE id = ANY (p_rechnung_ids) AND user_id = v_user FOR UPDATE;

  SELECT string_agg(coalesce(rg.rechnungsnummer, x.id::text) || ': ' ||
           CASE
             WHEN rg.id IS NULL THEN 'nicht gefunden'
             WHEN rg.zahlungsstatus IN ('bezahlt', 'abgeschrieben') THEN 'bereits ' || rg.zahlungsstatus
             WHEN rg.zahlungsstatus IS DISTINCT FROM (p_erwartet ->> (rg.id::text))
               THEN 'inzwischen geändert (' || coalesce(rg.zahlungsstatus, 'ohne Status') || ')'
             WHEN zahlung_gebucht(rg.id) THEN 'Zahlung bereits gebucht (Status nicht nachgezogen) — im Rechnungsdetail prüfen'
             WHEN rg.zahlung_eingegangen_am IS NOT NULL OR coalesce(rg.zahlung_betrag, 0) <> 0 THEN 'Zahlungseingang bereits vermerkt — im Rechnungsdetail prüfen'
             WHEN rg.rechnungstyp = 'heineken_monat' AND rg.zahlungsstatus <> 'freigegeben' THEN 'Heineken-Rechnung noch nicht freigegeben'
             ELSE 'nicht zahlbar'
           END, ' | ')
  INTO v_fehler
  FROM unnest(p_rechnung_ids) AS x(id)
  LEFT JOIN rechnungen rg ON rg.id = x.id AND rg.user_id = v_user
  WHERE rg.id IS NULL
     OR rg.zahlungsstatus IN ('bezahlt', 'abgeschrieben')
     OR rg.zahlungsstatus IS DISTINCT FROM (p_erwartet ->> (rg.id::text))
     OR zahlung_gebucht(rg.id)
     OR rg.zahlung_eingegangen_am IS NOT NULL
     OR coalesce(rg.zahlung_betrag, 0) <> 0
     OR (rg.rechnungstyp = 'heineken_monat' AND rg.zahlungsstatus IS DISTINCT FROM 'freigegeben');
  IF v_fehler IS NOT NULL THEN
    RAISE EXCEPTION 'Nicht zahlbar — nichts gebucht: %', v_fehler;
  END IF;

  -- 2. Gruppe
  INSERT INTO zahlungsgruppen (user_id, weg, betrag, datum, rechnung_ids, vorher, camt_tx_keys)
  VALUES (v_user, p_weg, p_betrag, p_datum, p_rechnung_ids, coalesce(p_vorher, '{}'::jsonb), coalesce(p_camt_tx_keys, '{}'))
  RETURNING id INTO v_gruppe;

  -- 3. Buchungen
  FOR z IN SELECT e.value FROM jsonb_array_elements(p_buchungen) AS e(value) LOOP
    INSERT INTO buchungen (user_id, datum, belegnummer, soll_konto, haben_konto, betrag_netto, mwst_satz, mwst_betrag,
                           betrag_brutto, beschreibung, zahlungsweg, beleg_typ, beleg_id, geschaeftsjahr, notizen,
                           camt_tx_key, zahlung_gruppe_id)
    VALUES (v_user, (z ->> 'datum')::date, z ->> 'belegnummer', (z ->> 'soll_konto')::int, (z ->> 'haben_konto')::int,
            (z ->> 'betrag_netto')::numeric, coalesce((z ->> 'mwst_satz')::numeric, 0), coalesce((z ->> 'mwst_betrag')::numeric, 0),
            (z ->> 'betrag_brutto')::numeric, z ->> 'beschreibung', z ->> 'zahlungsweg', z ->> 'beleg_typ',
            (z ->> 'beleg_id')::uuid, (z ->> 'geschaeftsjahr')::int, z ->> 'notizen', z ->> 'camt_tx_key', v_gruppe);
  END LOOP;

  -- 4. Rechnungen: bezahlt nur, wenn der Status noch der erwartete ist.
  --    (jsonb_each liefert key als TEXT, value als JSONB.)
  FOR r IN SELECT e.key AS id, e.value AS u FROM jsonb_each(p_updates) AS e LOOP
    UPDATE rechnungen
    SET zahlungsstatus = 'bezahlt',
        zahlung_eingegangen_am = (r.u ->> 'zahlung_eingegangen_am')::date,
        zahlung_betrag = (r.u ->> 'zahlung_betrag')::numeric,
        guthaben_verrechnet = coalesce((r.u ->> 'guthaben_verrechnet')::numeric, guthaben_verrechnet)
    WHERE id = r.id::uuid AND user_id = v_user
      AND zahlungsstatus = (p_erwartet ->> r.id);
    GET DIAGNOSTICS v_n = ROW_COUNT;
    IF v_n <> 1 THEN
      RAISE EXCEPTION 'Rechnung % wurde inzwischen geändert — nichts gebucht', r.id;
    END IF;
  END LOOP;

  RETURN v_gruppe;
END;
$$;

-- Rücknahme: ganze Gruppe (oder Altzahlung ohne Gruppe je Rechnung).
-- Liefert die Anzahl gelöschter Buchungen.
CREATE OR REPLACE FUNCTION zahlung_zuruecknehmen(p_rechnung UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_gruppe UUID;
  g zahlungsgruppen%ROWTYPE;
  v_ids UUID[];
  v_jahr INTEGER;
  v_anzahl INTEGER;
  v_n INTEGER := 0;
  r RECORD;
  v_vor JSONB;
  v_status TEXT;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'Nicht angemeldet'; END IF;

  -- Aktive Zahlung dieser Rechnung → Gruppe (NULL bei Altzahlung vor 209).
  SELECT b.zahlung_gruppe_id INTO v_gruppe
  FROM buchungen b
  WHERE b.beleg_id = p_rechnung AND b.user_id = v_user
    AND coalesce(b.ist_storniert, false) = false AND b.storno_von_id IS NULL
    AND (b.beleg_typ = 'zahlung' OR (b.soll_konto = 2030 AND b.haben_konto = 1100 AND b.beleg_typ = 'sonstiges'))
  ORDER BY b.zahlung_gruppe_id NULLS LAST LIMIT 1;

  IF v_gruppe IS NOT NULL THEN
    SELECT * INTO g FROM zahlungsgruppen WHERE id = v_gruppe AND user_id = v_user FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Zahlungsgruppe nicht gefunden'; END IF;
    IF g.zurueckgenommen_am IS NOT NULL THEN RAISE EXCEPTION 'Zahlung ist bereits zurückgenommen'; END IF;
    v_ids := g.rechnung_ids;
  ELSE
    v_ids := ARRAY[p_rechnung];
  END IF;

  -- Sperren, dann prüfen.
  PERFORM 1 FROM rechnungen WHERE id = ANY (v_ids) AND user_id = v_user FOR UPDATE;

  -- Storno-Sperre (wie 194): ist eine Buchung der Gruppe storniert, stimmt
  -- der Rückweg nicht mehr — und das Löschen des Originals würde über
  -- ON DELETE SET NULL die Storno-Buchung zur aktiven Zeile machen.
  IF v_gruppe IS NOT NULL AND EXISTS (
       SELECT 1 FROM buchungen b
       WHERE b.zahlung_gruppe_id = v_gruppe
         AND (coalesce(b.ist_storniert, false)
              OR b.storno_von_id IS NOT NULL
              OR EXISTS (SELECT 1 FROM buchungen s WHERE s.storno_von_id = b.id))) THEN
    RAISE EXCEPTION 'Eine Buchung dieser Zahlung ist storniert — Rücknahme von Hand im Journal';
  END IF;

  -- Jahressperre: keine Buchung der Zahlung darf in einem abgeschlossenen Jahr
  -- liegen (Sammelzahlung über den Jahreswechsel: jedes Jahr prüfen, nicht
  -- nur das kleinste).
  SELECT count(*), min(b.geschaeftsjahr) FILTER (WHERE geschaeftsjahr_abgeschlossen(v_user, b.geschaeftsjahr))
  INTO v_anzahl, v_jahr
  FROM buchungen b
  WHERE b.user_id = v_user AND coalesce(b.ist_storniert, false) = false AND b.storno_von_id IS NULL
    AND ((v_gruppe IS NOT NULL AND b.zahlung_gruppe_id = v_gruppe)
         OR (v_gruppe IS NULL AND b.beleg_id = p_rechnung
             AND (b.beleg_typ = 'zahlung' OR (b.soll_konto = 2030 AND b.haben_konto = 1100 AND b.beleg_typ = 'sonstiges'))));
  IF v_anzahl = 0 THEN RAISE EXCEPTION 'Keine aktive Zahlung zu dieser Rechnung gefunden'; END IF;
  IF v_jahr IS NOT NULL THEN
    RAISE EXCEPTION 'Zahlung aus abgeschlossenem Geschäftsjahr % — Storno von Hand im Journal', v_jahr;
  END IF;

  IF EXISTS (SELECT 1 FROM rechnungen WHERE id = ANY (v_ids) AND user_id = v_user
             AND zahlungsstatus IS DISTINCT FROM 'bezahlt') THEN
    RAISE EXCEPTION 'Mindestens eine Rechnung der Zahlung ist nicht mehr «bezahlt» — nichts geändert';
  END IF;

  -- Buchungen löschen (Fehlgriff-Korrektur im offenen Jahr, wie bisher).
  IF v_gruppe IS NOT NULL THEN
    DELETE FROM buchungen WHERE user_id = v_user AND zahlung_gruppe_id = v_gruppe;
  ELSE
    DELETE FROM buchungen WHERE user_id = v_user AND beleg_id = p_rechnung
      AND coalesce(ist_storniert, false) = false AND storno_von_id IS NULL
      AND (beleg_typ = 'zahlung' OR (soll_konto = 2030 AND haben_konto = 1100 AND beleg_typ = 'sonstiges'));
  END IF;
  GET DIAGNOSTICS v_n = ROW_COUNT;

  -- Rechnungen zurücksetzen: Vorher-Stand aus der Gruppe, sonst Rückfall.
  -- JSON-null im Vorher-Stand (Dart schickt null bei leerem Feld): `v_vor ? 'feld'`
  -- ist dann true und `(v_vor ->> 'feld')::date` NULL → das Feld wird auf NULL
  -- gesetzt. Gewollt: der Vorher-Stand WAR leer. Fehlt der Schlüssel ganz,
  -- bleibt der aktuelle Wert. Ausnahme mahnung_stufe/guthaben_verrechnet:
  -- coalesce → bei null bleibt der aktuelle Wert (guthaben_verrechnet ist
  -- NOT NULL).
  -- Rückfall ohne Gruppe (Altzahlung): Heineken → 'freigegeben' (nur von dort
  -- aus zahlbar); Kundenrechnung → höchste erreichte Mahnstufe aus den
  -- Mahn-Datumsfeldern (der alte Bankweg hat nur den Status überschrieben,
  -- die Datumsfelder blieben), sonst gesendet/offen.
  FOR r IN SELECT id, rechnungstyp, versendet_am, erinnerung_am, mahnung_1_am, mahnung_2_am
           FROM rechnungen WHERE id = ANY (v_ids) AND user_id = v_user LOOP
    v_vor := CASE WHEN v_gruppe IS NOT NULL THEN g.vorher -> (r.id::text) ELSE NULL END;
    v_status := coalesce(v_vor ->> 'zahlungsstatus',
      CASE
        WHEN r.rechnungstyp = 'heineken_monat' THEN 'freigegeben'
        WHEN r.mahnung_2_am IS NOT NULL THEN 'mahnung_2'
        WHEN r.mahnung_1_am IS NOT NULL THEN 'mahnung_1'
        WHEN r.erinnerung_am IS NOT NULL THEN 'erinnert'
        WHEN r.versendet_am IS NOT NULL THEN 'gesendet'
        ELSE 'offen'
      END);
    UPDATE rechnungen SET
      zahlungsstatus = v_status,
      zahlung_eingegangen_am = NULL,
      zahlung_betrag = NULL,
      mahnung_stufe = coalesce((v_vor ->> 'mahnung_stufe')::int, mahnung_stufe),
      letzte_mahnung_am = CASE WHEN v_vor ? 'letzte_mahnung_am' THEN (v_vor ->> 'letzte_mahnung_am')::date ELSE letzte_mahnung_am END,
      erinnerung_am     = CASE WHEN v_vor ? 'erinnerung_am'     THEN (v_vor ->> 'erinnerung_am')::date     ELSE erinnerung_am END,
      mahnung_1_am      = CASE WHEN v_vor ? 'mahnung_1_am'      THEN (v_vor ->> 'mahnung_1_am')::date      ELSE mahnung_1_am END,
      mahnung_2_am      = CASE WHEN v_vor ? 'mahnung_2_am'      THEN (v_vor ->> 'mahnung_2_am')::date      ELSE mahnung_2_am END,
      mahn_frist_bis    = CASE WHEN v_vor ? 'mahn_frist_bis'    THEN (v_vor ->> 'mahn_frist_bis')::date    ELSE mahn_frist_bis END,
      guthaben_verrechnet = coalesce((v_vor ->> 'guthaben_verrechnet')::numeric, guthaben_verrechnet)
    WHERE id = r.id AND user_id = v_user;
  END LOOP;

  IF v_gruppe IS NOT NULL THEN
    UPDATE zahlungsgruppen SET zurueckgenommen_am = now() WHERE id = v_gruppe;
  END IF;
  RETURN v_n;
END;
$$;

/* Proben nach dem Anwenden:

select zahlung_gebucht(id) from rechnungen where zahlungsstatus='bezahlt' limit 3;

select geschaeftsjahr_abgeschlossen(user_id, 2025), geschaeftsjahr_abgeschlossen(user_id, 2026) from rechnungen limit 1;

*/

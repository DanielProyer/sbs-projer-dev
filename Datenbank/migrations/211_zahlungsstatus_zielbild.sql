-- 211: Statusmodell der Rechnung — Zielbild (Entscheid Daniel 27.09.2026)
--
-- WARUM: `rechnungen.zahlungsstatus` mischte drei Dimensionen in EINEM Feld
-- (Analyse 25.09.2026, docs/analyse-2026-09-25/3-buchhaltung-rechnungen.md
-- Abschnitt 2):
--   * Zahlung      offen / bezahlt / abgeschrieben
--   * Zustellung   gesendet            (≙ versendet_am, doppelt geführt)
--   * Mahnstufe    erinnert / mahnung_1 / mahnung_2 (≙ mahnung_stufe 1/2/3)
--   * bei Heineken zusätzlich die Freigabe (freigegeben)
-- Deshalb vergass jeder Filter einen Wert (Befund A: Bankabgleich nahm nur
-- offen/gesendet), und nach einer Zahlungs-Rücknahme wichen Status und
-- Mahnstufe voneinander ab. Seit v0.148.0 leitet die App die Anzeige schon
-- aus den Feldern ab (`anzeigeStatus`/`anzeigeSchluessel`); hier wird der
-- Rohwert auf das Zielbild zurückgebaut:
--
--   zahlungsstatus  ∈ {offen, bezahlt, abgeschrieben}     (nur Zahlung)
--   Zustellung      = versendet_am (Mail/Post) / uebergeben_am (Tresen)
--   Mahnstufe       = mahnung_stufe 0–3 (1 = erinnert, 2 = Mahnung 1,
--                     3 = Mahnung 2/letzte — Konvention seit v0.144.0)
--   Heineken-Freigabe = freigegeben_am (NEU, timestamptz)
--
-- ⚠️ EINMAL-OPERATION (wie 166a): Der Snapshot in Schritt 1 hält den Stand VOR
-- dem Umbau fest. Ein zweiter Lauf nach einem DROP des Snapshots würde den
-- NACH-Stand sichern — der Rückweg wäre verloren. `CREATE TABLE … AS` bricht
-- bei einem zweiten Lauf ohnehin am bestehenden Objekt ab.
--
-- REIHENFOLGE BEIM AUSROLLEN (alte und neue Fassungen vertragen sich nicht
-- vollständig): 1. Edge Function `send-rechnung-mail` (schreibt keinen
-- Status mehr — läuft mit altem und neuem Schema), 2. diese Migration,
-- 3. App-Deploy unmittelbar danach. Eine alte App schreibt nach 211
-- `gesendet`/`erinnert`/`freigegeben` und scheitert am CHECK — laut, nicht
-- still, aber der Versandvermerk-Rückfall und der Mahnlauf brechen dann ab.
--
-- STAND VORHER (lesend geprüft 27.09.2026, eine user_id):
--   kundenrechnung  offen 1084 · gesendet 43 · bezahlt 4033 · abgeschrieben 30
--   heineken_monat  freigegeben 1 · bezahlt 87
--   erinnert/mahnung_1/mahnung_2: 0 · NULL: 0 · mahnung_stufe > 0: 0
--   mahnung_stufe NULL: 10 (werden 0, Spalte NOT NULL)
--   gesendet OHNE versendet_am: 0 (Query A unten) — sie blieben nach dem
--   Umbau «nicht zugestellt», das wäre ehrlich: Der Status behauptete eine
--   Zustellung, die nirgends vermerkt ist.
--   Heineken bezahlt mit Freigabe-Buchung (1100, beleg_typ rechnung): 8 von 87;
--   die 79 übrigen (Import 2019–2026) bekommen updated_at als freigegeben_am.
--
-- Geprüft und NICHT nachgezogen (kennen keine Altwerte oder feuern nie):
--   * abschreibung_jahrgang_buchen (194): prüft nur bezahlt/abgeschrieben,
--     schreibt abgeschrieben — gültig.
--   * view_offene_rechnungen (004/146): NOT IN (bezahlt, abgeschrieben) — gültig.
--   * view_entgeltsminderung (196/209c), mahnfaelle (204): kein Statusbezug.
--   * auto_buchung_rechnung_erstellt (003, Trigger): feuert nur bei
--     entwurf → offen, den Wert gibt es seit 081 nicht mehr.
--   * auto_buchung_zahlung_eingegangen (003): Funktion ohne Trigger (seit 102).
--   * idx_rechnungen_faellig (001): Teilindex auf offen/ueberfaellig — bleibt
--     gültig und deckt jetzt alle unbezahlten.
--   * material_bestellung_* : 'gesendet' ist dort der Bestellstatus.
--   (Suche: pg_proc.prosrc / pg_views.definition nach den Altwerten,
--   27.09.2026, plus grep in Datenbank/migrations.)
--
-- Query A (vorher, zur Kontrolle):
--   select rechnungstyp, zahlungsstatus, count(*),
--          count(*) filter (where versendet_am is null) as ohne_versendet_am,
--          count(*) filter (where coalesce(mahnung_stufe,0) > 0) as mit_stufe
--   from rechnungen group by 1, 2 order by 1, 2;

-- ─── 1. Snapshot (eigenes Schema: nicht über PostgREST erreichbar, kein
--        RLS-Leck wie public.snapshot_gampel_testdaten, siehe 176) ─────────

CREATE SCHEMA IF NOT EXISTS snapshot_status_umbau;

CREATE TABLE snapshot_status_umbau.snapshot_status_umbau_211 AS
SELECT id, user_id, rechnungsnummer, rechnungstyp, zahlungsstatus, mahnung_stufe,
       versendet_am, uebergeben_am, updated_at, now() AS snapshot_am
FROM public.rechnungen;

COMMENT ON TABLE snapshot_status_umbau.snapshot_status_umbau_211 IS
  'Stand von rechnungen.zahlungsstatus/mahnung_stufe VOR Migration 211 (Statusmodell-Zielbild). Rückweg siehe Kommentar am Ende von 211_zahlungsstatus_zielbild.sql.';

-- ─── 2. Heineken-Freigabe als eigenes Feld ────────────────────────────────

ALTER TABLE rechnungen ADD COLUMN IF NOT EXISTS freigegeben_am TIMESTAMPTZ;
COMMENT ON COLUMN rechnungen.freigegeben_am IS
  'Heineken-Monatsrechnung: Zeitpunkt der Freigabe (Ertragsbuchung 1100/3400). NULL = nicht freigegeben. Seit 211 ersetzt es den Status «freigegeben».';

-- VOR Schritt 3: Das Umschreiben des Status setzt updated_at (Trigger) neu —
-- der Rückfallwert muss vorher gelesen werden.
UPDATE rechnungen r
SET freigegeben_am = coalesce(
      (SELECT min(b.datum)::timestamptz FROM buchungen b
       WHERE b.beleg_id = r.id AND b.beleg_typ = 'rechnung' AND b.soll_konto = 1100),
      r.updated_at)
WHERE r.freigegeben_am IS NULL
  AND (r.zahlungsstatus = 'freigegeben'
       -- bezahlte Monatsrechnungen waren zwingend freigegeben
       OR (r.rechnungstyp = 'heineken_monat' AND r.zahlungsstatus = 'bezahlt'));

-- ─── 3. Werte umschreiben ────────────────────────────────────────────────

-- Mahnstufe, die ein Altwert ausdrückt (1–3 wie mahnung_stufe). Gebraucht
-- hier und in den Rückwegen unten: Vorher-Stände in zahlungsgruppen.vorher,
-- abschreibung_positionen.status_vorher und mahnschreiben.vorher können
-- noch Altwerte tragen. WARUM greatest(): Bis v0.144.0 schrieb der Mahnlauf
-- für die Erinnerung `mahnung_stufe = 0` (Enum-Index) — der Status war
-- dort die einzige Spur der Mahnung.
CREATE OR REPLACE FUNCTION rechnung_stufe_aus_altstatus(p_status TEXT)
RETURNS INTEGER
LANGUAGE sql IMMUTABLE
SET search_path = public
AS $$
  SELECT CASE p_status
    WHEN 'erinnert'  THEN 1
    WHEN 'mahnung_1' THEN 2
    WHEN 'mahnung_2' THEN 3
    ELSE 0
  END;
$$;

UPDATE rechnungen
SET mahnung_stufe = greatest(coalesce(mahnung_stufe, 0), rechnung_stufe_aus_altstatus(zahlungsstatus)),
    zahlungsstatus = 'offen'
WHERE zahlungsstatus IN ('erinnert', 'mahnung_1', 'mahnung_2');

-- gesendet → offen: versendet_am bleibt und trägt die Zustellung.
-- freigegeben → offen: freigegeben_am (Schritt 2) trägt die Freigabe.
UPDATE rechnungen SET zahlungsstatus = 'offen'
WHERE zahlungsstatus IN ('gesendet', 'freigegeben');

UPDATE rechnungen SET zahlungsstatus = 'offen' WHERE zahlungsstatus IS NULL;

-- mahnung_stufe trägt ab jetzt die Mahnung ALLEIN — NULL (10 Zeilen am
-- 27.09.2026, Default war immer 0) würde jeden Filter `mahnung_stufe = 0`
-- still verfehlen (NULL-Falle wie bei neq, siehe Memory null_falle_neq).
UPDATE rechnungen SET mahnung_stufe = 0 WHERE mahnung_stufe IS NULL;

-- ─── 4. CHECK, Vorgabe, NOT NULL ─────────────────────────────────────────
-- Schreibweise «CHECK, Klammer, zahlungsstatus IN, Werteliste» bewusst wie
-- in 083: test/zahlungsstatus_waechter_test.dart liest den letzten CHECK in
-- genau dieser Form (die ANY-ARRAY-Form fände er nicht).

ALTER TABLE rechnungen DROP CONSTRAINT IF EXISTS rechnungen_zahlungsstatus_check;
ALTER TABLE rechnungen ADD CONSTRAINT rechnungen_zahlungsstatus_check
  CHECK (zahlungsstatus IN ('offen', 'bezahlt', 'abgeschrieben'));
ALTER TABLE rechnungen ALTER COLUMN zahlungsstatus SET DEFAULT 'offen';
ALTER TABLE rechnungen ALTER COLUMN zahlungsstatus SET NOT NULL;
ALTER TABLE rechnungen ALTER COLUMN mahnung_stufe SET DEFAULT 0;
ALTER TABLE rechnungen ALTER COLUMN mahnung_stufe SET NOT NULL;

-- ─── 5. DB-Objekte, die Statuswerte kennen ───────────────────────────────

-- 5a. zahlung_erfassen (209, Stand 209d) — geändert NUR die Statuslogik:
--   * Heineken zahlbar = freigegeben_am gesetzt (statt Status 'freigegeben').
--   * Optimistisches Sperren auch auf die Mahnstufe: Bis 211 fing der
--     Status-Vergleich (p_erwartet) einen Mahnlauf zwischen Lesen und
--     Zahlen ab (offen → erinnert). Jetzt bleibt der Status 'offen' — also
--     wird die Stufe aus p_vorher gegen den DB-Stand gehalten. Sonst stellte
--     eine spätere Rücknahme eine veraltete Stufe wieder her und die
--     Mahnung beim Kunden verschwände aus der App.
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
  v_jahr INTEGER;
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

  -- 0. Jahressperre auch beim Erfassen (209d): keine Zeile in ein
  --    abgeschlossenes Geschäftsjahr. Symmetrisch zur Rücknahme.
  SELECT min((e.value ->> 'geschaeftsjahr')::int) INTO v_jahr
  FROM jsonb_array_elements(p_buchungen) AS e(value)
  WHERE geschaeftsjahr_abgeschlossen(v_user, (e.value ->> 'geschaeftsjahr')::int);
  IF v_jahr IS NOT NULL THEN
    RAISE EXCEPTION 'Zahlung in abgeschlossenem Geschäftsjahr % — nichts gebucht (Buchung von Hand im Journal)', v_jahr;
  END IF;

  -- 1. Sperren, dann prüfen — alles oder nichts.
  PERFORM 1 FROM rechnungen WHERE id = ANY (p_rechnung_ids) AND user_id = v_user FOR UPDATE;

  SELECT string_agg(coalesce(rg.rechnungsnummer, x.id::text) || ': ' ||
           CASE
             WHEN rg.id IS NULL THEN 'nicht gefunden'
             WHEN rg.zahlungsstatus IN ('bezahlt', 'abgeschrieben') THEN 'bereits ' || rg.zahlungsstatus
             WHEN rg.zahlungsstatus IS DISTINCT FROM (p_erwartet ->> (rg.id::text))
               THEN 'inzwischen geändert (' || coalesce(rg.zahlungsstatus, 'ohne Status') || ')'
             WHEN coalesce(rg.mahnung_stufe, 0) IS DISTINCT FROM
                  coalesce((p_vorher -> (rg.id::text) ->> 'mahnung_stufe')::int, coalesce(rg.mahnung_stufe, 0))
               THEN 'inzwischen geändert (Mahnstufe ' || coalesce(rg.mahnung_stufe, 0) || ')'
             WHEN zahlung_gebucht(rg.id) THEN 'Zahlung bereits gebucht (Status nicht nachgezogen) — im Rechnungsdetail prüfen'
             WHEN rg.zahlung_eingegangen_am IS NOT NULL OR coalesce(rg.zahlung_betrag, 0) <> 0 THEN 'Zahlungseingang bereits vermerkt — im Rechnungsdetail prüfen'
             WHEN rg.rechnungstyp = 'heineken_monat' AND rg.freigegeben_am IS NULL THEN 'Heineken-Rechnung noch nicht freigegeben'
             ELSE 'nicht zahlbar'
           END, ' | ')
  INTO v_fehler
  FROM unnest(p_rechnung_ids) AS x(id)
  LEFT JOIN rechnungen rg ON rg.id = x.id AND rg.user_id = v_user
  WHERE rg.id IS NULL
     OR rg.zahlungsstatus IN ('bezahlt', 'abgeschrieben')
     OR rg.zahlungsstatus IS DISTINCT FROM (p_erwartet ->> (rg.id::text))
     OR coalesce(rg.mahnung_stufe, 0) IS DISTINCT FROM
        coalesce((p_vorher -> (rg.id::text) ->> 'mahnung_stufe')::int, coalesce(rg.mahnung_stufe, 0))
     OR zahlung_gebucht(rg.id)
     OR rg.zahlung_eingegangen_am IS NOT NULL
     OR coalesce(rg.zahlung_betrag, 0) <> 0
     OR (rg.rechnungstyp = 'heineken_monat' AND rg.freigegeben_am IS NULL);
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

-- 5b. zahlung_zuruecknehmen (209, Stand 209e) — geändert NUR das
--     Zurücksetzen der Rechnung:
--   * Status immer 'offen' (erledigte Vorher-Stände gibt es nicht: erfassen
--     lehnt bezahlt/abgeschrieben ab). Ein Altwert im Vorher-Stand einer
--     Gruppe von vor 211 hebt die Mahnstufe an (rechnung_stufe_aus_altstatus).
--   * Rückfall ohne Gruppe (Altzahlung): Die Zahlung hat die Mahnstufe nie
--     angefasst — sie bleibt, angehoben um das, was die Mahn-Datumsfelder
--     belegen (derselbe Rückfall wie bisher, nur als Stufe statt Status).
--     Heineken: freigegeben_am bleibt stehen (vorher Status 'freigegeben').
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
  v_stufe INTEGER;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'Nicht angemeldet'; END IF;

  -- Aktive Zahlung dieser Rechnung → Gruppe (NULL bei Altzahlung vor 209).
  SELECT b.zahlung_gruppe_id INTO v_gruppe
  FROM buchungen b
  WHERE b.beleg_id = p_rechnung AND b.user_id = v_user
    AND coalesce(b.ist_storniert, false) = false AND b.storno_von_id IS NULL
    -- auch reine 3805-Zeilen einer Gruppe (Sammelzahlung, Verlust von hinten
    -- frisst die letzte Basis) — Review, angewendet als 209e
    AND (b.zahlung_gruppe_id IS NOT NULL
         OR b.beleg_typ = 'zahlung'
         OR (b.soll_konto = 2030 AND b.haben_konto = 1100 AND b.beleg_typ = 'sonstiges'))
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
  FOR r IN SELECT id, mahnung_stufe, erinnerung_am, mahnung_1_am, mahnung_2_am
           FROM rechnungen WHERE id = ANY (v_ids) AND user_id = v_user LOOP
    v_vor := CASE WHEN v_gruppe IS NOT NULL THEN g.vorher -> (r.id::text) ELSE NULL END;
    IF v_vor IS NOT NULL THEN
      v_stufe := greatest(
        coalesce((v_vor ->> 'mahnung_stufe')::int, r.mahnung_stufe, 0),
        rechnung_stufe_aus_altstatus(v_vor ->> 'zahlungsstatus'));
    ELSE
      v_stufe := greatest(
        coalesce(r.mahnung_stufe, 0),
        CASE
          WHEN r.mahnung_2_am IS NOT NULL THEN 3
          WHEN r.mahnung_1_am IS NOT NULL THEN 2
          WHEN r.erinnerung_am IS NOT NULL THEN 1
          ELSE 0
        END);
    END IF;
    UPDATE rechnungen SET
      zahlungsstatus = 'offen',
      zahlung_eingegangen_am = NULL,
      zahlung_betrag = NULL,
      mahnung_stufe = v_stufe,
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

-- 5c. abschreibung_lauf_zuruecknehmen (194) — geändert NUR das Zurücksetzen:
--     status_vorher kann einen Altwert tragen (z. B. 'gesendet' aus einem
--     Lauf vor 211). Zurück auf 'offen'; ein gemahnter Altwert hebt die
--     Mahnstufe (die Abschreibung selbst hat sie nie angefasst).
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
    UPDATE rechnungen
       SET zahlungsstatus = 'offen',
           mahnung_stufe = greatest(coalesce(mahnung_stufe, 0), rechnung_stufe_aus_altstatus(p.status_vorher))
     WHERE id = p.rechnung_id AND user_id = v_user AND zahlungsstatus = 'abgeschrieben';
    v_n := v_n + 1;
  END LOOP;

  UPDATE abschreibung_laeufe SET status = 'zurueckgenommen', zurueckgenommen_am = now() WHERE id = p_lauf;
  RETURN v_n;
END
$$;

-- 5d. view_mahnwesen_dashboard (084) — Empfehlung aus mahnung_stufe statt
--     aus dem Status. Spalten unverändert (CREATE OR REPLACE verlangt das),
--     security_invoker wie seit 146. Von der App nicht gelesen, aber sie
--     kannte die Altwerte — und 'gesendet' fiel dort still auf «warten».
CREATE OR REPLACE VIEW view_mahnwesen_dashboard
WITH (security_invoker = on) AS
SELECT
  r.id,
  r.user_id,
  r.rechnungsnummer,
  r.rechnungstyp,
  r.betrieb_id,
  b.name AS betrieb_name,
  r.rechnungsdatum,
  r.faelligkeitsdatum,
  (CURRENT_DATE - r.faelligkeitsdatum) AS ueberfaellig_seit_tagen,
  r.betrag_brutto,
  r.zahlungsstatus,
  r.mahnung_stufe,
  r.versandart,
  r.erinnerung_am,
  r.mahnung_1_am,
  r.mahnung_2_am,
  r.letzte_mahnung_am,
  CASE
    WHEN coalesce(r.mahnung_stufe, 0) = 0
         AND (CURRENT_DATE - r.faelligkeitsdatum) >= 5
         THEN 'erinnerung_faellig'
    WHEN r.mahnung_stufe = 1
         AND r.erinnerung_am IS NOT NULL
         AND (CURRENT_DATE - r.erinnerung_am) >= 25
         THEN 'mahnung_1_faellig'
    WHEN r.mahnung_stufe = 2
         AND r.mahnung_1_am IS NOT NULL
         AND (CURRENT_DATE - r.mahnung_1_am) >= 30
         THEN 'mahnung_2_faellig'
    WHEN r.mahnung_stufe >= 3
         THEN 'eskalation'
    ELSE 'warten'
  END AS empfohlene_aktion
FROM rechnungen r
LEFT JOIN betriebe b ON r.betrieb_id = b.id
WHERE r.zahlungsstatus NOT IN ('bezahlt', 'abgeschrieben')
  AND r.rechnungstyp != 'heineken_monat'
ORDER BY
  CASE
    WHEN r.mahnung_stufe >= 3 THEN 1
    WHEN r.mahnung_stufe = 2 THEN 2
    WHEN r.mahnung_stufe = 1 THEN 3
    ELSE 4
  END,
  r.faelligkeitsdatum;

/* ─── Prüf-Queries nach dem Anwenden ─────────────────────────────────────

-- P1: Anzahl je Status nachher. Erwartet (Stand 27.09.): kundenrechnung
--     offen 1127 (1084 + 43) · bezahlt 4033 · abgeschrieben 30;
--     heineken_monat offen 1 · bezahlt 87.
select rechnungstyp, zahlungsstatus, count(*),
       count(*) filter (where versendet_am is not null or uebergeben_am is not null) as zugestellt,
       count(*) filter (where coalesce(mahnung_stufe, 0) > 0) as gemahnt,
       count(*) filter (where freigegeben_am is not null) as freigegeben
from rechnungen group by 1, 2 order by 1, 2;

-- P2: keine Zeile ausserhalb des CHECK, kein NULL (muss 0 sein).
select count(*) from rechnungen
where zahlungsstatus is null or zahlungsstatus not in ('offen', 'bezahlt', 'abgeschrieben');

-- P3: vorher/nachher je Altwert (aus dem Snapshot).
select s.zahlungsstatus as vorher, r.zahlungsstatus as nachher,
       count(*), count(*) filter (where coalesce(r.mahnung_stufe,0) <> coalesce(s.mahnung_stufe,0)) as stufe_geaendert
from snapshot_status_umbau.snapshot_status_umbau_211 s
join rechnungen r on r.id = s.id
group by 1, 2 order by 1, 2;

-- P4: Heineken — jede bezahlte oder ehemals freigegebene hat freigegeben_am
--     (muss 0 sein).
select count(*) from rechnungen r
join snapshot_status_umbau.snapshot_status_umbau_211 s on s.id = r.id
where r.rechnungstyp = 'heineken_monat'
  and s.zahlungsstatus in ('freigegeben', 'bezahlt') and r.freigegeben_am is null;

-- P5: Default und NOT NULL (zahlungsstatus: 'offen', mahnung_stufe: 0).
select column_name, column_default, is_nullable from information_schema.columns
where table_schema = 'public' and table_name = 'rechnungen'
  and column_name in ('zahlungsstatus', 'mahnung_stufe');

-- P6: keine Funktion/View kennt noch die Altwerte (erwartet nur
--     rechnung_stufe_aus_altstatus und die zwei material_bestellung_*-
--     Funktionen — dort ist 'gesendet' der Bestellstatus).
select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.prosrc ~ '''(gesendet|freigegeben|erinnert|mahnung_1|mahnung_2)''';
select viewname from pg_views where schemaname = 'public'
  and definition ~ '''(gesendet|freigegeben|erinnert|mahnung_1|mahnung_2)''';

   ─── RÜCKWEG (nur im Notfall, in EINER Transaktion) ─────────────────────
   Die Rücksetzung nimmt nur Zeilen, die seit 211 noch auf 'offen' stehen —
   eine inzwischen bezahlte Rechnung darf nie auf 'gesendet' zurückfallen.
   Für neu angelegte Zeilen (nicht im Snapshot) wird der Altwert aus den
   Feldern abgeleitet.

alter table rechnungen drop constraint rechnungen_zahlungsstatus_check;
alter table rechnungen add constraint rechnungen_zahlungsstatus_check
  check (zahlungsstatus = any (array['offen','gesendet','freigegeben','bezahlt',
                                     'erinnert','mahnung_1','mahnung_2','abgeschrieben']));
update rechnungen r set zahlungsstatus = s.zahlungsstatus
from snapshot_status_umbau.snapshot_status_umbau_211 s
where s.id = r.id and r.zahlungsstatus = 'offen' and s.zahlungsstatus <> 'offen';
update rechnungen r set zahlungsstatus = case
    when r.rechnungstyp = 'heineken_monat' and r.freigegeben_am is not null then 'freigegeben'
    when coalesce(r.mahnung_stufe, 0) >= 3 then 'mahnung_2'
    when r.mahnung_stufe = 2 then 'mahnung_1'
    when r.mahnung_stufe = 1 then 'erinnert'
    when r.versendet_am is not null then 'gesendet'
    else 'offen' end
where r.zahlungsstatus = 'offen'
  and not exists (select 1 from snapshot_status_umbau.snapshot_status_umbau_211 s where s.id = r.id);
-- mahnung_stufe bleibt: 211 hob sie nur für erinnert/mahnung_x an (am
-- 27.09.2026: 0 Zeilen).
alter table rechnungen alter column zahlungsstatus drop not null;
alter table rechnungen alter column mahnung_stufe drop not null;  -- die 10 NULL waren gleichbedeutend mit 0
alter table rechnungen drop column freigegeben_am;
-- Danach die alten Definitionen erneut ausführen: zahlung_erfassen +
-- zahlung_zuruecknehmen aus 209_zahlung_kern.sql, abschreibung_lauf_zuruecknehmen
-- aus 194_abschreibung_jahrgang.sql, view_mahnwesen_dashboard aus 084 (mit
-- `alter view ... set (security_invoker = on)`), dann
-- drop function rechnung_stufe_aus_altstatus(text);
-- UND die App auf den Stand vor 211 zurückdeployen (sie schreibt sonst
-- freigegeben_am in eine fehlende Spalte).

*/

# Analyse-Runde 3 «ZahlungKern» — v0.142.0

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use `- [ ]`.

**Goal:** Eine Kundenzahlung wird an genau **einer** Stelle erfasst und zurückgenommen — atomar in der Datenbank, mit einheitlicher Sperrprüfung, einheitlichem `zahlung_betrag`, gespeichertem Vorher-Stand (Mahnfelder), Zahlungsgruppe für Sammelzahlungen, Jahressperre beim Rückgängigmachen, Wahl für Mehrzahlungen (8000 oder Kundenguthaben 2030) und MWST-korrekter Minderzahlung (3805 + 2200). Die sieben heutigen Schreibwege (Bank auto/manuell/Prüfliste, Bar, Guthaben-voll, Heineken Bank/Hand) rufen nur noch diesen Kern; tote Pfade und der Debitoren-Header verschwinden.

**Architektur:** *Planen in Dart, Schreiben in SQL.* Die reine, getestete Planlogik (`differenzPlan`) bleibt und wird um eine reine Funktion `zahlungKernPlan(...)` ergänzt, die die Buchungszeilen und Rechnungs-Updates als JSON erzeugt. Zwei SQL-Funktionen (`zahlung_erfassen`, `zahlung_zuruecknehmen`, Migration 209, Muster Migration 194) schreiben in **einer Transaktion**: Sperren prüfen (Status, Zahlung im Journal, Zahlungsfelder), Buchungen einfügen, Rechnungen nur mit erwartetem Status setzen, Gruppe + Vorher-Stand ablegen; die Rücknahme nimmt die ganze Gruppe, stellt die Mahnfelder wieder her und sperrt abgeschlossene Jahre. Ein Dart-Service `ZahlungKern` kapselt die RPC-Aufrufe; alle Aufrufer werden umgestellt, ein Wächter erzwingt, dass `zahlungsstatus: 'bezahlt'` nirgends sonst geschrieben wird.

**Befunde:** `docs/analyse-2026-09-25/3-buchhaltung-rechnungen.md` §1 (Tabelle der Wege, Abweichungen), §5 Prio 6–10; `docs/app-analyse-2026-09-25.md` §3 Zeile 2, §6 Runde 3. Stand 26.09.2026: `istZahlbar` (R2) ist umgesetzt, Barzahlung (v0.136) ist der einzige heute sauber geschützte Weg — sein Muster (`kassierSperre`, Vorher-Stand, `updateWennStatus`) wird zum Standard.

**Entscheide (Annahmen, von Daniel bestätigen zu lassen — im Plan so gebaut):**
1. **Minderzahlung** (Kunde zahlt weniger, Rest erlassen) = Entgeltsminderung: 3805 **netto** + 2200 **MWST-Anteil** (Satz der Rechnung: `mwst_betrag / betrag_brutto`), wie die Abschreibung — nicht mehr Brutto auf 3805. Bagatelle ≤ 1.00 gleich behandelt.
2. **Mehrzahlung**: Standard **8000 a.o. Ertrag** (Trinkgeld/Rundung) bis **CHF 5.00**, darüber **2030 Kundenguthaben** (wird mit der nächsten Rechnung verrechnet, v0.137). Im Zuordnen-Dialog und in der Abgleich-Vorschau wählbar, der Auto-Import nimmt den Standard.
3. **Rücknahme = Löschen** der Gruppe (Fehlgriff-Korrektur, wie heute), aber **gesperrt**, sobald eine Buchung der Gruppe in einem abgeschlossenen Geschäftsjahr liegt (Abschlussbuchung vorhanden) — dann Storno von Hand im Journal. Altzahlungen ohne Gruppe (vor Migration 209) nimmt dieselbe Funktion je Rechnung zurück (Zahlungs-, Verrechnungs- und Differenzzeilen der Rechnung; Vorher-Stand aus der Buchungsnotiz, sonst `gesendet`/`offen`).
4. `zahlung_betrag` = **tatsächlich zugeordneter Betrag je Rechnung** (Bank-/Kassenanteil + Verrechnung + erlassener Anteil), einheitlich für alle Wege; Guthaben-voll = 0 wie bisher.

**Regeln:** `CLAUDE.md` (CanvasKit: nur `TapKnopf`/`gefahrRueckfrage`; Pagination `.order('id')`; NULL-Falle; Buchhaltung Bruttomethode, 5-Rappen-Rundung nur aufs Total), App `sbs_projer_app/`, `export PATH="$PATH:/c/flutter/bin"`, kein `git stash`, Commits enden mit `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`, nach jedem Task `flutter test` grün (Stand 2347) und `flutter analyze` ≤ 56. Migrationen schreibt der Implementer nach `Datenbank/migrations/`, **anwenden tut der Controller** (MCP `apply_migration`). Mahnwesen bleibt im Testmodus.

**Nicht in dieser Runde:** Statusmodell entflechten (§2 der Analyse, Migration), Prüfseiten Monat/Jahr zusammenlegen, Jahrgang-Abschreibung gegen das Journal prüfen (SQL 194) — eigener Punkt.

---

### Task 1: Migration 209 — Zahlungsgruppen und die zwei SQL-Funktionen

**Files:**
- Create: `Datenbank/migrations/209_zahlung_kern.sql`
- Test: kein Dart-Test; der Controller prüft die Funktionen nach dem Anwenden mit den SQL-Proben aus Schritt 3.

- [ ] **Schritt 1: Migration schreiben**

```sql
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
COMMENT ON TABLE zahlungsgruppen IS
  'Eine erfasste Kundenzahlung (auch Sammelzahlung): alle Buchungen und Rechnungen, die zusammen entstanden sind. Rücknahme immer als Ganzes.';
ALTER TABLE zahlungsgruppen ENABLE ROW LEVEL SECURITY;
CREATE POLICY "zahlungsgruppen_select" ON zahlungsgruppen FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "zahlungsgruppen_insert" ON zahlungsgruppen FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "zahlungsgruppen_update" ON zahlungsgruppen FOR UPDATE USING (auth.uid() = user_id);

ALTER TABLE buchungen ADD COLUMN IF NOT EXISTS zahlung_gruppe_id UUID REFERENCES zahlungsgruppen(id);
CREATE INDEX IF NOT EXISTS buchungen_zahlung_gruppe ON buchungen (zahlung_gruppe_id) WHERE zahlung_gruppe_id IS NOT NULL;

-- Rechnung gilt als «Zahlung gebucht», wenn eine aktive Buchung mit
-- beleg_typ 'zahlung' oder eine Guthaben-Verrechnung (2030/1100) an ihr hängt.
CREATE OR REPLACE FUNCTION zahlung_gebucht(p_rechnung UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM buchungen b
    WHERE b.beleg_id = p_rechnung
      AND coalesce(b.ist_storniert, false) = false AND b.storno_von_id IS NULL
      AND (b.beleg_typ = 'zahlung'
           OR (b.soll_konto = 2030 AND b.haben_konto = 1100 AND b.beleg_typ = 'sonstiges'))
  );
$$;

-- Geschäftsjahr abgeschlossen = es gibt eine Buchung mit beleg_typ 'abschluss'
-- in diesem Jahr (dieselbe Regel wie BuchungNachholService.nachbuchGrenze).
CREATE OR REPLACE FUNCTION geschaeftsjahr_abgeschlossen(p_user UUID, p_jahr INTEGER)
RETURNS BOOLEAN LANGUAGE sql STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM buchungen
    WHERE user_id = p_user AND beleg_typ = 'abschluss'
      AND datum BETWEEN make_date(p_jahr, 1, 1) AND make_date(p_jahr, 12, 31)
  );
$$;

-- p_buchungen: JSON-Array von Buchungszeilen (Felder wie beim Insert:
--   datum, belegnummer, soll_konto, haben_konto, betrag_netto, mwst_satz,
--   mwst_betrag, betrag_brutto, beschreibung, zahlungsweg, beleg_typ,
--   beleg_id, geschaeftsjahr, notizen, camt_tx_key)
-- p_updates: JSON-Objekt {rechnung_id: {zahlung_betrag, zahlung_eingegangen_am,
--   guthaben_verrechnet?}} — der Status wird HIER auf 'bezahlt' gesetzt.
-- p_vorher: JSON-Objekt {rechnung_id: {zahlungsstatus, mahnung_stufe, ...,
--   guthaben_verrechnet}} — Stand vor der Zahlung, für die Rücknahme.
-- p_erwartet: JSON-Objekt {rechnung_id: 'status'} — der Status, den die
--   App gesehen hat (updateWennStatus-Semantik: weicht er ab → Abbruch).
CREATE OR REPLACE FUNCTION zahlung_erfassen(
  p_weg TEXT, p_betrag NUMERIC, p_datum DATE, p_rechnung_ids UUID[],
  p_buchungen JSONB, p_updates JSONB, p_vorher JSONB, p_erwartet JSONB,
  p_camt_tx_keys TEXT[] DEFAULT '{}'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_gruppe UUID;
  v_fehler TEXT;
  v_id UUID;
  z JSONB;
  r RECORD;
  v_n INTEGER;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'Nicht angemeldet'; END IF;
  IF p_rechnung_ids IS NULL OR cardinality(p_rechnung_ids) = 0 THEN
    RAISE EXCEPTION 'Keine Rechnungen übergeben';
  END IF;
  IF p_weg NOT IN ('bank', 'kasse', 'verrechnung') THEN
    RAISE EXCEPTION 'Unbekannter Zahlungsweg %', p_weg;
  END IF;

  -- 1. Sperren, alles oder nichts (Zeilen sperren, damit ein Doppeltipp wartet).
  SELECT string_agg(coalesce(rg.rechnungsnummer, x.id::text) || ': ' ||
           CASE
             WHEN rg.id IS NULL THEN 'nicht gefunden'
             WHEN rg.zahlungsstatus IN ('bezahlt', 'abgeschrieben') THEN 'bereits ' || rg.zahlungsstatus
             WHEN rg.zahlungsstatus <> (p_erwartet ->> rg.id::text) THEN 'inzwischen geändert (' || rg.zahlungsstatus || ')'
             WHEN zahlung_gebucht(rg.id) THEN 'Zahlung bereits gebucht (Status nicht nachgezogen) — im Rechnungsdetail prüfen'
             WHEN rg.zahlung_eingegangen_am IS NOT NULL OR coalesce(rg.zahlung_betrag, 0) <> 0 THEN 'Zahlungseingang bereits vermerkt — im Rechnungsdetail prüfen'
             WHEN rg.rechnungstyp = 'heineken_monat' AND rg.zahlungsstatus <> 'freigegeben' THEN 'Heineken-Rechnung noch nicht freigegeben'
           END, ' | ')
  INTO v_fehler
  FROM unnest(p_rechnung_ids) AS x(id)
  LEFT JOIN rechnungen rg ON rg.id = x.id AND rg.user_id = v_user
  WHERE rg.id IS NULL
     OR rg.zahlungsstatus IN ('bezahlt', 'abgeschrieben')
     OR rg.zahlungsstatus IS DISTINCT FROM (p_erwartet ->> rg.id::text)
     OR zahlung_gebucht(rg.id)
     OR rg.zahlung_eingegangen_am IS NOT NULL
     OR coalesce(rg.zahlung_betrag, 0) <> 0
     OR (rg.rechnungstyp = 'heineken_monat' AND rg.zahlungsstatus <> 'freigegeben');
  IF v_fehler IS NOT NULL THEN
    RAISE EXCEPTION 'Nicht zahlbar — nichts gebucht: %', v_fehler;
  END IF;
  PERFORM 1 FROM rechnungen WHERE id = ANY (p_rechnung_ids) AND user_id = v_user FOR UPDATE;

  -- 2. Gruppe
  INSERT INTO zahlungsgruppen (user_id, weg, betrag, datum, rechnung_ids, vorher, camt_tx_keys)
  VALUES (v_user, p_weg, p_betrag, p_datum, p_rechnung_ids, coalesce(p_vorher, '{}'::jsonb), coalesce(p_camt_tx_keys, '{}'))
  RETURNING id INTO v_gruppe;

  -- 3. Buchungen
  FOR z IN SELECT * FROM jsonb_array_elements(p_buchungen) LOOP
    INSERT INTO buchungen (user_id, datum, belegnummer, soll_konto, haben_konto, betrag_netto, mwst_satz, mwst_betrag,
                           betrag_brutto, beschreibung, zahlungsweg, beleg_typ, beleg_id, geschaeftsjahr, notizen,
                           camt_tx_key, zahlung_gruppe_id)
    VALUES (v_user, (z->>'datum')::date, z->>'belegnummer', (z->>'soll_konto')::int, (z->>'haben_konto')::int,
            (z->>'betrag_netto')::numeric, coalesce((z->>'mwst_satz')::numeric, 0), coalesce((z->>'mwst_betrag')::numeric, 0),
            (z->>'betrag_brutto')::numeric, z->>'beschreibung', z->>'zahlungsweg', z->>'beleg_typ',
            (z->>'beleg_id')::uuid, (z->>'geschaeftsjahr')::int, z->>'notizen', z->>'camt_tx_key', v_gruppe);
  END LOOP;

  -- 4. Rechnungen: bezahlt nur, wenn der Status noch der erwartete ist.
  FOR r IN SELECT key AS id, value AS u FROM jsonb_each(p_updates) LOOP
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
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_gruppe UUID;
  g RECORD;
  v_ids UUID[];
  v_jahr INTEGER;
  v_n INTEGER := 0;
  v_k INTEGER;
  r RECORD;
  v_vor JSONB;
  v_status TEXT;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'Nicht angemeldet'; END IF;

  -- Aktive Zahlung dieser Rechnung → Gruppe (null bei Altzahlung).
  SELECT b.zahlung_gruppe_id INTO v_gruppe
  FROM buchungen b
  WHERE b.beleg_id = p_rechnung AND b.user_id = v_user
    AND coalesce(b.ist_storniert, false) = false AND b.storno_von_id IS NULL
    AND (b.beleg_typ = 'zahlung' OR (b.soll_konto = 2030 AND b.haben_konto = 1100))
  ORDER BY b.zahlung_gruppe_id NULLS LAST LIMIT 1;

  IF v_gruppe IS NOT NULL THEN
    SELECT * INTO g FROM zahlungsgruppen WHERE id = v_gruppe AND user_id = v_user FOR UPDATE;
    IF g.zurueckgenommen_am IS NOT NULL THEN RAISE EXCEPTION 'Zahlung ist bereits zurückgenommen'; END IF;
    v_ids := g.rechnung_ids;
  ELSE
    v_ids := ARRAY[p_rechnung];
  END IF;

  -- Jahressperre: keine Buchung der Gruppe darf in einem abgeschlossenen Jahr liegen.
  SELECT min(b.geschaeftsjahr) INTO v_jahr FROM buchungen b
  WHERE b.user_id = v_user AND coalesce(b.ist_storniert, false) = false AND b.storno_von_id IS NULL
    AND ((v_gruppe IS NOT NULL AND b.zahlung_gruppe_id = v_gruppe)
         OR (v_gruppe IS NULL AND b.beleg_id = p_rechnung AND (b.beleg_typ = 'zahlung' OR (b.soll_konto = 2030 AND b.haben_konto = 1100))));
  IF v_jahr IS NULL THEN RAISE EXCEPTION 'Keine aktive Zahlung zu dieser Rechnung gefunden'; END IF;
  IF geschaeftsjahr_abgeschlossen(v_user, v_jahr) THEN
    RAISE EXCEPTION 'Zahlung aus abgeschlossenem Geschäftsjahr % — Storno von Hand im Journal', v_jahr;
  END IF;

  -- Alle Rechnungen der Gruppe müssen noch bezahlt sein (sonst hat jemand
  -- dazwischen etwas anderes gemacht — nicht still überschreiben).
  IF EXISTS (SELECT 1 FROM rechnungen WHERE id = ANY (v_ids) AND user_id = v_user AND zahlungsstatus <> 'bezahlt') THEN
    RAISE EXCEPTION 'Mindestens eine Rechnung der Zahlung ist nicht mehr «bezahlt» — nichts geändert';
  END IF;
  PERFORM 1 FROM rechnungen WHERE id = ANY (v_ids) AND user_id = v_user FOR UPDATE;

  -- Buchungen löschen (Fehlgriff-Korrektur; Storno wäre bei einer
  -- Falschzuordnung nur Rauschen — das Jahr ist offen, siehe Sperre oben).
  IF v_gruppe IS NOT NULL THEN
    DELETE FROM buchungen WHERE user_id = v_user AND zahlung_gruppe_id = v_gruppe;
  ELSE
    -- Altzahlung: Zahlungs-, Verrechnungs- und Differenzzeilen der Rechnung.
    DELETE FROM buchungen WHERE user_id = v_user AND beleg_id = p_rechnung
      AND coalesce(ist_storniert, false) = false AND storno_von_id IS NULL
      AND (beleg_typ = 'zahlung' OR (soll_konto = 2030 AND haben_konto = 1100 AND beleg_typ = 'sonstiges'));
  END IF;
  GET DIAGNOSTICS v_n = ROW_COUNT;

  -- Rechnungen zurücksetzen: Vorher-Stand aus der Gruppe, sonst Rückfall.
  FOR r IN SELECT id, versendet_am, guthaben_verrechnet FROM rechnungen WHERE id = ANY (v_ids) AND user_id = v_user LOOP
    v_vor := CASE WHEN v_gruppe IS NOT NULL THEN g.vorher -> r.id::text ELSE NULL END;
    v_status := coalesce(v_vor ->> 'zahlungsstatus', CASE WHEN r.versendet_am IS NOT NULL THEN 'gesendet' ELSE 'offen' END);
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

GRANT EXECUTE ON FUNCTION zahlung_erfassen(TEXT, NUMERIC, DATE, UUID[], JSONB, JSONB, JSONB, JSONB, TEXT[]) TO authenticated;
GRANT EXECUTE ON FUNCTION zahlung_zuruecknehmen(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION zahlung_gebucht(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION geschaeftsjahr_abgeschlossen(UUID, INTEGER) TO authenticated;
```
  Prüfe gegen Migration 194, ob dort `SECURITY DEFINER` oder `INVOKER` und welches `GRANT`-Muster verwendet wird, und gleiche dich an (RLS gilt bei INVOKER; die Funktionen filtern zusätzlich auf `auth.uid()`). Prüfe, ob `rechnungen.mahnung_stufe` `NOT NULL` ist (dann bleibt `coalesce(…, mahnung_stufe)` korrekt). Die Spalten `letzte_mahnung_am` etc. sind `date`? (grep in `Datenbank/migrations/` nach `mahn_frist_bis`; falls `timestamptz`, Casts anpassen.)

- [ ] **Schritt 2: Commit** `feat(db): Migration 209 ZahlungKern — zahlungsgruppen, zahlung_erfassen, zahlung_zuruecknehmen (noch nicht angewendet)`.

- [ ] **Schritt 3 (Controller):** Migration anwenden; danach Proben als reine SELECTs: `select zahlung_gebucht('<id einer bezahlten Rechnung>')` → true; `select geschaeftsjahr_abgeschlossen(auth-uid, 2025)` → true, `2026` → false. Die Erfassen-/Rücknahme-Funktionen werden erst in Task 7 im Browser ausgeübt (reversibel).

---

### Task 2: Reine Planfunktion `zahlungKernPlan` (Dart)

**Files:**
- Create: `sbs_projer_app/lib/core/util/zahlung_kern_plan.dart`
- Modify: `sbs_projer_app/lib/core/util/zahlungsdifferenz_text.dart` (Texte: 3805 + MWST, 8000/2030)
- Test: `sbs_projer_app/test/zahlung_kern_plan_test.dart`, `sbs_projer_app/test/zahlungsdifferenz_text_test.dart` (anpassen)

- [ ] **Schritt 1: Test schreiben** (`test/zahlung_kern_plan_test.dart`)

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/zahlung_kern_plan.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';

Rechnung _r(String id, double brutto, {double mwst = 0, double guthaben = 0, String status = 'gesendet', int stufe = 0}) =>
    Rechnung.fromJson({
      'id': id, 'user_id': 'u', 'rechnungsnummer': 'RG-$id', 'rechnungstyp': 'kundenrechnung',
      'betrieb_id': 'b1', 'rechnungsdatum': '2026-09-01', 'faelligkeitsdatum': '2026-10-01',
      'betrag_netto': brutto - mwst, 'mwst_betrag': mwst, 'betrag_brutto': brutto,
      'zahlungsstatus': status, 'mahnung_stufe': stufe, 'guthaben_verrechnet': guthaben,
    });

void main() {
  final tag = DateTime(2026, 9, 26);

  test('exakte Bankzahlung: eine Zeile 1020/1100, Update mit tatsaechlichem Betrag', () {
    final p = zahlungKernPlan(rechnungen: [_r('a', 108.10, mwst: 8.10)], betrag: 108.10, datum: tag, weg: ZahlungWeg.bank);
    expect(p.buchungen.length, 1);
    expect(p.buchungen.single['soll_konto'], 1020);
    expect(p.buchungen.single['haben_konto'], 1100);
    expect(p.buchungen.single['betrag_brutto'], 108.10);
    expect(p.buchungen.single['beleg_typ'], 'zahlung');
    expect(p.updates['a']!['zahlung_betrag'], 108.10);
    expect(p.updates['a']!['zahlung_eingegangen_am'], '2026-09-26');
    expect(p.vorher['a']!['zahlungsstatus'], 'gesendet');
    expect(p.erwartet['a'], 'gesendet');
  });

  test('Kasse: Soll 1000, zahlungsweg kasse', () {
    final p = zahlungKernPlan(rechnungen: [_r('a', 94.05)], betrag: 94.05, datum: tag, weg: ZahlungWeg.kasse);
    expect(p.buchungen.single['soll_konto'], 1000);
    expect(p.buchungen.single['zahlungsweg'], 'kasse');
  });

  test('Minderzahlung: 3805 netto + 2200 MWST im Satz der Rechnung, Bank gekuerzt', () {
    // Brutto 108.10 bei 8.1 %: Kunde zahlt 100.00 → 8.10 erlassen = 7.49 netto + 0.61 MWST
    final p = zahlungKernPlan(rechnungen: [_r('a', 108.10, mwst: 8.10)], betrag: 100.00, datum: tag, weg: ZahlungWeg.bank);
    final konten = p.buchungen.map((b) => '${b['soll_konto']}/${b['haben_konto']}').toList();
    expect(konten, ['1020/1100', '3805/1100', '2200/1100']);
    expect(p.buchungen[0]['betrag_brutto'], 100.00);
    expect((p.buchungen[1]['betrag_brutto'] as double) + (p.buchungen[2]['betrag_brutto'] as double), closeTo(8.10, 0.011));
    expect(p.buchungen[2]['betrag_brutto'], closeTo(0.61, 0.006));
    expect(p.updates['a']!['zahlung_betrag'], 108.10); // zugeordnet inkl. erlassenem Anteil
  });

  test('Minderzahlung ohne MWST auf der Rechnung: nur 3805', () {
    final p = zahlungKernPlan(rechnungen: [_r('a', 100.00)], betrag: 95.00, datum: tag, weg: ZahlungWeg.bank);
    expect(p.buchungen.map((b) => b['soll_konto']).toList(), [1020, 3805]);
    expect(p.buchungen[1]['betrag_brutto'], 5.00);
  });

  test('Mehrzahlung klein: 8000; gross: 2030 Kundenguthaben (Standard), Wahl ueberschreibt', () {
    final klein = zahlungKernPlan(rechnungen: [_r('a', 100.00)], betrag: 103.00, datum: tag, weg: ZahlungWeg.bank);
    expect(klein.buchungen.last['haben_konto'], 8000);
    expect(klein.buchungen.last['soll_konto'], 1020);
    final gross = zahlungKernPlan(rechnungen: [_r('a', 100.00)], betrag: 130.00, datum: tag, weg: ZahlungWeg.bank);
    expect(gross.buchungen.last['haben_konto'], 2030);
    expect(gross.buchungen.last['beleg_typ'], 'zahlung');
    final gewaehlt = zahlungKernPlan(rechnungen: [_r('a', 100.00)], betrag: 130.00, datum: tag, weg: ZahlungWeg.bank, mehrzahlung: MehrzahlungZiel.aoErtrag);
    expect(gewaehlt.buchungen.last['haben_konto'], 8000);
    expect(mehrzahlungStandard(5.00), MehrzahlungZiel.aoErtrag);
    expect(mehrzahlungStandard(5.05), MehrzahlungZiel.guthaben);
  });

  test('Guthaben verrechnet: 1020 ueber zu zahlen + 2030/1100, Update zahlung_betrag = Brutto', () {
    final p = zahlungKernPlan(rechnungen: [_r('a', 143.75, guthaben: 30)], betrag: 113.75, datum: tag, weg: ZahlungWeg.bank);
    final konten = p.buchungen.map((b) => '${b['soll_konto']}/${b['haben_konto']}').toList();
    expect(konten, ['1020/1100', '2030/1100']);
    expect(p.buchungen[0]['betrag_brutto'], 113.75);
    expect(p.buchungen[1]['betrag_brutto'], 30.00);
    expect(p.updates['a']!['zahlung_betrag'], 143.75);
  });

  test('Guthaben voll (Weg verrechnung): nur 2030/1100, zahlung_betrag 0, Datum = Rechnungsdatum', () {
    final r = _r('a', 30.00, guthaben: 30);
    final p = zahlungKernPlan(rechnungen: [r], betrag: 0, datum: DateTime(2026, 9, 1), weg: ZahlungWeg.verrechnung);
    expect(p.buchungen.single['soll_konto'], 2030);
    expect(p.updates['a']!['zahlung_betrag'], 0);
  });

  test('Sammelzahlung: Verlust von hinten, Differenzzeilen an der letzten Rechnung, je Rechnung Datum aus datumProRechnung', () {
    final p = zahlungKernPlan(
      rechnungen: [_r('a', 100.00), _r('b', 50.00)], betrag: 140.00, datum: tag, weg: ZahlungWeg.bank,
      datumProRechnung: {'b': DateTime(2026, 9, 20)},
      camtTxKeyProRechnung: {'a': 'tx1', 'b': 'tx2'},
    );
    expect(p.buchungen[0]['betrag_brutto'], 100.00);
    expect(p.buchungen[1]['betrag_brutto'], 40.00);
    expect(p.buchungen[1]['datum'], '2026-09-20');
    expect(p.buchungen[1]['camt_tx_key'], 'tx2');
    expect(p.buchungen[2]['soll_konto'], 3805);
    expect(p.buchungen[2]['beleg_id'], 'b');
    expect(p.updates['a']!['zahlung_betrag'], 100.00);
    expect(p.updates['b']!['zahlung_betrag'], 50.00);
    expect(p.camtTxKeys.toSet(), {'tx1', 'tx2'});
  });

  test('Vorher-Stand traegt Mahnfelder und Guthaben', () {
    final p = zahlungKernPlan(rechnungen: [_r('a', 100.00, status: 'mahnung_1', stufe: 2, guthaben: 0)], betrag: 100, datum: tag, weg: ZahlungWeg.kasse);
    expect(p.vorher['a']!['mahnung_stufe'], 2);
    expect(p.vorher['a']!.containsKey('mahn_frist_bis'), isTrue);
    expect(p.vorher['a']!['guthaben_verrechnet'], 0);
  });
}
```

- [ ] **Schritt 2: FAIL bestätigen.**

- [ ] **Schritt 3: Implementieren** (`lib/core/util/zahlung_kern_plan.dart`)

```dart
/// ZahlungKern — reine Planung (Analyse 25.09.2026 §3 Befund E, Runde 3).
///
/// Baut aus [differenzPlan] die Buchungszeilen und Rechnungs-Updates, die
/// `zahlung_erfassen` (SQL, Migration 209) in EINER Transaktion schreibt.
/// Alles Geld-Relevante (5-Rappen, Guthaben, Verlust von hinten) bleibt hier
/// in Dart und getestet; die DB prüft nur Sperren und schreibt.
library;

import 'package:sbs_projer_app/core/util/guthaben.dart';
import 'package:sbs_projer_app/core/util/guthaben_verrechnung.dart';
import 'package:sbs_projer_app/core/util/rundung.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/services/rechnung/mahnlauf_service.dart';

enum ZahlungWeg { bank, kasse, verrechnung }

/// Wohin eine Mehrzahlung geht (Entscheid 26.09.2026, Annahme 2).
enum MehrzahlungZiel { aoErtrag, guthaben }

/// Bis hierhin ist eine Mehrzahlung Trinkgeld/Rundung (8000); darüber ist
/// es Geld des Kunden (2030, wird mit der nächsten Rechnung verrechnet).
const double kMehrzahlungGuthabenAb = 5.00;

MehrzahlungZiel mehrzahlungStandard(double mehr) =>
    mehr > kMehrzahlungGuthabenAb + 1e-9 ? MehrzahlungZiel.guthaben : MehrzahlungZiel.aoErtrag;

class ZahlungKernPlan {
  final List<Map<String, dynamic>> buchungen;
  /// rechnung_id → {zahlung_betrag, zahlung_eingegangen_am, guthaben_verrechnet?}
  final Map<String, Map<String, dynamic>> updates;
  /// rechnung_id → Vorher-Stand (Status, 6 Mahnfelder, guthaben_verrechnet)
  final Map<String, Map<String, dynamic>> vorher;
  /// rechnung_id → Status, den die App gesehen hat
  final Map<String, String> erwartet;
  final List<String> camtTxKeys;
  final double differenz;
  final MehrzahlungZiel? mehrzahlungZiel;
  const ZahlungKernPlan({
    required this.buchungen, required this.updates, required this.vorher,
    required this.erwartet, required this.camtTxKeys, required this.differenz,
    required this.mehrzahlungZiel,
  });
}

String _tag(DateTime d) => d.toIso8601String().split('T').first;

/// MWST-Anteil eines Bruttobetrags im Satz der Rechnung (0, wenn die
/// Rechnung keine MWST trägt). Entgeltsminderung wie bei der Abschreibung.
double mwstAnteil(Rechnung r, double brutto) {
  if (r.mwstBetrag <= 0 || r.betragBrutto <= 0) return 0;
  return rundeAufRappen(brutto * r.mwstBetrag / r.betragBrutto);
}

ZahlungKernPlan zahlungKernPlan({
  required List<Rechnung> rechnungen,
  required double betrag,
  required DateTime datum,
  required ZahlungWeg weg,
  Map<String, DateTime> datumProRechnung = const {},
  Map<String, String> camtTxKeyProRechnung = const {},
  String? camtTxKey,
  MehrzahlungZiel? mehrzahlung,
}) {
  final plan = differenzPlan(rechnungen, betrag);
  final buchungen = <Map<String, dynamic>>[];
  final updates = <String, Map<String, dynamic>>{};
  final vorher = <String, Map<String, dynamic>>{};
  final erwartet = <String, String>{};
  final keys = <String>{};

  DateTime datumFuer(Rechnung r) => weg == ZahlungWeg.verrechnung
      ? r.rechnungsdatum
      : (datumProRechnung[r.id] ?? datum);
  String? keyFuer(Rechnung r) => camtTxKeyProRechnung[r.id] ?? camtTxKey;

  final sollHaupt = weg == ZahlungWeg.kasse ? 1000 : 1020;
  final wegText = weg == ZahlungWeg.kasse ? 'kasse' : 'bank';
  final sammel = rechnungen.length > 1 ? ' (Sammelzahlung)' : '';

  for (final z in plan.zeilen) {
    final r = z.rechnung;
    final nr = r.rechnungsnummer ?? '';
    final d = datumFuer(r);
    final key = keyFuer(r);
    if (key != null) keys.add(key);
    if (z.bank >= 0.005 && weg != ZahlungWeg.verrechnung) {
      buchungen.add({
        'datum': _tag(d), 'belegnummer': nr, 'soll_konto': sollHaupt, 'haben_konto': 1100,
        'betrag_netto': z.bank, 'mwst_satz': 0, 'mwst_betrag': 0, 'betrag_brutto': z.bank,
        'beschreibung': '${weg == ZahlungWeg.kasse ? 'Barzahlung' : 'Zahlungseingang'} $nr$sammel',
        'zahlungsweg': wegText, 'beleg_typ': 'zahlung', 'beleg_id': r.id, 'geschaeftsjahr': d.year,
        if (z.guthabenVorher > 0) 'notizen': guthabenNotiz(z.guthabenVorher),
        if (key != null) 'camt_tx_key': key,
      });
    }
    if (z.verrechnung >= 0.005) {
      buchungen.add({
        'datum': _tag(d), 'belegnummer': nr, 'soll_konto': kKontoKundenguthaben, 'haben_konto': 1100,
        'betrag_netto': z.verrechnung, 'mwst_satz': 0, 'mwst_betrag': 0, 'betrag_brutto': z.verrechnung,
        'beschreibung': 'Verrechnung Kundenguthaben $nr', 'zahlungsweg': 'intern',
        'beleg_typ': 'sonstiges', 'beleg_id': r.id, 'geschaeftsjahr': d.year,
      });
    }
    // zahlung_betrag = zugeordnet: Bank/Kasse + Verrechnung + erlassener Anteil
    // (= Basis der Zeile, d. h. «zu zahlen» bzw. Brutto) — einheitlich für alle Wege.
    final basis = rundeAuf5Rappen(plan.guthabenVerrechnet ? r.zuZahlen : r.betragBrutto);
    updates[r.id] = {
      'zahlung_betrag': weg == ZahlungWeg.verrechnung ? 0 : rundeAufRappen(basis + z.verrechnung),
      'zahlung_eingegangen_am': _tag(d),
      if (plan.guthabenZuruecksetzen && r.guthabenVerrechnet > 0) 'guthaben_verrechnet': 0,
    };
    vorher[r.id] = {...MahnlaufService.vorherStand(r), 'guthaben_verrechnet': r.guthabenVerrechnet};
    erwartet[r.id] = r.zahlungsstatus;
  }

  MehrzahlungZiel? ziel;
  final diff = plan.differenz;
  if (diff.abs() >= 0.01 && rechnungen.isNotEmpty && weg != ZahlungWeg.verrechnung) {
    final letzte = rechnungen.last;
    final nr = letzte.rechnungsnummer ?? '';
    final d = datumFuer(letzte);
    final key = keyFuer(letzte);
    if (diff < 0) {
      // Minderzahlung erlassen = Entgeltsminderung: netto auf 3805, MWST-Anteil zurück über 2200.
      final brutto = diff.abs();
      final mwst = mwstAnteil(letzte, brutto);
      final netto = rundeAufRappen(brutto - mwst);
      buchungen.add({
        'datum': _tag(d), 'belegnummer': nr, 'soll_konto': 3805, 'haben_konto': 1100,
        'betrag_netto': netto, 'mwst_satz': 0, 'mwst_betrag': 0, 'betrag_brutto': netto,
        'beschreibung': 'Debitorenverlust $nr$sammel (Differenz erlassen, netto)',
        'zahlungsweg': 'intern', 'beleg_typ': 'zahlung', 'beleg_id': letzte.id, 'geschaeftsjahr': d.year,
      });
      if (mwst >= 0.005) {
        buchungen.add({
          'datum': _tag(d), 'belegnummer': nr, 'soll_konto': 2200, 'haben_konto': 1100,
          'betrag_netto': mwst, 'mwst_satz': 0, 'mwst_betrag': 0, 'betrag_brutto': mwst,
          'beschreibung': 'MWST-Rückholung $nr (Differenz erlassen, Ziff. 235)',
          'zahlungsweg': 'intern', 'beleg_typ': 'zahlung', 'beleg_id': letzte.id, 'geschaeftsjahr': d.year,
        });
      }
    } else {
      ziel = mehrzahlung ?? mehrzahlungStandard(diff);
      final guthaben = ziel == MehrzahlungZiel.guthaben;
      buchungen.add({
        'datum': _tag(d), 'belegnummer': nr, 'soll_konto': sollHaupt,
        'haben_konto': guthaben ? kKontoKundenguthaben : 8000,
        'betrag_netto': diff, 'mwst_satz': 0, 'mwst_betrag': 0, 'betrag_brutto': diff,
        'beschreibung': guthaben
            ? 'Mehrzahlung $nr — Kundenguthaben (wird mit der nächsten Rechnung verrechnet)'
            : 'Mehrzahlung $nr (Trinkgeld/Rundung)',
        'zahlungsweg': wegText, 'beleg_typ': 'zahlung', 'beleg_id': letzte.id, 'geschaeftsjahr': d.year,
        if (key != null) 'camt_tx_key': key,
      });
    }
  }

  return ZahlungKernPlan(
    buchungen: buchungen, updates: updates, vorher: vorher, erwartet: erwartet,
    camtTxKeys: keys.toList(), differenz: diff, mehrzahlungZiel: ziel,
  );
}
```
  Hinweis: Eine Mehrzahlung auf 2030 mit `beleg_id` = Rechnung wird von `offenesGuthabenJeBetrieb` (guthaben.dart) über den Beleg dem Betrieb zugeordnet — prüfen, dass `beleg_typ 'zahlung'` dort nicht ausgeschlossen wird (Test in `guthaben_test.dart` ergänzen: eine 1020/2030-Zeile mit beleg_typ zahlung zählt als Guthaben). Die MWST-Rückholung 2200/1100 muss in `view_entgeltsminderung` (Migration 196) landen: prüfen, welche Kriterien die View nutzt (beleg_typ 'abschreibung'?); falls nur 'abschreibung', in der Zeile oben `beleg_typ: 'abschreibung'` verwenden **und** in Task 1 die Rücknahme-Filter entsprechend erweitern (`OR beleg_typ = 'abschreibung' AND zahlung_gruppe_id = gruppe` — bei Gruppen ohnehin über die Gruppe gelöscht; bei Altzahlungen gibt es keine solche Zeile). Entscheide und dokumentiere im Code.

- [ ] **Schritt 4:** `zahlungsdifferenz_text.dart`: `DifferenzInfo` bekommt `final MehrzahlungZiel? mehrzahlungZiel;` (Standard aus `mehrzahlungStandard(betrag)` bei `art == mehr`), Texte: Minder «… wird als Debitorenverlust (3805) gebucht, MWST-Anteil zurück (2200)»; Mehr: «Mehrzahlung CHF X — a.o. Ertrag (8000)» bzw. «… — Kundenguthaben (2030), wird mit der nächsten Rechnung verrechnet». `bewerteDifferenz` unverändert in der Signatur. `zahlungsdifferenz_text_test.dart` anpassen.
- [ ] **Schritt 5:** Tests grün, analyze. **Commit** `feat(buchhaltung): zahlungKernPlan — reine Planung mit MWST-korrekter Minderzahlung und Mehrzahlungs-Wahl`.

---

### Task 3: `ZahlungKern`-Service und Umstellung aller Erfassungswege

**Files:**
- Create: `sbs_projer_app/lib/services/rechnung/zahlung_kern.dart`
- Modify: `lib/services/camt/forderungs_abgleich_service.dart` (`verbuche` → Kern; `zahlungRueckgaengig` entfernen — Task 4), `lib/services/camt/camt_auto_booker.dart` (`run` löschen; `kundenzahlung`/`heineken` in `bucheVorschlag` → Kern), `lib/services/rechnung/barzahlung_service.dart` (`kassieren` → Kern, reine Helfer bleiben), `lib/services/rechnung/rechnung_service.dart` (`guthabenVollVerrechnen` → Kern), `lib/services/rechnung/jahresrechnung_service.dart:~196` (dito), `lib/services/buchhaltung/heineken_buchung_service.dart` (`createZahlungseingang` → Kern), `lib/presentation/screens/heineken/heineken_rechnung_detail_screen.dart:~440-480` (Hand-Zahlung → Kern mit Datum von heute), `lib/services/buchhaltung/zahlungsdifferenz_service.dart` (`verbuchen`, `verbuchenSammel` löschen; `verrechnungBuchen` bleibt für Abschreibungen)
- Test: `sbs_projer_app/test/zahlung_kern_waechter_test.dart`

- [ ] **Schritt 1: Wächter-Test**
```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Runde 3: «bezahlt» wird nur noch von der DB-Funktion zahlung_erfassen
/// gesetzt (über ZahlungKern). Kein Dart-Code schreibt den Wert direkt.
void main() {
  test("'zahlungsstatus': 'bezahlt' steht in keiner Dart-Datei mehr", () {
    final treffer = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final s = f.readAsStringSync();
      if (s.contains("'zahlungsstatus': 'bezahlt'")) treffer.add(f.path);
    }
    expect(treffer, isEmpty, reason: treffer.join('\n'));
  });
  test('tote Zahlungspfade sind weg', () {
    expect(File('lib/services/camt/camt_auto_booker.dart').readAsStringSync().contains('static Future<AutoBookResult> run('), isFalse);
    final z = File('lib/services/buchhaltung/zahlungsdifferenz_service.dart').readAsStringSync();
    expect(z.contains('verbuchenSammel('), isFalse);
    expect(z.contains('static Future<List<Buchung>> verbuchen('), isFalse);
  });
  test('alle Erfassungswege gehen ueber ZahlungKern.erfassen', () {
    for (final p in [
      'lib/services/camt/forderungs_abgleich_service.dart',
      'lib/services/rechnung/barzahlung_service.dart',
      'lib/services/rechnung/rechnung_service.dart',
      'lib/services/buchhaltung/heineken_buchung_service.dart',
    ]) {
      expect(File(p).readAsStringSync().contains('ZahlungKern.erfassen('), isTrue, reason: p);
    }
  });
}
```
  Prüfe vorab den Namen des Rückgabetyps von `CamtAutoBooker.run` (`AutoBookResult`?) und passe die Zeichenkette an.

- [ ] **Schritt 2: FAIL bestätigen.**

- [ ] **Schritt 3: Service** (`lib/services/rechnung/zahlung_kern.dart`)
```dart
import 'package:sbs_projer_app/core/util/anfrage_bloecke.dart';
import 'package:sbs_projer_app/core/util/zahlung_kern_plan.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

export 'package:sbs_projer_app/core/util/zahlung_kern_plan.dart' show ZahlungWeg, MehrzahlungZiel, mehrzahlungStandard;

/// Die DB hat abgelehnt (Sperre) — Text ist nutzerlesbar (aus RAISE EXCEPTION).
class ZahlungGesperrt implements Exception {
  final String text;
  const ZahlungGesperrt(this.text);
  @override
  String toString() => text;
}

class ZahlungErgebnis {
  final String gruppeId;
  final ZahlungKernPlan plan;
  const ZahlungErgebnis(this.gruppeId, this.plan);
}

/// DER Zahlungsweg (Runde 3). Plant in Dart, schreibt atomar per RPC.
class ZahlungKern {
  static Future<ZahlungErgebnis> erfassen({
    required List<Rechnung> rechnungen,
    required double betrag,
    required DateTime datum,
    required ZahlungWeg weg,
    Map<String, DateTime> datumProRechnung = const {},
    Map<String, String> camtTxKeyProRechnung = const {},
    String? camtTxKey,
    MehrzahlungZiel? mehrzahlung,
  }) async {
    final plan = zahlungKernPlan(
      rechnungen: rechnungen, betrag: betrag, datum: datum, weg: weg,
      datumProRechnung: datumProRechnung, camtTxKeyProRechnung: camtTxKeyProRechnung,
      camtTxKey: camtTxKey, mehrzahlung: mehrzahlung,
    );
    try {
      final res = await SupabaseService.client.rpc('zahlung_erfassen', params: {
        'p_weg': weg.name == 'kasse' ? 'kasse' : weg.name == 'bank' ? 'bank' : 'verrechnung',
        'p_betrag': betrag,
        'p_datum': datum.toIso8601String().split('T').first,
        'p_rechnung_ids': rechnungen.map((r) => r.id).toList(),
        'p_buchungen': plan.buchungen,
        'p_updates': plan.updates,
        'p_vorher': plan.vorher,
        'p_erwartet': plan.erwartet,
        'p_camt_tx_keys': plan.camtTxKeys,
      });
      return ZahlungErgebnis(res as String, plan);
    } on Exception catch (e) {
      final t = e.toString();
      if (t.contains('Nicht zahlbar') || t.contains('inzwischen geändert') || t.contains('nicht freigegeben')) {
        throw ZahlungGesperrt(_dbText(t));
      }
      rethrow;
    }
  }

  /// Nimmt die Zahlung zurück, an der [rechnungId] hängt — ganze Gruppe.
  /// Liefert die Zahl gelöschter Buchungen. Wirft [ZahlungGesperrt] bei
  /// Jahressperre/geändertem Status mit dem DB-Text.
  static Future<int> zuruecknehmen(String rechnungId) async {
    try {
      final res = await SupabaseService.client.rpc('zahlung_zuruecknehmen', params: {'p_rechnung': rechnungId});
      return (res as num).toInt();
    } on Exception catch (e) {
      final t = e.toString();
      if (t.contains('abgeschlossenem Geschäftsjahr') || t.contains('nicht mehr «bezahlt»') ||
          t.contains('bereits zurückgenommen') || t.contains('Keine aktive Zahlung')) {
        throw ZahlungGesperrt(_dbText(t));
      }
      rethrow;
    }
  }

  /// Nutzerlesbarer Text: eigene Sperren voll, alles andere gekürzt.
  static String meldung(Object e) => e is ZahlungGesperrt ? e.text : kurzeFehlermeldung(e);

  /// PostgrestException.toString() enthält «message: …» — nur die Meldung.
  static String _dbText(String roh) {
    final m = RegExp(r'message:\s*([^,}]+)').firstMatch(roh);
    return (m?.group(1) ?? roh).trim();
  }
}
```
  Prüfe, wie `PostgrestException` im Projekt behandelt wird (grep `PostgrestException` in `anfrage_bloecke.dart`); fange sie typisiert (`on PostgrestException catch (e) → e.message`) statt über `toString`, falls das Muster existiert. `rohe_ausnahme_ratsche_test` beachten.

- [ ] **Schritt 4: Aufrufer umstellen**
  - **`ForderungsAbgleichService.verbuche`**: Sperrprüfung `zuordnungGesperrt` bleibt als Vorprüfung (schnelle, lesbare Meldung); die Paarung `paareMitBetrag` bleibt; danach **ein** Aufruf `ZahlungKern.erfassen(rechnungen: forderungen, betrag: zahlbetrag, datum: datum, weg: ZahlungWeg.bank, datumProRechnung: {…bookingDate}, camtTxKeyProRechnung: {…txKey}, camtTxKey: camtTxKey, mehrzahlung: mehrzahlung)`; neuer optionaler Parameter `MehrzahlungZiel? mehrzahlung` in `verbuche`. Kein `setCamtTxKey`, kein `RechnungRepository.update` mehr.
  - **`CamtAutoBooker`**: `run` (Zeilen ~32–168) samt Ergebnisklasse löschen, wenn ohne Aufrufer (grep, auch Tests: `camt_auto_booker_plan_test.dart` prüfen, was er testet — reine Planfunktionen bleiben). `bucheVorschlag` Fall `heineken`: `ZahlungKern.erfassen(rechnungen: [frisch], betrag: frisch.betragBrutto, datum: v.tx.bookingDate, weg: ZahlungWeg.bank, camtTxKey: v.tx.txKey)` — `heinekenSperrgrund` bleibt als Vorprüfung.
  - **`BarzahlungService.kassieren`**: Schleife durch `ZahlungKern.erfassen(rechnungen: frische, betrag: Σ kassierBetragFuer, datum: tag, weg: ZahlungWeg.kasse)` ersetzen (eine Gruppe für alle gewählten Rechnungen — Rücknahme dann als Ganzes; `BarzahlungFehler` mit `kassiert` entfällt: entweder alle oder keine). `kassierSperre`, `kassierBetragFuer`, `verrechnungFuer`, `barzahlungAus`, `meldungFuer` bleiben (UI). `rueckgaengig`, `rueckgaengigSperre`, `vorherAusNotiz`, `kassenbuchungEntfernen` → Task 4. `barzahlung_service_test.dart` anpassen (Tests der gelöschten Funktionen entfernen, Rest bleibt).
  - **`RechnungService.guthabenVollVerrechnen`** und `jahresrechnung_service.dart:~196`: `ZahlungKern.erfassen(rechnungen: [rechnung], betrag: 0, datum: rechnung.rechnungsdatum, weg: ZahlungWeg.verrechnung)` — weiterhin «wirft nie» (try/catch mit debugPrint), Ergebnis frisch laden.
  - **`HeinekenBuchungService.createZahlungseingang`**: Signatur beibehalten (`Rechnung, {DateTime? datum, String? camtTxKey}`), intern `ZahlungKern.erfassen(weg: bank, betrag: rechnung.betragBrutto)`; gibt die Gruppen-Id zurück statt `Buchung?` → Aufrufer anpassen (`camt_auto_booker.bucheVorschlag`, Heineken-Detail). Duplikat-Check entfällt (macht die DB).
  - **Heineken-Detail Hand-Zahlung** (`heineken_rechnung_detail_screen.dart:~452-480`): das direkte `RechnungRepository.update(zahlungsstatus: newStatus …)` für `bezahlt` entfällt; stattdessen `createZahlungseingang(aktuell, datum: DateTime.now())`. Für `gesendet`/`freigegeben` bleibt die bestehende Logik (Freigabe über `HeinekenBuchungService.freigeben` aus Runde 1).
  - **`ZahlungsdifferenzService`**: `verbuchen` und `verbuchenSammel` löschen; `verrechnungBuchen` bleibt (Mahnwesen/Abschreibung).
- [ ] **Schritt 5:** `flutter test` + analyze. Betroffene Tests: `forderungs_abgleich_service_test.dart`, `camt_forderungs_abgleich_test.dart`, `barzahlung_service_test.dart`, `rechnung_guthaben_anlegen_test.dart`, `heineken_freigabe_test.dart` — nur anpassen, wo gelöschte Funktionen getestet wurden; die reine Logik bleibt getestet.
- [ ] **Schritt 6: Commit** `refactor(buchhaltung): ZahlungKern — alle Zahlungswege ueber zahlung_erfassen, tote Pfade weg`.

---

### Task 4: Rücknahme über den Kern, ein Knopf im Rechnungsdetail

**Files:**
- Modify: `lib/presentation/screens/rechnungen/rechnung_detail_screen.dart` (`_barzahlungRueckgaengig`, `_zahlungRueckgaengig`, Knöpfe ~405–440, Halbzustand-Block), `lib/services/camt/forderungs_abgleich_service.dart` (`zahlungRueckgaengig` löschen), `lib/services/rechnung/barzahlung_service.dart` (`rueckgaengig`, `rueckgaengigSperre`, `vorherAusNotiz`, `kassenbuchungEntfernen` löschen — `barzahlungAus` bleibt für die Anzeige «Bar bezahlt am»), `lib/data/repositories/buchung_repository.dart` (`getAktiveCamtZahlungsIds` löschen, wenn ohne Aufrufer)
- Test: `test/zahlung_kern_waechter_test.dart` ergänzen, `test/barzahlung_service_test.dart` anpassen

- [ ] **Schritt 1: Wächter ergänzen**
```dart
  test('Ruecknahme nur ueber ZahlungKern.zuruecknehmen', () {
    final d = File('lib/presentation/screens/rechnungen/rechnung_detail_screen.dart').readAsStringSync();
    expect(d.contains('ZahlungKern.zuruecknehmen('), isTrue);
    expect(d.contains('zahlungRueckgaengig('), isFalse);
    expect(d.contains('BarzahlungService.rueckgaengig('), isFalse);
    expect(File('lib/services/camt/forderungs_abgleich_service.dart').readAsStringSync().contains('zahlungRueckgaengig'), isFalse);
  });
```
- [ ] **Schritt 2: Detail-Screen**: Ein Handler `_zahlungZuruecknehmen()`:
```dart
  Future<void> _zahlungZuruecknehmen() async {
    final istBar = _barzahlung != null;
    final ok = await gefahrRueckfrage(
      context,
      titel: 'Zahlung rückgängig machen?',
      text: istBar
          ? 'Die Kassen-Buchung wird gelöscht und die Rechnung auf den Stand vor der '
            'Barzahlung gesetzt (inkl. Mahnstufe). Gehört die Zahlung zu mehreren Rechnungen, '
            'werden alle zurückgesetzt.'
          : 'Die Zahlungs-Buchungen werden gelöscht und die Rechnung auf den Stand vor der '
            'Zahlung gesetzt (inkl. Mahnstufe). Gehört die Gutschrift zu mehreren Rechnungen '
            '(Sammelzahlung), werden alle zurückgesetzt; die Bank-Gutschrift erscheint beim '
            'nächsten Import erneut zum Zuordnen.\n\nNur für falsch zugeordnete Zahlungen. '
            'In einem abgeschlossenen Geschäftsjahr ist das gesperrt.',
      bestaetigen: 'Rückgängig machen',
    );
    if (!ok) return;
    try {
      final anzahl = await ZahlungKern.zuruecknehmen(_rechnung.id);
      final frisch = await RechnungRepository.getById(_rechnung.id);
      ref.invalidate(rechnungenStreamProvider);
      ref.invalidate(buchungenStreamProvider);
      if (!mounted) return;
      setState(() { if (frisch != null) _rechnung = frisch; });
      await _reloadRechnung();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$anzahl Buchung(en) gelöscht — Rechnung wieder ${_rechnung.zahlungsstatus}.'),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.error,
        content: Text(ZahlungKern.meldung(e), style: const TextStyle(color: Colors.white)),
        duration: const Duration(seconds: 10),
      ));
    }
  }
```
  Beide alten Handler löschen; die zwei Knöpfe durch **einen** `TapKnopf(text: 'Zahlung rückgängig', icon: Icons.undo, gefahr: true, onTap: _zahlungZuruecknehmen)` ersetzen (Anzeige «Bar bezahlt am» bleibt). Den Halbzustand-Block (Kassenbuchung ohne bezahlten Status, `kassenbuchungEntfernen`) durch einen Hinweis ersetzen: «Zahlung gebucht, Status nicht bezahlt — im Journal prüfen» (seit dem atomaren Kern kann dieser Zustand nur noch aus Altdaten stammen). `_mahnfallErledigt`-Hinweis in den Text übernehmen, falls vorhanden.
- [ ] **Schritt 3:** Löschen wie in Files aufgeführt; Tests anpassen. Für `vorherAusNotiz`/`rueckgaengigSperre` entfallen die Tests (Logik jetzt in SQL).
- [ ] **Schritt 4:** `flutter test` + analyze. **Commit** `refactor(rechnungen): Zahlung rueckgaengig ueber ZahlungKern — ein Knopf, ganze Gruppe, Jahressperre`.

---

### Task 5: Differenz-Wahl in Prüfliste und Abgleich-Vorschau

**Files:**
- Modify: `lib/presentation/screens/buchhaltung/camt/kundenzahlung_zuordnen_dialog.dart` (~Z. 60–110 Info, ~185–240 Aktionen), `lib/presentation/screens/buchhaltung/widgets/abgleich_vorschau.dart` (5 `verbuche`-Aufrufe Z. 493/545/869/1150/1716; `bewerteDifferenz` bei 666/1011/1565)
- Create: `lib/presentation/widgets/mehrzahlung_wahl.dart`
- Test: `test/mehrzahlung_wahl_test.dart` (reine Helfer), `test/canvaskit_sichere_widgets_test.dart` läuft mit

- [ ] **Schritt 1:** Widget `MehrzahlungWahl({required double betrag, required MehrzahlungZiel wert, required ValueChanged<MehrzahlungZiel> onChanged})`: zwei Zeilen aus `InkWell` + `Container` (kein `RadioListTile` — CanvasKit), Texte «a.o. Ertrag 8000 (Trinkgeld/Rundung)» und «Kundenguthaben 2030 (mit nächster Rechnung verrechnen)», die gewählte Zeile grün umrandet. Reine Helfer `mehrzahlungText(MehrzahlungZiel)` getestet. Erscheint nur bei `info.art == DifferenzArt.mehr`.
- [ ] **Schritt 2: Zuordnen-Dialog:** State `MehrzahlungZiel? _mehr;` (initial `mehrzahlungStandard(info.betrag)` sobald Mehrzahlung); Widget unter der Differenz-Info; `verbuche(..., mehrzahlung: _mehr)`. Knöpfe `TextButton`/`FilledButton` → `TapKnopf` (Abbrechen/Verbuchen; Verbuchen `onTap: null` wenn nichts gewählt).
- [ ] **Schritt 3: Abgleich-Vorschau:** an den drei Stellen mit `bewerteDifferenz` das Widget einblenden (State je Fall: Map `_mehrJeFall` mit Schlüssel = Fall-Id/Index) und an den zugehörigen `verbuche`-Aufrufen `mehrzahlung:` mitgeben. Auto-Treffer (`_verbuche(AutoTreffer)`) ohne Dialog: Standard (`null` → Kern nimmt `mehrzahlungStandard`). Die `FilledButton`/`OutlinedButton` in `abgleich_vorschau.dart` sind **nicht** Teil dieses Tasks (Datei 1911 Zeilen; ToDo-Notiz).
- [ ] **Schritt 4:** Tests, analyze. **Commit** `feat(buchhaltung): Mehrzahlung waehlbar (8000 oder Kundenguthaben 2030) beim Zuordnen`.

---

### Task 6: Aufräumen — Debitoren-Header weg, Einzelabschreibung geschützt, Status-Fallback weg, Prüfregel Status↔Mahnstufe

**Files:**
- Delete: `lib/presentation/screens/rechnungen/widgets/debitoren_header.dart`; Modify: `lib/presentation/screens/rechnungen/rechnungen_list_screen.dart` (Header-Einbindung, Status-Fallback ~939–985, Einzelabschreibungs-Dialog `TextButton` → `TapKnopf`), `lib/presentation/providers/buchhaltung_providers.dart` (`debitorenUebersichtProvider` löschen, wenn ohne weiteren Aufrufer), `lib/services/buchhaltung/abschreibung_service.dart` (`delkredereSetzen` bleibt), `lib/presentation/screens/buchhaltung/audit_screen.dart` (o. ä., wo `DelkredereRegel` gezeigt wird: Knopf «Delkredere auf 5 % setzen» mit `gefahrRueckfrage`), `lib/services/rechnung/mahnwesen_service.dart` (`abschreiben`: Sperre `zahlungGebucht` + `updateWennStatus`), `lib/services/buchhaltung/abschluss_regeln.dart` + `abschluss_pruef_service.dart` + `buchhaltung_providers.dart` (Regel `StatusMahnstufeRegel`)
- Test: `test/debitoren_guthaben_regeln_test.dart` (Regel), `test/mahnwesen_abschreiben_sperre_test.dart` (rein), Wächter `test/zahlung_kern_waechter_test.dart` (Header-Datei existiert nicht mehr)

- [ ] **Schritt 1: Tests**: Regel `StatusMahnstufeRegel` (id `status_mahnstufe`, Gruppe Debitoren, Titel «Status und Mahnstufe widersprüchlich»): zählt Rechnungen mit `zahlungsstatus in {offen, gesendet}` und `mahnung_stufe > 0` **oder** `zahlungsstatus in {erinnert, mahnung_1, mahnung_2}` und `mahnung_stufe == 0`; Test mit 3 Rechnungen (2 widersprüchlich) → gelb «2». Reine Funktion `statusMahnstufeWiderspruch(Rechnung r) → bool` in `abschluss_regeln.dart`. `mahnwesen_abschreiben_sperre_test.dart`: `abschreibSperre(Rechnung r, {required bool hatZahlung}) → String?` (bezahlt/abgeschrieben, Zahlung gebucht, Zahlungsfelder gesetzt) analog `kassierSperre`.
- [ ] **Schritt 2:** `MahnwesenService.abschreiben`: vor dem Buchen `abschreibSperre` prüfen (wirft `Exception(text)` — `kurzeFehlermeldung` zeigt ihn), Status per `updateWennStatus(erwarteterStatus: rechnung.zahlungsstatus)`; bei `false` Exception «inzwischen geändert». Mahnfall-Service prüft weiter selbst (`zahlungGebucht`), doppelt ist hier richtig.
- [ ] **Schritt 3:** Debitoren-Header entfernen (Datei, Einbindung, Provider, ggf. `AbschreibungService.abschreiben` ohne `belegId` prüfen — bleibt für Mahnwesen). Delkredere-Knopf in die Abschlussprüfung neben `DelkredereRegel` (nur wenn Regel gelb/rot; `gefahrRueckfrage` «Delkredere auf 5 % buchen?»). Status-Fallback in `rechnungen_list_screen.dart` (~939–985, «Einfacher Status-Wechsel») löschen; `_naechsterStatus` auf die verbleibenden Fälle reduzieren; Einzelabschreibungs-Dialog `TextButton` → `TapKnopf(primaer: false)`.
- [ ] **Schritt 4:** Regel in `alleAbschlussRegeln()` registrieren, Kontext liefert `rechnungen` (prüfen, ob `AbschlussKontext` alle Rechnungen hat; sonst nur die offenen + gemahnten laden wie `DebitorenOffeneRechnungenRegel`).
- [ ] **Schritt 5:** Tests, analyze. **Commit** `refactor(rechnungen): Debitoren-Header weg, Einzelabschreibung geschuetzt, Status-Fallback weg, Regel Status/Mahnstufe`.

---

### Task 7: Migration anwenden, Browser-Probe auf der Produktion (reversibel), Release v0.142.0

**Files:** `sbs_projer_app/pubspec.yaml:4`, `lib/core/app_version.dart:12`, `docs/chronik.md`, `ToDo.md`, `Projekt.md`, `docs/app-analyse-2026-09-25.md` §6, Memory.

- [ ] **Schritt 1 (Controller):** Migration 209 anwenden (Task 1 Schritt 3), Proben. Lokaler Build `--base-href "/"`, Server `flutter-web`.
- [ ] **Schritt 2: Browser-Probe, alles reversibel, auf echten Daten:**
  1. Rechnungsdetail einer im September per Bank bezahlten Rechnung (Altzahlung ohne Gruppe, z. B. Bräma 2026-09-1470, falls die Gutschrift schon eingelesen ist; sonst eine ältere von August) → «Zahlung rückgängig» → Rückfrage → Snackbar «n Buchung(en) gelöscht — Rechnung wieder gesendet»; Journal: Zeilen weg; `mahnung_stufe` unverändert 0.
  2. Buchhaltung → Bank → die Gutschrift erscheint wieder in der Vorschau/Prüfliste → zuordnen (Gruppenweg): Snackbar, Rechnung bezahlt, `zahlungsgruppen` hat eine Zeile (SQL), Buchungen tragen `zahlung_gruppe_id`, `zahlung_betrag` = Brutto.
  3. Erneut «Zahlung rückgängig» (Gruppenweg) → Rechnung wieder gesendet, Gruppe `zurueckgenommen_am` gesetzt → und **noch einmal zuordnen**, damit der Endzustand dem Ausgangszustand entspricht (bezahlt, gleiche Beträge, gleiches Datum). SQL-Gegenprobe: Saldo 1020 und 1100 vor/nach identisch.
  4. Eine Rechnung aus **2025** (bezahlt) → «Zahlung rückgängig» → rote Snackbar «abgeschlossenes Geschäftsjahr 2025», nichts geändert.
  5. Prüfliste → «Zahlung zuordnen» öffnen: Differenz-Info und (bei Mehrzahlung) die Wahl sichtbar; abbrechen.
  6. Rechnungsliste: kein Debitoren-Header mehr; Abschlussprüfung zeigt die neue Regel Status/Mahnstufe (grün, 0).
  Screenshots ins Scratchpad; Befund in ToDo.md.
- [ ] **Schritt 3: Version** `0.142.0+795` / `kAppVersion '0.142.0'`; `flutter test test/app_version_test.dart`.
- [ ] **Schritt 4: Doku:** Chronik «26.09.2026 — v0.142.0 ZahlungKern: ein Zahlungsweg, atomar (Migration 209)» mit den vier Entscheiden (Annahmen) ausdrücklich als «von Daniel zu bestätigen»; ToDo Stand + Klicktest (Barzahlung beim Service kassieren → Rückgängig im Detail → Mahnstufe wieder da; Prüfliste Mehrzahlung > 5 CHF → Wahl) + offene Punkte (Abgleich-Vorschau Material-Buttons, SQL 194 gegen Journal, Statusmodell); Projekt.md; Analyse §6 Runde 3 ✅; Memory `app_analyse_2026_09_25.md` + MEMORY.md + neue Memory-Notiz `zahlungkern.md` (Regeln: bezahlt nur per `zahlung_erfassen`, Rücknahme per Gruppe, Jahressperre, Mehrzahlung 5-CHF-Grenze, Minderzahlung netto+MWST).
- [ ] **Schritt 5: Commit + Push main, Deploy gh-pages, Live-Version prüfen.**

---

## Selbstprüfung (Controller)

- **Abdeckung §6 Runde 3:** ein Zahlungsweg (Task 1–3), Rückgängig repariert (Task 1+4: Gruppe, Mahnfelder, Jahressperre), `istZahlbar` (schon R2), Debitoren-Header weg (Task 6), Wahl 8000/2030 (Task 2+5), 3805-MWST (Task 2). Zusätzlich Prio 10 (Einzelabschreibung) und Regel Status/Mahnstufe (Q5-Rest) in Task 6.
- **Namen konsistent:** `zahlung_erfassen(p_weg, p_betrag, p_datum, p_rechnung_ids, p_buchungen, p_updates, p_vorher, p_erwartet, p_camt_tx_keys)`, `zahlung_zuruecknehmen(p_rechnung)`, `zahlung_gebucht`, `geschaeftsjahr_abgeschlossen` (Task 1) ↔ `ZahlungKern.erfassen/zuruecknehmen` (Task 3) ↔ `zahlungKernPlan`, `ZahlungKernPlan{buchungen, updates, vorher, erwartet, camtTxKeys, differenz, mehrzahlungZiel}`, `ZahlungWeg`, `MehrzahlungZiel`, `mehrzahlungStandard`, `kMehrzahlungGuthabenAb`, `mwstAnteil` (Task 2) ↔ Task 5 `MehrzahlungWahl`; `ZahlungGesperrt`, `ZahlungKern.meldung` (Task 3) ↔ Task 4.
- **Risiken:** (a) JSON-Zahlen als `numeric` in plpgsql — `(z->>'betrag_brutto')::numeric` funktioniert für Dart-Doubles; Rundung auf 2 Stellen macht Dart. (b) `p_erwartet` als JSON-Objekt String→String; `p_updates` verschachtelt — `supabase_flutter` serialisiert Maps/Listen als JSON. (c) `beleg_typ` der MWST-Rückholung und `view_entgeltsminderung` (Task 2 Hinweis). (d) Barzahlung «alle oder keine» statt Teilerfolg — Verhaltensänderung, in Chronik nennen. (e) Heineken `createZahlungseingang` Rückgabetyp ändert sich — alle Aufrufer prüfen.

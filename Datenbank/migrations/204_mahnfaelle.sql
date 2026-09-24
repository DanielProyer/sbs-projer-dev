-- 204: Mahnfälle — Eskalation nach der letzten Mahnung (Mahnwesen Teil 2, 24.09.2026)
-- Ein Fall je Betrieb und Eskalation: Heineken einschalten → Ergebnis →
-- ggf. Betreibung. Spec docs/superpowers/specs/2026-09-23-mahnwesen-design.md §5.
--
-- Abweichung von der Plan-Vorlage: `user_id` ohne `DEFAULT auth.uid()` und
-- vier einzelne RLS-Policies (select/insert/update/delete) statt einer
-- `FOR ALL`-Policy — wie in Migration 200 (mahnschreiben), der zuletzt
-- angelegten vergleichbaren Tabelle im Mahnwesen.

CREATE TABLE public.mahnfaelle (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             uuid NOT NULL REFERENCES auth.users(id),
  betrieb_id          uuid NOT NULL REFERENCES public.betriebe(id) ON DELETE RESTRICT,
  rechnung_ids        uuid[] NOT NULL,
  eroeffnet_am        date NOT NULL DEFAULT current_date,
  status              text NOT NULL DEFAULT 'heineken'
    CHECK (status IN ('heineken', 'heineken_frist', 'betreibung', 'erledigt')),
  test                boolean NOT NULL DEFAULT true,
  -- Heineken
  heineken_kontakt_am date,
  heineken_empfaenger text,
  heineken_ergebnis   text
    CHECK (heineken_ergebnis IN ('vermittelt', 'uebernommen', 'konkurs', 'betreibung')),
  heineken_ergebnis_am date,
  heineken_frist_bis  date,
  -- Betreibung
  schuldner_name      text,
  schuldner_adresse   text,
  rechtsform          text CHECK (rechtsform IN ('einzelfirma', 'gmbh', 'ag', 'andere')),
  betreibungsamt      text,
  eingereicht_am      date,
  zahlungsbefehl_am   date,
  rechtsvorschlag     boolean,
  fortsetzung_am      date,
  kosten_vorschuss    numeric(10,2),
  -- Abschluss
  erledigt_am         date,
  erledigung          text
    CHECK (erledigung IN ('bezahlt', 'abgeschrieben', 'zurueckgezogen', 'uebernommen')),
  notiz               text,
  erstellt_am         timestamptz NOT NULL DEFAULT now(),
  aktualisiert_am     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX mahnfaelle_betrieb_idx ON public.mahnfaelle (betrieb_id);
CREATE INDEX mahnfaelle_rechnungen_idx ON public.mahnfaelle USING gin (rechnung_ids);

ALTER TABLE public.mahnfaelle ENABLE ROW LEVEL SECURITY;
CREATE POLICY mahnfaelle_select ON public.mahnfaelle
  FOR SELECT USING (user_id = auth.uid());
CREATE POLICY mahnfaelle_insert ON public.mahnfaelle
  FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY mahnfaelle_update ON public.mahnfaelle
  FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY mahnfaelle_delete ON public.mahnfaelle
  FOR DELETE USING (user_id = auth.uid());

-- Heineken-Kontakt für Mahnfälle
ALTER TABLE heineken_kontakt_zuweisungen DROP CONSTRAINT IF EXISTS heineken_zuweisung_funktion_check;
ALTER TABLE heineken_kontakt_zuweisungen ADD CONSTRAINT heineken_zuweisung_funktion_check
  CHECK (funktion IN ('monatsrechnung', 'raster', 'heigenie_service', 'materialbestellung', 'rsl', 'mahnwesen'));

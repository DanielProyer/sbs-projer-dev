-- 186: Archiv der Saisonfenster je Betrieb
--
-- Warum: Die Saisondaten am Betrieb (winter_start_datum … sommer_ende_datum)
-- halten immer nur die laufende Saison und werden jedes Jahr ueberschrieben.
-- Die Vorjahre gehen dabei verloren — genau die, aus denen sich eine kommende
-- Saison abschaetzen laesst, solange der Betrieb sie noch nicht angesagt hat
-- (Acla Grischuna: Winterende fuenf Jahre in Folge zwischen 30.03. und 04.04.).
--
-- Bewusst NICHT aus den erledigten Endreinigungen abgeleitet (Entscheid Daniel
-- 08.09.2026): Eine Endreinigung kann auch mitten in der Zwischensaison
-- stattfinden und waere dann kein Saisonende. Die Tabelle startet deshalb leer
-- und fuellt sich ab jetzt aus dem, was am Betrieb stand.

CREATE TABLE public.betrieb_saison_historie (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  betrieb_id    uuid NOT NULL REFERENCES public.betriebe(id) ON DELETE CASCADE,
  saison        text NOT NULL CHECK (saison IN ('winter','sommer')),
  start_datum   date NOT NULL,
  ende_datum    date,
  archiviert_am timestamptz NOT NULL DEFAULT now(),
  notiz         text,
  user_id       uuid NOT NULL REFERENCES auth.users(id),
  created_at    timestamptz NOT NULL DEFAULT now(),
  CHECK (ende_datum IS NULL OR ende_datum >= start_datum)
);

CREATE INDEX betrieb_saison_historie_betrieb_idx
  ON public.betrieb_saison_historie (betrieb_id, saison, start_datum DESC);

-- Dieselbe Saison nie zweimal archivieren: Wer ein Startdatum aendert und
-- danach wieder zuruecksetzt, wuerde sonst Dubletten anlegen. Die Anwendung
-- schreibt mit ON CONFLICT DO NOTHING.
CREATE UNIQUE INDEX betrieb_saison_historie_uniq
  ON public.betrieb_saison_historie (betrieb_id, saison, start_datum);

ALTER TABLE public.betrieb_saison_historie ENABLE ROW LEVEL SECURITY;
CREATE POLICY betrieb_saison_historie_select ON public.betrieb_saison_historie
  FOR SELECT USING (user_id = auth.uid());
CREATE POLICY betrieb_saison_historie_insert ON public.betrieb_saison_historie
  FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY betrieb_saison_historie_update ON public.betrieb_saison_historie
  FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY betrieb_saison_historie_delete ON public.betrieb_saison_historie
  FOR DELETE USING (user_id = auth.uid());

COMMENT ON TABLE public.betrieb_saison_historie IS
  'Abgeschlossene Saisonfenster. Ein Eintrag entsteht beim Speichern eines '
  'Betriebs, sobald sich das START-Datum einer Saison aendert — ein '
  'geaendertes Ende ist eine Korrektur derselben Saison und archiviert nichts.';
COMMENT ON COLUMN public.betrieb_saison_historie.ende_datum IS
  'Darf leer sein: war am Betrieb nur der Start gepflegt, ist die Teilangabe '
  'immer noch besser als keine.';

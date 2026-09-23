-- 200: Mahnwesen Teil 1 — Frist je Rechnung und Protokoll je Mahnschreiben
--
-- ANLASS (Daniel, 23.09.2026): Das Mahnwesen wird neu aufgebaut
-- (docs/superpowers/specs/2026-09-23-mahnwesen-design.md). Bisher kannte
-- eine Rechnung ihre Mahnstufe und deren Datum, aber nicht die im Schreiben
-- gesetzte Frist — die nächste Stufe liess sich nicht verlässlich
-- bestimmen. Und es gab kein Protokoll, wer wann welches Schreiben bekam;
-- ohne das lässt sich eine (Test-)Mahnung nicht sauber zurücknehmen.

ALTER TABLE public.rechnungen
  ADD COLUMN IF NOT EXISTS mahn_frist_bis date;

COMMENT ON COLUMN public.rechnungen.mahn_frist_bis IS
  'Im letzten Mahnschreiben gesetzte Zahlungsfrist (Versanddatum + 10 Tage). '
  'Grundlage für die Fälligkeit der nächsten Stufe (+5 Tage).';

CREATE TABLE public.mahnschreiben (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           uuid NOT NULL REFERENCES auth.users(id),
  betrieb_id        uuid NOT NULL REFERENCES public.betriebe(id) ON DELETE CASCADE,
  stufe             integer NOT NULL CHECK (stufe BETWEEN 0 AND 2),
  rechnung_ids      uuid[] NOT NULL,
  kanal             text NOT NULL CHECK (kanal IN ('mail', 'druck', 'mail_und_druck')),
  empfaenger        text,
  test              boolean NOT NULL DEFAULT true,
  frist_bis         date NOT NULL,
  pdf_pfad          text,
  -- Zustand der Rechnungen VOR dem Schreiben, je Rechnung:
  -- {"<id>": {"zahlungsstatus": …, "mahnung_stufe": …, "letzte_mahnung_am": …,
  --           "erinnerung_am": …, "mahnung_1_am": …, "mahnung_2_am": …,
  --           "mahn_frist_bis": …}}
  -- Grundlage für «Mahnung zurücknehmen».
  vorher            jsonb NOT NULL,
  erstellt_am       timestamptz NOT NULL DEFAULT now(),
  zurueckgenommen_am timestamptz
);

CREATE INDEX mahnschreiben_betrieb_idx ON public.mahnschreiben (betrieb_id, erstellt_am DESC);

ALTER TABLE public.mahnschreiben ENABLE ROW LEVEL SECURITY;
CREATE POLICY mahnschreiben_select ON public.mahnschreiben
  FOR SELECT USING (user_id = auth.uid());
CREATE POLICY mahnschreiben_insert ON public.mahnschreiben
  FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY mahnschreiben_update ON public.mahnschreiben
  FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY mahnschreiben_delete ON public.mahnschreiben
  FOR DELETE USING (user_id = auth.uid());

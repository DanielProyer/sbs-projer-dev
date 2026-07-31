-- 160: Betriebsferien als eigene Tabelle + Pflege-Zustand + Vorschlaege
-- Spec: docs/superpowers/specs/2026-07-31-betriebsdaten-aktuell-halten-design.md
--
-- Warum eine Tabelle statt der bisherigen 5 festen Spaltenpaare:
-- Ferien sind Kalenderdaten, die jedes Jahr neu erfasst werden. In 5 Slots
-- verdraengen neue Ferien die Historie — genau die, aus der der
-- Vorjahres-Hinweis stammt ("letztes Jahr hatte er hier Ferien").
-- Die alten Spalten bleiben vorerst STEHEN (Rueckweg), sie werden erst
-- entfernt, wenn die neue Struktur im Feld bestaetigt ist.

CREATE TABLE public.betrieb_ferien (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  betrieb_id    uuid NOT NULL REFERENCES public.betriebe(id) ON DELETE CASCADE,
  von           date NOT NULL,
  bis           date NOT NULL,
  quelle        text NOT NULL DEFAULT 'kunde'
                CHECK (quelle IN ('kunde','vor_ort','website','google','import')),
  bestaetigt_am timestamptz,
  notiz         text,
  user_id       uuid NOT NULL REFERENCES auth.users(id),
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CHECK (bis >= von)
);

CREATE INDEX betrieb_ferien_betrieb_idx ON public.betrieb_ferien (betrieb_id);
CREATE INDEX betrieb_ferien_zeitraum_idx ON public.betrieb_ferien (von, bis);

ALTER TABLE public.betrieb_ferien ENABLE ROW LEVEL SECURITY;
CREATE POLICY betrieb_ferien_select ON public.betrieb_ferien
  FOR SELECT USING (user_id = auth.uid());
CREATE POLICY betrieb_ferien_insert ON public.betrieb_ferien
  FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY betrieb_ferien_update ON public.betrieb_ferien
  FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY betrieb_ferien_delete ON public.betrieb_ferien
  FOR DELETE USING (user_id = auth.uid());
CREATE TRIGGER betrieb_ferien_updated_at BEFORE UPDATE ON public.betrieb_ferien
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

COMMENT ON COLUMN public.betrieb_ferien.quelle IS
  'Woher die Angabe stammt. kunde/vor_ort sind bestaetigtes Wissen und '
  'steuern die Planung; website/google sind Hinweise; import = Altbestand.';
COMMENT ON COLUMN public.betrieb_ferien.bestaetigt_am IS
  'Nur gesetzt, wenn ein Mensch die Angabe bestaetigt hat. Fremdquellen '
  'bestaetigen nichts und lassen das Feld leer.';

-- Uebernahme der bestehenden Slots. quelle='import', bewusst OHNE
-- bestaetigt_am: diese Angaben sind ungeprueft alt.
INSERT INTO public.betrieb_ferien (betrieb_id, von, bis, quelle, user_id)
SELECT b.id, s.von, s.bis, 'import', b.user_id
FROM public.betriebe b
CROSS JOIN LATERAL (VALUES
  (b.ferien_start,  b.ferien_ende),
  (b.ferien2_start, b.ferien2_ende),
  (b.ferien3_start, b.ferien3_ende),
  (b.ferien4_start, b.ferien4_ende),
  (b.ferien5_start, b.ferien5_ende)
) AS s(von, bis)
WHERE s.von IS NOT NULL AND s.bis IS NOT NULL AND s.bis >= s.von;

-- ── Pflege-Zustand am Betrieb ──────────────────────────────────────────
ALTER TABLE public.betriebe ADD COLUMN IF NOT EXISTS ferien_bestaetigt_am timestamptz;
ALTER TABLE public.betriebe ADD COLUMN IF NOT EXISTS ferien_frage_ruht_bis date;
ALTER TABLE public.betriebe ADD COLUMN IF NOT EXISTS ruhetage_bestaetigt_am timestamptz;
ALTER TABLE public.betriebe ADD COLUMN IF NOT EXISTS oeffnungszeiten_geprueft_am timestamptz;
ALTER TABLE public.betriebe ADD COLUMN IF NOT EXISTS google_place_id text;

COMMENT ON COLUMN public.betriebe.ruhetage_bestaetigt_am IS
  'Trennt "kein Ruhetag bekannt" (NULL) von "geprueft, hat keinen Ruhetag". '
  'Ein leeres ruhetage-Array allein ist mehrdeutig.';
COMMENT ON COLUMN public.betriebe.ferien_frage_ruht_bis IS
  'Antwort "weiss nicht" beim Reinigungs-Abschluss: bis dahin nicht erneut fragen.';
COMMENT ON COLUMN public.betriebe.oeffnungszeiten_geprueft_am IS
  'Letzter Abgleich mit Google/Website — auch wenn nichts abwich. Steuert, '
  'welche Betriebe der taegliche Lauf als naechstes vornimmt.';

-- ── Vorschlaege aus Fremdquellen ───────────────────────────────────────
-- Google und Website schreiben NIE direkt in den Betrieb: eine still
-- ueberschriebene Oeffnungszeit waere schlimmer als gar keine, weil sie
-- gepflegt aussieht. Alles laeuft ueber die Pruefliste.
CREATE TABLE public.betrieb_vorschlaege (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  betrieb_id  uuid NOT NULL REFERENCES public.betriebe(id) ON DELETE CASCADE,
  feld        text NOT NULL
              CHECK (feld IN ('ruhetage','oeffnungszeiten','ferien','saison','status')),
  alt_wert    jsonb,
  neu_wert    jsonb NOT NULL,
  quelle      text NOT NULL CHECK (quelle IN ('google','website','google_website')),
  konfidenz   numeric,
  gefunden_am timestamptz NOT NULL DEFAULT now(),
  status      text NOT NULL DEFAULT 'offen'
              CHECK (status IN ('offen','uebernommen','verworfen')),
  user_id     uuid NOT NULL REFERENCES auth.users(id)
);

-- Ein offener Vorschlag je (Betrieb, Feld, Quelle) — ein neuer Lauf
-- aktualisiert ihn, statt Dubletten zu haeufen.
CREATE UNIQUE INDEX betrieb_vorschlaege_offen_uniq
  ON public.betrieb_vorschlaege (betrieb_id, feld, quelle) WHERE status = 'offen';

ALTER TABLE public.betrieb_vorschlaege ENABLE ROW LEVEL SECURITY;
CREATE POLICY betrieb_vorschlaege_select ON public.betrieb_vorschlaege
  FOR SELECT USING (user_id = auth.uid());
CREATE POLICY betrieb_vorschlaege_insert ON public.betrieb_vorschlaege
  FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY betrieb_vorschlaege_update ON public.betrieb_vorschlaege
  FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY betrieb_vorschlaege_delete ON public.betrieb_vorschlaege
  FOR DELETE USING (user_id = auth.uid());

COMMENT ON TABLE public.betrieb_vorschlaege IS
  'Aenderungsvorschlaege aus Google und Website. Werden nie automatisch '
  'uebernommen. quelle=google_website heisst: beide Quellen sind einig.';

-- ── Leerfahrt im Wegpunkt-Strom ────────────────────────────────────────
ALTER TABLE public.wegpunkte DROP CONSTRAINT IF EXISTS wegpunkte_quelle_check;
ALTER TABLE public.wegpunkte ADD CONSTRAINT wegpunkte_quelle_check
  CHECK (quelle IN (
    'reinigung', 'stoerung', 'montage',
    'arbeitsbeginn', 'feierabend',
    'pause_start', 'pause_ende',
    'vergeblich'
  ));

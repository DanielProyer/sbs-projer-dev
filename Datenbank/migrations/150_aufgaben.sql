-- 150: Aufgaben-Erinnerungen (Spec 2026-07-22)
-- Persistenz NUR fuer eigene Aufgaben, Snoozes und manuelle Erledigt-Marker.
-- Die 4 automatischen Regeln (Heineken/MWST/Mahnlauf/Saisondaten) rechnen
-- client-seitig frisch und erzeugen KEINE Zeilen.
CREATE TABLE public.aufgaben (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id),
  typ text NOT NULL CHECK (typ IN ('eigene','marker','snooze')),
  key text,                    -- Detektor-Schluessel (marker/snooze); NULL bei eigene
  titel text,                  -- nur eigene
  faellig_am date,             -- nur eigene (optional)
  snooze_bis date,             -- nur snooze
  erledigt_am timestamptz,     -- eigene: Abhaken; marker: Zeitpunkt
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX aufgaben_user_typ_key_uniq
  ON public.aufgaben (user_id, typ, key) WHERE key IS NOT NULL;
ALTER TABLE public.aufgaben ENABLE ROW LEVEL SECURITY;
CREATE POLICY aufgaben_select ON public.aufgaben
  FOR SELECT USING (user_id = auth.uid());
CREATE POLICY aufgaben_insert ON public.aufgaben
  FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY aufgaben_update ON public.aufgaben
  FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY aufgaben_delete ON public.aufgaben
  FOR DELETE USING (user_id = auth.uid());
CREATE TRIGGER aufgaben_updated_at BEFORE UPDATE ON public.aufgaben
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

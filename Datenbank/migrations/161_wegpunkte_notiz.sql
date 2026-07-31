-- 161: Notiz-Feld auf wegpunkte
-- Spec: docs/superpowers/specs/2026-07-31-betriebsdaten-aktuell-halten-design.md
-- Baustein A ("War geschlossen"): Der Grund einer Leerfahrt (z.B. "Chef im
-- Urlaub, Kollege wusste nichts") soll am Wegpunkt haengen bleiben, nicht nur
-- im Betrieb (der bei "niemand da / anderes" gar nicht veraendert wird).
ALTER TABLE public.wegpunkte ADD COLUMN IF NOT EXISTS notiz text;

COMMENT ON COLUMN public.wegpunkte.notiz IS
  'Freitext, insbesondere bei quelle=vergeblich der Grund der Leerfahrt.';

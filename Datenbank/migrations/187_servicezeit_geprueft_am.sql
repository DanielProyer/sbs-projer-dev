-- 187: Merker fuer die Servicezeiten-Durchsicht
--
-- 201 der 305 aktiven Betriebe haben keine Servicezeit hinterlegt. Die
-- Durchsicht geht sie einzeln durch (Vorschlag aus den Besuchszeiten seit
-- 2019, bestaetigen oder korrigieren). Ohne Merker faengt sie bei jedem
-- Aufruf von vorne an.
--
-- Gleiches Muster wie ruhetage_bestaetigt_am und oeffnungszeiten_geprueft_am
-- aus Migration 160: der Stempel trennt "geprueft" von "nie angeschaut" —
-- ein leeres Servicezeit-Feld allein ist mehrdeutig.

ALTER TABLE public.betriebe
  ADD COLUMN IF NOT EXISTS servicezeit_geprueft_am timestamptz;

COMMENT ON COLUMN public.betriebe.servicezeit_geprueft_am IS
  'Gesetzt, wenn die Servicezeiten in der Durchsicht bestaetigt wurden. '
  'Uebersprungene Betriebe bleiben leer und kommen in der naechsten Runde '
  'wieder. Trennt "geprueft, hat keine Einschraenkung" von "nie angeschaut".';

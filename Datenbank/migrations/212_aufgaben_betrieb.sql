-- 212: Aufgaben bekommen einen Betriebsbezug (Entscheid Daniel 27.09.2026)
--
-- ANLASS: Eine eigene Aufgabe war bisher reiner Freitext. «Beim Rössli den
-- Hahn mitnehmen» verlor beim Diktat sogar den Betrieb: `parse-einsatz`
-- erkennt ihn zwar (betrieb_id), die Beschreibung lässt den Namen aber
-- bewusst weg — gespeichert wurde nur «Hahn mitnehmen».
--
-- Neu: optionale Spalte `betrieb_id`. Die App zeigt die Aufgaben damit auf
-- der Betriebsseite (Sektion «Aufgaben»), im Tourenplan und in der
-- Aufgabenliste mit dem Betriebsnamen.
--
-- `on delete set null`: Wird ein Betrieb gelöscht, bleibt die Aufgabe als
-- Freitext stehen — sie verschwindet nicht still.
--
-- Nur `typ = 'eigene'` trägt einen Betrieb; Marker- und Snooze-Zeilen
-- bleiben NULL. Keine Datenmigration: bestehende Aufgaben haben keinen
-- Betrieb und behalten ihn nicht.

ALTER TABLE public.aufgaben
  ADD COLUMN betrieb_id uuid REFERENCES public.betriebe(id) ON DELETE SET NULL;

-- Betriebsseite: «alle Aufgaben dieses Betriebs» (RLS filtert auf user_id).
CREATE INDEX aufgaben_user_betrieb_idx
  ON public.aufgaben (user_id, betrieb_id);

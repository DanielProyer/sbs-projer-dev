-- 169_event_stand_position_genauigkeit.sql
-- Event-Stände: Wie verlässlich ist die Position?
--
-- Ergänzung zu Migration 168 (Wunsch Daniel 11.08.2026). `position_quelle`
-- sagt, WOHER die Koordinaten stammen (Karte/GPS) — diese Spalte sagt, WIE GUT
-- sie sind:
--
--   'genau'     = auf den Meter (GPS-Messung vor Ort, sauber eingemessen)
--   'mittel'    = Standbereich stimmt, exakte Ecke unklar
--   'ungefaehr' = grobe Verortung, muss vor Ort geprüft werden
--
-- Bei einer GPS-Messung leitet die App die Stufe aus der gemeldeten
-- Messgenauigkeit ab (<=10 m genau, <=50 m mittel, darüber ungefähr); von Hand
-- eingegebene Koordinaten setzt der Nutzer selbst.

alter table event_staende add column position_genauigkeit text
  check (position_genauigkeit in ('genau', 'mittel', 'ungefaehr'));

-- Bestand: bisherige Positionen stammen aus GPS-Messungen vor Ort, die
-- Messgenauigkeit ist rückwirkend nicht mehr bekannt -> 'mittel' als
-- ehrliche Einstufung (nicht 'genau' behaupten, was nicht belegt ist).
update event_staende
set position_genauigkeit = 'mittel'
where latitude is not null and longitude is not null;

comment on column event_staende.position_genauigkeit is
  'genau | mittel | ungefaehr — Verlaesslichkeit der Position. Bei GPS aus der Messgenauigkeit abgeleitet, sonst vom Nutzer gesetzt.';

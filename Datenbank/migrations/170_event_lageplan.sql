-- 170_event_lageplan.sql
-- Events: georeferenzierter Lageplan (Wunsch Daniel 13.08.2026, Fall Gampel).
--
-- Ein Bild (JPG/PNG im Storage-Bucket event-dokumente) wird ueber 2-5
-- Passpunkte auf die Karte gelegt. Gespeichert werden nur die ROHDATEN --
-- Storage-Pfad, Bildmasse und Passpunkte; die Transformation rechnet die App
-- bei jeder Anzeige frisch (eine Wahrheit, Punkte bleiben nachjustierbar).
--
-- lageplan_punkte (jsonb):
--   { "bildBreite": 1600, "bildHoehe": 1131,
--     "punkte": [ {"px": .., "py": .., "lat": .., "lng": ..}, ... ] }

alter table events add column lageplan_pfad text;
alter table events add column lageplan_punkte jsonb;

comment on column events.lageplan_pfad is
  'Storage-Pfad des Lageplan-Bilds (Bucket event-dokumente). NULL = kein Lageplan.';
comment on column events.lageplan_punkte is
  'Bildmasse + Passpunkte fuer die Georeferenzierung (Berechnung: core/util/georeferenz.dart).';

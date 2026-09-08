-- 189: AHV, Unfall, Krankentaggeld und Haftpflicht werden eigene Bereiche.
--
-- Bis hierher lagen sie als Kategorien unter 'versicherungen'. Wer eine
-- SUVA-Verfuegung suchte, sah zuerst 101 Dokumente von vier Absendern.
-- Entscheid Daniel 08.09.2026: eine Ebene je Absender. 'versicherungen'
-- bleibt als Auffangbereich fuer Sach-/Rechtsschutz-/Fahrzeugversicherung.
--
-- Reihenfolge beachten: erst der Constraint, dann der Datenumzug
-- (Datenbank/werkzeuge/dokument_bereich_umziehen.py) -- sonst weist die DB
-- die neuen Werte zurueck.
alter table public.dokumente drop constraint if exists dokumente_bereich_check;
alter table public.dokumente add constraint dokumente_bereich_check
  check (bereich = any (array[
    'steuern', 'ahv', 'unfall', 'krankentaggeld', 'pensionskasse',
    'haftpflicht', 'versicherungen', 'vertraege', 'behoerden', 'bank',
    'sonstiges'
  ]));

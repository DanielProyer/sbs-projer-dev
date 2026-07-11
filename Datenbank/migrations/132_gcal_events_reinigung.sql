-- 132: google_calendar_events fuer Betriebs-Reinigungen (zusammengesetzter Schluessel)
alter table public.google_calendar_events
  alter column entity_id type text;

alter table public.google_calendar_events
  drop constraint if exists google_calendar_events_entity_type_check;
alter table public.google_calendar_events
  add constraint google_calendar_events_entity_type_check
  check (entity_type in ('termin','pikett','event','betrieb_reinigung'));

-- 133: google_calendar_events.entity_type um 'betrieb_manuell' erweitern (K2b).
-- Manuell im Google-Kalender erfasste Termine, die per K2 einem Betrieb
-- zugeordnet + getaggt werden (entity_id = Google-Event-ID).

alter table public.google_calendar_events
  drop constraint if exists google_calendar_events_entity_type_check;

alter table public.google_calendar_events
  add constraint google_calendar_events_entity_type_check
  check (entity_type = any (array[
    'termin'::text,
    'pikett'::text,
    'event'::text,
    'betrieb_reinigung'::text,
    'betrieb_manuell'::text
  ]));

-- 164: Kalender-Typ 'einsatz' zulassen (geplante Stoerungen und Montagen)
-- Spec: docs/superpowers/specs/2026-07-31-einsatzplanung-sprache-design.md
--
-- Die Zuordnungstabelle google_calendar_events erlaubte bisher nur
-- termin/pikett/event/betrieb_reinigung/betrieb_manuell. Ohne 'einsatz'
-- waere der Google-Termin zwar angelegt worden, die Zuordnungszeile aber an
-- der CHECK-Regel gescheitert — und der naechste Abgleich haette denselben
-- Termin nochmals angelegt. Duplikate im Kalender bei jedem Lauf.
--
-- Hintergrund zum Feature: Eine Web-App kann bei geschlossenem Tab keine
-- Erinnerung zustellen. Der Google-Kalender ist der einzige Kanal, der
-- Daniel zuverlaessig erreicht — die App plant, Google erinnert.

alter table public.google_calendar_events
  drop constraint if exists google_calendar_events_entity_type_check;

alter table public.google_calendar_events
  add constraint google_calendar_events_entity_type_check
  check (entity_type = any (array[
    'termin'::text,
    'pikett'::text,
    'event'::text,
    'betrieb_reinigung'::text,
    'betrieb_manuell'::text,
    'einsatz'::text
  ]));

comment on column public.google_calendar_events.entity_type is
  'Quelle des Kalendereintrags. einsatz = geplante Stoerung oder Montage, '
  'entity_id zusammengesetzt als "stoerung:<id>" bzw. "montage:<id>".';

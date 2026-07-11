-- 134: Original-Farbe/-Erinnerung eines Google-Termins sichern, damit K2-Untag
-- exakt den Ursprungszustand wiederherstellt (nicht nur Kalender-Default).
alter table public.google_calendar_events
  add column if not exists original_color_id text,
  add column if not exists original_reminders jsonb;

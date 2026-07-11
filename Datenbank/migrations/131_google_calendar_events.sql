-- 131: Zuordnung App-Entity <-> Google-Kalender-Event (server-only)
create table if not exists public.google_calendar_events (
  id bigserial primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  entity_type text not null check (entity_type in ('termin','pikett','event')),
  entity_id uuid not null,
  google_event_id text,
  content_hash text,
  synced_at timestamptz,
  status text not null default 'ok',
  fehler text,
  updated_at timestamptz not null default now(),
  unique (user_id, entity_type, entity_id)
);
alter table public.google_calendar_events enable row level security;
-- keine Client-Policy: nur service_role (Edge Function).

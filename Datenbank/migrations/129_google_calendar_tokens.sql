-- 129: Google-Kalender OAuth-Token (server-only) + Verbindungs-Status (client-lesbar)

create table if not exists public.google_calendar_tokens (
  user_id uuid primary key references auth.users(id) on delete cascade,
  refresh_token text not null,
  access_token text,
  access_token_expiry timestamptz,
  google_email text,
  scope text,
  calendar_id text,
  connected_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.google_calendar_tokens enable row level security;
-- BEWUSST keine Policy: nur service_role (Edge Functions) hat Zugriff. Der Browser sieht die Tokens nie.

create table if not exists public.google_calendar_status (
  user_id uuid primary key references auth.users(id) on delete cascade,
  connected boolean not null default false,
  google_email text,
  connected_at timestamptz,
  updated_at timestamptz not null default now()
);
alter table public.google_calendar_status enable row level security;
create policy "gcal_status_select_own" on public.google_calendar_status
  for select using (auth.uid() = user_id);
-- kein INSERT/UPDATE/DELETE fuer Clients: nur service_role schreibt.

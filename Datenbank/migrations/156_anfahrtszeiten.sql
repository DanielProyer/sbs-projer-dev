-- 156: Anfahrtszeiten von den festen Startorten zu allen Betrieben
-- (Daniel 31.07.2026): erste Grundlage für die Routen-Optimierung der
-- Tourenplanung. Standardzeiten ohne Verkehr, Quelle OSRM (kostenlos);
-- kann später durch Google-Routes-Werte überschrieben werden (quelle).
--
-- startort: 'domat_ems' = Via Rezia 8 (Zuhause), 'chur' = Giacomettistrasse
-- 89 (Lorena). Bewusst eigene Tabelle statt Pseudo-Betriebe in `fahrzeiten`
-- (dort sind beide Seiten echte Betriebe mit FK).

create table if not exists anfahrtszeiten (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  startort text not null check (startort in ('domat_ems', 'chur')),
  betrieb_id uuid not null references betriebe (id) on delete cascade,
  minuten int not null check (minuten > 0),
  distanz_km numeric(6, 1),
  quelle text not null default 'osrm',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, startort, betrieb_id)
);

alter table anfahrtszeiten enable row level security;

create policy "anfahrtszeiten_eigene" on anfahrtszeiten
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create index if not exists idx_anfahrtszeiten_betrieb
  on anfahrtszeiten (user_id, betrieb_id);

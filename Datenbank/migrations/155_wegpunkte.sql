-- 155: Wegpunkte — Zeit-/Ortsstempel je Ereignis des Arbeitstags
-- (Daniel 30.07.2026, «die Daten sind wertvoll und sollen spaeter fuer die
-- Optimierung der Routen verwendet werden»).
--
-- Statt Dauer-GPS-Tracking (in der Web-App nicht zuverlaessig: Browser
-- drosselt Hintergrund-Tabs, Bildschirm aus = kein JavaScript) stempelt die
-- App bei jedem EREIGNIS einen Punkt: Reinigung abgeschlossen, Stoerung/
-- Montage erfasst, Arbeitsbeginn, Feierabend. Jeder Punkt traegt Kontext
-- (Quelle, Betrieb, Referenz) — fuer die Routen-Optimierung wertvoller als
-- rohe 5-Minuten-Pings. Zweitnutzen: Die Fahrzeit-Nachfuehrung erkennt
-- daran, ob zwischen zwei Reinigungen ein anderer Einsatz lag (dann ist die
-- Luecke keine reine Fahrzeit und wird nicht gelernt).
create table if not exists wegpunkte (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  zeitpunkt timestamptz not null default now(),
  lat numeric,
  lng numeric,
  quelle text not null check (quelle in
    ('reinigung','stoerung','montage','arbeitsbeginn','feierabend')),
  betrieb_id uuid references betriebe(id) on delete set null,
  referenz_id uuid,
  created_at timestamptz not null default now()
);
alter table wegpunkte enable row level security;
create policy wegpunkte_all on wegpunkte
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create index if not exists wegpunkte_user_zeit on wegpunkte (user_id, zeitpunkt);

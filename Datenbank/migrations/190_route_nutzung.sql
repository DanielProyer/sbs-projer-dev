-- 190: Nutzungsmessung der App-Routen (Punkt 5 der App-Analyse vom 08.09.2026).
--
-- Frage, die beantwortet werden soll: Welcher Bereich wird tatsaechlich
-- geoeffnet? Ohne Zahlen ist «Anlagen braucht niemand» eine Meinung; die
-- Vorschlaege A6 (Ballast aus dem Hauptmenue) und B2 (Einsaetze zusammen-
-- fuehren) haengen daran.
--
-- Gezaehlt wird das Routen-MUSTER, das der NavigatorObserver liefert
-- ('/betriebe/:id'), nie die konkrete URL — es landen also keine
-- Datensatz-IDs in der Messung.
--
-- Getrennt nach Geraeteklasse, weil Befund 4 genau das behauptet: Werkstatt
-- (Handy) und Buero (PC) sind zwei verschiedene Apps in einer.
create table if not exists public.route_nutzung (
  user_id uuid not null references auth.users (id) on delete cascade,
  route text not null,
  geraet text not null check (geraet in ('handy', 'desktop')),
  tag date not null,
  anzahl integer not null default 0,
  primary key (user_id, route, geraet, tag)
);

alter table public.route_nutzung enable row level security;

drop policy if exists route_nutzung_all on public.route_nutzung;
create policy route_nutzung_all on public.route_nutzung
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create index if not exists route_nutzung_tag on public.route_nutzung (user_id, tag);

-- Hochzaehlen statt Ueberschreiben: Die App sammelt lokal und liefert
-- Teilmengen nach — auch nachtraeglich, wenn sie im Keller offline war.
-- Ein reines upsert wuerde dabei die schon gemeldete Anzahl ersetzen.
create or replace function public.route_nutzung_zaehlen(
  p_route text,
  p_geraet text,
  p_tag date,
  p_anzahl integer
) returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  insert into public.route_nutzung (user_id, route, geraet, tag, anzahl)
  values (auth.uid(), p_route, p_geraet, p_tag, p_anzahl)
  on conflict (user_id, route, geraet, tag)
  do update set anzahl = public.route_nutzung.anzahl + excluded.anzahl;
end;
$$;

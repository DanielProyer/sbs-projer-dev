-- 152: Fahrzeiten-Kaskade + Arbeitstag-Rahmen (Spec 2026-07-29 Tourenplan-Zeitachse)
--
-- Bereits angewendet; Datenkorrektur der 2 Fehlzeilen erfolgte per Hand am 29.07.2026
-- (Review-Befund: LATERAL-Join uebersprang Zwischenbesuche im selben Betrieb und
-- vermischte deren Arbeitszeit in die Fahrzeit -- siehe Fix in Abschnitt 4 unten).

-- 1) Gelernte/gecachte Fahrzeiten zwischen Betrieben.
create table if not exists fahrzeiten (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  von_betrieb_id uuid not null references betriebe(id) on delete cascade,
  nach_betrieb_id uuid not null references betriebe(id) on delete cascade,
  minuten int not null check (minuten between 1 and 300),
  quelle text not null check (quelle in ('beobachtet','route')),
  anzahl int not null default 1,
  updated_at timestamptz not null default now(),
  unique (user_id, von_betrieb_id, nach_betrieb_id)
);
alter table fahrzeiten enable row level security;
create policy fahrzeiten_all on fahrzeiten
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- 2) Arbeitstag-Rahmen am Tagesplan.
alter table tagesplaene
  add column if not exists arbeitsbeginn text,
  add column if not exists arbeitsende text,
  add column if not exists km_stand int;

-- 3) Startort (Zuhause) fuer Anfahrt/Heimweg.
alter table geschaeft_einstellungen
  add column if not exists startort_lat numeric,
  add column if not exists startort_lng numeric;

-- 4) Backfill beobachteter Fahrzeiten aus historischen Reinigungen:
--    Uebergang = Ende bei Betrieb A -> Start bei Betrieb B am selben Tag,
--    Luecke 3-120 min gilt als Fahrzeit. Median je Richtungspaar.
with tagesfolge as (
  select user_id, betrieb_id, datum,
         (datum::timestamp + uhrzeit_start::time) as start_ts,
         (datum::timestamp + uhrzeit_ende::time) as ende_ts
  from reinigungen
  where uhrzeit_start is not null and uhrzeit_ende is not null
    and betrieb_id is not null
),
uebergaenge as (
  select a.user_id, a.betrieb_id as von_id, b.betrieb_id as nach_id,
         extract(epoch from (b.start_ts - a.ende_ts)) / 60.0 as luecke_min
  from tagesfolge a
  join lateral (
    -- Hier NUR den chronologisch naechsten Besuch suchen, egal welcher Betrieb.
    -- Wuerde man "b.betrieb_id <> a.betrieb_id" bereits hier im Subquery filtern,
    -- wird bei einer Kette am selben Betrieb (A -> A -> B) der Zwischenbesuch A
    -- uebersprungen und dessen Arbeitszeit faelschlich als Fahrzeit A->B gezaehlt
    -- (Review-Befund 29.07.2026, 2 Zeilen live betroffen und per Hand korrigiert).
    select * from tagesfolge b
    where b.user_id = a.user_id and b.datum = a.datum
      and b.start_ts > a.ende_ts
    order by b.start_ts limit 1
  ) b on true
  -- Der Betrieb-Filter gehoert AUSSEN: so terminiert eine Kette am selben Betrieb
  -- korrekt (kein Uebergang, keine Fahrzeit), statt den naechsten Besuch zu
  -- ueberspringen.
  where b.betrieb_id <> a.betrieb_id
    and extract(epoch from (b.start_ts - a.ende_ts)) / 60.0 between 3 and 120
)
insert into fahrzeiten (user_id, von_betrieb_id, nach_betrieb_id, minuten, quelle, anzahl)
select user_id, von_id, nach_id,
       round(percentile_cont(0.5) within group (order by luecke_min))::int,
       'beobachtet', count(*)
from uebergaenge
group by user_id, von_id, nach_id
on conflict (user_id, von_betrieb_id, nach_betrieb_id) do nothing;

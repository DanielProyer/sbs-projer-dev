-- Rollback Zeiten-Nachtrag 30.07.2026: stellt die alten Uhrzeiten aus
-- import.zeiten_alt wieder her und baut die beobachteten Fahrzeiten aus dem
-- dann wieder alten Datenstand neu auf (gleiches Backfill wie im Vorwaerts-
-- Skript). Route-Cache-Zeilen bleiben unberuehrt.
begin;

update reinigungen r
set uhrzeit_start = a.uhrzeit_start, uhrzeit_ende = a.uhrzeit_ende
from import.zeiten_alt a
where r.id = a.id;

delete from fahrzeiten where quelle = 'beobachtet';

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
    select * from tagesfolge b
    where b.user_id = a.user_id and b.datum = a.datum
      and b.start_ts > a.ende_ts
    order by b.start_ts limit 1
  ) b on true
  where b.betrieb_id <> a.betrieb_id
    and extract(epoch from (b.start_ts - a.ende_ts)) / 60.0 between 3 and 120
)
insert into fahrzeiten (user_id, von_betrieb_id, nach_betrieb_id, minuten, quelle, anzahl)
select user_id, von_id, nach_id,
       round(percentile_cont(0.5) within group (order by luecke_min))::int,
       'beobachtet', count(*)
from uebergaenge
group by user_id, von_id, nach_id
on conflict (user_id, von_betrieb_id, nach_betrieb_id)
do update set minuten = excluded.minuten, quelle = 'beobachtet',
              anzahl = excluded.anzahl, updated_at = now();

commit;

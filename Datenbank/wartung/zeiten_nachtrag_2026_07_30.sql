-- Zeiten-Nachtrag aus dem Excel (Daniel 30.07.2026).
-- Importierte Reinigungen kamen ohne Uhrzeiten, App-nacherfasste haben teils
-- 1-Minuten-Zeiten - beides verfaelscht Dauer-Schaetzung und beobachtete
-- Fahrzeiten der Tourenplanung. Quelle: import.zeiten_nachtrag (7703 Zeilen
-- mit Beginn+Ende aus Excel-Spalten 16/17, via extract_zeiten_nachtrag.py).
-- Rollback: rollback_zeiten_nachtrag_2026_07_30.sql

begin;

-- 0) Sicherung der alten Werte beider Zielmengen.
drop table if exists import.zeiten_alt;
create table import.zeiten_alt as
select r.id, r.extern_id, r.uhrzeit_start, r.uhrzeit_ende
from reinigungen r
where (r.extern_id is not null
       and r.uhrzeit_start is null
       and exists (select 1 from import.zeiten_nachtrag s
                   where s.extern_id = r.extern_id))
   or (r.extern_id is null
       and r.dauer_minuten is not null and r.dauer_minuten <= 2);

-- 1) Importierte Reinigungen: exakter Abgleich ueber extern_id,
--    nur wo noch keine Zeiten stehen.
update reinigungen r
set uhrzeit_start = s.beginn, uhrzeit_ende = s.ende
from import.zeiten_nachtrag s
where r.extern_id = s.extern_id
  and r.uhrzeit_start is null;

-- 2) App-nacherfasste (<=2 min, ohne extern_id): Abgleich ueber eindeutiges
--    (Datum, Betriebsname). Beide Seiten muessen eindeutig sein, sonst kein
--    Update - lieber eine Luecke als eine falsche Zuordnung.
with staging_eindeutig as (
  select s.datum, lower(s.betrieb) as name_lc,
         min(s.beginn) as beginn, min(s.ende) as ende
  from import.zeiten_nachtrag s
  group by s.datum, lower(s.betrieb)
  having count(*) = 1
),
ziel_eindeutig as (
  select min(r.id::text)::uuid as id, r.datum, lower(b.name) as name_lc
  from reinigungen r
  join betriebe b on b.id = r.betrieb_id
  where r.extern_id is null
    and r.dauer_minuten is not null and r.dauer_minuten <= 2
  group by r.datum, lower(b.name)
  having count(*) = 1
)
update reinigungen r
set uhrzeit_start = se.beginn, uhrzeit_ende = se.ende
from ziel_eindeutig z
join staging_eindeutig se on se.datum = z.datum and se.name_lc = z.name_lc
where r.id = z.id;

-- 3) Beobachtete Fahrzeiten NEU aufbauen: Die bisherigen 216 Paare entstanden
--    teils aus den falschen 1-Minuten-Zeiten; mit den nachgetragenen Zeiten
--    gibt es zudem VIEL mehr echte Uebergaenge. Route-Cache bleibt, wird bei
--    Kollision aber von der Beobachtung ueberschrieben (Beobachtung > Route).
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
  -- Im LATERAL nur den chronologisch NAECHSTEN Besuch suchen; der
  -- Betriebs-Filter steht bewusst AUSSEN (Review-Befund 29.07.2026):
  -- Ketten am selben Betrieb terminieren so korrekt statt uebersprungen
  -- zu werden.
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

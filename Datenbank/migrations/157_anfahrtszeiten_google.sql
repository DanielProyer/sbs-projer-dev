-- 157: Zweite Meinung für die Anfahrtszeiten (Daniel 31.07.2026:
-- «2 Werte sind besser als einer»). OSRM (frei) und Google Routes
-- (TRAFFIC_UNAWARE = Standardzeiten ohne Verkehr) nebeneinander.
--
-- `minuten` wird zur GENERATED-Spalte: Google gewinnt, wenn vorhanden
-- (kennt Schweizer Tempolimits/Abbiegeverbote genauer), sonst OSRM. So
-- muss die App nur eine Spalte lesen, sieht aber beide Quellen.

alter table anfahrtszeiten
  add column if not exists minuten_google int check (minuten_google > 0),
  add column if not exists distanz_km_google numeric(6, 1),
  add column if not exists minuten_osrm int check (minuten_osrm > 0),
  add column if not exists distanz_km_osrm numeric(6, 1);

-- Bestehende Werte (alle aus dem OSRM-Lauf vom 31.07.) umziehen.
update anfahrtszeiten
   set minuten_osrm = coalesce(minuten_osrm, minuten),
       distanz_km_osrm = coalesce(distanz_km_osrm, distanz_km)
 where minuten_osrm is null;

alter table anfahrtszeiten drop column if exists minuten;
alter table anfahrtszeiten drop column if exists distanz_km;
alter table anfahrtszeiten drop column if exists quelle;

alter table anfahrtszeiten
  add column minuten int generated always as (
    coalesce(minuten_google, minuten_osrm)
  ) stored,
  add column distanz_km numeric(6, 1) generated always as (
    coalesce(distanz_km_google, distanz_km_osrm)
  ) stored;

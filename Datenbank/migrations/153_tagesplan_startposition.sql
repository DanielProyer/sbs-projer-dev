-- 153: Tagesstart-Position am Tagesplan (Daniel 29.07.2026):
-- Der Arbeitstag beginnt nicht immer am festen Startort (Zuhause Domat/Ems),
-- sondern oft anderswo (Chur). Beim Druck auf «Arbeitsbeginn» auf dem
-- Startbildschirm wird die aktuelle GPS-Position miterfasst; Anfahrt und
-- Heimweg der Zeitachse rechnen dann von dort. Der feste Startort aus
-- geschaeft_einstellungen bleibt der Rueckfall ohne GPS-Erfassung.
alter table tagesplaene
  add column if not exists start_lat numeric,
  add column if not exists start_lng numeric;

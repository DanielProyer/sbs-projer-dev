-- 154: km-Stand bei Arbeitsbeginn + GPS-Position bei Arbeitsende
-- (Daniel 29.07.2026): km an BEIDEN Tagesraendern erfassen, damit die
-- Tages-km-Differenz nicht durch Privatfahrten verfaelscht wird; dazu die
-- End-Position - damit liegen alle Daten fuer spaetere Auswertungen vor.
-- km_stand (bestehend) bleibt der km-Stand am Abend.
alter table tagesplaene
  add column if not exists km_start int,
  add column if not exists end_lat numeric,
  add column if not exists end_lng numeric;

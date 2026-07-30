-- 158: Routing-Referenzwert je Betriebspaar (Daniel 30.07.2026)
--
-- Problem: 503 von 2807 beobachteten Fahrzeiten (18 %) sind unplausibel hoch —
-- im Schnitt 43 min zu viel. Ursache sind Störungen, Pausen oder Wartezeiten
-- zwischen zwei Reinigungen, die als «Fahrzeit» in die Lernkurve liefen.
--
-- Lösung ohne Mehraufwand bei der Erfassung: ein von der Beobachtung
-- UNABHÄNGIGER Routing-Wert je Paar. Beim Lernen wird die gemessene Lücke
-- gegen ihn geprüft; nur plausible Werte (0.5x–2x) werden übernommen.
--
-- Bewusst eigene Spalten statt `quelle`: Bisher überschrieb eine Beobachtung
-- den gerouteten Wert, womit die Referenz verloren ging.

alter table fahrzeiten
  add column if not exists referenz_minuten int check (referenz_minuten > 0),
  add column if not exists referenz_quelle text
    check (referenz_quelle in ('osrm', 'google'));

comment on column fahrzeiten.referenz_minuten is
  'Reine Routing-Fahrzeit (ohne Parkieren/Rüsten). Massstab für die '
  'Plausibilitätsprüfung beim Lernen — wird von Beobachtungen NIE überschrieben.';

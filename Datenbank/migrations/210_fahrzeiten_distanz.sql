-- 210: Distanz je Fahrzeit-Paar (Fahrtenerkennung Stufe 1, 27.09.2026).
-- `fahrzeiten` kannte nur Minuten; für «Fahrten aus der Kette» braucht es die
-- Strecke. Gefüllt von der Edge Function fahrzeit-route (OSRM), nachträglich
-- beim ersten Bedarf. Luftlinien-Rückfall rechnet die App selbst und speichert
-- ihn NICHT (er ist kein Messwert).
alter table fahrzeiten
  add column if not exists distanz_km numeric(6,1),
  add column if not exists distanz_quelle text
    check (distanz_quelle in ('osrm', 'google'));
comment on column fahrzeiten.distanz_km is 'Strecke in km (eine Nachkommastelle), Quelle siehe distanz_quelle';

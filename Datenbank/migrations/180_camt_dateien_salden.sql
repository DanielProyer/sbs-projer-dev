-- 180: Anfangs-/Schlusssaldo je camt-Datei speichern (01.09.2026)
--
-- Der Parser liest OPBD/CLBD schon immer — genutzt hat sie niemand. Ab jetzt
-- werden sie je Datei gespeichert, damit der Bank-Wächter jederzeit prüfen
-- kann: (a) Anschluss der neuen Datei ans Journal (Lückenlosigkeit),
-- (b) Journal-Saldo 1020 gegen den letzten Bank-Schlusssaldo (alles verbucht?).
-- Anlass: Daniels Sorge nach dem ersten Echtlauf, dass ein untertags
-- gezogener Export Zahlungen vom Morgen/Abend verlieren könnte — die
-- Saldokette der Bank beantwortet das deterministisch.

alter table camt_dateien
  add column if not exists anfangssaldo numeric,
  add column if not exists schlusssaldo numeric;

comment on column camt_dateien.anfangssaldo is 'OPBD aus der camt-Datei (Bank-Anfangssaldo des Zeitraums)';
comment on column camt_dateien.schlusssaldo is 'CLBD aus der camt-Datei (Bank-Schlusssaldo des Zeitraums)';

-- Nachtrag für die letzte Datei (Werte aus dem Export vom 01.09.2026, von
-- Claude aus der XML gelesen; ältere Dateien bleiben leer — der Wächter
-- behandelt fehlende Werte als «keine Aussage»).
update camt_dateien
set anfangssaldo = 15816.07, schlusssaldo = 23351.23
where dateiname like '%20260901_135705%' and anfangssaldo is null;

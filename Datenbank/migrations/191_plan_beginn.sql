-- 191: Plan-Arbeitsbeginn vom tatsächlichen trennen
--
-- PROBLEM: `tagesplaene.arbeitsbeginn` trug zwei verschiedene Bedeutungen.
-- Die Planungszeile im Tourenplan schreibt dort einen HYPOTHETISCHEN Beginn,
-- damit die Zeitachse rechnen kann; «Jetzt starten» auf der Startseite
-- schreibt den TATSÄCHLICHEN Beginn samt km-Stand und GPS. Die Arbeitstag-
-- Karte kann beide nicht unterscheiden:
--
--     final beginnErfasst = gespeichert?.arbeitsbeginn != null;
--
-- Folge: Steht ein Planwert drin, zeigt die Karte «ab HH:mm» und den Knopf
-- «Neu starten» statt «Jetzt starten» — der Tag sieht aus, als liefe er
-- schon, und die Tages-Kilometer bleiben falsch, wenn niemand drückt.
-- Aufgefallen am 14.09.2026 am Montagsplan (06:47 ohne km-Start), von Daniel
-- als Fehler benannt: «ich brauche einen hypothetischen Arbeitsbeginn für die
-- Planung, dies ist aber nicht der tatsächliche Arbeitsbeginn».
--
-- LÖSUNG: `plan_beginn` für die Planung, `arbeitsbeginn` bleibt der Ist-Wert.
-- Die Zeitachse rechnet mit `plan_beginn ?? arbeitsbeginn ?? 06:00`, die
-- Arbeitstag-Karte liest nur noch `arbeitsbeginn`.

alter table tagesplaene
  add column if not exists plan_beginn text;

comment on column tagesplaene.plan_beginn is
  'Hypothetischer Arbeitsbeginn für die Zeitachse (HH:mm). Gesetzt in der '
  'Planungszeile des Tourenplans. NICHT der tatsächliche Arbeitsbeginn — '
  'der steht in arbeitsbeginn und wird nur von «Jetzt starten» geschrieben.';

-- BESTANDSDATEN: Nach km-Start unterscheiden (Entscheid Daniel, 15.09.2026).
-- Ein Arbeitstag, der über «Jetzt starten» begonnen wurde, trägt immer einen
-- km-Stand; ein reiner Planwert nie. Geprüft vor der Migration: 28 Zeilen mit
-- arbeitsbeginn, davon 27 mit km_start (echte Arbeitsbeginne, bleiben) und
-- genau 1 ohne (der Plan für den 16.09.2026, 06:15 — wandert).
update tagesplaene
set plan_beginn = arbeitsbeginn,
    arbeitsbeginn = null
where arbeitsbeginn is not null
  and km_start is null;

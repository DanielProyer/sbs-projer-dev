-- 163: Planung und Zeiterfassung fuer Stoerungen und Montagen
-- Spec: docs/superpowers/specs/2026-07-31-einsatzplanung-sprache-design.md
--
-- Ausgangslage: Es gab genau EIN Datumsfeld (`datum`, im Code als Meldedatum
-- kommentiert). "Gemeldet am" und "geplant fuer" fielen zusammen, ein Termin
-- liess sich gar nicht ausdruecken. Ergebnis: Der Schalter "Erst geplant"
-- wurde seit v0.60.0 kein einziges Mal benutzt — alle 1108 Stoerungen stehen
-- auf 'behoben', alle 810 Montagen auf 'abgeschlossen'.
--
-- Neu drei getrennte Zeitbegriffe (Entscheid Daniel 31.07.2026):
--   gemeldet  -> wann der Anruf kam        (gemeldet_am)
--   geplant   -> wann ich hin will         (geplant_am + optional geplant_zeit)
--   gearbeitet-> wann ich dort war         (arbeit_von / arbeit_bis)

alter table public.stoerungen
  add column if not exists geplant_am date,
  add column if not exists geplant_zeit time,
  add column if not exists geplant_dauer_min int,
  add column if not exists arbeit_von time,
  add column if not exists arbeit_bis time,
  add column if not exists gemeldet_am timestamptz;

alter table public.montagen
  add column if not exists geplant_am date,
  add column if not exists geplant_zeit time,
  add column if not exists geplant_dauer_min int,
  add column if not exists arbeit_von time,
  add column if not exists arbeit_bis time;

create index if not exists stoerungen_geplant_am_idx on public.stoerungen (geplant_am);
create index if not exists montagen_geplant_am_idx on public.montagen (geplant_am);

comment on column public.stoerungen.geplant_am is
  'Zieltag des Einsatzes. NULL = noch nicht eingeplant (Rueckstand, bleibt '
  'in der Faellig-Liste sichtbar).';
comment on column public.stoerungen.geplant_zeit is
  'Fixer Termin. NULL = ganztaegig an diesem Tag (Entscheid Daniel 31.07.).';
comment on column public.stoerungen.arbeit_von is
  'Tatsaechlicher Arbeitsbeginn, gesetzt per "Beginn"-Knopf inkl. GPS-Wegpunkt. '
  'Speist NICHT die generierte Spalte dauer_minuten (die haengt an '
  'uhrzeit_start/uhrzeit_ende) und aendert keine Abrechnung — Stoerungen '
  'werden ueber Pauschalen abgerechnet, Montagen ueber dauer_stunden.';
comment on column public.stoerungen.gemeldet_am is
  'Wann der Anruf kam. Beim Erfassen mit "jetzt" vorbelegt. Uebernommen aus '
  'dem alten Freitextfeld uhrzeit_start ("Stoerungseingang") — dessen 109 '
  'Altwerte sind uneinheitlich belegt (am 30.07. tragen zwei verschiedene '
  'Stoerungen dieselbe Zeit 11:43, das ist eher die Erfassungszeit), also '
  'nur ein Anhaltspunkt, keine belastbare Reaktionszeit-Grundlage.';
comment on column public.montagen.geplant_zeit is
  'Fixer Termin. NULL = ganztaegig an diesem Tag.';

-- ── Altwerte sichern und umziehen ──────────────────────────────────────
create schema if not exists import;

create table if not exists import.stoerung_uhrzeit_start_vor_163 as
  select id, datum, uhrzeit_start
  from public.stoerungen
  where uhrzeit_start is not null;

update public.stoerungen
set gemeldet_am = (datum + uhrzeit_start)::timestamptz
where uhrzeit_start is not null and gemeldet_am is null;

-- ── Verwaiste Termin-Vorschlaege entfernen ─────────────────────────────
-- Die Tabelle `termine` traegt 219 Zeilen aus einem frueheren Anlauf
-- (135 Endreinigungen, 84 Eroeffnungsreinigungen, alle Status
-- 'vorgeschlagen', zuletzt 11.07.2026). Im Flutter-Code greift NICHTS
-- darauf zu — die Saison-Logik rechnet die Vorschlaege stattdessen bei
-- jedem Aufruf neu (autoTermineProvider).
--
-- Bedingung Daniel ("nur wenn wir keine Daten verlieren") wurde geprueft:
-- 0 Notizen, 0 Uhrzeiten, 0 abweichende Status, 0 aktive Erinnerungen.
-- Titel und Anlass sind bei ALLEN 219 gesetzt, also systematisch erzeugt
-- und aus Betrieb + Saisondaten jederzeit wieder herstellbar.
-- Vollstaendige Kopie bleibt trotzdem erhalten.
create table if not exists import.termine_vor_loeschung_2026_07_31 as
  select * from public.termine;

delete from public.termine where status = 'vorgeschlagen';

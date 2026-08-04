-- 165: "übergeben" und "versendet" bei Rechnungen trennen
-- Anlass Daniel 02.08.2026: Rechnung Seven Alpina 2026-07-1267 wurde am
-- Tresen uebergeben; der Kunde wuenscht sie zusaetzlich per Mail. Beim
-- Mailversand wuerde `versendet_am` ueberschrieben — der Zeitpunkt der
-- Uebergabe waere verloren, und niemand koennte spaeter nachvollziehen,
-- dass der Kunde die Rechnung zweimal bekommen hat.
--
-- Neu: `uebergeben_am` haelt die persoenliche Uebergabe am Tresen fest,
-- `versendet_am` bleibt dem echten Versand (Mail, Post) vorbehalten.
-- Beide koennen nebeneinander stehen — genau das ist der Fall Seven Alpina.

alter table public.rechnungen
  add column if not exists uebergeben_am date;

comment on column public.rechnungen.uebergeben_am is
  'Persoenliche Uebergabe am Tresen. Unabhaengig von versendet_am — eine '
  'uebergebene Rechnung kann spaeter zusaetzlich per Mail verschickt werden.';
comment on column public.rechnungen.versendet_am is
  'Echter Versand per Mail oder Post. NICHT fuer die Tresen-Uebergabe, '
  'dafuer gibt es uebergeben_am (Migration 165).';

-- Altbestand sichern.
create schema if not exists import;
create table if not exists import.rechnungen_versendet_vor_165 as
  select id, rechnungsnummer, versandart, versendet_am
  from public.rechnungen
  where versendet_am is not null;

-- Bei Tresen-Rechnungen war `versendet_am` in Wahrheit die Uebergabe:
-- umziehen und das Versandfeld leeren, denn verschickt wurde nie etwas.
-- Betrifft 37 Zeilen (Stand 02.08.2026). Mail- und Post-Rechnungen bleiben
-- unberuehrt — dort ist versendet_am korrekt belegt.
update public.rechnungen
set uebergeben_am = versendet_am::date,
    versendet_am = null
where versandart = 'rechnung_tresen' and versendet_am is not null;

-- 159: Pausen im Arbeitstag (Daniel 30.07.2026)
--
-- Bisher liess sich nur Beginn und Ende erfassen. Zwischen zwei Besuchen
-- gemachte Pausen (am 30.07. z.B. 25 min zwischen Migros Golfpark und
-- Restaurant Linden) verschwanden damit in der Arbeitszeit — und in der
-- Fahrzeit-Lücke, wo sie die Lernkurve verdarben.
--
-- `pause_minuten` ist die Tagessumme (mehrere Pausen addieren sich),
-- `pause_start` hält eine LAUFENDE Pause fest, damit der Knopf über einen
-- App-Neustart hinweg weiss, dass die Pause noch läuft.

alter table tagesplaene
  add column if not exists pause_minuten int
    check (pause_minuten is null or pause_minuten >= 0),
  add column if not exists pause_start text;

comment on column tagesplaene.pause_minuten is
  'Summe aller Pausen des Tages in Minuten (Netto-Arbeitszeit = Ende - Beginn - Pause).';
comment on column tagesplaene.pause_start is
  'HH:mm einer noch LAUFENDEN Pause; null = keine Pause aktiv.';

-- Pausen-Stempel im Wegpunkt-Strom zulassen (Zeit + GPS + Kontext).
alter table wegpunkte drop constraint if exists wegpunkte_quelle_check;
alter table wegpunkte add constraint wegpunkte_quelle_check
  check (quelle in (
    'reinigung', 'stoerung', 'montage',
    'arbeitsbeginn', 'feierabend',
    'pause_start', 'pause_ende'
  ));

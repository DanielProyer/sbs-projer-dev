-- 130: Mehrere Erinnerungen pro Termin als jsonb-Array [{methode,minuten}]
alter table public.termine
  add column if not exists erinnerungen jsonb not null default '[]'::jsonb;

-- Backfill aus den bisherigen Einzelfeldern
update public.termine
set erinnerungen = jsonb_build_array(
      jsonb_build_object('methode', 'popup', 'minuten', erinnerung_vorlauf_minuten))
where erinnerung_aktiv = true
  and erinnerungen = '[]'::jsonb;

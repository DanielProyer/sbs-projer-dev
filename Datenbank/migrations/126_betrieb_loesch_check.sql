-- 126: Prüffunktion für das Löschen eines Betriebs.
-- Gibt die verknüpften Datensätze (nach Kategorie) zurück, die einem Löschen
-- im Weg stehen. Leeres Objekt {} = Betrieb ist löschbar.
-- Wird von der App vor dem Löschen aufgerufen ("nur wenn leer löschbar").
-- SECURITY INVOKER (Default): RLS greift, es werden nur eigene Daten gezählt.

create or replace function public.betrieb_loesch_hindernisse(p_betrieb_id uuid)
returns jsonb
language sql
stable
set search_path = public
as $$
  select coalesce(
    jsonb_object_agg(kategorie, anzahl) filter (where anzahl > 0),
    '{}'::jsonb
  )
  from (
    select 'Anlagen'               as kategorie, count(*) as anzahl from anlagen                 where betrieb_id = p_betrieb_id
    union all select 'Reinigungen',            count(*) from reinigungen              where betrieb_id = p_betrieb_id
    union all select 'Störungen',              count(*) from stoerungen               where betrieb_id = p_betrieb_id
    union all select 'Termine',                count(*) from termine                  where betrieb_id = p_betrieb_id
    union all select 'Montagen',               count(*) from montagen                 where betrieb_id = p_betrieb_id
    union all select 'Eigenaufträge',          count(*) from eigenauftraege           where betrieb_id = p_betrieb_id
    union all select 'Eröffnungsreinigungen',  count(*) from eroeffnungsreinigungen   where betrieb_id = p_betrieb_id
    union all select 'Rechnungen',             count(*) from rechnungen               where betrieb_id = p_betrieb_id
    union all select 'Bergkundenpauschalen',   count(*) from bergkundenpauschalen     where betrieb_id = p_betrieb_id
    union all select 'Events',                 count(*) from events                   where betrieb_id = p_betrieb_id
    union all select 'Kontakte',               count(*) from kontakte                 where betrieb_id = p_betrieb_id
    union all select 'Rechnungsadressen',      count(*) from betrieb_rechnungsadressen where betrieb_id = p_betrieb_id
  ) t;
$$;

grant execute on function public.betrieb_loesch_hindernisse(uuid) to authenticated, anon;

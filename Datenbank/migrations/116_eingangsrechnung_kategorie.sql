-- Migration 116: Eingangsrechnung-Kategorien (Config-Tabelle, global wie konten).
-- Per mcp__supabase__apply_migration auf PROD (pltbaqqwpnmdajwgnhpd) angewendet.
-- Inhaltsbasierte Kategorie pro Dokument (Rechnung + Info); Kategorie→Konto-Default.

create table if not exists public.eingangsrechnung_kategorie (
  code text primary key,
  bezeichnung text not null,
  default_aufwandskonto int,
  default_vorsteuer_konto int,
  reihenfolge int not null default 0,
  ist_aktiv boolean not null default true
);

alter table public.eingangsrechnung add column if not exists kategorie text;

insert into public.eingangsrechnung_kategorie
  (code, bezeichnung, default_aufwandskonto, default_vorsteuer_konto, reihenfolge) values
 ('versicherung','Versicherung',6300,null,10),
 ('sozialversicherung','Sozialversicherung',null,null,20),
 ('unfall_krankheit','Unfall & Krankheit',null,null,30),
 ('steuern','Steuern & MwSt',null,null,40),
 ('busse','Busse',6280,null,50),
 ('fahrzeug','Fahrzeug',6250,1171,60),
 ('telekom_it','Telekom & IT',6510,1171,70),
 ('franchise','Franchise',6301,1170,80),
 ('miete_raum','Miete & Raum',6000,null,90),
 ('entsorgung_gemeinde','Entsorgung & Gemeinde',6460,1171,100),
 ('material_werkzeug','Material & Werkzeug',4004,1170,110),
 ('treuhand_beratung','Treuhand & Beratung',6530,1171,120),
 ('lohn_personal','Lohn & Personal',null,null,130),
 ('behoerde_amtliches','Behörde & Amtliches',null,null,140),
 ('sonstiges','Sonstiges',null,null,150)
on conflict (code) do nothing;

alter table public.eingangsrechnung_kategorie enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where tablename='eingangsrechnung_kategorie' and policyname='kategorie_read') then
    create policy kategorie_read on public.eingangsrechnung_kategorie for select to authenticated using (true);
  end if;
end $$;

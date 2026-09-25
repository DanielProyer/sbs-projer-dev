-- 205: Verrechnetes Kundenguthaben auf der Rechnung (25.09.2026)
alter table rechnungen add column if not exists guthaben_verrechnet numeric(10,2) not null default 0
  check (guthaben_verrechnet >= 0);
comment on column rechnungen.guthaben_verrechnet is
  'Aus Konto 2030 verrechnetes Kundenguthaben; zu zahlen = betrag_brutto - guthaben_verrechnet';

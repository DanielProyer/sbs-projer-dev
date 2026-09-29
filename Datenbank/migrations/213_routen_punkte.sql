-- 213: Cache für geroutete Strecken zwischen beliebigen Punkten (29.09.2026).
-- fahrzeiten kennt nur Betrieb→Betrieb (FK). Die Fahrten-Auswertung braucht
-- auch GPS-Position↔Betrieb, Startort↔Startort und Startort↔Betrieb ohne
-- Google-Anfahrt. Schlüssel: 'b:<betrieb uuid>' oder 'p:<lat>,<lng>' mit
-- vier Nachkommastellen (≈ 11 m) — gleiche Rundung in App und Function.
--
-- Gefüllt NUR von der Edge Function fahrzeit-route (Service-Role, OSRM),
-- gelesen von der App (FahrzeitRepository.ladePunktRouten). Bewusst eigene
-- Tabelle statt Pseudo-Betriebe in fahrzeiten: Dort sind beide Seiten echte
-- Betriebe mit FK, und die Minuten dort lernen aus Beobachtungen (Tourenplan)
-- — ein GPS-Punkt kehrt kaum je genau wieder, da gibt es nichts zu lernen.
-- Schlüssel in der App: lib/core/util/routen_punkt_key.dart, in der Function:
-- supabase/functions/fahrzeit-route/keys.ts.
create table if not exists routen_punkte (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  von_key text not null,
  nach_key text not null,
  distanz_km numeric(6, 1) not null,
  minuten int not null check (minuten > 0),
  quelle text not null default 'osrm' check (quelle in ('osrm')),
  created_at timestamptz not null default now(),
  unique (user_id, von_key, nach_key)
);
alter table routen_punkte enable row level security;
create policy "routen_punkte_eigene" on routen_punkte
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create index if not exists idx_routen_punkte_user on routen_punkte (user_id);
comment on table routen_punkte is
  'Geroutete Strecken (OSRM) mit mindestens einem Ende, das kein Betrieb ist; Schlüssel b:<uuid> / p:<lat>,<lng> (4 Nachkommastellen)';

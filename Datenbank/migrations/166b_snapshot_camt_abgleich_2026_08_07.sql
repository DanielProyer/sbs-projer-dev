-- 166b: Sicherungs-Snapshot vor dem ersten camt-Kundenzahlungs-Abgleich
-- (Server 07.08.2026, Name: snapshot_camt_abgleich_2026_08_07).
-- Rekonstruiert am 26.09.2026 aus supabase_migrations.schema_migrations —
-- damals direkt angewendet, ohne lokale Datei.

-- Eigenes Schema: nicht über die PostgREST-API erreichbar (nur `public` ist
-- exponiert) — kein RLS-Leck wie bei den _bak_-Tabellen im Juli.
-- Stand bei Erstellung: 0 Buchungen mit camt_tx_key → JEDE spätere Buchung
-- mit camt_tx_key stammt aus dem Abgleich und ist per Skript rückrollbar.
CREATE SCHEMA IF NOT EXISTS snapshot_camt_abgleich;

CREATE TABLE snapshot_camt_abgleich.rechnungen_vorher AS
SELECT id, rechnungsnummer, zahlungsstatus, zahlung_eingegangen_am,
       zahlung_betrag, now() AS snapshot_am
FROM public.rechnungen;

CREATE TABLE snapshot_camt_abgleich.pruefliste_vorher AS
SELECT *, now() AS snapshot_am FROM public.camt_pruefliste;

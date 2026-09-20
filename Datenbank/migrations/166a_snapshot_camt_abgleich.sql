-- 166a: Sicherungs-Snapshot vor dem ersten camt-Kundenzahlungs-Abgleich
--
-- NACHGETRAGEN am 20.09.2026. Angewendet war sie am 07.08.2026, 20:07 —
-- direkt über `apply_migration`, ohne lokale Datei (Server-Version
-- 20260807200738 `snapshot_camt_abgleich_2026_08_07`). Einsortiert als 166a:
-- zeitlich nach 166 (16:37) und vor 166b (betriebe_service_hinweis, 21:58).
--
-- Wortlaut aus `supabase_migrations.schema_migrations.statements`.
-- GEGENGEPRÜFT am 20.09.2026: Das Schema `snapshot_camt_abgleich` existiert
-- mit `rechnungen_vorher` (6 Spalten) und `pruefliste_vorher` (17 Spalten).
-- Dazu kamen später von Hand `rueckgaengig_2026_09_01_buchungen` und
-- `rueckgaengig_2026_09_01_rechnungen` — die gehören NICHT zu dieser
-- Migration.
--
-- ⚠️ EINMAL-OPERATION, NICHT WIEDERHOLEN. `CREATE TABLE … AS SELECT` würde
-- bei einem zweiten Lauf am bestehenden Objekt scheitern; schlimmer wäre ein
-- Lauf nach einem DROP: Der Snapshot hielte dann den HEUTIGEN Stand fest und
-- der Rückweg zum 07.08.2026 wäre unwiederbringlich verloren. Bei einem
-- Neuaufbau der Datenbank hat diese Datei keinen Zweck.
--
-- ---------------------------------------------------------------------------
-- Original-Begründung vom 07.08.2026:
--
-- Sicherungs-Snapshot VOR dem ersten camt-Kundenzahlungs-Abgleich (07.08.2026).
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

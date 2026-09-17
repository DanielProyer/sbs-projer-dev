-- 166b: Service-Hinweis pro Betrieb (07.08.2026)
--
-- Wird beim Reinigungs-Abschluss prominent angezeigt (z. B. «Nächste
-- Reinigung GRATIS — Kulanz»). Wunsch Daniel 07.08.2026, Anlass war der
-- Fall Chleina Pub (Doppelzahlung 74.60).
--
-- NACHTRAG 17.09.2026: Diese Datei fehlte in der Ablage; die Migration war
-- am 07.08. direkt über `apply_migration` eingespielt worden. Der Inhalt ist
-- der Wortlaut aus `supabase_migrations.schema_migrations`
-- (version 20260807215834). Die Nummer 166b sortiert sie zwischen
-- 166_mwst_view_storno_gegenbuchungen (07.08. nachmittags) und
-- 167_rechnungsadresse_felder (10.08.) ein. Auf der Datenbank ist sie
-- bereits angewendet.
--
-- ⚠️ NICHT BLIND ERNEUT AUSFÜHREN: Der ALTER TABLE ist harmlos
-- (IF NOT EXISTS), das UPDATE dagegen setzt einen Einmal-Hinweis auf einen
-- konkreten Betrieb. Wer die Datei nochmals laufen lässt, schreibt den
-- Kulanz-Vermerk zurück, auch wenn er inzwischen erledigt und entfernt ist.
-- Für einen Neuaufbau der Datenbank nur den ALTER TABLE übernehmen.

ALTER TABLE betriebe ADD COLUMN IF NOT EXISTS service_hinweis text;

-- Einmal-Datenfix vom 07.08.2026 (Chleina Pub, Schiers) — siehe Warnung oben.
UPDATE betriebe SET service_hinweis =
  'Nächste Reinigung GRATIS (Kulanz) — Kundin hat die April-Rechnung doppelt bezahlt (74.60 am 30.04.2026).'
WHERE id = '9b3474f4-5166-4850-be63-658307c66a6e';

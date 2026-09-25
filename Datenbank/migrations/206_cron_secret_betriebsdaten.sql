-- 206: Nacht-Cron betriebsdaten-abgleich mit Cron-Secret (Analyse 25.09.2026, R11)
--
-- Bisher (Migration 162) schickte der Cron NUR `Content-Type` — kein
-- Authorization-Header, kein Secret. Das ging nur, weil die Function mit
-- --no-verify-jwt deployed war und niemanden prüfte (öffentlich auslösbar,
-- `limit` ohne Obergrenze). Ab dem Deploy vom 25.09.2026 gilt:
--   * Gateway: verify_jwt = true  -> braucht ein gültiges JWT (Anon-Key)
--   * Function: x-cron-secret == Edge-Secret CRON_SECRET
-- Ohne diese Migration läuft der Cron nach dem Deploy mit 401 ins Leere.
--
-- VORAUSSETZUNG (von Hand, NICHT hier — Secrets gehören nicht ins Repo):
--   1. Zufallswert erzeugen (mind. 16 Zeichen, z.B. 32 Byte hex).
--   2. Edge-Secret setzen:  supabase secrets set CRON_SECRET=<wert>
--   3. Denselben Wert und den Anon-Key im Vault ablegen (SQL-Editor):
--        select vault.create_secret('<wert>', 'cron_secret');
--        select vault.create_secret('<anon-key>', 'anon_key');
-- Reihenfolge beim Einspielen: Secrets (1-3) -> Functions deployen -> diese
-- Migration. Die Migration bricht ab, wenn die Vault-Einträge fehlen.

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM vault.decrypted_secrets WHERE name = 'cron_secret') THEN
    RAISE EXCEPTION 'Vault-Secret cron_secret fehlt — zuerst vault.create_secret(...) ausführen';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM vault.decrypted_secrets WHERE name = 'anon_key') THEN
    RAISE EXCEPTION 'Vault-Secret anon_key fehlt — zuerst vault.create_secret(...) ausführen';
  END IF;
END $$;

SELECT cron.unschedule('betriebsdaten-abgleich')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'betriebsdaten-abgleich');

-- Die Secrets werden bei JEDEM Lauf aus dem Vault gelesen (nicht beim
-- Anlegen eingesetzt) — so steht kein Klartext in cron.job.command, und ein
-- neu rotierter Wert gilt ab dem nächsten Lauf.
SELECT cron.schedule(
  'betriebsdaten-abgleich',
  '20 3 * * *',   -- 03:20 UTC = 05:20 Sommerzeit, unverändert
  $$
  SELECT net.http_post(
    url := 'https://pltbaqqwpnmdajwgnhpd.supabase.co/functions/v1/betriebsdaten-abgleich',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'anon_key'),
      'apikey', (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'anon_key'),
      'x-cron-secret', (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'cron_secret')
    ),
    body := '{"limit":10}'::jsonb,
    timeout_milliseconds := 300000
  );
  $$
);

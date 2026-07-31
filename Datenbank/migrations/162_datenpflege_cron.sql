-- 162: Taeglicher Betriebsdaten-Abgleich (Google + Website)
-- Spec: docs/superpowers/specs/2026-07-31-betriebsdaten-aktuell-halten-design.md
--
-- Zehn Betriebe pro Nacht, aelteste Pruefung zuerst. Bei 294 aktiven
-- Betrieben ist der Bestand damit in rund vier Wochen einmal durch — ohne
-- Lastspitze bei Google und Anthropic und ohne Kostenrisiko.
-- Die Edge-Function fragt je Betrieb BEIDE Quellen ab (Entscheid Daniel
-- 31.07.2026) und legt Abweichungen als Vorschlaege ab. Sie schreibt NIE
-- direkt in die Stammdaten.

CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Falls der Job schon existiert (erneutes Ausfuehren der Migration).
SELECT cron.unschedule('betriebsdaten-abgleich')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'betriebsdaten-abgleich');

SELECT cron.schedule(
  'betriebsdaten-abgleich',
  '20 3 * * *',   -- 03:20 UTC = 05:20 Sommerzeit, lange vor Arbeitsbeginn
  $$
  SELECT net.http_post(
    url := 'https://pltbaqqwpnmdajwgnhpd.supabase.co/functions/v1/betriebsdaten-abgleich',
    headers := '{"Content-Type":"application/json"}'::jsonb,
    body := '{"limit":10}'::jsonb,
    timeout_milliseconds := 300000
  );
  $$
);

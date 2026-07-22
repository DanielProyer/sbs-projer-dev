-- 148: Google-Kontakte-Sync (Spec 2026-07-21) — Status-Felder
-- scope wird in die App-lesbare Status-Tabelle gespiegelt, weil
-- google_calendar_tokens bewusst nur fuer die Service-Role lesbar ist
-- (Refresh-Tokens!).
--
-- Hinweis zur Historie: Die urspruengliche Fassung droppte hier auch
-- kontakte.phone_contact_id/phone_last_synced_at. Das war verfrueht — die
-- LIVE-Version schrieb die Spalten noch (alter nativer Handy-Sync via
-- flutter_contacts). Spalten wurden am 22.07. wiederhergestellt; der Drop
-- erfolgt in Migration 149 ERST NACH dem Deploy von v0.52.0.
ALTER TABLE public.google_calendar_status
  ADD COLUMN IF NOT EXISTS scope text,
  ADD COLUMN IF NOT EXISTS contacts_last_sync_at timestamptz,
  ADD COLUMN IF NOT EXISTS contacts_last_sync_info text;
UPDATE public.google_calendar_status s SET scope = t.scope
  FROM public.google_calendar_tokens t WHERE t.user_id = s.user_id;

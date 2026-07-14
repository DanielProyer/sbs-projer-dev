-- 138: Zeitstempel des letzten automatischen Kalender-Vollabgleichs.
-- Wird von der Edge Function `google-calendar-sync` (Aktion reconcile) gesetzt
-- und dient (a) der App als Trigger für den täglichen Auto-Sync, (b) der
-- Anzeige "zuletzt abgeglichen" in den Einstellungen.
ALTER TABLE google_calendar_status
  ADD COLUMN IF NOT EXISTS last_sync_at timestamptz;

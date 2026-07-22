-- 149: phone_contact-Spalten endgueltig entfernen (22.07.2026)
-- Voraussetzung erfuellt: v0.52.x live (schreibt die Spalten nicht mehr),
-- Abnahme Google-Kontakte-Sync durch Daniel bestaetigt. Der alte native
-- Handy-Sync (flutter_contacts) wurde mit GK-1 aus dem Code entfernt.
ALTER TABLE public.kontakte
  DROP COLUMN IF EXISTS phone_contact_id,
  DROP COLUMN IF EXISTS phone_last_synced_at;

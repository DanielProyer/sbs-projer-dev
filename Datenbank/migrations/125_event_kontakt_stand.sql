-- ============================================================
-- Migration 125: event_kontakte — optionale Stand-Zuordnung
-- Projekt: SBS Projer App · Stand: 10.07.2026
-- ============================================================
ALTER TABLE event_kontakte
  ADD COLUMN IF NOT EXISTS stand_id uuid REFERENCES event_staende(id) ON DELETE SET NULL;

-- ============================================================
-- Migration 118: Betriebsferien 4+5 (Erweiterung von 3 auf 5 Slots)
-- Projekt: SBS Projer App
-- Stand: 07.07.2026
-- ============================================================

ALTER TABLE betriebe
  ADD COLUMN IF NOT EXISTS ferien4_start date,
  ADD COLUMN IF NOT EXISTS ferien4_ende date,
  ADD COLUMN IF NOT EXISTS ferien5_start date,
  ADD COLUMN IF NOT EXISTS ferien5_ende date;

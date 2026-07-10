-- ============================================================
-- Migration 124: event_einsaetze — Material-Verknüpfung (Lager)
-- Projekt: SBS Projer App · Stand: 10.07.2026
-- ============================================================
ALTER TABLE event_einsaetze
  ADD COLUMN IF NOT EXISTS material_id uuid,
  ADD COLUMN IF NOT EXISTS material_menge numeric;

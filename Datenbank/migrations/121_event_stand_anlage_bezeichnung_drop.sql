-- ============================================================
-- Migration 121: Spalte bezeichnung aus event_stand_anlagen entfernen
-- Projekt: SBS Projer App
-- Stand: 10.07.2026
-- Grund: Bezeichnung bei Schankanlagen nicht benötigt (User-Feedback).
--        Spalte war in Migration 120 (E2) angelegt, praktisch ohne Daten.
-- ============================================================

ALTER TABLE event_stand_anlagen DROP COLUMN IF EXISTS bezeichnung;

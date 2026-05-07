-- ============================================================
-- Migration 075: Kontakt-Rolle «Vertreter» für Heineken
-- Projekt: SBS Projer App
-- Stand: 07.05.2026
-- ============================================================

ALTER TABLE kontakte DROP CONSTRAINT IF EXISTS kontakte_rolle_check;
ALTER TABLE kontakte ADD CONSTRAINT kontakte_rolle_check
  CHECK (rolle IN (
    'geschaeftsfuehrer', 'fb_manager', 'mitarbeiter', 'hauswart', 'sonstige',
    'rsl', 'vertreter', 'buero', 'monteur', 'event_heineken', 'pikett',
    'ok', 'bau', 'stand'
  ));

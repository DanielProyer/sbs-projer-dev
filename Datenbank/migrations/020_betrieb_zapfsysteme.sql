-- Migration 020: Zapfsysteme Mehrfachauswahl für Betriebe
-- Betriebe können verschiedene Zapfsysteme haben: David, Konventionell, Higenie, Orion

ALTER TABLE betriebe ADD COLUMN zapfsysteme text[] DEFAULT '{}';

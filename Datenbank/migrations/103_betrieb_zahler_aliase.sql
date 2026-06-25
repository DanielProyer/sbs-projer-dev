-- Migration 103: Zahlernamen-Aliase für Betriebe (TP-B Zahler→Betrieb-Lernen)
-- Speichert je Betrieb die (normalisierten) Bank-Zahlernamen, unter denen er zahlt.
-- Wird beim camt-Forderungsabgleich gelernt (manuelle Zuordnung) und als
-- deterministische Matching-Stufe vor dem unscharfen Namensvergleich angewandt.
ALTER TABLE betriebe ADD COLUMN IF NOT EXISTS zahler_aliase text[] NOT NULL DEFAULT '{}';

-- Migration 043: Kulanz und Heineken-Monteur Felder für Reinigungen
ALTER TABLE reinigungen ADD COLUMN IF NOT EXISTS ist_kulanz BOOLEAN DEFAULT FALSE;
ALTER TABLE reinigungen ADD COLUMN IF NOT EXISTS ist_heineken_monteur BOOLEAN DEFAULT FALSE;

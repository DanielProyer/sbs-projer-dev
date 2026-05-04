-- Migration 034: Biersorte "Eichhof" → "Eichhof Lager" umbenennen
-- Datum: 2026-03-29

UPDATE bierleitungen
SET biersorte = 'Eichhof Lager'
WHERE biersorte ILIKE '%eichhof%'
  AND biersorte NOT ILIKE '%hubertus%';

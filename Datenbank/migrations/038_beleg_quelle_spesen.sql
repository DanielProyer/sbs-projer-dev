-- Migration 038: beleg_quelle um 'spesen_scan' erweitern
-- Ermöglicht Belege die via Spesen-Scanner OCR erfasst wurden

ALTER TABLE buchungs_belege DROP CONSTRAINT IF EXISTS buchungs_belege_beleg_quelle_check;
ALTER TABLE buchungs_belege ADD CONSTRAINT buchungs_belege_beleg_quelle_check
  CHECK (beleg_quelle IN ('manuell', 'camt053', 'rechnung', 'spesen_scan'));

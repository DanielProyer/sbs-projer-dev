-- Migration 079: Pikett-Pauschale anpassen (Formulare ab 1.1.2025)
-- Pikettbereitschaft KW: 160 → 80 (neu: pro Einsatz FR-SA, nicht pro Woche)
-- Pikett Feiertag: bleibt 80 (unverändert)
-- Bergkunde-Preise bleiben unverändert (130, 130, 165, 120, 120)

UPDATE preise
SET
  pikett_pauschale = 80.00,
  updated_at = now()
WHERE user_id = '1e1ec2dd-7836-4d8e-8256-c5649d994ee2';

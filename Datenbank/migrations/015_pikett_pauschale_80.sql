-- Pikett-Pauschale von 160 auf 80 CHF (kein Sonntag mehr)
ALTER TABLE preise ALTER COLUMN pikett_pauschale SET DEFAULT 80.00;
UPDATE preise SET pikett_pauschale = 80.00 WHERE pikett_pauschale = 160.00;

ALTER TABLE pikett_dienste ALTER COLUMN pauschale SET DEFAULT 80.00;

-- 127: Betrieb-Lifecycle
-- (1) Schliessungs-Doku fuer dauerhaft geschlossene Betriebe
-- (2) Bereinigung "mein Kunde": Saison != inaktiv

-- Spalten
ALTER TABLE betriebe ADD COLUMN IF NOT EXISTS schliessungsgrund text;
ALTER TABLE betriebe ADD COLUMN IF NOT EXISTS schliessungsdatum date;

-- (a) Fehl-eingeordnete Saisonbetriebe zurueck auf aktiv (bleiben Kunde)
UPDATE betriebe SET status = 'aktiv'
WHERE status = 'inaktiv' AND ist_saisonbetrieb = true;

-- (b) Echte inaktive + geschlossene -> mein Kunde false; Saisonbetriebe geschuetzt
UPDATE betriebe SET ist_mein_kunde = false
WHERE status IN ('inaktiv', 'geschlossen')
  AND ist_saisonbetrieb = false
  AND ist_mein_kunde = true;

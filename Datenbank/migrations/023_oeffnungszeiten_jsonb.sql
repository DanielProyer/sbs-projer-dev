-- Migration 023: Öffnungszeiten pro Wochentag als JSONB
-- Ersetzt: oeffnung_morgen_von, oeffnung_morgen_bis, oeffnung_nachmittag_von, oeffnung_nachmittag_bis
-- Neu: oeffnungszeiten JSONB mit Struktur {"Mo": [{"von":"HH:mm","bis":"HH:mm"}, ...], ...}

-- 1) Neue Spalte hinzufügen
ALTER TABLE betriebe ADD COLUMN IF NOT EXISTS oeffnungszeiten JSONB DEFAULT '{}';

-- 2) Bestehende Daten migrieren (gleiche Zeiten für alle Tage)
UPDATE betriebe SET oeffnungszeiten = (
  SELECT jsonb_object_agg(tag, slots) FROM (
    SELECT unnest(ARRAY['Mo','Di','Mi','Do','Fr','Sa','So']) AS tag,
      CASE
        WHEN oeffnung_morgen_von IS NOT NULL AND oeffnung_nachmittag_von IS NOT NULL THEN
          jsonb_build_array(
            jsonb_build_object('von', oeffnung_morgen_von, 'bis', oeffnung_morgen_bis),
            jsonb_build_object('von', oeffnung_nachmittag_von, 'bis', oeffnung_nachmittag_bis))
        WHEN oeffnung_morgen_von IS NOT NULL THEN
          jsonb_build_array(jsonb_build_object('von', oeffnung_morgen_von, 'bis', oeffnung_morgen_bis))
        ELSE '[]'::jsonb
      END AS slots
  ) sub
) WHERE oeffnung_morgen_von IS NOT NULL OR oeffnung_nachmittag_von IS NOT NULL;

-- 3) Alte Spalten entfernen
ALTER TABLE betriebe DROP COLUMN IF EXISTS oeffnung_morgen_von;
ALTER TABLE betriebe DROP COLUMN IF EXISTS oeffnung_morgen_bis;
ALTER TABLE betriebe DROP COLUMN IF EXISTS oeffnung_nachmittag_von;
ALTER TABLE betriebe DROP COLUMN IF EXISTS oeffnung_nachmittag_bis;

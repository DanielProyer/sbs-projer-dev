-- ============================================================
-- Migration 175: montagen.material_N_id von uuid auf text
-- Stand: 15.08.2026 (Feldfund Daniel, Churerfest-Abrechnung blockiert)
--
-- Der Anlass-Montage-Fluss («Montage generieren» aus dem Event) schreibt
-- SEIT JEHER Freitext-Tageszeilen in material_1_id..5 (Code-Kommentar im
-- Formular: «Bei Anlass ist die material_id der Freitext») — die Spalten
-- waren aber uuid-typisiert. PostgREST lehnte jeden Anlass-Speichervorgang
-- mit 22P02 ab; DB-Befund: 0 Anlass-Montagen mit befüllten Material-Feldern
-- — es hat also nie funktioniert, bisherige Event-Abrechnungen liefen ohne
-- die Detailzeilen.
--
-- Fix: Spalten auf text; die 7 FKs auf lager(id) entfallen (Lager kennt nur
-- Soft-Delete, Namensauflösung ist app-seitig). Der Bestands-Trigger
-- sync_montage_material wird text-tauglich: Anlass bucht keinen Verbrauch,
-- valide UUIDs buchen wie bisher (jsonb-Schleife statt 7 Copy-Paste-Blöcke).
--
-- Verifiziert 15.08. in Rollback-Transaktion: Anlass-Freitext speichert,
-- Neumontage mit Lager-UUID bucht material_verbrauch (1 Zeile).
--
-- ⚠️ Folge-Härtung App: _loadMaterialNames (heineken_rechnung_service) darf
-- nur valide UUIDs in den lager-Lookup geben (sonst 22P02 im Monatslauf).
-- ============================================================

DROP TRIGGER montage_material_sync ON montagen;

ALTER TABLE montagen DROP CONSTRAINT montagen_material_1_id_fkey;
ALTER TABLE montagen DROP CONSTRAINT montagen_material_2_id_fkey;
ALTER TABLE montagen DROP CONSTRAINT montagen_material_3_id_fkey;
ALTER TABLE montagen DROP CONSTRAINT montagen_material_4_id_fkey;
ALTER TABLE montagen DROP CONSTRAINT montagen_material_5_id_fkey;
ALTER TABLE montagen DROP CONSTRAINT montagen_material_6_id_fkey;
ALTER TABLE montagen DROP CONSTRAINT montagen_material_7_id_fkey;

ALTER TABLE montagen ALTER COLUMN material_1_id TYPE text USING material_1_id::text;
ALTER TABLE montagen ALTER COLUMN material_2_id TYPE text USING material_2_id::text;
ALTER TABLE montagen ALTER COLUMN material_3_id TYPE text USING material_3_id::text;
ALTER TABLE montagen ALTER COLUMN material_4_id TYPE text USING material_4_id::text;
ALTER TABLE montagen ALTER COLUMN material_5_id TYPE text USING material_5_id::text;
ALTER TABLE montagen ALTER COLUMN material_6_id TYPE text USING material_6_id::text;
ALTER TABLE montagen ALTER COLUMN material_7_id TYPE text USING material_7_id::text;

CREATE OR REPLACE FUNCTION public.sync_montage_material() RETURNS trigger
LANGUAGE plpgsql AS $function$
DECLARE
  v jsonb := to_jsonb(NEW);
  i int;
  mid text;
  menge numeric;
BEGIN
  DELETE FROM material_verbrauch WHERE service_typ = 'montage' AND service_id = NEW.id;

  -- Anlass-Montagen tragen FREITEXT-Tageszeilen in den material-Feldern
  -- (Migration 175) — kein Lagerverbrauch.
  IF NEW.montage_typ = 'anlass' THEN
    RETURN NEW;
  END IF;

  FOR i IN 1..7 LOOP
    mid := v->>('material_' || i || '_id');
    menge := COALESCE((v->>('material_' || i || '_menge'))::numeric, 0);
    -- Nur valide UUIDs buchen — die Spalte ist seit Migration 175 text.
    IF mid IS NOT NULL AND menge > 0
       AND mid ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
      INSERT INTO material_verbrauch (user_id, lager_id, service_typ, service_id, menge, einheit, verbraucht_am)
      SELECT NEW.user_id, mid::uuid, 'montage', NEW.id, menge, l.einheit, NOW()
      FROM lager l WHERE l.id = mid::uuid;
    END IF;
  END LOOP;
  RETURN NEW;
END;
$function$;

CREATE TRIGGER montage_material_sync
  AFTER INSERT OR UPDATE OF material_1_id, material_1_menge, material_2_id,
    material_2_menge, material_3_id, material_3_menge, material_4_id,
    material_4_menge, material_5_id, material_5_menge, material_6_id,
    material_6_menge, material_7_id, material_7_menge
  ON public.montagen
  FOR EACH ROW EXECUTE FUNCTION sync_montage_material();

COMMENT ON COLUMN montagen.material_1_id IS
  'Lager-UUID als Text (normale Montage) ODER Freitext-Tageszeile (montage_typ=anlass). Historisch uuid — Migration 175.';

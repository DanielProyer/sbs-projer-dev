-- Migration 141: Material abgeholt → Bestände in einem Klick
--
-- Status-Flow neu: entwurf → gesendet → abgeholt (storniert bleibt).
-- Die Buchung läuft über zwei RPCs in EINER Transaktion mit RELATIVEM Update
-- (bestand_aktuell + delta). Grund: eine client-seitige Schleife könnte nach
-- halbem Durchlauf abbrechen → einige Bestände erhöht, Status noch 'gesendet'
-- → der zweite Klick würde doppelt zählen (stiller Lagerfehler).
-- SECURITY INVOKER: die bestehenden RLS-Policies (user_isolation) greifen.

ALTER TABLE material_bestellungen DROP CONSTRAINT IF EXISTS material_bestellungen_status_check;
ALTER TABLE material_bestellungen ADD CONSTRAINT material_bestellungen_status_check
  CHECK (status IN ('entwurf','gesendet','abgeholt','storniert'));

ALTER TABLE material_bestellungen     ADD COLUMN IF NOT EXISTS abgeholt_am date;
ALTER TABLE material_bestellpositionen ADD COLUMN IF NOT EXISTS menge_erhalten numeric;

-- Bucht die Abholung atomar. p_mengen: {"<positionId>": <menge>, …}
CREATE OR REPLACE FUNCTION material_bestellung_abholen(
  p_bestellung_id uuid, p_mengen jsonb)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER AS $$
DECLARE r record;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM material_bestellungen
                 WHERE id = p_bestellung_id AND status = 'gesendet') THEN
    RAISE EXCEPTION 'Bestellung ist nicht im Status "gesendet" (bereits gebucht?)';
  END IF;

  FOR r IN SELECT p.id, p.lager_id, (p_mengen ->> p.id::text)::numeric AS menge
           FROM material_bestellpositionen p
           WHERE p.bestellung_id = p_bestellung_id
             AND p.lager_id IS NOT NULL
             AND (p_mengen ->> p.id::text)::numeric > 0
  LOOP
    -- Relativ: mehrere Positionen auf denselben Lager-Artikel summieren sich
    -- dadurch automatisch korrekt.
    UPDATE lager SET bestand_aktuell = bestand_aktuell + r.menge WHERE id = r.lager_id;
    UPDATE material_bestellpositionen SET menge_erhalten = r.menge WHERE id = r.id;
  END LOOP;

  UPDATE material_bestellungen
     SET status = 'abgeholt', abgeholt_am = CURRENT_DATE, updated_at = now()
   WHERE id = p_bestellung_id;
END; $$;

-- Macht die Abholung atomar rückgängig.
CREATE OR REPLACE FUNCTION material_bestellung_abholung_rueckgaengig(
  p_bestellung_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER AS $$
DECLARE r record;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM material_bestellungen
                 WHERE id = p_bestellung_id AND status = 'abgeholt') THEN
    RAISE EXCEPTION 'Bestellung ist nicht im Status "abgeholt"';
  END IF;

  FOR r IN SELECT p.id, p.lager_id, p.menge_erhalten AS menge
           FROM material_bestellpositionen p
           WHERE p.bestellung_id = p_bestellung_id
             AND p.lager_id IS NOT NULL
             AND p.menge_erhalten IS NOT NULL
  LOOP
    -- Klemmung bei 0: negativer Bestand ist fachlich unsinnig (falls seit dem
    -- Buchen bereits Material verbraucht wurde).
    UPDATE lager SET bestand_aktuell = GREATEST(0, bestand_aktuell - r.menge)
     WHERE id = r.lager_id;
    UPDATE material_bestellpositionen SET menge_erhalten = NULL WHERE id = r.id;
  END LOOP;

  UPDATE material_bestellungen
     SET status = 'gesendet', abgeholt_am = NULL, updated_at = now()
   WHERE id = p_bestellung_id;
END; $$;

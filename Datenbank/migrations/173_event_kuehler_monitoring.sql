-- ============================================================
-- Migration 173: Event-Technik v2 — Kühler-Typenschilder + Temperatur-Monitoring
-- Projekt: SBS Projer App
-- Stand: 14.08.2026
-- Spec: docs/superpowers/specs/2026-08-14-event-anstiche-leitungen-design.md
--   (Abschnitt «Erweiterung v2», Entscheide Daniel 14.08. nachmittags)
-- ============================================================

-- ── event_geraete: Typenschild-Daten (Kühler + Pumpe) + Sollbereich ──
-- Typenschild-Werte kommen per KI-Vorschlag (Edge Function typenschild-lesen,
-- portiert aus Projekt Heineken foto-erkennen) und sind vom Nutzer korrigierbar.
-- Die Roh-Erkennung bleibt als JSONB liegen (Übernahme ins Projekt Heineken).
ALTER TABLE event_geraete ADD COLUMN kuehler_typ text;
ALTER TABLE event_geraete ADD COLUMN pumpe_typ text;
ALTER TABLE event_geraete ADD COLUMN typenschild_kuehler_pfad text;
ALTER TABLE event_geraete ADD COLUMN typenschild_pumpe_pfad text;
ALTER TABLE event_geraete ADD COLUMN typenschild_erkennung jsonb;
-- Sollbereich der Kühlertemperatur (Entscheid: manuell + Sollbereich mit
-- Warnung) — Messungen ausserhalb werden in der App rot markiert.
ALTER TABLE event_geraete ADD COLUMN soll_min_celsius numeric;
ALTER TABLE event_geraete ADD COLUMN soll_max_celsius numeric;

COMMENT ON COLUMN event_geraete.kuehler_typ IS
  'Typenbezeichnung des Durchlaufkühlers (vom Typenschild, KI-Vorschlag korrigierbar).';
COMMENT ON COLUMN event_geraete.pumpe_typ IS
  'Typenbezeichnung der Pumpe (vom Typenschild, KI-Vorschlag korrigierbar).';
COMMENT ON COLUMN event_geraete.typenschild_erkennung IS
  'Roh-Antwort der KI (hersteller/typ_bezeichnung/seriennummer/baujahr je Schild + unsicher_bei/sicherheit).';

-- ── event_kuehler_messungen: manuelle Temperaturmessungen ──
CREATE TABLE event_kuehler_messungen (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  geraet_id uuid NOT NULL REFERENCES event_geraete(id) ON DELETE CASCADE,
  gemessen_am timestamptz NOT NULL DEFAULT now(),
  temperatur numeric NOT NULL,
  notiz text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
ALTER TABLE event_kuehler_messungen ENABLE ROW LEVEL SECURITY;
CREATE POLICY event_kuehler_messungen_user_policy ON event_kuehler_messungen
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE TRIGGER update_event_kuehler_messungen_updated_at
  BEFORE UPDATE ON event_kuehler_messungen
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE INDEX idx_event_kuehler_messungen_geraet
  ON event_kuehler_messungen(user_id, geraet_id, gemessen_am);

COMMENT ON TABLE event_kuehler_messungen IS
  'Manuell erfasste Kühlertemperaturen am Event (mehrmals täglich); Verlauf als Grafik in der App.';

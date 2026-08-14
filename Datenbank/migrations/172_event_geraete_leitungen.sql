-- ============================================================
-- Migration 172: Event-Technik — Anstiche & Leitungen
-- Projekt: SBS Projer App
-- Stand: 14.08.2026
-- Anlass: Openair Gampel 17.–23.08.2026. Spec:
--   docs/superpowers/specs/2026-08-14-event-anstiche-leitungen-design.md
-- ============================================================

-- ── event_geraete: Anstiche UND Durchlaufkühler ──
-- Beide in EINER Tabelle: es sind Geräte, an denen Leitungen hängen,
-- beide haben Standort + Inbetriebnahme.
CREATE TABLE event_geraete (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  typ text NOT NULL CHECK (typ IN (
    'orion_1000', 'orion_500', 'mehrfachanstich', 'durchlaufkuehler'
  )),
  bezeichnung text NOT NULL,
  -- nur beim Mehrfachanstich: wie viele Tanks hängen an der Leitung (1–4)
  anzahl_tanks int CHECK (anzahl_tanks BETWEEN 1 AND 4),
  standort_notiz text,
  -- Position optional, gleiche Mechanik wie event_staende (Migration 168/169).
  -- Wird in dieser Ausbaustufe nur in der DB vorgehalten (Übernahme ins
  -- Projekt Heineken), die UI setzt sie noch nicht.
  latitude double precision,
  longitude double precision,
  position_quelle text,
  position_genauigkeit text
    CHECK (position_genauigkeit IN ('genau', 'mittel', 'ungefaehr')),
  in_betrieb boolean NOT NULL DEFAULT false,
  in_betrieb_am timestamptz,
  sortierung int NOT NULL DEFAULT 0,
  notizen text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
ALTER TABLE event_geraete ENABLE ROW LEVEL SECURITY;
CREATE POLICY event_geraete_user_policy ON event_geraete
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE TRIGGER update_event_geraete_updated_at BEFORE UPDATE ON event_geraete
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE INDEX idx_event_geraete_event ON event_geraete(user_id, event_id);

-- ── event_leitungen: eine Zeile je physisch angeschriebener Leitung ──
-- nummer ist TEXT: vor Ort kann «7a» oder «B3» angeschrieben sein, und ein
-- Zahlentyp erzwingt eine Sortierung, der die Beschriftung nicht folgen muss.
-- Nummern sind eindeutig JE ANSTICH (Auskunft Daniel 14.08.), nicht eventweit.
-- stand_id/stand_anlage_id nullable: beim Erzeugen steht das Ziel noch nicht
-- fest, es wird beim Anschliessen gesetzt.
CREATE TABLE event_leitungen (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  -- redundant zur Quelle, erspart beim Laden den Join über event_geraete
  event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  nummer text NOT NULL,
  quelle_id uuid NOT NULL REFERENCES event_geraete(id) ON DELETE CASCADE,
  kuehler_id uuid REFERENCES event_geraete(id) ON DELETE SET NULL,
  stand_id uuid REFERENCES event_staende(id) ON DELETE SET NULL,
  stand_anlage_id uuid REFERENCES event_stand_anlagen(id) ON DELETE SET NULL,
  in_betrieb boolean NOT NULL DEFAULT false,
  in_betrieb_am timestamptz,
  sortierung int NOT NULL DEFAULT 0,
  notiz text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
ALTER TABLE event_leitungen ENABLE ROW LEVEL SECURITY;
CREATE POLICY event_leitungen_user_policy ON event_leitungen
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE TRIGGER update_event_leitungen_updated_at BEFORE UPDATE ON event_leitungen
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE INDEX idx_event_leitungen_event ON event_leitungen(user_id, event_id);
CREATE INDEX idx_event_leitungen_stand ON event_leitungen(user_id, stand_id);
CREATE UNIQUE INDEX uq_event_leitungen_quelle_nummer
  ON event_leitungen(quelle_id, nummer);

COMMENT ON TABLE event_geraete IS
  'Event-Technik: Anstiche (Orion 500/1000, Mehrfachanstich) und Durchlaufkühler. Gampel-Erfassung; Zielmodell entsteht im Projekt Heineken.';
COMMENT ON TABLE event_leitungen IS
  'Bierleitungen am Event: physisch angeschriebene Nummer (eindeutig je Anstich), Quelle, optional Kühler und Ziel-Stand.';
COMMENT ON COLUMN event_leitungen.nummer IS
  'Angeschriebene Nummer (Text, z. B. «7» oder «7a») — steht am Anstich UND am Zapfhahn.';

-- Migration 067: Unified Kontakte
-- Vereint betrieb_kontakte + heineken_kontakte in eine Tabelle "kontakte"
-- Erstellt anruf_logs + montage_kontakte Tabellen

-- 1. Neue Spalten hinzufuegen
ALTER TABLE betrieb_kontakte
  ADD COLUMN IF NOT EXISTS kategorie TEXT NOT NULL DEFAULT 'betrieb',
  ADD COLUMN IF NOT EXISTS rolle TEXT;

-- 2. betrieb_id nullable machen (Heineken/Event haben keinen Betrieb)
ALTER TABLE betrieb_kontakte ALTER COLUMN betrieb_id DROP NOT NULL;

-- 3. nachname nullable machen
ALTER TABLE betrieb_kontakte ALTER COLUMN nachname DROP NOT NULL;

-- 4. vorname NOT NULL sicherstellen
UPDATE betrieb_kontakte SET vorname = nachname WHERE vorname IS NULL OR vorname = '';
ALTER TABLE betrieb_kontakte ALTER COLUMN vorname SET NOT NULL;

-- 5. CHECK Constraints
ALTER TABLE betrieb_kontakte ADD CONSTRAINT kontakte_kategorie_check
  CHECK (kategorie IN ('betrieb', 'heineken', 'event'));
ALTER TABLE betrieb_kontakte ADD CONSTRAINT kontakte_rolle_check
  CHECK (rolle IN (
    'geschaeftsfuehrer', 'fb_manager', 'mitarbeiter', 'hauswart', 'sonstige',
    'rsl', 'buero', 'monteur', 'event_heineken', 'pikett',
    'ok', 'bau', 'stand'
  ));

-- 6. Bestehende funktion -> rolle mappen
UPDATE betrieb_kontakte SET rolle = CASE
  WHEN funktion = 'Geschäftsführer' THEN 'geschaeftsfuehrer'
  WHEN funktion = 'F&B Manager' THEN 'fb_manager'
  WHEN funktion = 'Mitarbeiter' THEN 'mitarbeiter'
  WHEN funktion = 'Hauswart' THEN 'hauswart'
  ELSE 'sonstige'
END WHERE rolle IS NULL;

-- 7. Tabelle umbenennen
ALTER TABLE betrieb_kontakte RENAME TO kontakte;

-- 8. heineken_kontakte Daten migrieren
INSERT INTO kontakte (id, user_id, betrieb_id, vorname, nachname, telefon, email,
                      kontakt_methode, ist_hauptkontakt, ist_du_anrede, kategorie, rolle,
                      notizen, created_at, updated_at)
SELECT id, user_id, NULL, vorname, nachname, telefon, email,
       'telefon', FALSE, (anrede = 'du'), 'heineken', rolle,
       notizen, created_at, updated_at
FROM heineken_kontakte;

-- 9. heineken_kontakte Tabelle droppen
DROP TABLE IF EXISTS heineken_kontakte;

-- 10. Indexes umbenennen + neue erstellen
ALTER INDEX IF EXISTS idx_betrieb_kontakte_betrieb RENAME TO idx_kontakte_betrieb;
ALTER INDEX IF EXISTS idx_betrieb_kontakte_user RENAME TO idx_kontakte_user;
ALTER INDEX IF EXISTS idx_betrieb_kontakte_telefon RENAME TO idx_kontakte_telefon;
CREATE INDEX IF NOT EXISTS idx_kontakte_kategorie ON kontakte(user_id, kategorie);

-- 11. RLS Policies aktualisieren
DROP POLICY IF EXISTS betrieb_kontakte_user_isolation ON kontakte;
DROP POLICY IF EXISTS heineken_kontakte_user_policy ON kontakte;
CREATE POLICY kontakte_user_policy ON kontakte
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- 12. Trigger aktualisieren
DROP TRIGGER IF EXISTS update_betrieb_kontakte_updated_at ON kontakte;
CREATE TRIGGER update_kontakte_updated_at BEFORE UPDATE ON kontakte
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 13. Anruf-Log Tabelle
CREATE TABLE anruf_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  kontakt_id UUID NOT NULL REFERENCES kontakte(id) ON DELETE CASCADE,
  anruf_zeitpunkt TIMESTAMPTZ NOT NULL DEFAULT now(),
  notiz TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX idx_anruf_logs_kontakt ON anruf_logs(kontakt_id);
ALTER TABLE anruf_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY anruf_logs_user_policy ON anruf_logs
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- 14. Montage-Kontakt Verknuepfung (m:n)
CREATE TABLE montage_kontakte (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  montage_id UUID NOT NULL REFERENCES montagen(id) ON DELETE CASCADE,
  kontakt_id UUID NOT NULL REFERENCES kontakte(id) ON DELETE CASCADE,
  rolle TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(montage_id, kontakt_id)
);
CREATE INDEX idx_montage_kontakte_montage ON montage_kontakte(montage_id);
ALTER TABLE montage_kontakte ENABLE ROW LEVEL SECURITY;
CREATE POLICY montage_kontakte_policy ON montage_kontakte
  FOR ALL USING (EXISTS (SELECT 1 FROM montagen WHERE id = montage_id AND user_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM montagen WHERE id = montage_id AND user_id = auth.uid()));

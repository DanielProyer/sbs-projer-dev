-- ============================================================
-- Migration 002: Row Level Security (RLS)
-- Projekt: SBS Projer App
-- Stand: 12.02.2026
-- Beschreibung: RLS aktivieren + Policies für alle 23 Tabellen
--               Prinzip: Jeder User sieht nur seine eigenen Daten
-- Idempotent: DROP IF EXISTS vor jedem CREATE POLICY
-- Ausführen NACH: 001_initial_schema.sql
-- ============================================================

-- STAMMDATEN
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS user_profiles_own ON user_profiles;
CREATE POLICY user_profiles_own ON user_profiles
  FOR ALL USING (id = auth.uid());

ALTER TABLE regionen ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS regionen_user_isolation ON regionen;
CREATE POLICY regionen_user_isolation ON regionen
  FOR ALL USING (user_id = auth.uid());

ALTER TABLE betriebe ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS betriebe_user_isolation ON betriebe;
CREATE POLICY betriebe_user_isolation ON betriebe
  FOR ALL USING (user_id = auth.uid());

ALTER TABLE betrieb_kontakte ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS betrieb_kontakte_user_isolation ON betrieb_kontakte;
CREATE POLICY betrieb_kontakte_user_isolation ON betrieb_kontakte
  FOR ALL USING (user_id = auth.uid());

ALTER TABLE betrieb_rechnungsadressen ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS betrieb_rechnungsadressen_user_isolation ON betrieb_rechnungsadressen;
CREATE POLICY betrieb_rechnungsadressen_user_isolation ON betrieb_rechnungsadressen
  FOR ALL USING (user_id = auth.uid());

-- ANLAGEN
ALTER TABLE anlagen ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS anlagen_user_isolation ON anlagen;
CREATE POLICY anlagen_user_isolation ON anlagen
  FOR ALL USING (user_id = auth.uid());

ALTER TABLE bierleitungen ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS bierleitungen_user_isolation ON bierleitungen;
CREATE POLICY bierleitungen_user_isolation ON bierleitungen
  FOR ALL USING (user_id = auth.uid());

ALTER TABLE anlagen_fotos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS anlagen_fotos_user_isolation ON anlagen_fotos;
CREATE POLICY anlagen_fotos_user_isolation ON anlagen_fotos
  FOR ALL USING (user_id = auth.uid());

-- PREISE
ALTER TABLE preise ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS preise_user_isolation ON preise;
CREATE POLICY preise_user_isolation ON preise
  FOR ALL USING (user_id = auth.uid());

-- SERVICES
ALTER TABLE reinigungen ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS reinigungen_user_isolation ON reinigungen;
CREATE POLICY reinigungen_user_isolation ON reinigungen
  FOR ALL USING (user_id = auth.uid());

ALTER TABLE stoerungen ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS stoerungen_user_isolation ON stoerungen;
CREATE POLICY stoerungen_user_isolation ON stoerungen
  FOR ALL USING (user_id = auth.uid());

ALTER TABLE montagen ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS montagen_user_isolation ON montagen;
CREATE POLICY montagen_user_isolation ON montagen
  FOR ALL USING (user_id = auth.uid());

ALTER TABLE eigenauftraege ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS eigenauftraege_user_isolation ON eigenauftraege;
CREATE POLICY eigenauftraege_user_isolation ON eigenauftraege
  FOR ALL USING (user_id = auth.uid());

ALTER TABLE pikett_dienste ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS pikett_user_isolation ON pikett_dienste;
CREATE POLICY pikett_user_isolation ON pikett_dienste
  FOR ALL USING (user_id = auth.uid());

-- MATERIAL
ALTER TABLE material_kategorien ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS material_kategorien_user_isolation ON material_kategorien;
CREATE POLICY material_kategorien_user_isolation ON material_kategorien
  FOR ALL USING (user_id = auth.uid());

ALTER TABLE material ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS material_user_isolation ON material;
CREATE POLICY material_user_isolation ON material
  FOR ALL USING (user_id = auth.uid());

ALTER TABLE lager ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS lager_user_isolation ON lager;
CREATE POLICY lager_user_isolation ON lager
  FOR ALL USING (user_id = auth.uid());

ALTER TABLE material_verbrauch ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS material_verbrauch_user_isolation ON material_verbrauch;
CREATE POLICY material_verbrauch_user_isolation ON material_verbrauch
  FOR ALL USING (user_id = auth.uid());

-- RECHNUNGEN
ALTER TABLE rechnungen ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS rechnungen_user_isolation ON rechnungen;
CREATE POLICY rechnungen_user_isolation ON rechnungen
  FOR ALL USING (user_id = auth.uid());

ALTER TABLE rechnungs_positionen ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS rechnungs_positionen_user_isolation ON rechnungs_positionen;
CREATE POLICY rechnungs_positionen_user_isolation ON rechnungs_positionen
  FOR ALL USING (user_id = auth.uid());

-- FORMULARE
ALTER TABLE formulare ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS formulare_user_isolation ON formulare;
CREATE POLICY formulare_user_isolation ON formulare
  FOR ALL USING (user_id = auth.uid());

-- BUCHHALTUNG
ALTER TABLE konten ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS konten_user_isolation ON konten;
CREATE POLICY konten_user_isolation ON konten
  FOR ALL USING (user_id = auth.uid());

ALTER TABLE buchungs_vorlagen ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS buchungs_vorlagen_user_isolation ON buchungs_vorlagen;
CREATE POLICY buchungs_vorlagen_user_isolation ON buchungs_vorlagen
  FOR ALL USING (user_id = auth.uid());

ALTER TABLE buchungen ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS buchungen_user_isolation ON buchungen;
CREATE POLICY buchungen_user_isolation ON buchungen
  FOR ALL USING (user_id = auth.uid());

-- ============================================================
-- Supabase Storage: Buckets & Policies
-- ============================================================
-- Hinweis: Storage-Buckets werden im Supabase Dashboard oder via API erstellt.
-- Die SQL-Befehle unten sind zur Dokumentation.

-- Bucket: "material-fotos"
--   Zweck: Artikel-Fotos aus dem Heineken-Artikelstamm
--   Pfad:  {user_id}/{dbo_nr}.jpg
--   Zugriff: Öffentlich lesbar (public), write nur für Auth-User

-- Bucket: "formulare"
--   Zweck: Generierte Heineken-PDF-Formulare
--   Pfad:  {user_id}/{YYYY}/{MM}/{formular_typ}/{referenz_nr}.pdf
--   Zugriff: Privat (nur Auth-User mit matching user_id)

-- Bucket: "anlagen-fotos"
--   Zweck: Fotos von Zapfanlagen (Supabase Storage URL in anlagen_fotos.foto_url)
--   Pfad:  {user_id}/{anlage_id}/{foto_nummer}.jpg
--   Zugriff: Privat

-- ============================================================
-- Migration 001: Initiales Schema
-- Projekt: SBS Projer App
-- Stand: 12.02.2026
-- Beschreibung: Alle 23 Tabellen in Abhängigkeitsreihenfolge
--               (ohne RLS, Trigger, Views → separate Dateien)
-- Ausführen in: Supabase SQL Editor
-- ============================================================

-- UUID Extension (in Supabase standardmässig aktiv)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Sequence für Rechnungsnummern
CREATE SEQUENCE IF NOT EXISTS rechnungsnummer_seq START 1;

-- ============================================================
-- STAMMDATEN
-- ============================================================

-- 1. user_profiles
CREATE TABLE IF NOT EXISTS user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  vorname TEXT NOT NULL,
  nachname TEXT NOT NULL,
  telefon TEXT,
  email TEXT,
  firma_name TEXT NOT NULL,
  firma_strasse TEXT,
  firma_nr TEXT,
  firma_plz TEXT,
  firma_ort TEXT,
  uid_nummer TEXT,
  mwst_nummer TEXT,
  iban TEXT,
  heineken_po_nummer TEXT,
  default_region_id UUID,
  sprache TEXT DEFAULT 'de' CHECK (sprache IN ('de', 'fr', 'it')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. regionen
CREATE TABLE IF NOT EXISTS regionen (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, name)
);

CREATE INDEX IF NOT EXISTS idx_regionen_user ON regionen(user_id);

-- FK von user_profiles → regionen (nach Erstellung)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_user_profiles_region'
  ) THEN
    ALTER TABLE user_profiles
      ADD CONSTRAINT fk_user_profiles_region
      FOREIGN KEY (default_region_id) REFERENCES regionen(id) ON DELETE SET NULL;
  END IF;
END;
$$;

-- 3. betriebe
CREATE TABLE IF NOT EXISTS betriebe (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  strasse TEXT,
  nr TEXT,
  plz TEXT,
  ort TEXT,
  region_id UUID REFERENCES regionen(id) ON DELETE SET NULL,
  email TEXT,
  website TEXT,
  zugang_notizen TEXT,
  -- Heineken-Kundennummer (für Formular-Referenznummern: {heineken_nr}_{YYYY}_{MM}_{DD})
  heineken_nr TEXT,
  status TEXT DEFAULT 'aktiv' CHECK (status IN ('aktiv', 'inaktiv', 'geschlossen')),
  ist_mein_kunde BOOLEAN DEFAULT TRUE,
  ist_bergkunde BOOLEAN DEFAULT FALSE,
  ist_saisonbetrieb BOOLEAN DEFAULT FALSE,
  winter_saison_aktiv BOOLEAN DEFAULT FALSE,
  winter_start_monat INTEGER CHECK (winter_start_monat BETWEEN 1 AND 12),
  winter_ende_monat INTEGER CHECK (winter_ende_monat BETWEEN 1 AND 12),
  sommer_saison_aktiv BOOLEAN DEFAULT FALSE,
  sommer_start_monat INTEGER CHECK (sommer_start_monat BETWEEN 1 AND 12),
  sommer_ende_monat INTEGER CHECK (sommer_ende_monat BETWEEN 1 AND 12),
  ruhetage TEXT[] DEFAULT '{}',
  rechnungsstellung TEXT DEFAULT 'rechnung_mail' CHECK (rechnungsstellung IN (
    'barzahler', 'rechnung_tresen', 'rechnung_mail', 'rechnung_post', 'rechnung_heineken'
  )),
  latitude DECIMAL(9,6),
  longitude DECIMAL(9,6),
  ferien_start DATE,
  ferien_ende DATE,
  notizen TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_betriebe_user ON betriebe(user_id);
CREATE INDEX IF NOT EXISTS idx_betriebe_region ON betriebe(region_id);
CREATE INDEX IF NOT EXISTS idx_betriebe_status ON betriebe(status);
CREATE INDEX IF NOT EXISTS idx_betriebe_mein_kunde ON betriebe(ist_mein_kunde);
CREATE INDEX IF NOT EXISTS idx_betriebe_bergkunde ON betriebe(ist_bergkunde);

-- 4. betrieb_kontakte
CREATE TABLE IF NOT EXISTS betrieb_kontakte (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  betrieb_id UUID NOT NULL REFERENCES betriebe(id) ON DELETE CASCADE,
  vorname TEXT,
  nachname TEXT NOT NULL,
  funktion TEXT,
  telefon TEXT,
  email TEXT,
  telefon_normalized TEXT,
  phone_contact_id TEXT,
  phone_last_synced_at TIMESTAMPTZ,
  kontakt_methode TEXT DEFAULT 'telefon' CHECK (kontakt_methode IN (
    'telefon', 'whatsapp', 'email', 'sms'
  )),
  ist_hauptkontakt BOOLEAN DEFAULT FALSE,
  notizen TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_betrieb_kontakte_betrieb ON betrieb_kontakte(betrieb_id);
CREATE INDEX IF NOT EXISTS idx_betrieb_kontakte_user ON betrieb_kontakte(user_id);
CREATE INDEX IF NOT EXISTS idx_betrieb_kontakte_telefon ON betrieb_kontakte(telefon_normalized);

-- 5. betrieb_rechnungsadressen
CREATE TABLE IF NOT EXISTS betrieb_rechnungsadressen (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  betrieb_id UUID NOT NULL REFERENCES betriebe(id) ON DELETE CASCADE,
  firma TEXT,
  vorname TEXT,
  nachname TEXT NOT NULL,
  strasse TEXT NOT NULL,
  nr TEXT,
  plz TEXT NOT NULL,
  ort TEXT NOT NULL,
  email TEXT,
  notizen TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(betrieb_id)
);

CREATE INDEX IF NOT EXISTS idx_betrieb_rechnungsadressen_betrieb ON betrieb_rechnungsadressen(betrieb_id);

-- ============================================================
-- ANLAGEN
-- ============================================================

-- 6. anlagen
CREATE TABLE IF NOT EXISTS anlagen (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  betrieb_id UUID NOT NULL REFERENCES betriebe(id) ON DELETE CASCADE,
  bezeichnung TEXT,
  seriennummer TEXT,
  typ_anlage TEXT NOT NULL CHECK (typ_anlage IN (
    'Warmanstich', 'Kaltanstich', 'Buffetanstich', 'Orion'
  )),
  typ_saeule TEXT CHECK (typ_saeule IN (
    'Europe 1-Way', 'Europe 2-Way', 'Europe 3-Way', 'Europe 4-Way',
    'HeiTube 1-Way', 'Arrow 1-Way', 'Fountain 1-Way',
    'Fountain Extra Cold 1-Way', 'Falco 2-Way', 'Keramik 1-Way',
    'Keramik 2-Way', 'Adimat', 'BuyToSell', 'Fremdsäule'
  )),
  anzahl_haehne INTEGER NOT NULL DEFAULT 1,
  backpython BOOLEAN DEFAULT FALSE,
  booster BOOLEAN DEFAULT FALSE,
  vorkuehler TEXT DEFAULT 'keiner' CHECK (vorkuehler IN (
    'keiner', 'Fasskühler', 'Kühlzelle', 'Buffet'
  )),
  durchlaufkuehler TEXT CHECK (durchlaufkuehler IN (
    'H60', 'H75', 'H100', 'H120', 'H150', 'H200',
    'Fremdkühler', 'Fremdkühler Sat.', 'keiner'
  )),
  letzter_wasserwechsel DATE,
  gas_typ_1 TEXT CHECK (gas_typ_1 IN ('Aligal2', 'Aligal13', 'Kompressor')),
  gas_typ_2 TEXT CHECK (gas_typ_2 IN ('Aligal2', 'Aligal13', 'Kompressor')),
  hauptdruck_bar DECIMAL(3,1),
  hat_niederdruck BOOLEAN DEFAULT FALSE,
  CONSTRAINT check_gas_typen_different CHECK (
    gas_typ_1 IS NULL OR gas_typ_2 IS NULL OR gas_typ_1 != gas_typ_2
  ),
  servicezeit_morgen_ab TIME,
  servicezeit_morgen_bis TIME,
  servicezeit_nachmittag_ab TIME,
  servicezeit_nachmittag_bis TIME,
  reinigung_rhythmus TEXT DEFAULT '4-Wochen' CHECK (reinigung_rhythmus IN (
    '4-Wochen', '6-Wochen', '2-Monate', '3-Monate',
    '6-Monate', 'Jährlich', 'auf-Abruf', 'Selbstreiniger'
  )),
  letzte_reinigung DATE,
  naechste_reinigung DATE,
  status TEXT DEFAULT 'aktiv' CHECK (status IN ('aktiv', 'inaktiv', 'stillgelegt')),
  notizen TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_anlagen_user ON anlagen(user_id);
CREATE INDEX IF NOT EXISTS idx_anlagen_betrieb ON anlagen(betrieb_id);
CREATE INDEX IF NOT EXISTS idx_anlagen_status ON anlagen(status);
CREATE INDEX IF NOT EXISTS idx_anlagen_naechste_reinigung ON anlagen(naechste_reinigung);

-- 7. bierleitungen
CREATE TABLE IF NOT EXISTS bierleitungen (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  anlage_id UUID NOT NULL REFERENCES anlagen(id) ON DELETE CASCADE,
  leitungs_nummer INTEGER NOT NULL CHECK (leitungs_nummer BETWEEN 1 AND 4),
  biersorte TEXT,
  hahn_typ TEXT,
  niederdruck_bar DECIMAL(3,1),
  hat_fob_stop BOOLEAN DEFAULT FALSE,
  UNIQUE(anlage_id, leitungs_nummer)
);

CREATE INDEX IF NOT EXISTS idx_bierleitungen_anlage ON bierleitungen(anlage_id);
CREATE INDEX IF NOT EXISTS idx_bierleitungen_user ON bierleitungen(user_id);

-- 8. anlagen_fotos
CREATE TABLE IF NOT EXISTS anlagen_fotos (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  anlage_id UUID NOT NULL REFERENCES anlagen(id) ON DELETE CASCADE,
  foto_nummer INTEGER NOT NULL CHECK (foto_nummer BETWEEN 1 AND 4),
  foto_url TEXT NOT NULL,
  beschreibung TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(anlage_id, foto_nummer)
);

CREATE INDEX IF NOT EXISTS idx_anlagen_fotos_anlage ON anlagen_fotos(anlage_id);

-- ============================================================
-- PREISE
-- ============================================================

-- 9. preise
CREATE TABLE IF NOT EXISTS preise (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  gueltig_ab DATE NOT NULL,
  gueltig_bis DATE,
  mwst_satz DECIMAL(4,2) NOT NULL DEFAULT 8.10,
  bergkunden_zuschlag DECIMAL(10,2) NOT NULL DEFAULT 180.00,
  grundtarif_reinigung_bier DECIMAL(10,2) NOT NULL,
  grundtarif_reinigung_orion DECIMAL(10,2) NOT NULL,
  grundtarif_heigenie DECIMAL(10,2) NOT NULL,
  grundtarif_reinigung_fremd DECIMAL(10,2) NOT NULL,
  grundtarif_wein DECIMAL(10,2) NOT NULL,
  zusatz_hahn_eigen DECIMAL(10,2) NOT NULL,
  zusatz_hahn_orion DECIMAL(10,2) NOT NULL,
  zusatz_hahn_fremd DECIMAL(10,2) NOT NULL,
  zusatz_hahn_wein DECIMAL(10,2) NOT NULL,
  zusatz_hahn_anderer_standort DECIMAL(10,2) NOT NULL,
  eigenauftrag_pauschale DECIMAL(10,2) NOT NULL DEFAULT 30.00,
  montage_stundensatz DECIMAL(10,2) NOT NULL,
  pikett_pauschale DECIMAL(10,2) NOT NULL DEFAULT 160.00,
  pikett_feiertag_zuschlag DECIMAL(10,2) NOT NULL DEFAULT 80.00,
  eroeffnung_preis_normal DECIMAL(10,2) NOT NULL DEFAULT 60.00,
  eroeffnung_preis_bergkunde DECIMAL(10,2) NOT NULL DEFAULT 135.00,
  stoerung_1_normal DECIMAL(10,2) NOT NULL DEFAULT 55.00,
  stoerung_1_bergkunde DECIMAL(10,2) NOT NULL DEFAULT 130.00,
  stoerung_2_normal DECIMAL(10,2) NOT NULL DEFAULT 55.00,
  stoerung_2_bergkunde DECIMAL(10,2) NOT NULL DEFAULT 130.00,
  stoerung_3_normal DECIMAL(10,2) NOT NULL DEFAULT 90.00,
  stoerung_3_bergkunde DECIMAL(10,2) NOT NULL DEFAULT 165.00,
  stoerung_4_normal DECIMAL(10,2) NOT NULL DEFAULT 45.00,
  stoerung_4_bergkunde DECIMAL(10,2) NOT NULL DEFAULT 120.00,
  stoerung_5_normal DECIMAL(10,2) NOT NULL DEFAULT 45.00,
  stoerung_5_bergkunde DECIMAL(10,2) NOT NULL DEFAULT 120.00,
  stoerung_anfahrt_pauschale DECIMAL(10,2) NOT NULL DEFAULT 60.00,
  stoerung_anfahrt_km_grenze INTEGER NOT NULL DEFAULT 80,
  stoerung_anfahrt_km_satz DECIMAL(5,3) NOT NULL DEFAULT 0.720,
  stoerung_wochenende_zuschlag DECIMAL(10,2) NOT NULL DEFAULT 100.00,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT preise_zeitraum_check CHECK (gueltig_bis IS NULL OR gueltig_bis > gueltig_ab)
);

CREATE INDEX IF NOT EXISTS idx_preise_user ON preise(user_id);
CREATE INDEX IF NOT EXISTS idx_preise_gueltig ON preise(gueltig_ab, gueltig_bis);

-- ============================================================
-- MATERIAL (muss vor Service-Tabellen stehen wegen FKs)
-- ============================================================

-- 15. material_kategorien
CREATE TABLE IF NOT EXISTS material_kategorien (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  beschreibung TEXT,
  sortierung INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, name)
);

CREATE INDEX IF NOT EXISTS idx_material_kategorien_user ON material_kategorien(user_id);

-- 16. material (Heineken Artikelstamm / Produktkatalog)
CREATE TABLE IF NOT EXISTS material (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  kategorie_id UUID REFERENCES material_kategorien(id) ON DELETE SET NULL,
  dbo_nr TEXT NOT NULL,
  name TEXT NOT NULL,
  beschreibung TEXT,
  einheit TEXT NOT NULL DEFAULT 'Stück' CHECK (einheit IN (
    'Stück', 'Liter', 'Meter', 'Kilogramm', 'Packung', 'Set'
  )),
  foto_storage_path TEXT,
  gueltig_ab DATE,
  ist_auslaufartikel BOOLEAN DEFAULT FALSE,
  auslauf_datum DATE,
  nachfolger_id UUID REFERENCES material(id) ON DELETE SET NULL,
  ist_aktiv BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, dbo_nr)
);

CREATE INDEX IF NOT EXISTS idx_material_user ON material(user_id);
CREATE INDEX IF NOT EXISTS idx_material_kategorie ON material(kategorie_id);
CREATE INDEX IF NOT EXISTS idx_material_dbo_nr ON material(dbo_nr);
CREATE INDEX IF NOT EXISTS idx_material_aktiv ON material(user_id, ist_auslaufartikel)
  WHERE ist_auslaufartikel = FALSE;
CREATE INDEX IF NOT EXISTS idx_material_nachfolger ON material(nachfolger_id)
  WHERE nachfolger_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_material_mit_foto ON material(user_id)
  WHERE foto_storage_path IS NOT NULL;

-- 17. lager (Fahrzeuglager – Bestand im Auto)
CREATE TABLE IF NOT EXISTS lager (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  kategorie_id UUID REFERENCES material_kategorien(id) ON DELETE SET NULL,
  material_id UUID REFERENCES material(id) ON DELETE SET NULL,
  dbo_nr TEXT,
  name TEXT NOT NULL,
  beschreibung TEXT,
  einheit TEXT NOT NULL DEFAULT 'Stück' CHECK (einheit IN (
    'Stück', 'Liter', 'Meter', 'Kilogramm', 'Packung', 'Set'
  )),
  bestand_aktuell DECIMAL(10,2) NOT NULL DEFAULT 0,
  bestand_mindest DECIMAL(10,2) NOT NULL DEFAULT 5,
  bestand_optimal DECIMAL(10,2) NOT NULL DEFAULT 10,
  bestand_niedrig BOOLEAN GENERATED ALWAYS AS (bestand_aktuell <= bestand_mindest) STORED,
  lieferant TEXT,
  lieferanten_artikel_nr TEXT,
  preis_einkauf DECIMAL(10,2),
  ist_aktiv BOOLEAN DEFAULT TRUE,
  notizen TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_lager_user ON lager(user_id);
CREATE INDEX IF NOT EXISTS idx_lager_kategorie ON lager(kategorie_id);
CREATE INDEX IF NOT EXISTS idx_lager_material ON lager(material_id);
CREATE INDEX IF NOT EXISTS idx_lager_bestand_niedrig ON lager(bestand_niedrig)
  WHERE bestand_niedrig = TRUE;

-- ============================================================
-- SERVICES
-- ============================================================

-- 10. reinigungen
CREATE TABLE IF NOT EXISTS reinigungen (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  anlage_id UUID NOT NULL REFERENCES anlagen(id) ON DELETE CASCADE,
  betrieb_id UUID NOT NULL REFERENCES betriebe(id) ON DELETE CASCADE,
  datum DATE NOT NULL,
  uhrzeit_start TIME,
  uhrzeit_ende TIME,
  dauer_minuten INTEGER GENERATED ALWAYS AS (
    EXTRACT(EPOCH FROM (uhrzeit_ende - uhrzeit_start)) / 60
  ) STORED,
  hat_durchlaufkuehler BOOLEAN NOT NULL DEFAULT FALSE,
  hat_buffetanstich BOOLEAN NOT NULL DEFAULT FALSE,
  hat_kuehlkeller BOOLEAN NOT NULL DEFAULT FALSE,
  hat_fasskuehler BOOLEAN NOT NULL DEFAULT FALSE,
  begleitkuehlung_kontrolliert BOOLEAN DEFAULT FALSE,
  installation_allgemein_kontrolliert BOOLEAN DEFAULT FALSE,
  aligal_anschluesse_kontrolliert BOOLEAN DEFAULT FALSE,
  durchlaufkuehler_ausgeblasen BOOLEAN DEFAULT FALSE,
  wasserstand_kontrolliert BOOLEAN DEFAULT FALSE,
  wasser_gewechselt BOOLEAN DEFAULT FALSE,
  leitung_wasser_vorgespuelt BOOLEAN DEFAULT FALSE,
  leitungsreinigung_reinigungsmittel BOOLEAN DEFAULT FALSE,
  foerderdruck_kontrolliert BOOLEAN DEFAULT FALSE,
  zapfhahn_zerlegt_gereinigt BOOLEAN DEFAULT FALSE,
  zapfkopf_zerlegt_gereinigt BOOLEAN DEFAULT FALSE,
  servicekarte_ausgefuellt BOOLEAN DEFAULT FALSE,
  unterschrift_techniker TEXT,
  unterschrift_kunde TEXT,
  unterschrift_kunde_name TEXT,
  notizen TEXT,
  preisliste_id UUID REFERENCES preise(id),
  service_typ TEXT CHECK (service_typ IN (
    'reinigung_bier', 'reinigung_orion', 'heigenie',
    'reinigung_fremd', 'wein'
  )),
  anzahl_haehne_eigen INTEGER DEFAULT 0,
  anzahl_haehne_orion INTEGER DEFAULT 0,
  anzahl_haehne_fremd INTEGER DEFAULT 0,
  anzahl_haehne_wein INTEGER DEFAULT 0,
  anzahl_haehne_anderer_standort INTEGER DEFAULT 0,
  ist_bergkunde BOOLEAN DEFAULT FALSE,
  preis_grundtarif DECIMAL(10,2),
  preis_zusatz_haehne DECIMAL(10,2) DEFAULT 0.00,
  bergkunden_zuschlag DECIMAL(10,2) DEFAULT 0.00,
  preis_netto DECIMAL(10,2),
  mwst_satz DECIMAL(4,2),
  preis_mwst DECIMAL(10,2),
  preis_brutto DECIMAL(10,2),
  status TEXT DEFAULT 'offen' CHECK (status IN (
    'offen', 'abgeschlossen', 'abgerechnet', 'storniert'
  )),
  ist_synced BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_reinigungen_user ON reinigungen(user_id);
CREATE INDEX IF NOT EXISTS idx_reinigungen_anlage ON reinigungen(anlage_id);
CREATE INDEX IF NOT EXISTS idx_reinigungen_betrieb ON reinigungen(betrieb_id);
CREATE INDEX IF NOT EXISTS idx_reinigungen_datum ON reinigungen(datum DESC);
CREATE INDEX IF NOT EXISTS idx_reinigungen_status ON reinigungen(status);

-- 11. stoerungen
CREATE TABLE IF NOT EXISTS stoerungen (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  anlage_id UUID NOT NULL REFERENCES anlagen(id) ON DELETE CASCADE,
  betrieb_id UUID NOT NULL REFERENCES betriebe(id) ON DELETE CASCADE,
  stoerungsnummer TEXT NOT NULL,
  referenz_nr TEXT,
  datum DATE NOT NULL,
  uhrzeit_start TIME,
  uhrzeit_ende TIME,
  dauer_minuten INTEGER GENERATED ALWAYS AS (
    EXTRACT(EPOCH FROM (uhrzeit_ende - uhrzeit_start)) / 60
  ) STORED,
  anlage_typ TEXT CHECK (anlage_typ IN ('konventionell', 'heigenie', 'orion', 'david')),
  problem_beschreibung TEXT NOT NULL,
  loesung_beschreibung TEXT,
  ist_pikett_einsatz BOOLEAN DEFAULT FALSE,
  status TEXT DEFAULT 'offen' CHECK (status IN (
    'offen', 'in_bearbeitung', 'behoben', 'nicht_behebbar'
  )),
  stoerung_bereich INTEGER CHECK (stoerung_bereich BETWEEN 1 AND 5),
  preisliste_id UUID REFERENCES preise(id),
  ist_bergkunde BOOLEAN DEFAULT FALSE,
  anfahrt_km INTEGER DEFAULT 0,
  ist_wochenende BOOLEAN DEFAULT FALSE,
  komplexitaet_zuschlag DECIMAL(10,2) DEFAULT 0.00,
  preis_basis DECIMAL(10,2),
  preis_anfahrt DECIMAL(10,2),
  preis_wochenende DECIMAL(10,2) DEFAULT 0.00,
  preis_netto DECIMAL(10,2),
  mwst_satz DECIMAL(4,2),
  preis_mwst DECIMAL(10,2),
  preis_brutto DECIMAL(10,2),
  material_1_id UUID REFERENCES lager(id) ON DELETE SET NULL,
  material_1_menge DECIMAL(10,2) DEFAULT 1,
  material_2_id UUID REFERENCES lager(id) ON DELETE SET NULL,
  material_2_menge DECIMAL(10,2) DEFAULT 1,
  material_3_id UUID REFERENCES lager(id) ON DELETE SET NULL,
  material_3_menge DECIMAL(10,2) DEFAULT 1,
  material_4_id UUID REFERENCES lager(id) ON DELETE SET NULL,
  material_4_menge DECIMAL(10,2) DEFAULT 1,
  material_5_id UUID REFERENCES lager(id) ON DELETE SET NULL,
  material_5_menge DECIMAL(10,2) DEFAULT 1,
  abrechnungs_monat DATE,
  abgerechnet BOOLEAN DEFAULT FALSE,
  notizen TEXT,
  ist_synced BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_stoerungen_user ON stoerungen(user_id);
CREATE INDEX IF NOT EXISTS idx_stoerungen_anlage ON stoerungen(anlage_id);
CREATE INDEX IF NOT EXISTS idx_stoerungen_betrieb ON stoerungen(betrieb_id);
CREATE INDEX IF NOT EXISTS idx_stoerungen_datum ON stoerungen(datum DESC);
CREATE INDEX IF NOT EXISTS idx_stoerungen_abrechnungsmonat ON stoerungen(abrechnungs_monat);
CREATE INDEX IF NOT EXISTS idx_stoerungen_bereich ON stoerungen(stoerung_bereich);
CREATE INDEX IF NOT EXISTS idx_stoerungen_anlage_typ ON stoerungen(anlage_typ);

-- 12. montagen
CREATE TABLE IF NOT EXISTS montagen (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  anlage_id UUID REFERENCES anlagen(id) ON DELETE SET NULL,
  betrieb_id UUID NOT NULL REFERENCES betriebe(id) ON DELETE CASCADE,
  montage_typ TEXT NOT NULL CHECK (montage_typ IN (
    'neu_installation', 'umbau', 'erweiterung', 'abbau',
    'heigenie_service', 'sonstiges'
  )),
  beschreibung TEXT NOT NULL,
  referenz_nr TEXT,
  datum DATE NOT NULL,
  uhrzeit_start TIME,
  uhrzeit_ende TIME,
  dauer_minuten INTEGER GENERATED ALWAYS AS (
    EXTRACT(EPOCH FROM (uhrzeit_ende - uhrzeit_start)) / 60
  ) STORED,
  status TEXT DEFAULT 'geplant' CHECK (status IN (
    'geplant', 'in_bearbeitung', 'abgeschlossen', 'abgebrochen'
  )),
  preisliste_id UUID REFERENCES preise(id),
  stundensatz DECIMAL(10,2),
  dauer_stunden DECIMAL(5,2),
  kosten_arbeit DECIMAL(10,2),
  abrechnungs_monat DATE,
  abgerechnet BOOLEAN DEFAULT FALSE,
  material_1_id UUID REFERENCES lager(id) ON DELETE SET NULL,
  material_1_menge DECIMAL(10,2) DEFAULT 1,
  material_2_id UUID REFERENCES lager(id) ON DELETE SET NULL,
  material_2_menge DECIMAL(10,2) DEFAULT 1,
  material_3_id UUID REFERENCES lager(id) ON DELETE SET NULL,
  material_3_menge DECIMAL(10,2) DEFAULT 1,
  material_4_id UUID REFERENCES lager(id) ON DELETE SET NULL,
  material_4_menge DECIMAL(10,2) DEFAULT 1,
  material_5_id UUID REFERENCES lager(id) ON DELETE SET NULL,
  material_5_menge DECIMAL(10,2) DEFAULT 1,
  material_6_id UUID REFERENCES lager(id) ON DELETE SET NULL,
  material_6_menge DECIMAL(10,2) DEFAULT 1,
  material_7_id UUID REFERENCES lager(id) ON DELETE SET NULL,
  material_7_menge DECIMAL(10,2) DEFAULT 1,
  notizen TEXT,
  ist_synced BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_montagen_user ON montagen(user_id);
CREATE INDEX IF NOT EXISTS idx_montagen_anlage ON montagen(anlage_id);
CREATE INDEX IF NOT EXISTS idx_montagen_betrieb ON montagen(betrieb_id);
CREATE INDEX IF NOT EXISTS idx_montagen_datum ON montagen(datum DESC);
CREATE INDEX IF NOT EXISTS idx_montagen_abrechnungsmonat ON montagen(abrechnungs_monat);

-- 13. eigenauftraege
CREATE TABLE IF NOT EXISTS eigenauftraege (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  anlage_id UUID NOT NULL REFERENCES anlagen(id) ON DELETE CASCADE,
  betrieb_id UUID NOT NULL REFERENCES betriebe(id) ON DELETE CASCADE,
  stoerungsnummer TEXT NOT NULL,
  referenz_nr TEXT,
  datum DATE NOT NULL,
  uhrzeit TIME,
  entdeckt_bei_service_id UUID REFERENCES reinigungen(id) ON DELETE SET NULL,
  problem_beschreibung TEXT NOT NULL,
  loesung_beschreibung TEXT,
  status TEXT DEFAULT 'behoben' CHECK (status IN (
    'behoben', 'nicht_behebbar', 'nachbearbeitung_noetig'
  )),
  preisliste_id UUID REFERENCES preise(id),
  pauschale DECIMAL(10,2) DEFAULT 30.00,
  abrechnungs_monat DATE,
  abgerechnet BOOLEAN DEFAULT FALSE,
  material_1_id UUID REFERENCES lager(id) ON DELETE SET NULL,
  material_1_menge DECIMAL(10,2) DEFAULT 1,
  material_2_id UUID REFERENCES lager(id) ON DELETE SET NULL,
  material_2_menge DECIMAL(10,2) DEFAULT 1,
  material_3_id UUID REFERENCES lager(id) ON DELETE SET NULL,
  material_3_menge DECIMAL(10,2) DEFAULT 1,
  material_4_id UUID REFERENCES lager(id) ON DELETE SET NULL,
  material_4_menge DECIMAL(10,2) DEFAULT 1,
  material_5_id UUID REFERENCES lager(id) ON DELETE SET NULL,
  material_5_menge DECIMAL(10,2) DEFAULT 1,
  notizen TEXT,
  ist_synced BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_eigenauftraege_user ON eigenauftraege(user_id);
CREATE INDEX IF NOT EXISTS idx_eigenauftraege_anlage ON eigenauftraege(anlage_id);
CREATE INDEX IF NOT EXISTS idx_eigenauftraege_betrieb ON eigenauftraege(betrieb_id);
CREATE INDEX IF NOT EXISTS idx_eigenauftraege_datum ON eigenauftraege(datum DESC);
CREATE INDEX IF NOT EXISTS idx_eigenauftraege_service ON eigenauftraege(entdeckt_bei_service_id);
CREATE INDEX IF NOT EXISTS idx_eigenauftraege_abrechnungsmonat ON eigenauftraege(abrechnungs_monat);

-- 14. pikett_dienste
CREATE TABLE IF NOT EXISTS pikett_dienste (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  datum_start DATE NOT NULL,
  datum_ende DATE NOT NULL,
  referenz_nr TEXT,
  ist_aktiv BOOLEAN DEFAULT FALSE,
  preisliste_id UUID REFERENCES preise(id),
  pauschale DECIMAL(10,2) DEFAULT 160.00,
  anzahl_feiertage INTEGER DEFAULT 0,
  feiertag_zuschlag DECIMAL(10,2) DEFAULT 0.00,
  pauschale_gesamt DECIMAL(10,2),
  abrechnungs_monat DATE,
  abgerechnet BOOLEAN DEFAULT FALSE,
  google_calendar_event_id TEXT,
  kalender_sync_status TEXT DEFAULT 'pending' CHECK (kalender_sync_status IN (
    'pending', 'synced', 'error'
  )),
  kalender_sync_fehler TEXT,
  kalender_sync_at TIMESTAMPTZ,
  notizen TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT pikett_zeitraum_check CHECK (datum_ende >= datum_start)
);

CREATE INDEX IF NOT EXISTS idx_pikett_user ON pikett_dienste(user_id);
CREATE INDEX IF NOT EXISTS idx_pikett_zeitraum ON pikett_dienste(datum_start, datum_ende);
CREATE INDEX IF NOT EXISTS idx_pikett_aktiv ON pikett_dienste(ist_aktiv) WHERE ist_aktiv = TRUE;
CREATE INDEX IF NOT EXISTS idx_pikett_kalender_sync ON pikett_dienste(kalender_sync_status)
  WHERE kalender_sync_status != 'synced';

-- 18. material_verbrauch
CREATE TABLE IF NOT EXISTS material_verbrauch (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  lager_id UUID NOT NULL REFERENCES lager(id) ON DELETE CASCADE,
  service_typ TEXT NOT NULL CHECK (service_typ IN (
    'reinigung', 'stoerung', 'montage', 'eigenauftrag'
  )),
  service_id UUID NOT NULL,
  menge DECIMAL(10,2) NOT NULL,
  einheit TEXT NOT NULL,
  preis_einkauf DECIMAL(10,2),
  verbraucht_am TIMESTAMPTZ DEFAULT NOW(),
  notizen TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT menge_positiv CHECK (menge > 0)
);

CREATE INDEX IF NOT EXISTS idx_material_verbrauch_user ON material_verbrauch(user_id);
CREATE INDEX IF NOT EXISTS idx_material_verbrauch_lager ON material_verbrauch(lager_id);
CREATE INDEX IF NOT EXISTS idx_material_verbrauch_service ON material_verbrauch(service_typ, service_id);

-- ============================================================
-- RECHNUNGEN
-- ============================================================

-- 18. rechnungen (Tabellennummer 18, nach Umstrukturierung)
CREATE TABLE IF NOT EXISTS rechnungen (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  rechnungsnummer TEXT UNIQUE,
  rechnungstyp TEXT NOT NULL CHECK (rechnungstyp IN ('kundenrechnung', 'heineken_monat')),
  betrieb_id UUID REFERENCES betriebe(id) ON DELETE SET NULL,
  heineken_po_nummer TEXT,
  heineken_monat DATE,
  rechnungsdatum DATE NOT NULL DEFAULT CURRENT_DATE,
  faelligkeitsdatum DATE NOT NULL,
  betrag_netto DECIMAL(10,2) NOT NULL DEFAULT 0,
  mwst_betrag DECIMAL(10,2) NOT NULL DEFAULT 0,
  betrag_brutto DECIMAL(10,2) NOT NULL DEFAULT 0,
  zahlungsstatus TEXT DEFAULT 'entwurf' CHECK (zahlungsstatus IN (
    'entwurf', 'offen', 'teilbezahlt', 'bezahlt', 'ueberfaellig', 'storniert'
  )),
  versandart TEXT,
  versendet_am DATE,
  zahlung_eingegangen_am DATE,
  zahlung_betrag DECIMAL(10,2),
  mahnung_stufe INTEGER DEFAULT 0 CHECK (mahnung_stufe BETWEEN 0 AND 3),
  letzte_mahnung_am DATE,
  pdf_url TEXT,
  notizen TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT rechnung_kunde_check CHECK (
    rechnungstyp != 'kundenrechnung' OR betrieb_id IS NOT NULL
  ),
  CONSTRAINT rechnung_heineken_check CHECK (
    rechnungstyp != 'heineken_monat' OR
    (heineken_po_nummer IS NOT NULL AND heineken_monat IS NOT NULL)
  )
);

CREATE INDEX IF NOT EXISTS idx_rechnungen_user ON rechnungen(user_id);
CREATE INDEX IF NOT EXISTS idx_rechnungen_betrieb ON rechnungen(betrieb_id);
CREATE INDEX IF NOT EXISTS idx_rechnungen_datum ON rechnungen(rechnungsdatum DESC);
CREATE INDEX IF NOT EXISTS idx_rechnungen_status ON rechnungen(zahlungsstatus);
CREATE INDEX IF NOT EXISTS idx_rechnungen_faellig ON rechnungen(faelligkeitsdatum)
  WHERE zahlungsstatus IN ('offen', 'ueberfaellig');

-- 19. rechnungs_positionen
CREATE TABLE IF NOT EXISTS rechnungs_positionen (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  rechnung_id UUID NOT NULL REFERENCES rechnungen(id) ON DELETE CASCADE,
  service_typ TEXT CHECK (service_typ IN (
    'reinigung', 'stoerung', 'montage', 'eigenauftrag', 'pikett'
  )),
  service_id UUID,
  position INTEGER NOT NULL,
  beschreibung TEXT NOT NULL,
  betrag_netto DECIMAL(10,2) NOT NULL,
  mwst_satz DECIMAL(4,2) NOT NULL DEFAULT 8.10,
  mwst_betrag DECIMAL(10,2) NOT NULL,
  betrag_brutto DECIMAL(10,2) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(rechnung_id, position)
);

CREATE INDEX IF NOT EXISTS idx_rechnungs_positionen_rechnung ON rechnungs_positionen(rechnung_id);
CREATE INDEX IF NOT EXISTS idx_rechnungs_positionen_service ON rechnungs_positionen(service_typ, service_id);

-- 20. formulare (PDF-Formulare für Heineken Monatsabrechnung)
CREATE TABLE IF NOT EXISTS formulare (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  formular_typ TEXT NOT NULL CHECK (formular_typ IN (
    'stoerung', 'eigenauftrag', 'ee_reinigung', 'montage', 'pikett', 'pauschale'
  )),
  service_typ TEXT NOT NULL CHECK (service_typ IN (
    'stoerung', 'eigenauftrag', 'montage', 'pikett', 'reinigung'
  )),
  service_id UUID NOT NULL,
  referenz_nr TEXT,
  rechnung_id UUID REFERENCES rechnungen(id) ON DELETE SET NULL,
  abrechnungs_monat DATE,
  pdf_storage_path TEXT,
  pdf_generiert_at TIMESTAMPTZ,
  pdf_status TEXT DEFAULT 'ausstehend' CHECK (pdf_status IN (
    'ausstehend', 'in_bearbeitung', 'fertig', 'fehler'
  )),
  pdf_fehler TEXT,
  formular_daten JSONB,
  notizen TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(service_typ, service_id, formular_typ)
);

CREATE INDEX IF NOT EXISTS idx_formulare_user ON formulare(user_id);
CREATE INDEX IF NOT EXISTS idx_formulare_service ON formulare(service_typ, service_id);
CREATE INDEX IF NOT EXISTS idx_formulare_rechnung ON formulare(rechnung_id);
CREATE INDEX IF NOT EXISTS idx_formulare_monat ON formulare(abrechnungs_monat);
CREATE INDEX IF NOT EXISTS idx_formulare_pdf_status ON formulare(pdf_status)
  WHERE pdf_status != 'fertig';

-- ============================================================
-- BUCHHALTUNG
-- ============================================================

-- 21. konten
CREATE TABLE IF NOT EXISTS konten (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  kontonummer INTEGER NOT NULL,
  bezeichnung TEXT NOT NULL,
  beschreibung TEXT,
  kategorie TEXT,
  kontenklasse INTEGER GENERATED ALWAYS AS (kontonummer / 1000) STORED,
  ist_aktiv BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, kontonummer)
);

CREATE INDEX IF NOT EXISTS idx_konten_user ON konten(user_id);
CREATE INDEX IF NOT EXISTS idx_konten_nummer ON konten(kontonummer);

-- 22. buchungs_vorlagen
CREATE TABLE IF NOT EXISTS buchungs_vorlagen (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  geschaeftsfall_id TEXT NOT NULL,
  bezeichnung TEXT NOT NULL,
  soll_konto INTEGER NOT NULL,
  haben_konto INTEGER NOT NULL,
  mwst_konto INTEGER,
  mwst_satz DECIMAL(4,2),
  zahlungsweg TEXT CHECK (zahlungsweg IN ('kasse', 'bank', 'privat', 'alle')),
  belegordner TEXT,
  auto_trigger TEXT CHECK (auto_trigger IN (
    'rechnung_erstellt_kunde',
    'rechnung_erstellt_heineken',
    'zahlung_eingegangen_kunde',
    'zahlung_eingegangen_heineken',
    'mwst_abrechnung',
    NULL
  )),
  ist_aktiv BOOLEAN DEFAULT TRUE,
  notizen TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, geschaeftsfall_id, zahlungsweg)
);

CREATE INDEX IF NOT EXISTS idx_buchungs_vorlagen_user ON buchungs_vorlagen(user_id);
CREATE INDEX IF NOT EXISTS idx_buchungs_vorlagen_trigger ON buchungs_vorlagen(auto_trigger)
  WHERE auto_trigger IS NOT NULL;

-- 23. buchungen
CREATE TABLE IF NOT EXISTS buchungen (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  datum DATE NOT NULL DEFAULT CURRENT_DATE,
  belegnummer TEXT,
  vorlage_id UUID REFERENCES buchungs_vorlagen(id) ON DELETE SET NULL,
  soll_konto INTEGER NOT NULL,
  haben_konto INTEGER NOT NULL,
  mwst_konto INTEGER,
  betrag_netto DECIMAL(10,2) NOT NULL,
  mwst_satz DECIMAL(4,2) NOT NULL DEFAULT 0,
  mwst_betrag DECIMAL(10,2) NOT NULL DEFAULT 0,
  betrag_brutto DECIMAL(10,2) NOT NULL,
  beschreibung TEXT NOT NULL,
  zahlungsweg TEXT CHECK (zahlungsweg IN ('kasse', 'bank', 'privat')),
  belegordner TEXT,
  beleg_typ TEXT CHECK (beleg_typ IN ('rechnung', 'eingang', 'lohn', 'mwst', 'sonstiges')),
  beleg_id UUID,
  geschaeftsjahr INTEGER NOT NULL DEFAULT EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER,
  monat INTEGER GENERATED ALWAYS AS (EXTRACT(MONTH FROM datum)::INTEGER) STORED,
  quartal INTEGER GENERATED ALWAYS AS (EXTRACT(QUARTER FROM datum)::INTEGER) STORED,
  ist_storniert BOOLEAN DEFAULT FALSE,
  storno_von_id UUID REFERENCES buchungen(id) ON DELETE SET NULL,
  notizen TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_buchungen_user ON buchungen(user_id);
CREATE INDEX IF NOT EXISTS idx_buchungen_datum ON buchungen(datum DESC);
CREATE INDEX IF NOT EXISTS idx_buchungen_konto_soll ON buchungen(soll_konto);
CREATE INDEX IF NOT EXISTS idx_buchungen_konto_haben ON buchungen(haben_konto);
CREATE INDEX IF NOT EXISTS idx_buchungen_beleg ON buchungen(beleg_typ, beleg_id);
CREATE INDEX IF NOT EXISTS idx_buchungen_periode ON buchungen(geschaeftsjahr, quartal, monat);

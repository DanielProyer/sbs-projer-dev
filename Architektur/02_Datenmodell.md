# Datenmodell - SBS Projer App

**Stand**: 12.02.2026
**Datenbank**: PostgreSQL (Supabase)
**Basierend auf**: Geschäftsabläufe, Excel-Analyse, Heineken-Preisstruktur

---

## ÜBERSICHT TABELLEN

| # | Tabelle | Beschreibung |
|---|---------|-------------|
| **STAMMDATEN** | | |
| 1 | `user_profiles` | Erweiterte Benutzerprofile (Franchise-Partner) |
| 2 | `regionen` | Geografische Regionen (später mit GIS-Polygonen) |
| 3 | `betriebe` | Kunden (Restaurants, Hotels, Bars) |
| 4 | `betrieb_kontakte` | Kontaktpersonen der Betriebe |
| 5 | `betrieb_rechnungsadressen` | Optionale abweichende Rechnungsadressen |
| **ANLAGEN** | | |
| 6 | `anlagen` | Zapfanlagen (Kern der App) |
| 7 | `bierleitungen` | 1–4 Bierleitungen pro Anlage |
| 8 | `anlagen_fotos` | Bis zu 4 Fotos pro Anlage |
| **PREISE** | | |
| 9 | `preise` | Versionierbare Heineken-Preislisten |
| **SERVICES** | | |
| 10 | `reinigungen` | Reguläre Services (4-Wochen-Rhythmus) |
| 11 | `stoerungen` | Störungsbehebungen (Abrechnung via Heineken) |
| 12 | `montagen` | Montageaufträge (Stundenabrechnung) |
| 13 | `eigenauftraege` | Eigenaufträge (Pauschale via Heineken) |
| 14 | `pikett_dienste` | Pikett-Wochenenden (Pauschale) |
| **MATERIAL** | | |
| 15 | `material_kategorien` | Materialkategorien |
| 16 | `material` | Material-Inventar (lagert im Auto) |
| 17 | `material_verbrauch` | Verbrauch bei Services |
| **RECHNUNGEN** | | |
| 18 | `rechnungen` | Kunden- und Heineken-Monatsrechnungen |
| 19 | `rechnungs_positionen` | Einzelpositionen auf Rechnungen |
| **FORMULARE** | | |
| 20 | `formulare` | Heineken-PDF-Formulare (F_Störung, F_Montage, etc.) |
| **BUCHHALTUNG** | | |
| 21 | `konten` | Kontenrahmen (KMU-Standard, 61 Konten) |
| 22 | `buchungs_vorlagen` | Geschäftsfälle-Templates (Soll/Haben vordefiniert) |
| 23 | `buchungen` | Journal (Buchungssätze, auto + manuell) |

---

## HELPER FUNCTION (wird zuerst erstellt)

```sql
-- Automatisches updated_at für alle Tabellen
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

---

## 1. user_profiles

**Beschreibung**: Erweiterung des Supabase Auth Users. Ein User = ein Franchise-Partner.

```sql
CREATE TABLE user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Persönliche Informationen
  vorname TEXT NOT NULL,
  nachname TEXT NOT NULL,
  telefon TEXT,
  email TEXT,

  -- Firma
  firma_name TEXT NOT NULL,
  firma_strasse TEXT,
  firma_nr TEXT,
  firma_plz TEXT,
  firma_ort TEXT,
  uid_nummer TEXT,               -- UID-Nummer (z.B. CHE-123.456.789)
  mwst_nummer TEXT,              -- MWST-Nummer
  iban TEXT,                     -- Bankverbindung
  heineken_po_nummer TEXT,       -- Jährlich neu vergeben (z.B. 6170496129)

  -- App-Einstellungen
  default_region_id UUID,        -- FK wird später hinzugefügt (nach regionen)
  sprache TEXT DEFAULT 'de' CHECK (sprache IN ('de', 'fr', 'it')),

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TRIGGER update_user_profiles_updated_at
  BEFORE UPDATE ON user_profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- RLS
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY user_profiles_own ON user_profiles FOR ALL USING (id = auth.uid());
```

---

## 2. regionen

**Beschreibung**: Geografische Serviceregionen. Aktuell 11 Regionen für Daniel.
Später: GIS-Polygone via KML-Import (Daniel erstellt KML-Dateien in QGIS).

```sql
CREATE TABLE regionen (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  name TEXT NOT NULL,  -- Vollständiger Name, kein Kürzel (z.B. "Flims/Laax/Falera")

  -- GIS (später via KML-Import befüllt)
  -- polygon GEOGRAPHY(POLYGON, 4326),  -- PostGIS, WGS84
  -- center_lat DECIMAL(9,6),
  -- center_lng DECIMAL(9,6),

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(user_id, name)
);

CREATE INDEX idx_regionen_user ON regionen(user_id);

CREATE TRIGGER update_regionen_updated_at
  BEFORE UPDATE ON regionen
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- RLS
ALTER TABLE regionen ENABLE ROW LEVEL SECURITY;
CREATE POLICY regionen_user_isolation ON regionen FOR ALL USING (user_id = auth.uid());

-- Initial-Daten (Daniels Regionen)
-- INSERT INTO regionen (user_id, name) VALUES
--   (..., 'Arosa'), (..., 'Chur'), (..., 'Davos'), (..., 'Domleschg'),
--   (..., 'Flims/Laax/Falera'), (..., 'Lenzerheide'), (..., 'Oberland'),
--   (..., 'Prättigau'), (..., 'Rheintal'), (..., 'Rheinwald'), (..., 'Innerschweiz');
```

---

## 3. betriebe

**Beschreibung**: Kunden (Restaurants, Hotels, Bars). Kern der Tourenplanung.

```sql
CREATE TABLE betriebe (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Basis
  name TEXT NOT NULL,
  strasse TEXT,
  nr TEXT,
  plz TEXT,
  ort TEXT,

  -- Zuordnung
  region_id UUID REFERENCES regionen(id) ON DELETE SET NULL,

  -- Kontakt (Haupt-Kontakt, Details in betrieb_kontakte)
  email TEXT,
  website TEXT,

  -- Zugang
  zugang_notizen TEXT,  -- z.B. "Schlüsselcode: 1234", "Schlüssel beim Empfang"

  -- Status
  status TEXT DEFAULT 'aktiv' CHECK (status IN ('aktiv', 'inaktiv', 'geschlossen')),
  ist_mein_kunde BOOLEAN DEFAULT TRUE,  -- FALSE = fremder Betrieb (nur Sichtbarkeit)
  ist_bergkunde BOOLEAN DEFAULT FALSE,

  -- Saisonalität (können beide aktiv sein bei Ganzjahresbetrieb mit 2 Saisons)
  ist_saisonbetrieb BOOLEAN DEFAULT FALSE,
  winter_saison_aktiv BOOLEAN DEFAULT FALSE,
  winter_start_monat INTEGER CHECK (winter_start_monat BETWEEN 1 AND 12),
  winter_ende_monat INTEGER CHECK (winter_ende_monat BETWEEN 1 AND 12),
  sommer_saison_aktiv BOOLEAN DEFAULT FALSE,
  sommer_start_monat INTEGER CHECK (sommer_start_monat BETWEEN 1 AND 12),
  sommer_ende_monat INTEGER CHECK (sommer_ende_monat BETWEEN 1 AND 12),

  -- Ruhetage (Array, z.B. ['Montag', 'Dienstag'])
  ruhetage TEXT[] DEFAULT '{}',

  -- Rechnungsstellung
  rechnungsstellung TEXT DEFAULT 'rechnung_mail' CHECK (rechnungsstellung IN (
    'barzahler',
    'rechnung_tresen',
    'rechnung_mail',
    'rechnung_post',
    'rechnung_heineken'
  )),

  -- Koordinaten (für Karte & Navigation)
  latitude DECIMAL(9,6),
  longitude DECIMAL(9,6),

  -- Ferien-Tracking
  ferien_start DATE,
  ferien_ende DATE,

  -- Notizen
  notizen TEXT,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_betriebe_user ON betriebe(user_id);
CREATE INDEX idx_betriebe_region ON betriebe(region_id);
CREATE INDEX idx_betriebe_status ON betriebe(status);
CREATE INDEX idx_betriebe_mein_kunde ON betriebe(ist_mein_kunde);
CREATE INDEX idx_betriebe_bergkunde ON betriebe(ist_bergkunde);

CREATE TRIGGER update_betriebe_updated_at
  BEFORE UPDATE ON betriebe
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- RLS
ALTER TABLE betriebe ENABLE ROW LEVEL SECURITY;
CREATE POLICY betriebe_user_isolation ON betriebe FOR ALL USING (user_id = auth.uid());
```

---

## 4. betrieb_kontakte

**Beschreibung**: Kontaktpersonen eines Betriebs. Vorbereitet für Smartphone-Sync.

```sql
CREATE TABLE betrieb_kontakte (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  betrieb_id UUID NOT NULL REFERENCES betriebe(id) ON DELETE CASCADE,

  -- Kontaktdaten
  vorname TEXT,
  nachname TEXT NOT NULL,
  funktion TEXT,  -- z.B. "Geschäftsführer", "Servicechef"
  telefon TEXT,
  email TEXT,

  -- Smartphone-Sync Vorbereitung (E.164 Format für eindeutige Zuordnung)
  telefon_normalized TEXT,      -- E.164 Format: +41791234567
  phone_contact_id TEXT,        -- ID aus Smartphone-Kontakten (nach Sync)
  phone_last_synced_at TIMESTAMPTZ,

  -- Bevorzugte Kontaktmethode
  kontakt_methode TEXT DEFAULT 'telefon' CHECK (kontakt_methode IN (
    'telefon', 'whatsapp', 'email', 'sms'
  )),

  ist_hauptkontakt BOOLEAN DEFAULT FALSE,

  notizen TEXT,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_betrieb_kontakte_betrieb ON betrieb_kontakte(betrieb_id);
CREATE INDEX idx_betrieb_kontakte_user ON betrieb_kontakte(user_id);
CREATE INDEX idx_betrieb_kontakte_telefon ON betrieb_kontakte(telefon_normalized);

CREATE TRIGGER update_betrieb_kontakte_updated_at
  BEFORE UPDATE ON betrieb_kontakte
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- RLS
ALTER TABLE betrieb_kontakte ENABLE ROW LEVEL SECURITY;
CREATE POLICY betrieb_kontakte_user_isolation ON betrieb_kontakte FOR ALL USING (user_id = auth.uid());
```

---

## 5. betrieb_rechnungsadressen

**Beschreibung**: Optionale abweichende Rechnungsadresse (nur für eigene Kunden).

```sql
CREATE TABLE betrieb_rechnungsadressen (
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

  UNIQUE(betrieb_id)  -- Maximal eine Rechnungsadresse pro Betrieb
);

CREATE INDEX idx_betrieb_rechnungsadressen_betrieb ON betrieb_rechnungsadressen(betrieb_id);

-- RLS
ALTER TABLE betrieb_rechnungsadressen ENABLE ROW LEVEL SECURITY;
CREATE POLICY betrieb_rechnungsadressen_user_isolation ON betrieb_rechnungsadressen FOR ALL USING (user_id = auth.uid());
```

---

## 6. anlagen

**Beschreibung**: Zapfanlagen (Kern der App). Detaillierte technische Erfassung.

```sql
CREATE TABLE anlagen (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  betrieb_id UUID NOT NULL REFERENCES betriebe(id) ON DELETE CASCADE,

  -- Identifikation
  bezeichnung TEXT,       -- z.B. "Restaurant", "Bar", "Terrasse"
  seriennummer TEXT,

  -- Technische Details
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

  -- Booster / Backpython
  backpython BOOLEAN DEFAULT FALSE,
  booster BOOLEAN DEFAULT FALSE,

  -- Kühlsystem
  vorkuehler TEXT DEFAULT 'keiner' CHECK (vorkuehler IN (
    'keiner', 'Fasskühler', 'Kühlzelle', 'Buffet'
  )),
  durchlaufkuehler TEXT CHECK (durchlaufkuehler IN (
    'H60', 'H75', 'H100', 'H120', 'H150', 'H200',
    'Fremdkühler', 'Fremdkühler Sat.', 'keiner'
  )),
  letzter_wasserwechsel DATE,  -- Wird via Trigger bei Reinigung aktualisiert

  -- Gas / CO2
  gas_typ_1 TEXT CHECK (gas_typ_1 IN ('Aligal2', 'Aligal13', 'Kompressor')),
  gas_typ_2 TEXT CHECK (gas_typ_2 IN ('Aligal2', 'Aligal13', 'Kompressor')),
  hauptdruck_bar DECIMAL(3,1),
  hat_niederdruck BOOLEAN DEFAULT FALSE,  -- Separate Niederdruckmanometer pro Leitung

  CONSTRAINT check_gas_typen_different CHECK (
    gas_typ_1 IS NULL OR gas_typ_2 IS NULL OR gas_typ_1 != gas_typ_2
  ),

  -- Servicezeiten (für Routenplanung)
  servicezeit_morgen_ab TIME,
  servicezeit_morgen_bis TIME,
  servicezeit_nachmittag_ab TIME,
  servicezeit_nachmittag_bis TIME,

  -- Service-Rhythmus
  reinigung_rhythmus TEXT DEFAULT '4-Wochen' CHECK (reinigung_rhythmus IN (
    '4-Wochen', '6-Wochen', '2-Monate', '3-Monate',
    '6-Monate', 'Jährlich', 'auf-Abruf', 'Selbstreiniger'
  )),

  -- Service-Tracking
  letzte_reinigung DATE,
  naechste_reinigung DATE,  -- Berechnet via Trigger

  -- Status
  status TEXT DEFAULT 'aktiv' CHECK (status IN ('aktiv', 'inaktiv', 'stillgelegt')),

  notizen TEXT,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_anlagen_user ON anlagen(user_id);
CREATE INDEX idx_anlagen_betrieb ON anlagen(betrieb_id);
CREATE INDEX idx_anlagen_status ON anlagen(status);
CREATE INDEX idx_anlagen_naechste_reinigung ON anlagen(naechste_reinigung);

CREATE TRIGGER update_anlagen_updated_at
  BEFORE UPDATE ON anlagen
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- RLS
ALTER TABLE anlagen ENABLE ROW LEVEL SECURITY;
CREATE POLICY anlagen_user_isolation ON anlagen FOR ALL USING (user_id = auth.uid());

-- Trigger: naechste_reinigung automatisch berechnen
CREATE OR REPLACE FUNCTION calculate_naechste_reinigung()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.letzte_reinigung IS NOT NULL THEN
    NEW.naechste_reinigung := NEW.letzte_reinigung + (
      CASE NEW.reinigung_rhythmus
        WHEN '4-Wochen'    THEN INTERVAL '4 weeks'
        WHEN '6-Wochen'    THEN INTERVAL '6 weeks'
        WHEN '2-Monate'    THEN INTERVAL '2 months'
        WHEN '3-Monate'    THEN INTERVAL '3 months'
        WHEN '6-Monate'    THEN INTERVAL '6 months'
        WHEN 'Jährlich'    THEN INTERVAL '1 year'
        ELSE NULL
      END
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER anlagen_naechste_reinigung
  BEFORE INSERT OR UPDATE OF letzte_reinigung, reinigung_rhythmus ON anlagen
  FOR EACH ROW EXECUTE FUNCTION calculate_naechste_reinigung();
```

---

## 7. bierleitungen

**Beschreibung**: 1–4 Bierleitungen pro Anlage mit Biersorte, Hahn-Typ und Druck.

```sql
CREATE TABLE bierleitungen (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  anlage_id UUID NOT NULL REFERENCES anlagen(id) ON DELETE CASCADE,

  leitungs_nummer INTEGER NOT NULL CHECK (leitungs_nummer BETWEEN 1 AND 4),
  biersorte TEXT,        -- z.B. "Heineken", "Desperados", "Orion", "Wein Rot"
  hahn_typ TEXT,         -- z.B. "Standard", "Kompensator", "Kugelkopf"
  niederdruck_bar DECIMAL(3,1),  -- Nur wenn anlage.hat_niederdruck = TRUE
  hat_fob_stop BOOLEAN DEFAULT FALSE,

  UNIQUE(anlage_id, leitungs_nummer)
);

CREATE INDEX idx_bierleitungen_anlage ON bierleitungen(anlage_id);
CREATE INDEX idx_bierleitungen_user ON bierleitungen(user_id);

-- RLS
ALTER TABLE bierleitungen ENABLE ROW LEVEL SECURITY;
CREATE POLICY bierleitungen_user_isolation ON bierleitungen FOR ALL USING (user_id = auth.uid());
```

---

## 8. anlagen_fotos

**Beschreibung**: Bis zu 4 Fotos pro Anlage (Supabase Storage).

```sql
CREATE TABLE anlagen_fotos (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  anlage_id UUID NOT NULL REFERENCES anlagen(id) ON DELETE CASCADE,

  foto_nummer INTEGER NOT NULL CHECK (foto_nummer BETWEEN 1 AND 4),
  foto_url TEXT NOT NULL,    -- Supabase Storage Pfad
  beschreibung TEXT,

  created_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(anlage_id, foto_nummer)
);

CREATE INDEX idx_anlagen_fotos_anlage ON anlagen_fotos(anlage_id);

-- RLS
ALTER TABLE anlagen_fotos ENABLE ROW LEVEL SECURITY;
CREATE POLICY anlagen_fotos_user_isolation ON anlagen_fotos FOR ALL USING (user_id = auth.uid());
```

---

## 9. preise

**Beschreibung**: Versionierbare Heineken-Preislisten. Historische Preise bleiben erhalten.

```sql
CREATE TABLE preise (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Gültigkeitszeitraum
  gueltig_ab DATE NOT NULL,
  gueltig_bis DATE,

  -- Allgemeine Werte
  mwst_satz DECIMAL(4,2) NOT NULL DEFAULT 8.10,          -- 8.1%
  bergkunden_zuschlag DECIMAL(10,2) NOT NULL DEFAULT 180.00,

  -- Grundtarife Reinigung (Heineken-Preisstruktur)
  grundtarif_reinigung_bier DECIMAL(10,2) NOT NULL,      -- Heineken/Desperados eigen
  grundtarif_reinigung_orion DECIMAL(10,2) NOT NULL,     -- Orion-Anlage
  grundtarif_heigenie DECIMAL(10,2) NOT NULL,            -- Offenausschank Heigenie
  grundtarif_reinigung_fremd DECIMAL(10,2) NOT NULL,     -- Fremdbier/Mineralwasser
  grundtarif_wein DECIMAL(10,2) NOT NULL,                -- Wein (= gleich wie fremd)

  -- Zusatzhähne (Preis pro zusätzlichem Hahn)
  zusatz_hahn_eigen DECIMAL(10,2) NOT NULL,
  zusatz_hahn_orion DECIMAL(10,2) NOT NULL,
  zusatz_hahn_fremd DECIMAL(10,2) NOT NULL,
  zusatz_hahn_wein DECIMAL(10,2) NOT NULL,
  zusatz_hahn_anderer_standort DECIMAL(10,2) NOT NULL,

  -- Eigenaufträge
  eigenauftrag_pauschale DECIMAL(10,2) NOT NULL DEFAULT 30.00,

  -- Montagen
  montage_stundensatz DECIMAL(10,2) NOT NULL,

  -- Pikett
  pikett_pauschale DECIMAL(10,2) NOT NULL DEFAULT 160.00,         -- Pro Wochenende (Sa+So = 2×80)
  pikett_feiertag_zuschlag DECIMAL(10,2) NOT NULL DEFAULT 80.00,  -- Pro Feiertag zusätzlich

  -- Eröffnungen / Endreinigungen
  eroeffnung_preis_normal DECIMAL(10,2) NOT NULL DEFAULT 60.00,
  eroeffnung_preis_bergkunde DECIMAL(10,2) NOT NULL DEFAULT 135.00,

  -- Störungspreise (5 Bereiche × Normal/Bergkunde, exkl. MWST)
  -- Bereich 1: Zapfhahn / Zapfkopf
  stoerung_1_normal DECIMAL(10,2) NOT NULL DEFAULT 55.00,
  stoerung_1_bergkunde DECIMAL(10,2) NOT NULL DEFAULT 130.00,
  -- Bereich 2: Leitungen
  stoerung_2_normal DECIMAL(10,2) NOT NULL DEFAULT 55.00,
  stoerung_2_bergkunde DECIMAL(10,2) NOT NULL DEFAULT 130.00,
  -- Bereich 3: Kühlsystem
  stoerung_3_normal DECIMAL(10,2) NOT NULL DEFAULT 90.00,
  stoerung_3_bergkunde DECIMAL(10,2) NOT NULL DEFAULT 165.00,
  -- Bereich 4: Fass / Fassanschluss
  stoerung_4_normal DECIMAL(10,2) NOT NULL DEFAULT 45.00,
  stoerung_4_bergkunde DECIMAL(10,2) NOT NULL DEFAULT 120.00,
  -- Bereich 5: CO2 / Gas
  stoerung_5_normal DECIMAL(10,2) NOT NULL DEFAULT 45.00,
  stoerung_5_bergkunde DECIMAL(10,2) NOT NULL DEFAULT 120.00,

  -- Störung: Anfahrt (gilt für Normal- und Bergkunden gleichermassen)
  stoerung_anfahrt_pauschale DECIMAL(10,2) NOT NULL DEFAULT 60.00,  -- Pauschal für < 80 km
  stoerung_anfahrt_km_grenze INTEGER NOT NULL DEFAULT 80,           -- Grenze in km
  stoerung_anfahrt_km_satz DECIMAL(5,3) NOT NULL DEFAULT 0.720,    -- CHF/km ab Grenze

  -- Störung: Wochenendzuschlag
  stoerung_wochenende_zuschlag DECIMAL(10,2) NOT NULL DEFAULT 100.00,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  CONSTRAINT preise_zeitraum_check CHECK (gueltig_bis IS NULL OR gueltig_bis > gueltig_ab)
);

CREATE INDEX idx_preise_user ON preise(user_id);
CREATE INDEX idx_preise_gueltig ON preise(gueltig_ab, gueltig_bis);

-- RLS
ALTER TABLE preise ENABLE ROW LEVEL SECURITY;
CREATE POLICY preise_user_isolation ON preise FOR ALL USING (user_id = auth.uid());
```

---

## 10. reinigungen

**Beschreibung**: Reguläre Services. Preise werden automatisch via Trigger berechnet.

```sql
CREATE TABLE reinigungen (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  anlage_id UUID NOT NULL REFERENCES anlagen(id) ON DELETE CASCADE,
  betrieb_id UUID NOT NULL REFERENCES betriebe(id) ON DELETE CASCADE,

  -- Zeitpunkt
  datum DATE NOT NULL,
  uhrzeit_start TIME,
  uhrzeit_ende TIME,
  dauer_minuten INTEGER GENERATED ALWAYS AS (
    EXTRACT(EPOCH FROM (uhrzeit_ende - uhrzeit_start)) / 60
  ) STORED,

  -- Checkliste: Auto-populated aus Anlagendaten (READ-ONLY in App)
  hat_durchlaufkuehler BOOLEAN NOT NULL DEFAULT FALSE,
  hat_buffetanstich BOOLEAN NOT NULL DEFAULT FALSE,
  hat_kuehlkeller BOOLEAN NOT NULL DEFAULT FALSE,
  hat_fasskuehler BOOLEAN NOT NULL DEFAULT FALSE,

  -- Checkliste: Manuelle Punkte (12 Punkte)
  begleitkuehlung_kontrolliert BOOLEAN DEFAULT FALSE,
  installation_allgemein_kontrolliert BOOLEAN DEFAULT FALSE,
  aligal_anschluesse_kontrolliert BOOLEAN DEFAULT FALSE,
  durchlaufkuehler_ausgeblasen BOOLEAN DEFAULT FALSE,
  wasserstand_kontrolliert BOOLEAN DEFAULT FALSE,
  wasser_gewechselt BOOLEAN DEFAULT FALSE,        -- Trigger → anlagen.letzter_wasserwechsel
  leitung_wasser_vorgespuelt BOOLEAN DEFAULT FALSE,
  leitungsreinigung_reinigungsmittel BOOLEAN DEFAULT FALSE,
  foerderdruck_kontrolliert BOOLEAN DEFAULT FALSE,
  zapfhahn_zerlegt_gereinigt BOOLEAN DEFAULT FALSE,
  zapfkopf_zerlegt_gereinigt BOOLEAN DEFAULT FALSE,
  servicekarte_ausgefuellt BOOLEAN DEFAULT FALSE,

  -- Unterschriften (Base64 oder Storage URL)
  unterschrift_techniker TEXT,
  unterschrift_kunde TEXT,
  unterschrift_kunde_name TEXT,

  -- Notizen
  notizen TEXT,

  -- Preisberechnung (via Trigger befüllt)
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

  -- Status
  status TEXT DEFAULT 'offen' CHECK (status IN (
    'offen', 'abgeschlossen', 'abgerechnet', 'storniert'
  )),

  -- Sync
  ist_synced BOOLEAN DEFAULT FALSE,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_reinigungen_user ON reinigungen(user_id);
CREATE INDEX idx_reinigungen_anlage ON reinigungen(anlage_id);
CREATE INDEX idx_reinigungen_betrieb ON reinigungen(betrieb_id);
CREATE INDEX idx_reinigungen_datum ON reinigungen(datum DESC);
CREATE INDEX idx_reinigungen_status ON reinigungen(status);

CREATE TRIGGER update_reinigungen_updated_at
  BEFORE UPDATE ON reinigungen
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- RLS
ALTER TABLE reinigungen ENABLE ROW LEVEL SECURITY;
CREATE POLICY reinigungen_user_isolation ON reinigungen FOR ALL USING (user_id = auth.uid());
```

### Trigger: Checkliste Auto-Populate

```sql
CREATE OR REPLACE FUNCTION populate_reinigung_checklist()
RETURNS TRIGGER AS $$
DECLARE v_anlage anlagen%ROWTYPE;
BEGIN
  SELECT * INTO v_anlage FROM anlagen WHERE id = NEW.anlage_id;
  NEW.hat_durchlaufkuehler := (v_anlage.durchlaufkuehler IS NOT NULL AND v_anlage.durchlaufkuehler != 'keiner');
  NEW.hat_buffetanstich    := (v_anlage.typ_anlage = 'Buffetanstich');
  NEW.hat_kuehlkeller      := (v_anlage.vorkuehler = 'Kühlzelle');
  NEW.hat_fasskuehler      := (v_anlage.vorkuehler = 'Fasskühler');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER reinigung_checklist_populate
  BEFORE INSERT OR UPDATE OF anlage_id ON reinigungen
  FOR EACH ROW EXECUTE FUNCTION populate_reinigung_checklist();
```

### Trigger: Preisberechnung

```sql
CREATE OR REPLACE FUNCTION calculate_reinigung_preis()
RETURNS TRIGGER AS $$
DECLARE
  v_preisliste preise%ROWTYPE;
  v_betrieb betriebe%ROWTYPE;
  v_zusatz_haehne INTEGER;
BEGIN
  SELECT * INTO v_preisliste FROM preise
  WHERE user_id = NEW.user_id AND gueltig_ab <= NEW.datum
    AND (gueltig_bis IS NULL OR gueltig_bis >= NEW.datum)
  ORDER BY gueltig_ab DESC LIMIT 1;

  IF v_preisliste.id IS NULL THEN
    RAISE EXCEPTION 'Keine Preisliste für Datum % gefunden', NEW.datum;
  END IF;

  SELECT * INTO v_betrieb FROM betriebe WHERE id = NEW.betrieb_id;

  NEW.preisliste_id := v_preisliste.id;
  NEW.ist_bergkunde := COALESCE(v_betrieb.ist_bergkunde, FALSE);

  -- Hähne aus bierleitungen ermitteln
  SELECT
    COUNT(*) FILTER (WHERE biersorte ILIKE ANY(ARRAY['%Heineken%','%Desperados%'])),
    COUNT(*) FILTER (WHERE biersorte ILIKE '%Orion%'),
    COUNT(*) FILTER (WHERE biersorte ILIKE '%Wein%'),
    COUNT(*) FILTER (WHERE
      biersorte NOT ILIKE ANY(ARRAY['%Heineken%','%Desperados%','%Orion%','%Wein%']))
  INTO NEW.anzahl_haehne_eigen, NEW.anzahl_haehne_orion,
       NEW.anzahl_haehne_wein, NEW.anzahl_haehne_fremd
  FROM bierleitungen WHERE anlage_id = NEW.anlage_id;

  NEW.anzahl_haehne_anderer_standort := COALESCE(NEW.anzahl_haehne_anderer_standort, 0);

  -- Grundtarif und Zusatzhähne
  CASE NEW.service_typ
    WHEN 'reinigung_bier' THEN
      NEW.preis_grundtarif := v_preisliste.grundtarif_reinigung_bier;
      NEW.preis_zusatz_haehne := GREATEST(NEW.anzahl_haehne_eigen - 1, 0) * v_preisliste.zusatz_hahn_eigen;
    WHEN 'reinigung_orion' THEN
      NEW.preis_grundtarif := v_preisliste.grundtarif_reinigung_orion;
      NEW.preis_zusatz_haehne := GREATEST(NEW.anzahl_haehne_orion - 1, 0) * v_preisliste.zusatz_hahn_orion;
    WHEN 'heigenie' THEN
      NEW.preis_grundtarif := v_preisliste.grundtarif_heigenie;
      NEW.preis_zusatz_haehne := 0;
    WHEN 'reinigung_fremd' THEN
      NEW.preis_grundtarif := v_preisliste.grundtarif_reinigung_fremd;
      NEW.preis_zusatz_haehne := GREATEST(NEW.anzahl_haehne_fremd - 1, 0) * v_preisliste.zusatz_hahn_fremd;
    WHEN 'wein' THEN
      NEW.preis_grundtarif := v_preisliste.grundtarif_wein;
      NEW.preis_zusatz_haehne := GREATEST(NEW.anzahl_haehne_wein - 1, 0) * v_preisliste.zusatz_hahn_wein;
    ELSE
      NEW.preis_grundtarif := 0;
      NEW.preis_zusatz_haehne := 0;
  END CASE;

  -- Anderer Standort Zusatz
  NEW.preis_zusatz_haehne := COALESCE(NEW.preis_zusatz_haehne, 0) +
    (NEW.anzahl_haehne_anderer_standort * v_preisliste.zusatz_hahn_anderer_standort);

  -- Bergkunde
  NEW.bergkunden_zuschlag := CASE WHEN NEW.ist_bergkunde THEN v_preisliste.bergkunden_zuschlag ELSE 0 END;

  -- Summen
  NEW.preis_netto   := COALESCE(NEW.preis_grundtarif, 0) + COALESCE(NEW.preis_zusatz_haehne, 0) + NEW.bergkunden_zuschlag;
  NEW.mwst_satz     := v_preisliste.mwst_satz;
  NEW.preis_mwst    := ROUND(NEW.preis_netto * (NEW.mwst_satz / 100), 2);
  NEW.preis_brutto  := NEW.preis_netto + NEW.preis_mwst;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER reinigung_preis_berechnung
  BEFORE INSERT OR UPDATE ON reinigungen
  FOR EACH ROW EXECUTE FUNCTION calculate_reinigung_preis();
```

### Trigger: Wasserwechsel-Datum in Anlage aktualisieren

```sql
CREATE OR REPLACE FUNCTION update_anlage_wasserwechsel()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.wasser_gewechselt = TRUE AND (OLD IS NULL OR OLD.wasser_gewechselt = FALSE) THEN
    UPDATE anlagen SET letzter_wasserwechsel = NEW.datum, updated_at = NOW()
    WHERE id = NEW.anlage_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER reinigung_wasserwechsel_update
  AFTER INSERT OR UPDATE ON reinigungen
  FOR EACH ROW EXECUTE FUNCTION update_anlage_wasserwechsel();
```

### Trigger: Letzte Reinigung in Anlage aktualisieren

```sql
CREATE OR REPLACE FUNCTION update_letzte_reinigung()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'abgeschlossen' THEN
    UPDATE anlagen SET letzte_reinigung = NEW.datum, updated_at = NOW()
    WHERE id = NEW.anlage_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER reinigung_letzte_reinigung_update
  AFTER INSERT OR UPDATE OF status ON reinigungen
  FOR EACH ROW WHEN (NEW.status = 'abgeschlossen')
  EXECUTE FUNCTION update_letzte_reinigung();
```

---

## 11. stoerungen

**Beschreibung**: Störungsbehebungen. Abrechnung über Monatsrechnung an Heineken.
Störungsnummer ist Pflicht für Abrechnung.

```sql
CREATE TABLE stoerungen (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  anlage_id UUID NOT NULL REFERENCES anlagen(id) ON DELETE CASCADE,
  betrieb_id UUID NOT NULL REFERENCES betriebe(id) ON DELETE CASCADE,

  -- Störungsnummer (von Heineken vergeben – Pflicht!)
  stoerungsnummer TEXT NOT NULL,
  referenz_nr TEXT,  -- Heineken-Formular Referenz: {betrieb_heineken_nr}_{YYYY}_{MM}_{DD}

  -- Zeitpunkt
  datum DATE NOT NULL,
  uhrzeit_start TIME,
  uhrzeit_ende TIME,
  dauer_minuten INTEGER GENERATED ALWAYS AS (
    EXTRACT(EPOCH FROM (uhrzeit_ende - uhrzeit_start)) / 60
  ) STORED,

  -- Anlagetyp (für Dokumentation und Abrechnung)
  anlage_typ TEXT CHECK (anlage_typ IN (
    'konventionell', 'heigenie', 'orion', 'david'
  )),

  -- Beschreibung
  problem_beschreibung TEXT NOT NULL,
  loesung_beschreibung TEXT,

  -- Pikett-Einsatz?
  ist_pikett_einsatz BOOLEAN DEFAULT FALSE,

  -- Status
  status TEXT DEFAULT 'offen' CHECK (status IN (
    'offen', 'in_bearbeitung', 'behoben', 'nicht_behebbar'
  )),

  -- Preisberechnung (via Trigger befüllt)
  stoerung_bereich INTEGER CHECK (stoerung_bereich BETWEEN 1 AND 5),
  -- 1=Zapfhahn/Zapfkopf, 2=Leitungen, 3=Kühlsystem, 4=Fass/Fassanschluss, 5=CO2/Gas

  preisliste_id UUID REFERENCES preise(id),
  ist_bergkunde BOOLEAN DEFAULT FALSE,
  anfahrt_km INTEGER DEFAULT 0,                          -- Anfahrtsweg in km (0 = Pauschale)
  ist_wochenende BOOLEAN DEFAULT FALSE,                  -- Wochenendeinsatz (+100 CHF)
  komplexitaet_zuschlag DECIMAL(10,2) DEFAULT 0.00,     -- Manueller Aufwandszuschlag (0–100 CHF)

  preis_basis DECIMAL(10,2),              -- Störungsbasis je Bereich (normal oder Bergkunde)
  preis_anfahrt DECIMAL(10,2),           -- Anfahrtspauschale oder km-Betrag (Normal + Bergkunde)
  preis_wochenende DECIMAL(10,2) DEFAULT 0.00,
  preis_netto DECIMAL(10,2),             -- basis + anfahrt + wochenende + komplexitaet
  mwst_satz DECIMAL(4,2),
  preis_mwst DECIMAL(10,2),
  preis_brutto DECIMAL(10,2),

  -- Material (bis zu 5 ausgetauschte Artikel, inline für Offline-Erfassung)
  -- → Trigger erstellt automatisch material_verbrauch-Einträge und trägt Auto-Lager aus
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

  -- Abrechnung (Monatsrechnung an Heineken)
  abrechnungs_monat DATE,   -- '2026-02-01' = Februar 2026
  abgerechnet BOOLEAN DEFAULT FALSE,

  notizen TEXT,
  ist_synced BOOLEAN DEFAULT FALSE,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_stoerungen_user ON stoerungen(user_id);
CREATE INDEX idx_stoerungen_anlage ON stoerungen(anlage_id);
CREATE INDEX idx_stoerungen_betrieb ON stoerungen(betrieb_id);
CREATE INDEX idx_stoerungen_datum ON stoerungen(datum DESC);
CREATE INDEX idx_stoerungen_abrechnungsmonat ON stoerungen(abrechnungs_monat);
CREATE INDEX idx_stoerungen_bereich ON stoerungen(stoerung_bereich);
CREATE INDEX idx_stoerungen_anlage_typ ON stoerungen(anlage_typ);

CREATE TRIGGER update_stoerungen_updated_at
  BEFORE UPDATE ON stoerungen
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- RLS
ALTER TABLE stoerungen ENABLE ROW LEVEL SECURITY;
CREATE POLICY stoerungen_user_isolation ON stoerungen FOR ALL USING (user_id = auth.uid());
```

### Trigger: Störungs-Preisberechnung

```sql
CREATE OR REPLACE FUNCTION calculate_stoerung_preis()
RETURNS TRIGGER AS $$
DECLARE
  v_preisliste preise%ROWTYPE;
  v_betrieb betriebe%ROWTYPE;
  v_basis DECIMAL(10,2);
  v_anfahrt DECIMAL(10,2);
BEGIN
  -- Nur berechnen wenn Bereich angegeben
  IF NEW.stoerung_bereich IS NULL THEN
    RETURN NEW;
  END IF;

  -- Aktuelle Preisliste laden
  SELECT * INTO v_preisliste FROM preise
  WHERE user_id = NEW.user_id AND gueltig_ab <= NEW.datum
    AND (gueltig_bis IS NULL OR gueltig_bis >= NEW.datum)
  ORDER BY gueltig_ab DESC LIMIT 1;

  IF v_preisliste.id IS NULL THEN
    RAISE EXCEPTION 'Keine Preisliste für Datum % gefunden', NEW.datum;
  END IF;

  SELECT * INTO v_betrieb FROM betriebe WHERE id = NEW.betrieb_id;

  NEW.preisliste_id := v_preisliste.id;
  NEW.ist_bergkunde := COALESCE(v_betrieb.ist_bergkunde, FALSE);
  NEW.mwst_satz := v_preisliste.mwst_satz;

  -- Basispreis je Bereich (Normal vs. Bergkunde)
  v_basis := CASE NEW.stoerung_bereich
    WHEN 1 THEN CASE WHEN NEW.ist_bergkunde THEN v_preisliste.stoerung_1_bergkunde ELSE v_preisliste.stoerung_1_normal END
    WHEN 2 THEN CASE WHEN NEW.ist_bergkunde THEN v_preisliste.stoerung_2_bergkunde ELSE v_preisliste.stoerung_2_normal END
    WHEN 3 THEN CASE WHEN NEW.ist_bergkunde THEN v_preisliste.stoerung_3_bergkunde ELSE v_preisliste.stoerung_3_normal END
    WHEN 4 THEN CASE WHEN NEW.ist_bergkunde THEN v_preisliste.stoerung_4_bergkunde ELSE v_preisliste.stoerung_4_normal END
    WHEN 5 THEN CASE WHEN NEW.ist_bergkunde THEN v_preisliste.stoerung_5_bergkunde ELSE v_preisliste.stoerung_5_normal END
    ELSE 0
  END;

  NEW.preis_basis := v_basis;

  -- Anfahrt (gilt für Normal- und Bergkunden gleichermassen)
  IF COALESCE(NEW.anfahrt_km, 0) < v_preisliste.stoerung_anfahrt_km_grenze THEN
    v_anfahrt := v_preisliste.stoerung_anfahrt_pauschale;
  ELSE
    v_anfahrt := ROUND(NEW.anfahrt_km * v_preisliste.stoerung_anfahrt_km_satz, 2);
  END IF;

  NEW.preis_anfahrt := v_anfahrt;

  -- Wochenendzuschlag
  NEW.preis_wochenende := CASE WHEN NEW.ist_wochenende THEN v_preisliste.stoerung_wochenende_zuschlag ELSE 0.00 END;

  -- Netto = Basis + Anfahrt + Wochenende + Komplexität
  NEW.preis_netto := v_basis + v_anfahrt + COALESCE(NEW.preis_wochenende, 0) + COALESCE(NEW.komplexitaet_zuschlag, 0);

  -- MWST und Brutto
  NEW.preis_mwst   := ROUND(NEW.preis_netto * (NEW.mwst_satz / 100), 2);
  NEW.preis_brutto := NEW.preis_netto + NEW.preis_mwst;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER stoerung_preis_berechnung
  BEFORE INSERT OR UPDATE OF stoerung_bereich, anfahrt_km, ist_wochenende, komplexitaet_zuschlag ON stoerungen
  FOR EACH ROW EXECUTE FUNCTION calculate_stoerung_preis();
```

### Trigger: Material-Sync (Lagerbestand automatisch austragen)

```sql
-- Synchronisiert die 5 inline Material-Slots mit material_verbrauch
-- → Löscht alte Einträge für diese Störung, erstellt neue
-- → material_verbrauch-Trigger zieht Bestand automatisch ab/auf
CREATE OR REPLACE FUNCTION sync_stoerung_material()
RETURNS TRIGGER AS $$
DECLARE
  v_stoerung_id UUID;
BEGIN
  v_stoerung_id := NEW.id;

  -- Alte material_verbrauch Einträge dieser Störung löschen (stellt Bestand wieder her)
  DELETE FROM material_verbrauch
  WHERE service_typ = 'stoerung' AND service_id = v_stoerung_id;

  -- Slot 1
  IF NEW.material_1_id IS NOT NULL AND COALESCE(NEW.material_1_menge, 0) > 0 THEN
    INSERT INTO material_verbrauch (user_id, lager_id, service_typ, service_id, menge, einheit, verbraucht_am)
    SELECT NEW.user_id, NEW.material_1_id, 'stoerung', v_stoerung_id,
           NEW.material_1_menge, l.einheit, NOW()
    FROM lager l WHERE l.id = NEW.material_1_id;
  END IF;

  -- Slot 2
  IF NEW.material_2_id IS NOT NULL AND COALESCE(NEW.material_2_menge, 0) > 0 THEN
    INSERT INTO material_verbrauch (user_id, lager_id, service_typ, service_id, menge, einheit, verbraucht_am)
    SELECT NEW.user_id, NEW.material_2_id, 'stoerung', v_stoerung_id,
           NEW.material_2_menge, l.einheit, NOW()
    FROM lager l WHERE l.id = NEW.material_2_id;
  END IF;

  -- Slot 3
  IF NEW.material_3_id IS NOT NULL AND COALESCE(NEW.material_3_menge, 0) > 0 THEN
    INSERT INTO material_verbrauch (user_id, lager_id, service_typ, service_id, menge, einheit, verbraucht_am)
    SELECT NEW.user_id, NEW.material_3_id, 'stoerung', v_stoerung_id,
           NEW.material_3_menge, l.einheit, NOW()
    FROM lager l WHERE l.id = NEW.material_3_id;
  END IF;

  -- Slot 4
  IF NEW.material_4_id IS NOT NULL AND COALESCE(NEW.material_4_menge, 0) > 0 THEN
    INSERT INTO material_verbrauch (user_id, lager_id, service_typ, service_id, menge, einheit, verbraucht_am)
    SELECT NEW.user_id, NEW.material_4_id, 'stoerung', v_stoerung_id,
           NEW.material_4_menge, l.einheit, NOW()
    FROM lager l WHERE l.id = NEW.material_4_id;
  END IF;

  -- Slot 5
  IF NEW.material_5_id IS NOT NULL AND COALESCE(NEW.material_5_menge, 0) > 0 THEN
    INSERT INTO material_verbrauch (user_id, lager_id, service_typ, service_id, menge, einheit, verbraucht_am)
    SELECT NEW.user_id, NEW.material_5_id, 'stoerung', v_stoerung_id,
           NEW.material_5_menge, l.einheit, NOW()
    FROM lager l WHERE l.id = NEW.material_5_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER stoerung_material_sync
  AFTER INSERT OR UPDATE OF
    material_1_id, material_1_menge,
    material_2_id, material_2_menge,
    material_3_id, material_3_menge,
    material_4_id, material_4_menge,
    material_5_id, material_5_menge
  ON stoerungen
  FOR EACH ROW EXECUTE FUNCTION sync_stoerung_material();
```

---

## 12. montagen

**Beschreibung**: Montageaufträge von Heineken. Stundenabrechnung.
Heigenie-Service wird ebenfalls als Montage erfasst (nicht als Reinigung).

```sql
CREATE TABLE montagen (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  anlage_id UUID REFERENCES anlagen(id) ON DELETE SET NULL,  -- Optional (Neu-Installation)
  betrieb_id UUID NOT NULL REFERENCES betriebe(id) ON DELETE CASCADE,

  -- Auftrag
  montage_typ TEXT NOT NULL CHECK (montage_typ IN (
    'neu_installation', 'umbau', 'erweiterung', 'abbau',
    'heigenie_service', 'sonstiges'
  )),
  beschreibung TEXT NOT NULL,
  referenz_nr TEXT,  -- Heineken-Formular Referenz: {betrieb_heineken_nr}_{YYYY}_{MM}_{DD}

  -- Zeitpunkt
  datum DATE NOT NULL,
  uhrzeit_start TIME,
  uhrzeit_ende TIME,
  dauer_minuten INTEGER GENERATED ALWAYS AS (
    EXTRACT(EPOCH FROM (uhrzeit_ende - uhrzeit_start)) / 60
  ) STORED,

  -- Status
  status TEXT DEFAULT 'geplant' CHECK (status IN (
    'geplant', 'in_bearbeitung', 'abgeschlossen', 'abgebrochen'
  )),

  -- Abrechnung (Stundenbasiert)
  preisliste_id UUID REFERENCES preise(id),
  stundensatz DECIMAL(10,2),           -- Aus Preisliste kopiert
  dauer_stunden DECIMAL(5,2),          -- Manuell oder aus dauer_minuten
  kosten_arbeit DECIMAL(10,2),         -- dauer_stunden × stundensatz (Material wird nicht verrechnet)

  -- Abrechnung (Monatsrechnung an Heineken)
  abrechnungs_monat DATE,
  abgerechnet BOOLEAN DEFAULT FALSE,

  -- Material (7 Inline-Slots, Lager wird per Trigger aktualisiert)
  -- Material wird nicht verrechnet, aber für Lagerführung erfasst
  -- F_Montage Formular hat 7 Art.Nr.-Zeilen → 7 Slots
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

CREATE INDEX idx_montagen_user ON montagen(user_id);
CREATE INDEX idx_montagen_anlage ON montagen(anlage_id);
CREATE INDEX idx_montagen_betrieb ON montagen(betrieb_id);
CREATE INDEX idx_montagen_datum ON montagen(datum DESC);
CREATE INDEX idx_montagen_abrechnungsmonat ON montagen(abrechnungs_monat);

CREATE TRIGGER update_montagen_updated_at
  BEFORE UPDATE ON montagen
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- RLS
ALTER TABLE montagen ENABLE ROW LEVEL SECURITY;
CREATE POLICY montagen_user_isolation ON montagen FOR ALL USING (user_id = auth.uid());

-- Trigger: Stundensatz und Arbeitskosten berechnen
CREATE OR REPLACE FUNCTION calculate_montage_kosten()
RETURNS TRIGGER AS $$
DECLARE v_preisliste preise%ROWTYPE;
BEGIN
  SELECT * INTO v_preisliste FROM preise
  WHERE user_id = NEW.user_id AND gueltig_ab <= NEW.datum
    AND (gueltig_bis IS NULL OR gueltig_bis >= NEW.datum)
  ORDER BY gueltig_ab DESC LIMIT 1;

  IF v_preisliste.id IS NOT NULL THEN
    NEW.preisliste_id := v_preisliste.id;
    NEW.stundensatz   := v_preisliste.montage_stundensatz;
  END IF;

  IF NEW.dauer_stunden IS NULL AND NEW.dauer_minuten IS NOT NULL THEN
    NEW.dauer_stunden := ROUND(NEW.dauer_minuten / 60.0, 2);
  END IF;

  IF NEW.dauer_stunden IS NOT NULL AND NEW.stundensatz IS NOT NULL THEN
    NEW.kosten_arbeit := NEW.dauer_stunden * NEW.stundensatz;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER montage_kosten_berechnung
  BEFORE INSERT OR UPDATE ON montagen
  FOR EACH ROW EXECUTE FUNCTION calculate_montage_kosten();

-- Trigger: Material-Slots → material_verbrauch synchronisieren (Lagerabzug)
CREATE OR REPLACE FUNCTION sync_montage_material()
RETURNS TRIGGER AS $$
DECLARE v_montage_id UUID;
BEGIN
  v_montage_id := NEW.id;

  -- Alle bisherigen Verbrauchseinträge für diese Montage löschen
  DELETE FROM material_verbrauch
  WHERE service_typ = 'montage' AND service_id = v_montage_id;

  -- Slot 1
  IF NEW.material_1_id IS NOT NULL AND COALESCE(NEW.material_1_menge, 0) > 0 THEN
    INSERT INTO material_verbrauch (user_id, lager_id, service_typ, service_id, menge, einheit, verbraucht_am)
    SELECT NEW.user_id, NEW.material_1_id, 'montage', v_montage_id,
           NEW.material_1_menge, l.einheit, NOW()
    FROM lager l WHERE l.id = NEW.material_1_id;
  END IF;

  -- Slot 2
  IF NEW.material_2_id IS NOT NULL AND COALESCE(NEW.material_2_menge, 0) > 0 THEN
    INSERT INTO material_verbrauch (user_id, lager_id, service_typ, service_id, menge, einheit, verbraucht_am)
    SELECT NEW.user_id, NEW.material_2_id, 'montage', v_montage_id,
           NEW.material_2_menge, l.einheit, NOW()
    FROM lager l WHERE l.id = NEW.material_2_id;
  END IF;

  -- Slot 3
  IF NEW.material_3_id IS NOT NULL AND COALESCE(NEW.material_3_menge, 0) > 0 THEN
    INSERT INTO material_verbrauch (user_id, lager_id, service_typ, service_id, menge, einheit, verbraucht_am)
    SELECT NEW.user_id, NEW.material_3_id, 'montage', v_montage_id,
           NEW.material_3_menge, l.einheit, NOW()
    FROM lager l WHERE l.id = NEW.material_3_id;
  END IF;

  -- Slot 4
  IF NEW.material_4_id IS NOT NULL AND COALESCE(NEW.material_4_menge, 0) > 0 THEN
    INSERT INTO material_verbrauch (user_id, lager_id, service_typ, service_id, menge, einheit, verbraucht_am)
    SELECT NEW.user_id, NEW.material_4_id, 'montage', v_montage_id,
           NEW.material_4_menge, l.einheit, NOW()
    FROM lager l WHERE l.id = NEW.material_4_id;
  END IF;

  -- Slot 5
  IF NEW.material_5_id IS NOT NULL AND COALESCE(NEW.material_5_menge, 0) > 0 THEN
    INSERT INTO material_verbrauch (user_id, lager_id, service_typ, service_id, menge, einheit, verbraucht_am)
    SELECT NEW.user_id, NEW.material_5_id, 'montage', v_montage_id,
           NEW.material_5_menge, l.einheit, NOW()
    FROM lager l WHERE l.id = NEW.material_5_id;
  END IF;

  -- Slot 6
  IF NEW.material_6_id IS NOT NULL AND COALESCE(NEW.material_6_menge, 0) > 0 THEN
    INSERT INTO material_verbrauch (user_id, lager_id, service_typ, service_id, menge, einheit, verbraucht_am)
    SELECT NEW.user_id, NEW.material_6_id, 'montage', v_montage_id,
           NEW.material_6_menge, l.einheit, NOW()
    FROM lager l WHERE l.id = NEW.material_6_id;
  END IF;

  -- Slot 7
  IF NEW.material_7_id IS NOT NULL AND COALESCE(NEW.material_7_menge, 0) > 0 THEN
    INSERT INTO material_verbrauch (user_id, lager_id, service_typ, service_id, menge, einheit, verbraucht_am)
    SELECT NEW.user_id, NEW.material_7_id, 'montage', v_montage_id,
           NEW.material_7_menge, l.einheit, NOW()
    FROM lager l WHERE l.id = NEW.material_7_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER montage_material_sync
  AFTER INSERT OR UPDATE OF
    material_1_id, material_1_menge,
    material_2_id, material_2_menge,
    material_3_id, material_3_menge,
    material_4_id, material_4_menge,
    material_5_id, material_5_menge,
    material_6_id, material_6_menge,
    material_7_id, material_7_menge
  ON montagen
  FOR EACH ROW EXECUTE FUNCTION sync_montage_material();
```

---

## 13. eigenauftraege

**Beschreibung**: Kleinreparaturen, meist während Reinigung entdeckt.
Werden mit Störungsnummer über Heineken abgerechnet (30 CHF Pauschale).

```sql
CREATE TABLE eigenauftraege (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  anlage_id UUID NOT NULL REFERENCES anlagen(id) ON DELETE CASCADE,
  betrieb_id UUID NOT NULL REFERENCES betriebe(id) ON DELETE CASCADE,

  -- Störungsnummer (von Heineken vergeben – Pflicht für Abrechnung!)
  stoerungsnummer TEXT NOT NULL,
  referenz_nr TEXT,  -- Heineken-Formular Referenz: {betrieb_heineken_nr}_{YYYY}_{MM}_{DD}

  -- Zeitpunkt
  datum DATE NOT NULL,
  uhrzeit TIME,

  -- Wurde während regulärem Service entdeckt?
  entdeckt_bei_service_id UUID REFERENCES reinigungen(id) ON DELETE SET NULL,

  -- Beschreibung
  problem_beschreibung TEXT NOT NULL,
  loesung_beschreibung TEXT,

  -- Status
  status TEXT DEFAULT 'behoben' CHECK (status IN (
    'behoben', 'nicht_behebbar', 'nachbearbeitung_noetig'
  )),

  -- Abrechnung (Pauschale an Heineken)
  preisliste_id UUID REFERENCES preise(id),
  pauschale DECIMAL(10,2) DEFAULT 30.00,

  -- Abrechnung (Monatsrechnung an Heineken)
  abrechnungs_monat DATE,
  abgerechnet BOOLEAN DEFAULT FALSE,

  -- Material (5 Inline-Slots, Lager wird per Trigger aktualisiert)
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

CREATE INDEX idx_eigenauftraege_user ON eigenauftraege(user_id);
CREATE INDEX idx_eigenauftraege_anlage ON eigenauftraege(anlage_id);
CREATE INDEX idx_eigenauftraege_betrieb ON eigenauftraege(betrieb_id);
CREATE INDEX idx_eigenauftraege_datum ON eigenauftraege(datum DESC);
CREATE INDEX idx_eigenauftraege_service ON eigenauftraege(entdeckt_bei_service_id);
CREATE INDEX idx_eigenauftraege_abrechnungsmonat ON eigenauftraege(abrechnungs_monat);

CREATE TRIGGER update_eigenauftraege_updated_at
  BEFORE UPDATE ON eigenauftraege
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- RLS
ALTER TABLE eigenauftraege ENABLE ROW LEVEL SECURITY;
CREATE POLICY eigenauftraege_user_isolation ON eigenauftraege FOR ALL USING (user_id = auth.uid());

-- Trigger: Pauschale aus Preisliste setzen
CREATE OR REPLACE FUNCTION set_eigenauftrag_pauschale()
RETURNS TRIGGER AS $$
DECLARE v_preisliste preise%ROWTYPE;
BEGIN
  SELECT * INTO v_preisliste FROM preise
  WHERE user_id = NEW.user_id AND gueltig_ab <= NEW.datum
    AND (gueltig_bis IS NULL OR gueltig_bis >= NEW.datum)
  ORDER BY gueltig_ab DESC LIMIT 1;

  IF v_preisliste.id IS NOT NULL THEN
    NEW.preisliste_id := v_preisliste.id;
    NEW.pauschale     := v_preisliste.eigenauftrag_pauschale;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER eigenauftrag_pauschale_setzen
  BEFORE INSERT OR UPDATE ON eigenauftraege
  FOR EACH ROW EXECUTE FUNCTION set_eigenauftrag_pauschale();

-- Trigger: Material-Slots → material_verbrauch synchronisieren (Lagerabzug)
CREATE OR REPLACE FUNCTION sync_eigenauftrag_material()
RETURNS TRIGGER AS $$
DECLARE v_eigenauftrag_id UUID;
BEGIN
  v_eigenauftrag_id := NEW.id;

  -- Alle bisherigen Verbrauchseinträge für diesen Eigenauftrag löschen
  DELETE FROM material_verbrauch
  WHERE service_typ = 'eigenauftrag' AND service_id = v_eigenauftrag_id;

  -- Slot 1
  IF NEW.material_1_id IS NOT NULL AND COALESCE(NEW.material_1_menge, 0) > 0 THEN
    INSERT INTO material_verbrauch (user_id, lager_id, service_typ, service_id, menge, einheit, verbraucht_am)
    SELECT NEW.user_id, NEW.material_1_id, 'eigenauftrag', v_eigenauftrag_id,
           NEW.material_1_menge, l.einheit, NOW()
    FROM lager l WHERE l.id = NEW.material_1_id;
  END IF;

  -- Slot 2
  IF NEW.material_2_id IS NOT NULL AND COALESCE(NEW.material_2_menge, 0) > 0 THEN
    INSERT INTO material_verbrauch (user_id, lager_id, service_typ, service_id, menge, einheit, verbraucht_am)
    SELECT NEW.user_id, NEW.material_2_id, 'eigenauftrag', v_eigenauftrag_id,
           NEW.material_2_menge, l.einheit, NOW()
    FROM lager l WHERE l.id = NEW.material_2_id;
  END IF;

  -- Slot 3
  IF NEW.material_3_id IS NOT NULL AND COALESCE(NEW.material_3_menge, 0) > 0 THEN
    INSERT INTO material_verbrauch (user_id, lager_id, service_typ, service_id, menge, einheit, verbraucht_am)
    SELECT NEW.user_id, NEW.material_3_id, 'eigenauftrag', v_eigenauftrag_id,
           NEW.material_3_menge, l.einheit, NOW()
    FROM lager l WHERE l.id = NEW.material_3_id;
  END IF;

  -- Slot 4
  IF NEW.material_4_id IS NOT NULL AND COALESCE(NEW.material_4_menge, 0) > 0 THEN
    INSERT INTO material_verbrauch (user_id, lager_id, service_typ, service_id, menge, einheit, verbraucht_am)
    SELECT NEW.user_id, NEW.material_4_id, 'eigenauftrag', v_eigenauftrag_id,
           NEW.material_4_menge, l.einheit, NOW()
    FROM lager l WHERE l.id = NEW.material_4_id;
  END IF;

  -- Slot 5
  IF NEW.material_5_id IS NOT NULL AND COALESCE(NEW.material_5_menge, 0) > 0 THEN
    INSERT INTO material_verbrauch (user_id, lager_id, service_typ, service_id, menge, einheit, verbraucht_am)
    SELECT NEW.user_id, NEW.material_5_id, 'eigenauftrag', v_eigenauftrag_id,
           NEW.material_5_menge, l.einheit, NOW()
    FROM lager l WHERE l.id = NEW.material_5_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER eigenauftrag_material_sync
  AFTER INSERT OR UPDATE OF
    material_1_id, material_1_menge,
    material_2_id, material_2_menge,
    material_3_id, material_3_menge,
    material_4_id, material_4_menge,
    material_5_id, material_5_menge
  ON eigenauftraege
  FOR EACH ROW EXECUTE FUNCTION sync_eigenauftrag_material();
```

---

## 14. pikett_dienste

**Beschreibung**: Pikett-Wochenenden. 160 CHF Pauschale unabhängig von Einsätzen.
Einsätze werden als Störungen mit `ist_pikett_einsatz = TRUE` erfasst.

**Workflow**: Ende Jahr → Einsatzplan für Folgejahr erhalten → Bulk-Import in App
→ App erstellt automatisch Google Calendar-Einträge für jeden Pikett-Dienst.
Google Calendar Event-ID wird gespeichert, damit Einträge später aktualisiert
oder gelöscht werden können.

```sql
CREATE TABLE pikett_dienste (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Zeitraum (meist Sa–So)
  datum_start DATE NOT NULL,
  datum_ende DATE NOT NULL,
  referenz_nr TEXT,  -- Heineken-Formular Referenz: {YYYY}_{KW} (Kalenderwoche, z.B. 2026_08)

  -- Aktuell aktiv?
  ist_aktiv BOOLEAN DEFAULT FALSE,

  -- Abrechnung (Pauschale)
  preisliste_id UUID REFERENCES preise(id),
  pauschale DECIMAL(10,2) DEFAULT 160.00,          -- Wochenende (aus Preisliste)
  anzahl_feiertage INTEGER DEFAULT 0,              -- Anzahl Feiertage im Pikett-Zeitraum
  feiertag_zuschlag DECIMAL(10,2) DEFAULT 0.00,   -- anzahl_feiertage × pikett_feiertag_zuschlag
  pauschale_gesamt DECIMAL(10,2),                 -- pauschale + feiertag_zuschlag

  -- Abrechnung (Monatsrechnung an Heineken)
  abrechnungs_monat DATE,
  abgerechnet BOOLEAN DEFAULT FALSE,

  -- Google Calendar Integration
  -- Event-ID wird von Google zurückgegeben und gespeichert für Update/Delete
  google_calendar_event_id TEXT,
  kalender_sync_status TEXT DEFAULT 'pending' CHECK (kalender_sync_status IN (
    'pending',   -- Noch nicht in Kalender eingetragen
    'synced',    -- Erfolgreich synchronisiert
    'error'      -- Fehler bei letzter Synchronisation
  )),
  kalender_sync_fehler TEXT,      -- Fehlermeldung bei Status 'error'
  kalender_sync_at TIMESTAMPTZ,   -- Zeitpunkt der letzten Synchronisation

  notizen TEXT,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  CONSTRAINT pikett_zeitraum_check CHECK (datum_ende >= datum_start)
);

CREATE INDEX idx_pikett_user ON pikett_dienste(user_id);
CREATE INDEX idx_pikett_zeitraum ON pikett_dienste(datum_start, datum_ende);
CREATE INDEX idx_pikett_aktiv ON pikett_dienste(ist_aktiv) WHERE ist_aktiv = TRUE;
CREATE INDEX idx_pikett_kalender_sync ON pikett_dienste(kalender_sync_status) WHERE kalender_sync_status != 'synced';

CREATE TRIGGER update_pikett_dienste_updated_at
  BEFORE UPDATE ON pikett_dienste
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- RLS
ALTER TABLE pikett_dienste ENABLE ROW LEVEL SECURITY;
CREATE POLICY pikett_user_isolation ON pikett_dienste FOR ALL USING (user_id = auth.uid());

-- Trigger: Pauschale aus Preisliste setzen
CREATE OR REPLACE FUNCTION set_pikett_pauschale()
RETURNS TRIGGER AS $$
DECLARE v_preisliste preise%ROWTYPE;
BEGIN
  SELECT * INTO v_preisliste FROM preise
  WHERE user_id = NEW.user_id AND gueltig_ab <= NEW.datum_start
    AND (gueltig_bis IS NULL OR gueltig_bis >= NEW.datum_start)
  ORDER BY gueltig_ab DESC LIMIT 1;

  IF v_preisliste.id IS NOT NULL THEN
    NEW.preisliste_id    := v_preisliste.id;
    NEW.pauschale        := v_preisliste.pikett_pauschale;
    NEW.feiertag_zuschlag := COALESCE(NEW.anzahl_feiertage, 0) * v_preisliste.pikett_feiertag_zuschlag;
    NEW.pauschale_gesamt  := NEW.pauschale + NEW.feiertag_zuschlag;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER pikett_pauschale_setzen
  BEFORE INSERT OR UPDATE OF anzahl_feiertage ON pikett_dienste
  FOR EACH ROW EXECUTE FUNCTION set_pikett_pauschale();
```

---

## 15. material_kategorien

**Beschreibung**: Kategorien aus dem Heineken-Artikelstamm (Sheet "Artikel Heineken",
885 Artikel mit DBO-Nr.). Die 20 Kategorien decken alle Artikel vollständig ab.

```sql
CREATE TABLE material_kategorien (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  name TEXT NOT NULL,
  beschreibung TEXT,
  sortierung INTEGER DEFAULT 0,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(user_id, name)
);

CREATE INDEX idx_material_kategorien_user ON material_kategorien(user_id);

-- RLS
ALTER TABLE material_kategorien ENABLE ROW LEVEL SECURITY;
CREATE POLICY material_kategorien_user_isolation ON material_kategorien FOR ALL USING (user_id = auth.uid());

-- Seed-Daten: Kategorien aus Heineken-Artikelstamm (20 Kategorien, 885 Artikel)
-- Wird beim Onboarding eines neuen Users einmalig eingespielt
-- Sortierung: logische Reihenfolge nach Häufigkeit/Wichtigkeit im Alltag
INSERT INTO material_kategorien (user_id, name, beschreibung, sortierung) VALUES
  (auth.uid(), 'Zapfhahn',               'Bierhähne, Rosetten, Stutzen, Dichtungssätze, Kompensatoren',        10),
  (auth.uid(), 'Zapfkopf',               'Micro-Matic, Fob-Stop, Ergogriff, Reinigungsadapter Bier',           20),
  (auth.uid(), 'Säule',                  'Cobra, Falco, Tube, Laser, Arrow, Europe – inkl. Balken und Sätze',  30),
  (auth.uid(), 'Bierkühler',             'FK-MU, BKG, CR, V100GE, H100GE, Boosterkühler, Glykolkühler',       40),
  (auth.uid(), 'Fasskühler',             'FK2/FK4/FK6/FK8, Türdichtungen, Magnetverschluss, Steg',             50),
  (auth.uid(), 'Kühlschlange',           'Kühlschlangensätze zu CR 4 / CR 5-6 / CR 7',                        60),
  (auth.uid(), 'Pumpe/Motor/Lüfter',     'Pumpen (Gamko, Samec, EBM), Rührwerke, Ventilatormotoren',           70),
  (auth.uid(), 'Thermostat/Regler',      'Thermostate, Eisbankregulator, Temperaturfühler, Regelboxen',        80),
  (auth.uid(), 'Druck/Gas',              'CO2-Druckreduzierer, Manometer, HD-Schlauch, Fl.-Anschluss, Filter', 90),
  (auth.uid(), 'Verbinder / Briden',     'John-Guest-Verbinder, Umkehrbögen, Winkel, Dreifachverteiler',      100),
  (auth.uid(), 'Bierleitung',            'Bierleitungen, Pythons, Isolierschläuche',                          110),
  (auth.uid(), 'Gläserdusche/Tropfschale','ETS, Auflegetropfschalen, Spritzdüsen, Spülkreuz, Einbauschalen', 120),
  (auth.uid(), 'Dichtungen',             'Bierdichtungen, O-Ringe, Hauptdichtungen, Gehäusedichtungen',       130),
  (auth.uid(), 'Elektronik',             'Kondensatoren, Startrelais, Platinen, Trafos, LED-Beleuchtung',     140),
  (auth.uid(), 'Montagematerial',        'Abdeckplatten, Alu-Konsolen, Tablare, Holzböckli, Befestigungen',   150),
  (auth.uid(), 'Reinigungsmaterial',     'Reinigungsadapter Wein/Bier, Reinigungstank, Spülzubehör',         160),
  (auth.uid(), 'Verbrauchsmaterial',     'Glykol, Kühlflüssigkeit, Reinigungsmittel',                        170),
  (auth.uid(), 'Branding',              'Plaketten, Linsen, Griffe, Werbepanels, Logos (Heineken/Calanda/…)', 180),
  (auth.uid(), 'Werkzeug',              'Spezialwerkzeug (z.B. Halteelement-Werkzeug JG)',                   190),
  (auth.uid(), 'Sonstiges',            'Kugelventile, Sicherungen, Kleider, nicht klassifizierbare Artikel', 200);
```

---

## 16. material

**Beschreibung**: Heineken-Artikelstamm (Produktkatalog). Enthält alle 885 Artikel
aus dem Excel-Sheet "Artikel Heineken" mit DBO-Nummer, Kategorie und Beschreibung.
Wird einmalig importiert und laufend gepflegt — neue Artikel werden ergänzt,
ausgelaufene Artikel werden als Auslaufartikel markiert (nicht gelöscht, da historische
Verbrauchsdaten erhalten bleiben müssen). Fotos werden in Supabase Storage gespeichert.

**Lifecycle:**
- **Neuer Artikel**: INSERT mit `gueltig_ab = heute`
- **Auslaufartikel**: `ist_auslaufartikel = TRUE` + `auslauf_datum` setzen, optional `nachfolger_id` auf Ersatzartikel
- **Artikel bleibt in DB**: historische `material_verbrauch`-Einträge bleiben korrekt verknüpft
- **Foto**: Path im Supabase-Storage-Bucket `material-fotos/{user_id}/{dbo_nr}.jpg`

```sql
CREATE TABLE material (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  kategorie_id UUID REFERENCES material_kategorien(id) ON DELETE SET NULL,

  -- Heineken DBO-Nummer (Primärschlüssel im Heineken-Artikelstamm)
  dbo_nr TEXT NOT NULL,              -- z.B. "30.1900.04"
  name TEXT NOT NULL,                -- Kurztext aus Excel
  beschreibung TEXT,                 -- Optionale Ergänzung / interne Notiz

  einheit TEXT NOT NULL DEFAULT 'Stück' CHECK (einheit IN (
    'Stück', 'Liter', 'Meter', 'Kilogramm', 'Packung', 'Set'
  )),

  -- Foto (Supabase Storage)
  -- Path innerhalb des Buckets "material-fotos", z.B. "user-uuid/30.1900.04.jpg"
  -- Vollständige URL: {SUPABASE_URL}/storage/v1/object/public/material-fotos/{foto_storage_path}
  foto_storage_path TEXT,

  -- Artikel-Lifecycle
  gueltig_ab DATE,                   -- Ab wann im Heineken-Sortiment (NULL = unbekannt)
  ist_auslaufartikel BOOLEAN DEFAULT FALSE,   -- TRUE wenn von Heineken ausgelistet
  auslauf_datum DATE,                -- Wann ausgelistet (leer = noch aktiv)
  nachfolger_id UUID REFERENCES material(id) ON DELETE SET NULL,
  -- ↑ Zeigt auf Nachfolge-/Ersatzartikel (hilfreich für Lager-Umstellung)

  -- Artikel bleibt immer in DB (soft-delete), damit historische Verbrauchsdaten erhalten bleiben
  -- ist_auslaufartikel = TRUE → wird in App-Auswahl ausgeblendet, bleibt aber in Verbrauchshistorie
  ist_aktiv BOOLEAN DEFAULT TRUE,    -- FALSE nur bei manuellen Fehleinträgen (hard-hide)

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(user_id, dbo_nr)            -- DBO-Nr. eindeutig pro Franchise-Partner
);

CREATE INDEX idx_material_user ON material(user_id);
CREATE INDEX idx_material_kategorie ON material(kategorie_id);
CREATE INDEX idx_material_dbo_nr ON material(dbo_nr);
CREATE INDEX idx_material_aktiv ON material(user_id, ist_auslaufartikel) WHERE ist_auslaufartikel = FALSE;
CREATE INDEX idx_material_nachfolger ON material(nachfolger_id) WHERE nachfolger_id IS NOT NULL;
CREATE INDEX idx_material_mit_foto ON material(user_id) WHERE foto_storage_path IS NOT NULL;

CREATE TRIGGER update_material_updated_at
  BEFORE UPDATE ON material
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- RLS
ALTER TABLE material ENABLE ROW LEVEL SECURITY;
CREATE POLICY material_user_isolation ON material FOR ALL USING (user_id = auth.uid());

-- Trigger: auslauf_datum automatisch setzen wenn ist_auslaufartikel = TRUE gesetzt wird
CREATE OR REPLACE FUNCTION set_material_auslauf_datum()
RETURNS TRIGGER AS $$
BEGIN
  -- Auslaufdatum automatisch auf heute setzen wenn nicht explizit angegeben
  IF NEW.ist_auslaufartikel = TRUE
     AND OLD.ist_auslaufartikel = FALSE
     AND NEW.auslauf_datum IS NULL THEN
    NEW.auslauf_datum := CURRENT_DATE;
  END IF;
  -- Auslaufdatum zurücksetzen wenn Artikel reaktiviert wird
  IF NEW.ist_auslaufartikel = FALSE AND OLD.ist_auslaufartikel = TRUE THEN
    NEW.auslauf_datum := NULL;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER material_auslauf_datum_setzen
  BEFORE UPDATE OF ist_auslaufartikel ON material
  FOR EACH ROW EXECUTE FUNCTION set_material_auslauf_datum();

-- Supabase Storage: Bucket für Artikel-Fotos
-- Bucket-Name: "material-fotos"
-- Zugriffsregel: Öffentlich lesbar (für App-Anzeige ohne Auth-Token)
-- Pfad-Konvention: {user_id}/{dbo_nr}.jpg  (z.B. "abc-123/30.1900.04.jpg")
-- RLS auf Storage: INSERT/DELETE nur durch authentifizierte User (eigener user_id-Pfad)

-- Seed-Daten: Alle 885 Heineken-Artikel aus Sheet "Artikel Heineken"
-- → Vollständige Seed-Datei: Datenanalyse/07_Artikelstamm_Heineken.sql
-- Beispiele (erste Zeilen aus Excel):
INSERT INTO material (user_id, dbo_nr, name, einheit, kategorie_id) VALUES
-- Kategorie: Pumpe/Motor/Lüfter
(auth.uid(), '20.1800.02', 'Rührwerk mit Pumpe 5.2m zu CR 4 - CR7',         'Stück', (SELECT id FROM material_kategorien WHERE user_id=auth.uid() AND name='Pumpe/Motor/Lüfter')),
(auth.uid(), '20.1800.03', 'Pumpe Samec 11m zu V100E und H100E',             'Stück', (SELECT id FROM material_kategorien WHERE user_id=auth.uid() AND name='Pumpe/Motor/Lüfter')),
(auth.uid(), '20.1800.04', 'Rührwerkmotor Gamko zu BKG 50/54',               'Stück', (SELECT id FROM material_kategorien WHERE user_id=auth.uid() AND name='Pumpe/Motor/Lüfter')),
(auth.uid(), '20.1800.05', 'Papst-Lüfter',                                   'Stück', (SELECT id FROM material_kategorien WHERE user_id=auth.uid() AND name='Pumpe/Motor/Lüfter')),
-- Kategorie: Thermostat/Regler
(auth.uid(), '20.1800.06', 'Kombiregler TECG 2000',                          'Stück', (SELECT id FROM material_kategorien WHERE user_id=auth.uid() AND name='Thermostat/Regler')),
(auth.uid(), '20.1800.07', 'Raumthermostat zu Fasskühler',                   'Stück', (SELECT id FROM material_kategorien WHERE user_id=auth.uid() AND name='Thermostat/Regler')),
-- Kategorie: Elektronik
(auth.uid(), '20.1800.08', 'Anlaufkondensator',                              'Stück', (SELECT id FROM material_kategorien WHERE user_id=auth.uid() AND name='Elektronik')),
(auth.uid(), '20.1800.09', 'Anlaufkondensator Rührwerkmotor 2 MF',           'Stück', (SELECT id FROM material_kategorien WHERE user_id=auth.uid() AND name='Elektronik'));
-- ... vollständiger Import via 07_Artikelstamm_Heineken.sql (alle 885 Artikel)
```

---

## 17. lager

**Beschreibung**: Fahrzeuglager — alle Artikel, die Daniel in seinem Auto mitführt.
Bestand wird automatisch bei Verbrauch reduziert. Warnung bei Unterschreitung des Mindestbestands.
Jeder Lager-Artikel kann optional mit einem Heineken-Artikel aus dem Artikelstamm (`material`) verknüpft werden.

```sql
CREATE TABLE lager (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  kategorie_id UUID REFERENCES material_kategorien(id) ON DELETE SET NULL,

  -- Verknüpfung zum Heineken-Artikelstamm (optional, für eigene Artikel NULL)
  material_id UUID REFERENCES material(id) ON DELETE SET NULL,

  -- Artikel-Info (kann von material übernommen oder manuell erfasst werden)
  dbo_nr TEXT,           -- Heineken DBO-Nr. (z.B. "30.1900.04")
  name TEXT NOT NULL,
  beschreibung TEXT,
  einheit TEXT NOT NULL DEFAULT 'Stück' CHECK (einheit IN (
    'Stück', 'Liter', 'Meter', 'Kilogramm', 'Packung', 'Set'
  )),

  -- Bestand
  bestand_aktuell DECIMAL(10,2) NOT NULL DEFAULT 0,
  bestand_mindest DECIMAL(10,2) NOT NULL DEFAULT 5,
  bestand_optimal DECIMAL(10,2) NOT NULL DEFAULT 10,
  bestand_niedrig BOOLEAN GENERATED ALWAYS AS (bestand_aktuell <= bestand_mindest) STORED,

  -- Lieferant
  lieferant TEXT,
  lieferanten_artikel_nr TEXT,
  preis_einkauf DECIMAL(10,2),

  ist_aktiv BOOLEAN DEFAULT TRUE,
  notizen TEXT,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_lager_user ON lager(user_id);
CREATE INDEX idx_lager_kategorie ON lager(kategorie_id);
CREATE INDEX idx_lager_material ON lager(material_id);
CREATE INDEX idx_lager_bestand_niedrig ON lager(bestand_niedrig) WHERE bestand_niedrig = TRUE;

CREATE TRIGGER update_lager_updated_at
  BEFORE UPDATE ON lager
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- RLS
ALTER TABLE lager ENABLE ROW LEVEL SECURITY;
CREATE POLICY lager_user_isolation ON lager FOR ALL USING (user_id = auth.uid());
```

---

## 17. material_verbrauch

**Beschreibung**: Verbrauch bei Services. Reduziert automatisch den Bestand.

```sql
CREATE TABLE material_verbrauch (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  lager_id UUID NOT NULL REFERENCES lager(id) ON DELETE CASCADE,

  -- Polymorphe Beziehung (welcher Service)
  service_typ TEXT NOT NULL CHECK (service_typ IN (
    'reinigung', 'stoerung', 'montage', 'eigenauftrag'
  )),
  service_id UUID NOT NULL,

  -- Menge
  menge DECIMAL(10,2) NOT NULL,
  einheit TEXT NOT NULL,
  preis_einkauf DECIMAL(10,2),   -- Kopie zum Zeitpunkt des Verbrauchs

  verbraucht_am TIMESTAMPTZ DEFAULT NOW(),
  notizen TEXT,

  created_at TIMESTAMPTZ DEFAULT NOW(),

  CONSTRAINT menge_positiv CHECK (menge > 0)
);

CREATE INDEX idx_material_verbrauch_user ON material_verbrauch(user_id);
CREATE INDEX idx_material_verbrauch_lager ON material_verbrauch(lager_id);
CREATE INDEX idx_material_verbrauch_service ON material_verbrauch(service_typ, service_id);

-- RLS
ALTER TABLE material_verbrauch ENABLE ROW LEVEL SECURITY;
CREATE POLICY material_verbrauch_user_isolation ON material_verbrauch FOR ALL USING (user_id = auth.uid());

-- Trigger: Lager-Bestand reduzieren
CREATE OR REPLACE FUNCTION update_lager_bestand_insert()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE lager SET bestand_aktuell = bestand_aktuell - NEW.menge, updated_at = NOW()
  WHERE id = NEW.lager_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER material_verbrauch_bestand_reduzieren
  AFTER INSERT ON material_verbrauch
  FOR EACH ROW EXECUTE FUNCTION update_lager_bestand_insert();

-- Trigger: Lager-Bestand wiederherstellen bei Löschung
CREATE OR REPLACE FUNCTION update_lager_bestand_delete()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE lager SET bestand_aktuell = bestand_aktuell + OLD.menge, updated_at = NOW()
  WHERE id = OLD.lager_id;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER material_verbrauch_bestand_wiederherstellen
  AFTER DELETE ON material_verbrauch
  FOR EACH ROW EXECUTE FUNCTION update_material_bestand_delete();
```

---

## 18. rechnungen

**Beschreibung**: Zwei Typen:
- `kundenrechnung` → An Betrieb direkt (für Reinigungen)
- `heineken_monat` → Monatsrechnung an Heineken (für Störungen, Montagen, Eigenaufträge, Pikett)

```sql
CREATE SEQUENCE rechnungsnummer_seq;

CREATE TABLE rechnungen (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  rechnungstyp TEXT NOT NULL CHECK (rechnungstyp IN ('kundenrechnung', 'heineken_monat')),
  rechnungsnummer TEXT NOT NULL UNIQUE,  -- Auto: '2026-02-0042'

  -- Empfänger
  betrieb_id UUID REFERENCES betriebe(id) ON DELETE RESTRICT,
  rechnungs_adresse_id UUID REFERENCES betrieb_rechnungsadressen(id),
  heineken_po_nummer TEXT,
  heineken_monat DATE,   -- '2026-02-01' = Februar 2026

  -- Datum
  rechnungsdatum DATE NOT NULL DEFAULT CURRENT_DATE,
  faelligkeitsdatum DATE NOT NULL,

  -- Beträge (via Trigger aus Positionen berechnet)
  betrag_netto DECIMAL(10,2) NOT NULL DEFAULT 0,
  mwst_betrag DECIMAL(10,2) NOT NULL DEFAULT 0,
  betrag_brutto DECIMAL(10,2) NOT NULL DEFAULT 0,

  -- Status
  zahlungsstatus TEXT DEFAULT 'entwurf' CHECK (zahlungsstatus IN (
    'entwurf', 'offen', 'teilbezahlt', 'bezahlt', 'ueberfaellig', 'storniert'
  )),

  -- Versand
  versandart TEXT,  -- Aus betriebe.rechnungsstellung
  versendet_am DATE,

  -- Zahlung
  zahlung_eingegangen_am DATE,
  zahlung_betrag DECIMAL(10,2),

  -- Mahnwesen
  mahnung_stufe INTEGER DEFAULT 0 CHECK (mahnung_stufe BETWEEN 0 AND 3),
  letzte_mahnung_am DATE,

  -- PDF
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

CREATE INDEX idx_rechnungen_user ON rechnungen(user_id);
CREATE INDEX idx_rechnungen_betrieb ON rechnungen(betrieb_id);
CREATE INDEX idx_rechnungen_datum ON rechnungen(rechnungsdatum DESC);
CREATE INDEX idx_rechnungen_status ON rechnungen(zahlungsstatus);
CREATE INDEX idx_rechnungen_faellig ON rechnungen(faelligkeitsdatum)
  WHERE zahlungsstatus IN ('offen', 'ueberfaellig');

CREATE TRIGGER update_rechnungen_updated_at
  BEFORE UPDATE ON rechnungen
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- RLS
ALTER TABLE rechnungen ENABLE ROW LEVEL SECURITY;
CREATE POLICY rechnungen_user_isolation ON rechnungen FOR ALL USING (user_id = auth.uid());

-- Trigger: Rechnungsnummer und Fälligkeitsdatum
CREATE OR REPLACE FUNCTION generate_rechnungsnummer()
RETURNS TRIGGER AS $$
BEGIN
  NEW.rechnungsnummer := TO_CHAR(CURRENT_DATE, 'YYYY-MM')
    || '-' || LPAD(nextval('rechnungsnummer_seq')::TEXT, 4, '0');
  IF NEW.faelligkeitsdatum IS NULL THEN
    NEW.faelligkeitsdatum := NEW.rechnungsdatum + INTERVAL '30 days';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_rechnungsnummer
  BEFORE INSERT ON rechnungen
  FOR EACH ROW EXECUTE FUNCTION generate_rechnungsnummer();
```

---

## 19. rechnungs_positionen

```sql
CREATE TABLE rechnungs_positionen (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  rechnung_id UUID NOT NULL REFERENCES rechnungen(id) ON DELETE CASCADE,

  -- Service-Referenz (polymorphe Beziehung)
  service_typ TEXT CHECK (service_typ IN (
    'reinigung', 'stoerung', 'montage', 'eigenauftrag', 'pikett'
  )),
  service_id UUID,   -- NULL erlaubt für manuelle Positionen

  -- Position
  position INTEGER NOT NULL,
  beschreibung TEXT NOT NULL,

  -- Beträge
  betrag_netto DECIMAL(10,2) NOT NULL,
  mwst_satz DECIMAL(4,2) NOT NULL DEFAULT 8.10,
  mwst_betrag DECIMAL(10,2) NOT NULL,
  betrag_brutto DECIMAL(10,2) NOT NULL,

  created_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(rechnung_id, position)
);

CREATE INDEX idx_rechnungs_positionen_rechnung ON rechnungs_positionen(rechnung_id);
CREATE INDEX idx_rechnungs_positionen_service ON rechnungs_positionen(service_typ, service_id);

-- RLS
ALTER TABLE rechnungs_positionen ENABLE ROW LEVEL SECURITY;
CREATE POLICY rechnungs_positionen_user_isolation ON rechnungs_positionen FOR ALL USING (user_id = auth.uid());

-- Trigger: Rechnungssummen aktualisieren
CREATE OR REPLACE FUNCTION update_rechnung_summen()
RETURNS TRIGGER AS $$
DECLARE v_rechnung_id UUID;
BEGIN
  v_rechnung_id := COALESCE(NEW.rechnung_id, OLD.rechnung_id);
  UPDATE rechnungen SET
    betrag_netto  = (SELECT COALESCE(SUM(betrag_netto), 0)  FROM rechnungs_positionen WHERE rechnung_id = v_rechnung_id),
    mwst_betrag   = (SELECT COALESCE(SUM(mwst_betrag), 0)   FROM rechnungs_positionen WHERE rechnung_id = v_rechnung_id),
    betrag_brutto = (SELECT COALESCE(SUM(betrag_brutto), 0) FROM rechnungs_positionen WHERE rechnung_id = v_rechnung_id),
    updated_at    = NOW()
  WHERE id = v_rechnung_id;
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER rechnung_summen_update
  AFTER INSERT OR UPDATE OR DELETE ON rechnungs_positionen
  FOR EACH ROW EXECUTE FUNCTION update_rechnung_summen();
```

---

## 20. formulare

**Beschreibung**: Heineken-PDF-Formulare für Monatsabrechnung. Pro Service-Einsatz wird
ein Formular ausgefüllt und als PDF generiert. Die PDFs werden der Heineken-Monatsrechnung
angehängt (F_Störung, F_Eigenauftrag, F_EE_Reinigung, F_Montage, F_Pikett, F_Pauschale).

**Formular-Typen:**
- `stoerung` → F_Störung: Störungsbehebung (Anlagetyp, Störungsbereich, Material bis 3 Pos.)
- `eigenauftrag` → F_Eigenauftrag: Eigenauftrag 30 CHF Pauschale (Material bis 3 Pos.)
- `ee_reinigung` → F_EE_Reinigung: Eröffnung/Endreinigung Bergrestaurant (135 CHF inkl. Bergbahnentschädigung)
- `montage` → F_Montage: Montageauftrag (Stunden × 80 CHF + ggf. Montagepauschale 600 CHF/Tag, Material bis 7 Pos.)
- `pikett` → F_Pikett: Pikett-Bereitschaft (Pikettbereitschaft 160 CHF + Feiertag 80 CHF, Referenz im KW-Format)
- `pauschale` → F_Pauschale: Anfahrtspauschale Bergrestaurant bei regulärer Reinigung (180 CHF)

**referenz_nr Format:**
- stoerung/eigenauftrag/montage/ee_reinigung/pauschale: `{betrieb_heineken_nr}_{YYYY}_{MM}_{DD}`
- pikett: `{YYYY}_{KW}` (z.B. `2026_08`)

**PDF-Storage:** Supabase Storage Bucket `formulare`
- Pfad: `{user_id}/{YYYY}/{MM}/{formular_typ}/{referenz_nr}.pdf`

```sql
CREATE TABLE formulare (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Formular-Typ (bestimmt welches PDF-Template verwendet wird)
  formular_typ TEXT NOT NULL CHECK (formular_typ IN (
    'stoerung',       -- F_Störung
    'eigenauftrag',   -- F_Eigenauftrag
    'ee_reinigung',   -- F_EE_Reinigung (Eröffnung/Endreinigung Bergrestaurant)
    'montage',        -- F_Montage
    'pikett',         -- F_Pikett
    'pauschale'       -- F_Pauschale (Anfahrtspauschale Bergrestaurant bei Reinigung)
  )),

  -- Polymorphe Verknüpfung mit dem auslösenden Service-Einsatz
  service_typ TEXT NOT NULL CHECK (service_typ IN (
    'stoerung', 'eigenauftrag', 'montage', 'pikett', 'reinigung'
    -- 'reinigung' wird für ee_reinigung und pauschale verwendet
  )),
  service_id UUID NOT NULL,
  -- FK zu stoerungen.id / eigenauftraege.id / montagen.id / pikett_dienste.id / reinigungen.id

  -- Identifikation (Heineken-Formular-Referenznummer)
  referenz_nr TEXT,  -- {betrieb_heineken_nr}_{YYYY}_{MM}_{DD} oder {YYYY}_{KW} für Pikett

  -- Verknüpfung mit Monatsrechnung
  rechnung_id UUID REFERENCES rechnungen(id) ON DELETE SET NULL,
  abrechnungs_monat DATE,  -- '2026-02-01' = Februar 2026

  -- PDF-Generierung (Supabase Storage Bucket: "formulare")
  -- Pfad: {user_id}/{YYYY}/{MM}/{formular_typ}/{referenz_nr}.pdf
  pdf_storage_path TEXT,
  pdf_generiert_at TIMESTAMPTZ,
  pdf_status TEXT DEFAULT 'ausstehend' CHECK (pdf_status IN (
    'ausstehend',     -- Noch nicht generiert
    'in_bearbeitung', -- PDF wird gerade erstellt
    'fertig',         -- PDF erfolgreich generiert
    'fehler'          -- Fehler bei PDF-Generierung
  )),
  pdf_fehler TEXT,  -- Fehlermeldung bei Status 'fehler'

  -- Snapshot der Formulardaten zum Zeitpunkt der Erstellung
  -- Ermöglicht PDF-Regenerierung ohne erneutes Laden aller Verknüpfungen
  -- (Betrieb, Anlage, Preise, Material, Unterschriften etc.)
  formular_daten JSONB,

  notizen TEXT,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Pro Einsatz kann jeder Formular-Typ nur einmal vorkommen
  -- (aber z.B. Störung + Pauschale = zwei Formulare für denselben Einsatz möglich)
  UNIQUE(service_typ, service_id, formular_typ)
);

CREATE INDEX idx_formulare_user ON formulare(user_id);
CREATE INDEX idx_formulare_service ON formulare(service_typ, service_id);
CREATE INDEX idx_formulare_rechnung ON formulare(rechnung_id);
CREATE INDEX idx_formulare_monat ON formulare(abrechnungs_monat);
CREATE INDEX idx_formulare_pdf_status ON formulare(pdf_status) WHERE pdf_status != 'fertig';

CREATE TRIGGER update_formulare_updated_at
  BEFORE UPDATE ON formulare
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- RLS
ALTER TABLE formulare ENABLE ROW LEVEL SECURITY;
CREATE POLICY formulare_user_isolation ON formulare FOR ALL USING (user_id = auth.uid());
```

---

## 21. konten

**Beschreibung**: Kontenrahmen nach KMU-Standard (Schweiz). Vorgefüllt mit Daniels
61 Konten aus dem Kontenrahmen-Sheet. Basis für alle Buchungssätze.

```sql
CREATE TABLE konten (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  kontonummer INTEGER NOT NULL,
  bezeichnung TEXT NOT NULL,
  beschreibung TEXT,                -- Aus Kontenrahmen-Sheet
  kategorie TEXT,                   -- z.B. 'Umlaufvermögen', 'Lohnaufwand'
  kontenklasse INTEGER GENERATED ALWAYS AS (kontonummer / 1000) STORED,

  ist_aktiv BOOLEAN DEFAULT TRUE,

  created_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(user_id, kontonummer)
);

CREATE INDEX idx_konten_user ON konten(user_id);
CREATE INDEX idx_konten_nummer ON konten(kontonummer);

-- RLS
ALTER TABLE konten ENABLE ROW LEVEL SECURITY;
CREATE POLICY konten_user_isolation ON konten FOR ALL USING (user_id = auth.uid());

-- Initiale Konten (Daniel's Kontenrahmen – 61 Konten)
-- Wird beim Onboarding automatisch eingefügt:
-- (1000,'Kasse','Eintragen der laufenden Ein- und Auszahlungen','Umlaufvermögen')
-- (1020,'Bankguthaben','...','Umlaufvermögen')
-- (1100,'Forderungen aus Lieferung und Leistungen (Debitoren)','...','Umlaufvermögen')
-- (1170,'Vorsteuer MWST Material, Waren, Dienstleistungen, Energie','...','Umlaufvermögen')
-- (1171,'Vorsteuer MWST Investitionen, übriger Betriebsaufwand','...','Umlaufvermögen')
-- (1180,'Forderungen gegenüber Sozialversicherungen und Vorsorgeeinrichtungen',NULL,'Umlaufvermögen')
-- (1190,'Konto Korrent Gesellschafter','...','Umlaufvermögen')
-- (2000,'Verbindlichkeiten aus Lieferungen und Leistungen (Kreditoren)','...','Kurzfristiges Fremdkapital')
-- (2200,'Geschuldete MWST (Umsatzsteuer)','...','Kurzfristiges Fremdkapital')
-- (2202,'Abrechnungskonto MWST','...','Kurzfristiges Fremdkapital')
-- (3400,'Dienstleistungserlöse','...','Betriebsertrag')
-- (4004,'Hilfs- und Verbrauchsmaterialaufwand','...','Materialaufwand')
-- (5000,'Lohnaufwand','...','Lohnaufwand')
-- (6200,'Betriebsaufwand Fahrzeuge','...','Fahrzeug- und Transportaufwand')
-- (6301,'Franchisegebühr Heineken','Monatliche Zahlung an Heineken per Dauerauftrag','Sachversicherungen, Abgaben')
-- ... (alle 61 Konten)
```

---

## 22. buchungs_vorlagen

**Beschreibung**: Vordefinierte Geschäftsfälle-Templates aus dem Excel-Sheet "Geschäftsfälle".
Legen fest welche Konten (Soll/Haben/MWST) für jeden Geschäftsfall verwendet werden.
Basis für automatische und manuelle Buchungen.

```sql
CREATE TABLE buchungs_vorlagen (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Geschäftsfall-Identifikation (aus Excel)
  geschaeftsfall_id TEXT NOT NULL,   -- z.B. '1', '1.1', '1.2', '22.4'
  bezeichnung TEXT NOT NULL,          -- z.B. 'Reinigung Bar', 'Lohnzahlung'

  -- Konten (Nummern, da konten-Tabelle user-spezifisch)
  soll_konto INTEGER NOT NULL,        -- Sollkonto-Nummer
  haben_konto INTEGER NOT NULL,       -- Habenkonto-Nummer
  mwst_konto INTEGER,                 -- MWST-Konto (NULL = keine MWST)
  mwst_satz DECIMAL(4,2),             -- z.B. 8.10 (NULL = keine MWST)

  -- Zahlungsweg (für Vorlagen mit mehreren Varianten)
  zahlungsweg TEXT CHECK (zahlungsweg IN ('kasse', 'bank', 'privat', 'alle')),

  -- Belegordner (aus Excel)
  belegordner TEXT,                   -- z.B. '010_Reinigung', '220_Lohnzahlung'

  -- Automatische Auslösung durch App-Events
  auto_trigger TEXT CHECK (auto_trigger IN (
    'rechnung_erstellt_kunde',    -- GF 1.1: Kundenrechnung erstellt
    'rechnung_erstellt_heineken', -- GF 1.2: Heineken-Monatsrechnung erstellt
    'zahlung_eingegangen_kunde',  -- GF 2: Zahlungseingang vom Kunden
    'zahlung_eingegangen_heineken', -- GF 2.2: Zahlungseingang Heineken
    'mwst_abrechnung',            -- GF 25.x: Quartals-MWST
    NULL                          -- Nur manuelle Buchung
  )),

  ist_aktiv BOOLEAN DEFAULT TRUE,
  notizen TEXT,

  created_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(user_id, geschaeftsfall_id, zahlungsweg)
);

CREATE INDEX idx_buchungs_vorlagen_user ON buchungs_vorlagen(user_id);
CREATE INDEX idx_buchungs_vorlagen_trigger ON buchungs_vorlagen(auto_trigger) WHERE auto_trigger IS NOT NULL;

-- RLS
ALTER TABLE buchungs_vorlagen ENABLE ROW LEVEL SECURITY;
CREATE POLICY buchungs_vorlagen_user_isolation ON buchungs_vorlagen FOR ALL USING (user_id = auth.uid());

-- Initiale Vorlagen (aus Geschäftsfälle-Sheet – wird beim Onboarding eingefügt)
-- GF  1   Reinigung Bar:              1000 / 3400 (MWST 2200, 8.1%) → auto: NULL
-- GF  1.1 Reinigung Rechnung:         1100 / 3400 (MWST 2200, 8.1%) → auto: rechnung_erstellt_kunde
-- GF  1.2 Heineken Monatsrechnung:    1100 / 3400 (MWST 2200, 8.1%) → auto: rechnung_erstellt_heineken
-- GF  1.9 Abgeschriebene Rechnungen:  3400 / 1100 (MWST 2200, 8.1%) → auto: NULL
-- GF  2   Zahlungseingang Reinigung:  1020 / 1100 (keine MWST)       → auto: zahlung_eingegangen_kunde
-- GF  2.1 Zahlungseingang Kasse:      1020 / 1000 (keine MWST)       → auto: NULL
-- GF  2.2 Zahlungseingang Heineken:   1020 / 1100 (keine MWST)       → auto: zahlung_eingegangen_heineken
-- GF  3.1 Spesen (Kasse):             5820 / 1000 (VS 1171, 8.1%)    → zahlungsweg: kasse
-- GF  3.2 Spesen (Bank):              5820 / 1020 (VS 1171, 8.1%)    → zahlungsweg: bank
-- GF  3.3 Spesen (Privat):            5820 / 2260 (VS 1171, 8.1%)    → zahlungsweg: privat
-- GF  4.x Tanken:                     6200 / var  (VS 1171, 8.1%)
-- GF  5.x Parkgebühren:               6270 / var  (VS 1171, 8.1%)
-- GF  6.x Bussen:                     6280 / var  (VS 1171, 8.1%)
-- GF  7.x Fahrbewilligungen:          6275 / var  (VS 1171, 8.1%)
-- GF  8.x Autoreparaturen:            6250 / var  (VS 1171, 8.1%)
-- GF 10.x Werkzeug/Material:          4004 / var  (VS 1171, 8.1%)
-- GF 11.x Berufskleider:              5850 / var  (VS 1171, 8.1%)
-- GF 14.x Briefmarken:                6510 / var  (keine MWST)
-- GF 15.x Internetabo:                6510 / var  (VS 1171, 8.1%)
-- GF 16.x Mobileabo:                  6510 / var  (VS 1171, 8.1%)
-- GF 17.x Software:                   6560 / var  (VS 1171, 8.1%)
-- GF 18.x Büromiete:                  6000 / 1020 (keine MWST)
-- GF 19   Rechnung Franchisegebühr:   6301 / 2000 (VS 1170, 8.1%)   → auto: NULL
-- GF 19.1 Einzahlung Franchisegebühr: 2000 / 1020 (keine MWST)      → auto: NULL
-- GF 20.x Bankgebühren:               6940 / 1020 (keine MWST)
-- GF 21.x Buchführung:                6530 / 1020 (VS 1171, 8.1%)
-- GF 22   Lohnzahlung:                5000 / 2002 (keine MWST)
-- GF 22.1–22.6 Sozialabzüge: je nach Abzugsart
-- GF 22.7 Nettolohn auszahlen:        2002 / 1020 (keine MWST)
-- GF 23.x Auszahlung SVA/AXA/SUVA:   271/272/273 / 1020
-- GF 24   Haftpflicht:                6300 / 1020 (keine MWST)
-- GF 25.1–25.4 MWST-Abrechnung:      auto: mwst_abrechnung
-- GF 30.x Steuern/Abschluss: div.
```

---

## 23. buchungen

**Beschreibung**: Journal – alle Buchungssätze chronologisch. Werden teils automatisch
durch App-Events (Rechnung erstellt, Zahlung eingegangen) erzeugt, teils manuell erfasst.

**Buchungslogik Splitbuchung (3-Konto)**:
- `betrag_brutto` → Soll-Konto (z.B. 1100 Debitoren bei Rechnung)
- `betrag_netto` → Haben-Konto (z.B. 3400 Ertrag)
- `mwst_betrag` → MWST-Konto (z.B. 2200 Geschuldete MWST)

```sql
CREATE TABLE buchungen (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Datum und Identifikation
  datum DATE NOT NULL DEFAULT CURRENT_DATE,
  belegnummer TEXT,                  -- z.B. Rechnungsnummer, QR-Ref.

  -- Vorlage (Geschäftsfall)
  vorlage_id UUID REFERENCES buchungs_vorlagen(id) ON DELETE SET NULL,

  -- Konten (Nummern – kann von Vorlage abweichen für Sonderfälle)
  soll_konto INTEGER NOT NULL,       -- z.B. 1100
  haben_konto INTEGER NOT NULL,      -- z.B. 3400
  mwst_konto INTEGER,                -- z.B. 2200 (NULL = keine MWST)

  -- Beträge
  betrag_netto DECIMAL(10,2) NOT NULL,
  mwst_satz DECIMAL(4,2) NOT NULL DEFAULT 0,
  mwst_betrag DECIMAL(10,2) NOT NULL DEFAULT 0,
  betrag_brutto DECIMAL(10,2) NOT NULL,

  -- Beschreibung
  beschreibung TEXT NOT NULL,

  -- Zahlungsweg (Kasse / Bank / Privat)
  zahlungsweg TEXT CHECK (zahlungsweg IN ('kasse', 'bank', 'privat')),

  -- Belegordner
  belegordner TEXT,                  -- z.B. '010_Reinigung'

  -- Verknüpfung mit Quelldokument (optional)
  beleg_typ TEXT CHECK (beleg_typ IN (
    'rechnung', 'eingang', 'lohn', 'mwst', 'sonstiges'
  )),
  beleg_id UUID,                     -- FK zu rechnungen.id o.ä.

  -- Buchungsperiode
  geschaeftsjahr INTEGER NOT NULL DEFAULT EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER,
  monat INTEGER GENERATED ALWAYS AS (EXTRACT(MONTH FROM datum)::INTEGER) STORED,
  quartal INTEGER GENERATED ALWAYS AS (EXTRACT(QUARTER FROM datum)::INTEGER) STORED,

  -- Stornierung
  ist_storniert BOOLEAN DEFAULT FALSE,
  storno_von_id UUID REFERENCES buchungen(id) ON DELETE SET NULL,

  notizen TEXT,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_buchungen_user ON buchungen(user_id);
CREATE INDEX idx_buchungen_datum ON buchungen(datum DESC);
CREATE INDEX idx_buchungen_konto_soll ON buchungen(soll_konto);
CREATE INDEX idx_buchungen_konto_haben ON buchungen(haben_konto);
CREATE INDEX idx_buchungen_beleg ON buchungen(beleg_typ, beleg_id);
CREATE INDEX idx_buchungen_periode ON buchungen(geschaeftsjahr, quartal, monat);

CREATE TRIGGER update_buchungen_updated_at
  BEFORE UPDATE ON buchungen
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- RLS
ALTER TABLE buchungen ENABLE ROW LEVEL SECURITY;
CREATE POLICY buchungen_user_isolation ON buchungen FOR ALL USING (user_id = auth.uid());
```

### Trigger: Auto-Buchung bei Rechnung erstellt

```sql
-- Wenn Rechnung von 'entwurf' → 'offen' wechselt, automatisch Buchung erstellen
CREATE OR REPLACE FUNCTION auto_buchung_rechnung_erstellt()
RETURNS TRIGGER AS $$
DECLARE
  v_vorlage buchungs_vorlagen%ROWTYPE;
  v_trigger_name TEXT;
BEGIN
  -- Nur bei Statuswechsel entwurf → offen
  IF OLD.zahlungsstatus = 'entwurf' AND NEW.zahlungsstatus = 'offen' THEN

    v_trigger_name := CASE NEW.rechnungstyp
      WHEN 'kundenrechnung'  THEN 'rechnung_erstellt_kunde'
      WHEN 'heineken_monat'  THEN 'rechnung_erstellt_heineken'
    END;

    SELECT * INTO v_vorlage FROM buchungs_vorlagen
    WHERE user_id = NEW.user_id AND auto_trigger = v_trigger_name
    LIMIT 1;

    IF v_vorlage.id IS NOT NULL THEN
      INSERT INTO buchungen (
        user_id, datum, belegnummer,
        vorlage_id, soll_konto, haben_konto, mwst_konto,
        betrag_netto, mwst_satz, mwst_betrag, betrag_brutto,
        beschreibung, belegordner, beleg_typ, beleg_id, geschaeftsjahr
      ) VALUES (
        NEW.user_id,
        NEW.rechnungsdatum,
        NEW.rechnungsnummer,
        v_vorlage.id,
        v_vorlage.soll_konto,
        v_vorlage.haben_konto,
        v_vorlage.mwst_konto,
        NEW.betrag_netto,
        COALESCE(v_vorlage.mwst_satz, 0),
        NEW.mwst_betrag,
        NEW.betrag_brutto,
        CASE NEW.rechnungstyp
          WHEN 'kundenrechnung' THEN 'Rechnung ' || NEW.rechnungsnummer
          WHEN 'heineken_monat' THEN 'Heineken Monatsrechnung ' || TO_CHAR(NEW.heineken_monat, 'MM/YYYY')
        END,
        v_vorlage.belegordner,
        'rechnung',
        NEW.id,
        EXTRACT(YEAR FROM NEW.rechnungsdatum)::INTEGER
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER rechnungen_auto_buchung_erstellt
  AFTER UPDATE OF zahlungsstatus ON rechnungen
  FOR EACH ROW EXECUTE FUNCTION auto_buchung_rechnung_erstellt();
```

### Trigger: Auto-Buchung bei Zahlungseingang

```sql
CREATE OR REPLACE FUNCTION auto_buchung_zahlung_eingegangen()
RETURNS TRIGGER AS $$
DECLARE
  v_vorlage buchungs_vorlagen%ROWTYPE;
  v_trigger_name TEXT;
BEGIN
  -- Nur bei Statuswechsel → bezahlt
  IF NEW.zahlungsstatus = 'bezahlt' AND OLD.zahlungsstatus != 'bezahlt' THEN

    v_trigger_name := CASE NEW.rechnungstyp
      WHEN 'kundenrechnung'  THEN 'zahlung_eingegangen_kunde'
      WHEN 'heineken_monat'  THEN 'zahlung_eingegangen_heineken'
    END;

    SELECT * INTO v_vorlage FROM buchungs_vorlagen
    WHERE user_id = NEW.user_id AND auto_trigger = v_trigger_name
    LIMIT 1;

    IF v_vorlage.id IS NOT NULL THEN
      INSERT INTO buchungen (
        user_id, datum, belegnummer,
        vorlage_id, soll_konto, haben_konto, mwst_konto,
        betrag_netto, mwst_satz, mwst_betrag, betrag_brutto,
        beschreibung, belegordner, beleg_typ, beleg_id, geschaeftsjahr
      ) VALUES (
        NEW.user_id,
        COALESCE(NEW.zahlung_eingegangen_am, CURRENT_DATE),
        NEW.rechnungsnummer,
        v_vorlage.id,
        v_vorlage.soll_konto,   -- 1020 (Bank)
        v_vorlage.haben_konto,  -- 1100 (Debitoren)
        NULL,                    -- Zahlungseingang: keine MWST
        NEW.betrag_brutto,      -- Brutto = Netto bei Zahlungseingang (MWST bereits gebucht)
        0,
        0,
        NEW.betrag_brutto,
        'Zahlungseingang ' || NEW.rechnungsnummer,
        v_vorlage.belegordner,
        'rechnung',
        NEW.id,
        EXTRACT(YEAR FROM COALESCE(NEW.zahlung_eingegangen_am, CURRENT_DATE))::INTEGER
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER rechnungen_auto_buchung_zahlung
  AFTER UPDATE OF zahlungsstatus ON rechnungen
  FOR EACH ROW EXECUTE FUNCTION auto_buchung_zahlung_eingegangen();
```

---

## VIEWS

### Anlagen mit Service-Status

```sql
CREATE OR REPLACE VIEW view_anlagen_service_status AS
SELECT
  a.id,
  a.user_id,
  b.name AS betrieb_name,
  b.ort,
  r.name AS region_name,
  a.bezeichnung,
  a.typ_anlage,
  a.anzahl_haehne,
  a.reinigung_rhythmus,
  a.letzte_reinigung,
  a.naechste_reinigung,
  CASE
    WHEN a.naechste_reinigung < CURRENT_DATE                       THEN 'ueberfaellig'
    WHEN a.naechste_reinigung <= CURRENT_DATE + INTERVAL '7 days' THEN 'faellig_bald'
    ELSE 'ok'
  END AS service_status,
  a.status,
  b.ist_bergkunde,
  b.ist_saisonbetrieb
FROM anlagen a
JOIN betriebe b ON a.betrieb_id = b.id
LEFT JOIN regionen r ON b.region_id = r.id
WHERE a.status = 'aktiv';
```

### Bestellliste (Material mit niedrigem Bestand)

```sql
CREATE OR REPLACE VIEW view_bestellliste AS
SELECT
  m.id,
  m.user_id,
  mk.name AS kategorie,
  m.name,
  m.artikel_nummer,
  m.einheit,
  m.bestand_aktuell,
  m.bestand_mindest,
  m.bestand_optimal,
  (m.bestand_optimal - m.bestand_aktuell) AS bestellmenge,
  m.lieferant,
  m.lieferanten_artikel_nr,
  m.preis_einkauf,
  ((m.bestand_optimal - m.bestand_aktuell) * m.preis_einkauf) AS bestellkosten_geschaetzt
FROM material m
LEFT JOIN material_kategorien mk ON m.kategorie_id = mk.id
WHERE m.bestand_niedrig = TRUE AND m.ist_aktiv = TRUE
ORDER BY mk.sortierung, mk.name, m.name;
```

### Offene Rechnungen

```sql
CREATE OR REPLACE VIEW view_offene_rechnungen AS
SELECT
  r.id,
  r.user_id,
  r.rechnungsnummer,
  r.rechnungstyp,
  b.name AS betrieb_name,
  r.heineken_monat,
  r.rechnungsdatum,
  r.faelligkeitsdatum,
  (CURRENT_DATE - r.faelligkeitsdatum) AS ueberfaellig_seit_tagen,
  r.betrag_brutto,
  r.zahlungsstatus,
  r.mahnung_stufe,
  r.versandart
FROM rechnungen r
LEFT JOIN betriebe b ON r.betrieb_id = b.id
WHERE r.zahlungsstatus IN ('offen', 'ueberfaellig', 'teilbezahlt')
ORDER BY r.faelligkeitsdatum ASC;
```

### MWST-Abrechnung (quartalsweise)

```sql
CREATE OR REPLACE VIEW view_mwst_abrechnung AS
SELECT
  b.user_id,
  b.geschaeftsjahr,
  b.quartal,
  -- Umsatzsteuer (Konto 2200 im Haben = geschuldete MWST)
  SUM(CASE WHEN b.mwst_konto = 2200 THEN b.mwst_betrag ELSE 0 END) AS umsatzsteuer,
  -- Vorsteuer Material (Konto 1170 im Haben = Vorsteuer)
  SUM(CASE WHEN b.mwst_konto = 1170 THEN b.mwst_betrag ELSE 0 END) AS vorsteuer_investitionen,
  -- Vorsteuer übrig (Konto 1171)
  SUM(CASE WHEN b.mwst_konto = 1171 THEN b.mwst_betrag ELSE 0 END) AS vorsteuer_betrieb,
  -- Netto-MWST-Schuld
  SUM(CASE WHEN b.mwst_konto = 2200 THEN b.mwst_betrag ELSE 0 END)
  - SUM(CASE WHEN b.mwst_konto IN (1170, 1171) THEN b.mwst_betrag ELSE 0 END) AS netto_mwst_schuld,
  COUNT(*) FILTER (WHERE NOT b.ist_storniert) AS anzahl_buchungen
FROM buchungen b
WHERE NOT b.ist_storniert
  AND b.mwst_konto IS NOT NULL
GROUP BY b.user_id, b.geschaeftsjahr, b.quartal
ORDER BY b.geschaeftsjahr DESC, b.quartal DESC;
```

### Erfolgsrechnung (P&L nach Monat)

```sql
CREATE OR REPLACE VIEW view_erfolgsrechnung AS
SELECT
  b.user_id,
  b.geschaeftsjahr,
  b.monat,
  -- Erträge (Klasse 3: Haben-Seite)
  SUM(CASE WHEN b.haben_konto BETWEEN 3000 AND 3999 THEN b.betrag_netto ELSE 0 END) AS ertrag,
  -- Materialaufwand (Klasse 4)
  SUM(CASE WHEN b.soll_konto BETWEEN 4000 AND 4999 THEN b.betrag_netto ELSE 0 END) AS materialaufwand,
  -- Personalaufwand (Klasse 5)
  SUM(CASE WHEN b.soll_konto BETWEEN 5000 AND 5999 THEN b.betrag_netto ELSE 0 END) AS personalaufwand,
  -- Betriebsaufwand (Klasse 6)
  SUM(CASE WHEN b.soll_konto BETWEEN 6000 AND 6999 THEN b.betrag_netto ELSE 0 END) AS betriebsaufwand,
  -- Betriebsergebnis
  SUM(CASE WHEN b.haben_konto BETWEEN 3000 AND 3999 THEN b.betrag_netto ELSE 0 END)
  - SUM(CASE WHEN b.soll_konto BETWEEN 4000 AND 6999 THEN b.betrag_netto ELSE 0 END) AS betriebsergebnis
FROM buchungen b
WHERE NOT b.ist_storniert
GROUP BY b.user_id, b.geschaeftsjahr, b.monat
ORDER BY b.geschaeftsjahr DESC, b.monat DESC;
```

### Hauptbuch (Kontoauszug pro Konto)

```sql
CREATE OR REPLACE VIEW view_hauptbuch AS
SELECT
  b.user_id,
  b.datum,
  b.belegnummer,
  b.beschreibung,
  -- Soll-Seite
  b.soll_konto,
  CASE WHEN b.soll_konto = k_soll.kontonummer THEN b.betrag_brutto END AS soll_betrag,
  -- Haben-Seite
  b.haben_konto,
  CASE WHEN b.haben_konto = k_haben.kontonummer THEN b.betrag_netto END AS haben_betrag,
  b.mwst_konto,
  b.mwst_betrag,
  b.belegordner,
  b.ist_storniert
FROM buchungen b
LEFT JOIN konten k_soll  ON k_soll.kontonummer  = b.soll_konto  AND k_soll.user_id  = b.user_id
LEFT JOIN konten k_haben ON k_haben.kontonummer = b.haben_konto AND k_haben.user_id = b.user_id
WHERE NOT b.ist_storniert
ORDER BY b.datum DESC, b.created_at DESC;
```

### Monatsübersicht Heineken-Abrechnung

```sql
CREATE OR REPLACE VIEW view_heineken_monatsabrechnung AS
SELECT
  user_id,
  abrechnungs_monat,
  'stoerung' AS typ,
  COUNT(*) AS anzahl,
  SUM(0) AS betrag_gesamt   -- Heineken: Störungsabrechnung individuell
FROM stoerungen WHERE abgerechnet = FALSE AND abrechnungs_monat IS NOT NULL
GROUP BY user_id, abrechnungs_monat

UNION ALL

SELECT user_id, abrechnungs_monat, 'montage', COUNT(*), SUM(kosten_gesamt)
FROM montagen WHERE abgerechnet = FALSE AND abrechnungs_monat IS NOT NULL
GROUP BY user_id, abrechnungs_monat

UNION ALL

SELECT user_id, abrechnungs_monat, 'eigenauftrag', COUNT(*), SUM(pauschale)
FROM eigenauftraege WHERE abgerechnet = FALSE AND abrechnungs_monat IS NOT NULL
GROUP BY user_id, abrechnungs_monat

UNION ALL

SELECT user_id, abrechnungs_monat, 'pikett', COUNT(*), SUM(pauschale)
FROM pikett_dienste WHERE abgerechnet = FALSE AND abrechnungs_monat IS NOT NULL
GROUP BY user_id, abrechnungs_monat

ORDER BY abrechnungs_monat, typ;
```

---

## MIGRATION REIHENFOLGE

```sql
-- supabase/migrations/001_initial_schema.sql

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
-- (Optional später: CREATE EXTENSION IF NOT EXISTS postgis;)

-- 1. Helper Function
-- 2. user_profiles
-- 3. regionen
-- 4. betriebe
-- 5. betrieb_kontakte
-- 6. betrieb_rechnungsadressen
-- 7. anlagen
-- 8. bierleitungen
-- 9. anlagen_fotos
-- 10. preise
-- 11. reinigungen (inkl. Trigger)
-- 12. stoerungen
-- 13. montagen (inkl. Trigger)
-- 14. eigenauftraege (inkl. Trigger)
-- 15. pikett_dienste (inkl. Trigger)
-- 16. material_kategorien
-- 17. material
-- 18. material_verbrauch (inkl. Trigger)
-- 19. rechnungsnummer_seq
-- 20. rechnungen (inkl. Trigger)
-- 21. rechnungs_positionen (inkl. Trigger)
-- 22. konten
-- 23. buchungs_vorlagen
-- 24. buchungen (inkl. Trigger)
-- 25. Views (inkl. Buchhaltungs-Views)

-- FK nachträglich hinzufügen:
ALTER TABLE user_profiles
  ADD CONSTRAINT fk_user_profiles_region
  FOREIGN KEY (default_region_id) REFERENCES regionen(id) ON DELETE SET NULL;
```

---

## ABRECHNUNGSLOGIK ÜBERSICHT

| Service | Empfänger | Abrechnungsart |
|---------|-----------|----------------|
| Reinigung | Betrieb direkt | Kundenrechnung (wöchentlich aggregiert) |
| Störung | Heineken | Monatsrechnung + Störungsnummer |
| Montage | Heineken | Monatsrechnung + Auftragsnummer (Stundenbasiert) |
| Eigenauftrag | Heineken | Monatsrechnung + Störungsnummer (30 CHF Pauschale) |
| Pikett | Heineken | Monatsrechnung (160 CHF Pauschale pro Wochenende) |

---

## BUCHHALTUNGSLOGIK ÜBERSICHT

### Automatische Buchungen (App-generiert)

| Auslöser | GF | Soll | Haben | MWST | Betrag |
|----------|----|------|-------|------|--------|
| Kundenrechnung erstellt | 1.1 | 1100 | 3400 | 2200 (8.1%) | Rechnungsbetrag |
| Heineken-Monatsrechnung erstellt | 1.2 | 1100 | 3400 | 2200 (8.1%) | Rechnungsbetrag |
| Zahlungseingang Kunde | 2 | 1020 | 1100 | — | Brutto-Betrag |
| Zahlungseingang Heineken | 2.2 | 1020 | 1100 | — | Brutto-Betrag |

### Manuelle Buchungen (Daniel erfasst in App)

| Kategorie | GF | Soll | Haben | MWST |
|-----------|-----|------|-------|------|
| Tanken (Bank) | 4.2 | 6200 | 1020 | VS 1171 (8.1%) |
| Spesen (Bank) | 3.2 | 5820 | 1020 | VS 1171 (8.1%) |
| Parkgebühren | 5.x | 6270 | var | VS 1171 (8.1%) |
| Werkzeug/Material | 10.x | 4004 | var | VS 1171 (8.1%) |
| Berufskleider | 11.x | 5850 | var | VS 1171 (8.1%) |
| Franchisegebühr Heineken | 19 | 6301 | 2000 | VS 1170 (8.1%) |
| Franchisegebühr Einzahlung | 19.1 | 2000 | 1020 | — |
| Lohnzahlung | 22.7 | 2002 | 1020 | — |
| MWST-Abrechnung (quartalsweise) | 25.x | 2202 | 1170/1171/2200 | — |

### 3 Zahlungswege (konsequent durch alle Ausgabenbuchungen)

| Zahlungsweg | Habenkonto | Verwendung |
|-------------|------------|------------|
| Kasse | 1000 | Barausgaben |
| Bank | 1020 | IBAN-Zahlungen, Lastschriften |
| Privat | 2260 | Daniel zahlt privat → Erstattung via KK Gesellschafter |

---

**Zuletzt aktualisiert**: 12.02.2026

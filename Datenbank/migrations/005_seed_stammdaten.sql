-- ============================================================
-- Migration 005: Seed-Daten Stammdaten
-- Projekt: SBS Projer App
-- Stand: 12.02.2026
-- Beschreibung: Regionen (11 Stück) + Materialkategorien (20 Stück)
--               Wird beim Onboarding eines neuen Users ausgeführt.
-- WICHTIG: auth.uid() muss gültig sein (User muss eingeloggt sein)
-- Ausführen NACH: 002_rls_policies.sql
-- ============================================================

-- Regionen (Daniels 11 Serviceregionen in Graubünden)
INSERT INTO regionen (user_id, name)
VALUES
  (auth.uid(), 'Arosa'),
  (auth.uid(), 'Chur'),
  (auth.uid(), 'Davos'),
  (auth.uid(), 'Domleschg'),
  (auth.uid(), 'Flims/Laax/Falera'),
  (auth.uid(), 'Lenzerheide'),
  (auth.uid(), 'Oberland'),
  (auth.uid(), 'Prättigau'),
  (auth.uid(), 'Rheintal'),
  (auth.uid(), 'Rheinwald'),
  (auth.uid(), 'Innerschweiz')
ON CONFLICT (user_id, name) DO NOTHING;

-- Materialkategorien (20 Kategorien aus Heineken-Artikelstamm, 885 Artikel)
INSERT INTO material_kategorien (user_id, name, beschreibung, sortierung)
VALUES
  (auth.uid(), 'Zapfhahn',               'Bierhähne, Rosetten, Stutzen, Dichtungssätze, Kompensatoren',         10),
  (auth.uid(), 'Zapfkopf',               'Micro-Matic, Fob-Stop, Ergogriff, Reinigungsadapter Bier',            20),
  (auth.uid(), 'Säule',                  'Cobra, Falco, Tube, Laser, Arrow, Europe – inkl. Balken und Sätze',   30),
  (auth.uid(), 'Bierkühler',             'FK-MU, BKG, CR, V100GE, H100GE, Boosterkühler, Glykolkühler',        40),
  (auth.uid(), 'Fasskühler',             'FK2/FK4/FK6/FK8, Türdichtungen, Magnetverschluss, Steg',              50),
  (auth.uid(), 'Kühlschlange',           'Kühlschlangensätze zu CR 4 / CR 5-6 / CR 7',                         60),
  (auth.uid(), 'Pumpe/Motor/Lüfter',     'Pumpen (Gamko, Samec, EBM), Rührwerke, Ventilatormotoren',            70),
  (auth.uid(), 'Thermostat/Regler',      'Thermostate, Eisbankregulator, Temperaturfühler, Regelboxen',         80),
  (auth.uid(), 'Druck/Gas',              'CO2-Druckreduzierer, Manometer, HD-Schlauch, Fl.-Anschluss, Filter',  90),
  (auth.uid(), 'Verbinder / Briden',     'John-Guest-Verbinder, Umkehrbögen, Winkel, Dreifachverteiler',       100),
  (auth.uid(), 'Bierleitung',            'Bierleitungen, Pythons, Isolierschläuche',                           110),
  (auth.uid(), 'Gläserdusche/Tropfschale','ETS, Auflegetropfschalen, Spritzdüsen, Spülkreuz, Einbauschalen',  120),
  (auth.uid(), 'Dichtungen',             'Bierdichtungen, O-Ringe, Hauptdichtungen, Gehäusedichtungen',        130),
  (auth.uid(), 'Elektronik',             'Kondensatoren, Startrelais, Platinen, Trafos, LED-Beleuchtung',      140),
  (auth.uid(), 'Montagematerial',        'Abdeckplatten, Alu-Konsolen, Tablare, Holzböckli, Befestigungen',    150),
  (auth.uid(), 'Reinigungsmaterial',     'Reinigungsadapter Wein/Bier, Reinigungstank, Spülzubehör',          160),
  (auth.uid(), 'Verbrauchsmaterial',     'Glykol, Kühlflüssigkeit, Reinigungsmittel',                         170),
  (auth.uid(), 'Branding',              'Plaketten, Linsen, Griffe, Werbepanels, Logos (Heineken/Calanda/…)',  180),
  (auth.uid(), 'Werkzeug',              'Spezialwerkzeug (z.B. Halteelement-Werkzeug JG)',                    190),
  (auth.uid(), 'Sonstiges',            'Kugelventile, Sicherungen, Kleider, nicht klassifizierbare Artikel',   200)
ON CONFLICT (user_id, name) DO NOTHING;

-- Initiale Preisliste (Heineken 2026)
-- HINWEIS: Preise nach erstem Login manuell prüfen und ggf. anpassen
INSERT INTO preise (
  user_id, gueltig_ab,
  grundtarif_reinigung_bier, grundtarif_reinigung_orion,
  grundtarif_heigenie, grundtarif_reinigung_fremd, grundtarif_wein,
  zusatz_hahn_eigen, zusatz_hahn_orion, zusatz_hahn_fremd,
  zusatz_hahn_wein, zusatz_hahn_anderer_standort,
  montage_stundensatz
) VALUES (
  auth.uid(), '2026-01-01',
  -- Grundtarife Reinigung (aus Excel-Analyse, exkl. MWST)
  69.00,  -- Bier/Eigen
  92.00,  -- Orion
  0.00,   -- Heigenie (TODO: Preis prüfen)
  92.00,  -- Fremd
  92.00,  -- Wein
  -- Zusatz-Hähne
  23.00,  -- Eigen (1 Hahn inklusive, ab 2. Hahn)
  23.00,  -- Orion
  23.00,  -- Fremd
  23.00,  -- Wein
  23.00,  -- Anderer Standort
  -- Montage
  80.00   -- CHF/Stunde
)
ON CONFLICT DO NOTHING;

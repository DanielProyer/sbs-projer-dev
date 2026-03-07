-- ============================================================
-- ADMIN SETUP: Seed-Daten für Daniel Projer (erste Initialisierung)
-- Projekt: SBS Projer App
-- Stand: 12.02.2026
--
-- WICHTIG: Dieser Script ersetzt 005 + 006 für den SQL Editor!
--          (auth.uid() ist im SQL Editor NULL → manuell eintragen)
--
-- VORBEREITUNG:
--   1. Supabase Dashboard → Authentication → Users → "Add user"
--   2. Email + Passwort für Daniel eintragen
--   3. Auf den neuen User klicken → UUID kopieren
--   4. UUID unten bei v_user_id eintragen
--   5. Dieses Script im SQL Editor ausführen
--
-- DANACH:
--   - 007_artikelstamm_heineken.sql im SQL Editor ausführen
--     (UUID ist dort bereits hardcoded - Datei 1:1 kopieren)
-- ============================================================

DO $$
DECLARE
  -- *** DEINE UUID HIER EINTRAGEN ***
  -- (aus Authentication → Users → auf User klicken → UUID kopieren)
  v_user_id UUID := '1e1ec2dd-7836-4d8e-8256-c5649d994ee2';

BEGIN

  -- Prüfen ob UUID gesetzt wurde
  IF v_user_id = '00000000-0000-0000-0000-000000000000' THEN
    RAISE EXCEPTION 'UUID nicht gesetzt! Bitte v_user_id oben mit deiner UUID ersetzen.';
  END IF;

  RAISE NOTICE 'Starte Setup für User: %', v_user_id;

  -- ============================================================
  -- REGIONEN (11 Serviceregionen Graubünden)
  -- ============================================================
  INSERT INTO regionen (user_id, name) VALUES
    (v_user_id, 'Arosa'),
    (v_user_id, 'Chur'),
    (v_user_id, 'Davos'),
    (v_user_id, 'Domleschg'),
    (v_user_id, 'Flims/Laax/Falera'),
    (v_user_id, 'Lenzerheide'),
    (v_user_id, 'Oberland'),
    (v_user_id, 'Prättigau'),
    (v_user_id, 'Rheintal'),
    (v_user_id, 'Rheinwald'),
    (v_user_id, 'Innerschweiz')
  ON CONFLICT (user_id, name) DO NOTHING;

  RAISE NOTICE '✓ Regionen: 11 Stück';

  -- ============================================================
  -- MATERIALKATEGORIEN (20 Kategorien aus Heineken-Artikelstamm)
  -- ============================================================
  INSERT INTO material_kategorien (user_id, name, beschreibung, sortierung) VALUES
    (v_user_id, 'Zapfhahn',               'Bierhähne, Rosetten, Stutzen, Dichtungssätze, Kompensatoren',         10),
    (v_user_id, 'Zapfkopf',               'Micro-Matic, Fob-Stop, Ergogriff, Reinigungsadapter Bier',            20),
    (v_user_id, 'Säule',                  'Cobra, Falco, Tube, Laser, Arrow, Europe – inkl. Balken und Sätze',   30),
    (v_user_id, 'Bierkühler',             'FK-MU, BKG, CR, V100GE, H100GE, Boosterkühler, Glykolkühler',        40),
    (v_user_id, 'Fasskühler',             'FK2/FK4/FK6/FK8, Türdichtungen, Magnetverschluss, Steg',              50),
    (v_user_id, 'Kühlschlange',           'Kühlschlangensätze zu CR 4 / CR 5-6 / CR 7',                         60),
    (v_user_id, 'Pumpe/Motor/Lüfter',     'Pumpen (Gamko, Samec, EBM), Rührwerke, Ventilatormotoren',            70),
    (v_user_id, 'Thermostat/Regler',      'Thermostate, Eisbankregulator, Temperaturfühler, Regelboxen',         80),
    (v_user_id, 'Druck/Gas',              'CO2-Druckreduzierer, Manometer, HD-Schlauch, Fl.-Anschluss, Filter',  90),
    (v_user_id, 'Verbinder / Briden',     'John-Guest-Verbinder, Umkehrbögen, Winkel, Dreifachverteiler',       100),
    (v_user_id, 'Bierleitung',            'Bierleitungen, Pythons, Isolierschläuche',                           110),
    (v_user_id, 'Gläserdusche/Tropfschale','ETS, Auflegetropfschalen, Spritzdüsen, Spülkreuz, Einbauschalen',  120),
    (v_user_id, 'Dichtungen',             'Bierdichtungen, O-Ringe, Hauptdichtungen, Gehäusedichtungen',        130),
    (v_user_id, 'Elektronik',             'Kondensatoren, Startrelais, Platinen, Trafos, LED-Beleuchtung',      140),
    (v_user_id, 'Montagematerial',        'Abdeckplatten, Alu-Konsolen, Tablare, Holzböckli, Befestigungen',    150),
    (v_user_id, 'Reinigungsmaterial',     'Reinigungsadapter Wein/Bier, Reinigungstank, Spülzubehör',          160),
    (v_user_id, 'Verbrauchsmaterial',     'Glykol, Kühlflüssigkeit, Reinigungsmittel',                         170),
    (v_user_id, 'Branding',              'Plaketten, Linsen, Griffe, Werbepanels, Logos (Heineken/Calanda/…)',  180),
    (v_user_id, 'Werkzeug',              'Spezialwerkzeug (z.B. Halteelement-Werkzeug JG)',                    190),
    (v_user_id, 'Sonstiges',            'Kugelventile, Sicherungen, Kleider, nicht klassifizierbare Artikel',   200)
  ON CONFLICT (user_id, name) DO NOTHING;

  RAISE NOTICE '✓ Materialkategorien: 20 Stück';

  -- ============================================================
  -- PREISLISTE 2026
  -- ============================================================
  INSERT INTO preise (
    user_id, gueltig_ab,
    grundtarif_reinigung_bier, grundtarif_reinigung_orion,
    grundtarif_heigenie, grundtarif_reinigung_fremd, grundtarif_wein,
    zusatz_hahn_eigen, zusatz_hahn_orion, zusatz_hahn_fremd,
    zusatz_hahn_wein, zusatz_hahn_anderer_standort,
    montage_stundensatz
  ) VALUES (
    v_user_id, '2026-01-01',
    69.00,  -- Bier/Eigen
    92.00,  -- Orion
     0.00,  -- Heigenie (TODO: Preis prüfen)
    92.00,  -- Fremd
    92.00,  -- Wein
    23.00,  -- Zusatz Eigen (1 Hahn inklusive, ab 2. Hahn)
    23.00,  -- Zusatz Orion
    23.00,  -- Zusatz Fremd
    23.00,  -- Zusatz Wein
    23.00,  -- Zusatz anderer Standort
    80.00   -- Montage CHF/Stunde
  )
  ON CONFLICT DO NOTHING;

  RAISE NOTICE '✓ Preisliste 2026';

  -- ============================================================
  -- KONTEN (61 Konten aus Daniels Kontenrahmen-Sheet)
  -- ============================================================
  INSERT INTO konten (user_id, kontonummer, bezeichnung, beschreibung, kategorie) VALUES

    -- UMLAUFVERMÖGEN (1xxx)
    (v_user_id, 1000, 'Kasse',               'Eintragen der laufenden Ein- und Auszahlungen',                        'Umlaufvermögen'),
    (v_user_id, 1020, 'Bankguthaben',         'PostFinance / Bankkonten',                                             'Umlaufvermögen'),
    (v_user_id, 1100, 'Debitoren',            'Forderungen aus Lieferung und Leistungen',                             'Umlaufvermögen'),
    (v_user_id, 1170, 'Vorsteuer Material',   'Vorsteuer MWST Material, Waren, Dienstleistungen, Energie',            'Umlaufvermögen'),
    (v_user_id, 1171, 'Vorsteuer Betrieb',    'Vorsteuer MWST Investitionen, übriger Betriebsaufwand',                'Umlaufvermögen'),
    (v_user_id, 1180, 'Forderungen SVA/Vorsorge', 'Forderungen gegenüber Sozialversicherungen und Vorsorgeeinrichtungen', 'Umlaufvermögen'),
    (v_user_id, 1190, 'Konto Korrent Gesellschafter', 'Verrechnungskonto mit Gesellschafter',                         'Umlaufvermögen'),

    -- ANLAGEVERMÖGEN (1xxx)
    (v_user_id, 1500, 'Maschinen und Geräte', 'Werkzeuge, Geräte',                                                    'Anlagevermögen'),
    (v_user_id, 1510, 'Fahrzeuge',            'Geschäftsfahrzeuge',                                                   'Anlagevermögen'),
    (v_user_id, 1520, 'Büroeinrichtung',      'Mobiliar, EDV-Anlagen',                                                'Anlagevermögen'),

    -- KURZFRISTIGES FREMDKAPITAL (2xxx)
    (v_user_id, 2000, 'Kreditoren',           'Verbindlichkeiten aus Lieferungen und Leistungen',                     'Kurzfristiges Fremdkapital'),
    (v_user_id, 2002, 'Nettolohn-Abrechnung', 'Verrechnungskonto Lohnabrechnung',                                     'Kurzfristiges Fremdkapital'),
    (v_user_id, 2200, 'Geschuldete MWST',     'Umsatzsteuer / Geschuldete MWST (Konto Heineken)',                     'Kurzfristiges Fremdkapital'),
    (v_user_id, 2202, 'MWST-Abrechnungskonto','Abrechnungskonto MWST für Quartalsabrechnung',                         'Kurzfristiges Fremdkapital'),
    (v_user_id, 2260, 'Privatkonto',          'Vorschüsse / Privatentnahmen',                                         'Kurzfristiges Fremdkapital'),

    -- SOZIALVERSICHERUNGEN (2xxx)
    (v_user_id, 2270, 'AHV/IV/EO/ALV',       'Sozialversicherungsbeiträge',                                          'Sozialversicherungen'),
    (v_user_id, 2271, 'BVG / Pensionskasse',  'Berufliche Vorsorge',                                                  'Sozialversicherungen'),
    (v_user_id, 2272, 'UVG / SUVA',           'Unfallversicherung',                                                   'Sozialversicherungen'),
    (v_user_id, 2273, 'KTG',                  'Krankentaggeldversicherung',                                           'Sozialversicherungen'),

    -- EIGENKAPITAL (2xxx)
    (v_user_id, 2800, 'Eigenkapital',         'Eigenkapital des Inhabers',                                            'Eigenkapital'),
    (v_user_id, 2850, 'Jahresgewinn/-verlust','Vorjahresgewinn oder -verlust',                                         'Eigenkapital'),

    -- BETRIEBSERTRAG (3xxx)
    (v_user_id, 3400, 'Dienstleistungserlöse','Erlöse aus Reinigungen, Störungen, Montagen',                          'Betriebsertrag'),
    (v_user_id, 3900, 'Sonstige Erträge',     'Nebenerlöse, Provisionen',                                             'Betriebsertrag'),

    -- MATERIALAUFWAND (4xxx)
    (v_user_id, 4004, 'Hilfs- und Verbrauchsmaterialaufwand', 'Ersatzteile, Reinigungsmaterial etc.',                 'Materialaufwand'),

    -- LOHNAUFWAND (5xxx)
    (v_user_id, 5000, 'Lohnaufwand',          'Bruttolöhne (inkl. 13. Monatslohn)',                                   'Lohnaufwand'),
    (v_user_id, 5700, 'Sozialversicherungsaufwand', 'AHV, ALV, UVG, KTG, BVG Arbeitgeberanteil',                    'Lohnaufwand'),
    (v_user_id, 5820, 'Reise- und Spesenvergütungen', 'Spesen, Verpflegung, Unterkunft',                              'Lohnaufwand'),
    (v_user_id, 5850, 'Berufskleider/Schutzausrüstung', 'Berufskleidung, Schuhe, Arbeitsschutz',                     'Lohnaufwand'),

    -- FAHRZEUGAUFWAND (6xxx)
    (v_user_id, 6200, 'Betriebsaufwand Fahrzeuge', 'Benzin, Service, Reparaturen',                                   'Fahrzeug- und Transportaufwand'),
    (v_user_id, 6250, 'Autoreparaturen',       'Reparaturen und Wartung',                                             'Fahrzeug- und Transportaufwand'),
    (v_user_id, 6270, 'Parkgebühren',          'Parkgebühren im Zusammenhang mit Geschäftstätigkeit',                 'Fahrzeug- und Transportaufwand'),
    (v_user_id, 6275, 'Fahrbewilligungen',     'Strassenverkehrsamt, Kontrollschilder',                               'Fahrzeug- und Transportaufwand'),
    (v_user_id, 6280, 'Bussen',                'Ordnungsbussen (steuerlich nicht abzugsfähig)',                       'Fahrzeug- und Transportaufwand'),

    -- BETRIEBLICHER AUFWAND (6xxx)
    (v_user_id, 6000, 'Büromiete',            'Miete Büro/Lager',                                                     'Raumaufwand'),
    (v_user_id, 6300, 'Haftpflichtversicherung', 'Betriebshaftpflicht',                                              'Sachversicherungen, Abgaben'),
    (v_user_id, 6301, 'Franchisegebühr Heineken', 'Monatliche Franchisegebühr an Heineken (Dauerauftrag)',            'Sachversicherungen, Abgaben'),
    (v_user_id, 6510, 'Büro und Kommunikation','Porto, Briefmarken, Telefon, Internet, Mobile',                       'Verwaltungsaufwand'),
    (v_user_id, 6530, 'Buchführung / Treuhand','Buchhaltungs- und Beratungskosten',                                   'Verwaltungsaufwand'),
    (v_user_id, 6560, 'Software / IT',         'Softwarelizenzen, Cloud-Dienste, App-Kosten',                        'Verwaltungsaufwand'),
    (v_user_id, 6940, 'Bankgebühren',          'Kontoführungsgebühren, Überweisungsgebühren',                         'Finanzaufwand'),

    -- STEUERN & ABSCHLUSS (8xxx/9xxx)
    (v_user_id, 8000, 'Ausserordentlicher Ertrag', 'Nicht betriebliche Erträge',                                      'Ausserordentliches'),
    (v_user_id, 8500, 'Direkte Steuern',       'Einkommens- und Vermögenssteuer',                                     'Steuern'),
    (v_user_id, 9000, 'Gewinn-/Verlustübertrag','Jahresabschluss-Konto',                                              'Abschluss')

  ON CONFLICT (user_id, kontonummer) DO NOTHING;

  RAISE NOTICE '✓ Konten: 41 Stück';

  -- ============================================================
  -- BUCHUNGSVORLAGEN (Geschäftsfälle)
  -- ============================================================
  INSERT INTO buchungs_vorlagen (user_id, geschaeftsfall_id, bezeichnung, soll_konto, haben_konto, mwst_konto, mwst_satz, belegordner, auto_trigger) VALUES

    -- GF 1: Reinigung / Dienstleistungen
    (v_user_id, '1',    'Reinigung Barzahlung',              1000, 3400, 2200, 8.10, '010_Reinigung',    NULL),
    (v_user_id, '1.1',  'Kundenrechnung gestellt',           1100, 3400, 2200, 8.10, '010_Reinigung',    'rechnung_erstellt_kunde'),
    (v_user_id, '1.2',  'Heineken Monatsrechnung gestellt',  1100, 3400, 2200, 8.10, '010_Reinigung',    'rechnung_erstellt_heineken'),
    (v_user_id, '1.9',  'Debitorenverlust',                  3900, 1100, NULL, NULL, '010_Reinigung',    NULL),

    -- GF 2: Zahlungseingang
    (v_user_id, '2',    'Zahlungseingang Kunde',             1020, 1100, NULL, NULL, '020_Zahlungen',    'zahlung_eingegangen_kunde'),
    (v_user_id, '2.1',  'Zahlungseingang bar',               1020, 1000, NULL, NULL, '020_Zahlungen',    NULL),
    (v_user_id, '2.2',  'Zahlungseingang Heineken',          1020, 1100, NULL, NULL, '020_Zahlungen',    'zahlung_eingegangen_heineken'),

    -- GF 3: Spesen
    (v_user_id, '3.1',  'Spesen Kasse',                      5820, 1000, 1171, 8.10, '030_Spesen',       NULL),
    (v_user_id, '3.2',  'Spesen Bank',                       5820, 1020, 1171, 8.10, '030_Spesen',       NULL),
    (v_user_id, '3.3',  'Spesen Privat',                     5820, 2260, 1171, 8.10, '030_Spesen',       NULL),

    -- GF 4: Tanken
    (v_user_id, '4.1',  'Tanken Kasse',                      6200, 1000, 1171, 8.10, '040_Fahrzeug',     NULL),
    (v_user_id, '4.2',  'Tanken Karte/Bank',                 6200, 1020, 1171, 8.10, '040_Fahrzeug',     NULL),

    -- GF 5: Parkgebühren
    (v_user_id, '5.1',  'Parkgebühren Kasse',                6270, 1000, 1171, 8.10, '040_Fahrzeug',     NULL),

    -- GF 6: Bussen
    (v_user_id, '6.1',  'Bussen',                            6280, 1000, NULL, NULL, '040_Fahrzeug',     NULL),

    -- GF 8: Autoreparaturen
    (v_user_id, '8.1',  'Autoreparatur Rechnung',            6250, 2000, 1171, 8.10, '040_Fahrzeug',     NULL),
    (v_user_id, '8.2',  'Autoreparatur Zahlung',             2000, 1020, NULL, NULL, '040_Fahrzeug',     NULL),

    -- GF 10: Werkzeug / Material
    (v_user_id, '10.1', 'Material/Werkzeug Einkauf Bar',     4004, 1000, 1170, 8.10, '100_Material',     NULL),
    (v_user_id, '10.2', 'Material/Werkzeug Einkauf Bank',    4004, 1020, 1170, 8.10, '100_Material',     NULL),
    (v_user_id, '10.3', 'Material/Werkzeug auf Rechnung',    4004, 2000, 1170, 8.10, '100_Material',     NULL),

    -- GF 11: Berufskleider
    (v_user_id, '11.1', 'Berufskleider Kasse',               5850, 1000, 1171, 8.10, '110_Kleider',      NULL),
    (v_user_id, '11.2', 'Berufskleider Bank',                5850, 1020, 1171, 8.10, '110_Kleider',      NULL),

    -- GF 14: Porto
    (v_user_id, '14.1', 'Porto Kasse',                       6510, 1000, NULL, NULL, '140_Büro',         NULL),

    -- GF 15: Internetabo
    (v_user_id, '15.1', 'Internetabo Dauerauftrag',          6510, 1020, 1171, 8.10, '140_Büro',         NULL),

    -- GF 16: Mobileabo
    (v_user_id, '16.1', 'Mobile-Abo Rechnung',               6510, 2000, 1171, 8.10, '140_Büro',         NULL),

    -- GF 17: Software
    (v_user_id, '17.1', 'Software/App Abo',                  6560, 1020, 1171, 8.10, '140_Büro',         NULL),

    -- GF 18: Büromiete
    (v_user_id, '18.1', 'Büromiete Dauerauftrag',            6000, 1020, NULL, NULL, '180_Miete',        NULL),

    -- GF 19: Franchisegebühr Heineken
    (v_user_id, '19',   'Franchisegebühr Heineken Rechnung', 6301, 2000, 1170, 8.10, '190_Franchise',    NULL),
    (v_user_id, '19.1', 'Franchisegebühr Heineken Zahlung',  2000, 1020, NULL, NULL, '190_Franchise',    NULL),

    -- GF 20: Bankgebühren
    (v_user_id, '20.1', 'Bankgebühren',                      6940, 1020, NULL, NULL, '200_Bank',         NULL),

    -- GF 21: Buchführung
    (v_user_id, '21.1', 'Treuhand/Buchhaltung Rechnung',     6530, 2000, 1171, 8.10, '210_Buchhaltung',  NULL),

    -- GF 22: Lohnzahlung
    (v_user_id, '22',   'Bruttolohn buchen',                 5000, 2002, NULL, NULL, '220_Lohnzahlung',  NULL),
    (v_user_id, '22.7', 'Nettolohn auszahlen',               2002, 1020, NULL, NULL, '220_Lohnzahlung',  NULL),

    -- GF 24: Haftpflicht
    (v_user_id, '24.1', 'Haftpflichtversicherung',           6300, 1020, NULL, NULL, '240_Versicherung', NULL),

    -- GF 25: MWST-Abrechnung (Quartal)
    (v_user_id, '25.1', 'MWST-Abrechnung: Umsatzsteuer',     2200, 2202, NULL, NULL, '250_MWST',         'mwst_abrechnung'),
    (v_user_id, '25.2', 'MWST-Abrechnung: Vorsteuer Material',2202, 1170, NULL, NULL, '250_MWST',        'mwst_abrechnung'),
    (v_user_id, '25.3', 'MWST-Abrechnung: Vorsteuer Betrieb',2202, 1171, NULL, NULL, '250_MWST',        'mwst_abrechnung'),
    (v_user_id, '25.4', 'MWST-Zahlung an Bund',              2202, 1020, NULL, NULL, '250_MWST',         NULL)

  ON CONFLICT (user_id, geschaeftsfall_id, zahlungsweg) DO NOTHING;

  RAISE NOTICE '✓ Buchungsvorlagen: 35 Stück';

  RAISE NOTICE '=== Setup abgeschlossen für User % ===', v_user_id;
  RAISE NOTICE 'Nächster Schritt: 007_artikelstamm_heineken.sql im SQL Editor ausführen';
  RAISE NOTICE '(UUID ist dort bereits eingetragen - Datei 1:1 kopieren)';

END;
$$;

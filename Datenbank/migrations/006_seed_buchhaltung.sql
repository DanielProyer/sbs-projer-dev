-- ============================================================
-- Migration 006: Seed-Daten Buchhaltung
-- Projekt: SBS Projer App
-- Stand: 12.02.2026
-- Beschreibung: Kontenrahmen (61 Konten) + Buchungsvorlagen
--               aus Daniels Excel (Sheet "Kontenrahmen" + "Geschäftsfälle")
-- WICHTIG: User-UUID hardcoded fuer Seed-Migration
-- Ausführen NACH: 005_seed_stammdaten.sql
-- ============================================================

-- ============================================================
-- KONTEN (61 Konten aus Daniels Kontenrahmen-Sheet)
-- ============================================================

INSERT INTO konten (user_id, kontonummer, bezeichnung, beschreibung, kategorie)
VALUES
  -- UMLAUFVERMÖGEN (1xxx)
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 1000, 'Kasse',               'Eintragen der laufenden Ein- und Auszahlungen',                        'Umlaufvermögen'),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 1020, 'Bankguthaben',         'PostFinance / Bankkonten',                                             'Umlaufvermögen'),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 1100, 'Debitoren',            'Forderungen aus Lieferung und Leistungen',                             'Umlaufvermögen'),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 1170, 'Vorsteuer Material',   'Vorsteuer MWST Material, Waren, Dienstleistungen, Energie',            'Umlaufvermögen'),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 1171, 'Vorsteuer Betrieb',    'Vorsteuer MWST Investitionen, übriger Betriebsaufwand',                'Umlaufvermögen'),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 1180, 'Forderungen SVA/Vorsorge', 'Forderungen gegenüber Sozialversicherungen und Vorsorgeeinrichtungen', 'Umlaufvermögen'),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 1190, 'Konto Korrent Gesellschafter', 'Verrechnungskonto mit Gesellschafter',                         'Umlaufvermögen'),

  -- ANLAGEVERMÖGEN (1xxx)
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 1500, 'Maschinen und Geräte', 'Werkzeuge, Geräte',                                                    'Anlagevermögen'),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 1510, 'Fahrzeuge',            'Geschäftsfahrzeuge',                                                   'Anlagevermögen'),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 1520, 'Büroeinrichtung',      'Mobiliar, EDV-Anlagen',                                                'Anlagevermögen'),

  -- KURZFRISTIGES FREMDKAPITAL (2xxx)
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 2000, 'Kreditoren',           'Verbindlichkeiten aus Lieferungen und Leistungen',                     'Kurzfristiges Fremdkapital'),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 2002, 'Nettolohn-Abrechnung', 'Verrechnungskonto Lohnabrechnung',                                     'Kurzfristiges Fremdkapital'),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 2200, 'Geschuldete MWST',     'Umsatzsteuer / Geschuldete MWST (Konto Heineken)',                     'Kurzfristiges Fremdkapital'),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 2202, 'MWST-Abrechnungskonto','Abrechnungskonto MWST für Quartalsabrechnung',                         'Kurzfristiges Fremdkapital'),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 2260, 'Privatkonto',          'Vorschüsse / Privatentnahmen',                                         'Kurzfristiges Fremdkapital'),

  -- SOZIALVERSICHERUNGEN (2xxx)
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 2270, 'AHV/IV/EO/ALV',       'Sozialversicherungsbeiträge',                                          'Sozialversicherungen'),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 2271, 'BVG / Pensionskasse',  'Berufliche Vorsorge',                                                  'Sozialversicherungen'),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 2272, 'UVG / SUVA',           'Unfallversicherung',                                                   'Sozialversicherungen'),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 2273, 'KTG',                  'Krankentaggeldversicherung',                                           'Sozialversicherungen'),

  -- EIGENKAPITAL (2xxx)
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 2800, 'Eigenkapital',         'Eigenkapital des Inhabers',                                            'Eigenkapital'),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 2850, 'Jahresgewinn/-verlust','Vorjahresgewinn oder -verlust',                                         'Eigenkapital'),

  -- BETRIEBSERTRAG (3xxx)
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 3400, 'Dienstleistungserlöse','Erlöse aus Reinigungen, Störungen, Montagen',                          'Betriebsertrag'),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 3900, 'Sonstige Erträge',     'Nebenerlöse, Provisionen',                                             'Betriebsertrag'),

  -- MATERIALAUFWAND (4xxx)
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 4004, 'Hilfs- und Verbrauchsmaterialaufwand', 'Ersatzteile, Reinigungsmaterial etc.',                 'Materialaufwand'),

  -- LOHNAUFWAND (5xxx)
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 5000, 'Lohnaufwand',          'Bruttolöhne (inkl. 13. Monatslohn)',                                   'Lohnaufwand'),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 5700, 'Sozialversicherungsaufwand', 'AHV, ALV, UVG, KTG, BVG Arbeitgeberanteil',                    'Lohnaufwand'),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 5820, 'Reise- und Spesenvergütungen', 'Spesen, Verpflegung, Unterkunft',                              'Lohnaufwand'),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 5850, 'Berufskleider/Schutzausrüstung', 'Berufskleidung, Schuhe, Arbeitsschutz',                     'Lohnaufwand'),

  -- FAHRZEUGAUFWAND (6xxx)
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 6200, 'Betriebsaufwand Fahrzeuge', 'Benzin, Service, Reparaturen',                                   'Fahrzeug- und Transportaufwand'),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 6250, 'Autoreparaturen',       'Reparaturen und Wartung',                                             'Fahrzeug- und Transportaufwand'),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 6270, 'Parkgebühren',          'Parkgebühren im Zusammenhang mit Geschäftstätigkeit',                 'Fahrzeug- und Transportaufwand'),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 6275, 'Fahrbewilligungen',     'Strassenverkehrsamt, Kontrollschilder',                               'Fahrzeug- und Transportaufwand'),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 6280, 'Bussen',                'Ordnungsbussen (steuerlich nicht abzugsfähig)',                       'Fahrzeug- und Transportaufwand'),

  -- BETRIEBLICHER AUFWAND (6xxx)
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 6000, 'Büromiete',            'Miete Büro/Lager',                                                     'Raumaufwand'),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 6300, 'Haftpflichtversicherung', 'Betriebshaftpflicht',                                              'Sachversicherungen, Abgaben'),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 6301, 'Franchisegebühr Heineken', 'Monatliche Franchisegebühr an Heineken (Dauerauftrag)',            'Sachversicherungen, Abgaben'),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 6510, 'Büro und Kommunikation','Porto, Briefmarken, Telefon, Internet, Mobile',                       'Verwaltungsaufwand'),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 6530, 'Buchführung / Treuhand','Buchhaltungs- und Beratungskosten',                                   'Verwaltungsaufwand'),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 6560, 'Software / IT',         'Softwarelizenzen, Cloud-Dienste, App-Kosten',                        'Verwaltungsaufwand'),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 6940, 'Bankgebühren',          'Kontoführungsgebühren, Überweisungsgebühren',                         'Finanzaufwand'),

  -- STEUERN & ABSCHLUSS (8xxx/9xxx)
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 8000, 'Ausserordentlicher Ertrag', 'Nicht betriebliche Erträge',                                      'Ausserordentliches'),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 8500, 'Direkte Steuern',       'Einkommens- und Vermögenssteuer',                                     'Steuern'),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 9000, 'Gewinn-/Verlustübertrag','Jahresabschluss-Konto',                                              'Abschluss')

ON CONFLICT (user_id, kontonummer) DO NOTHING;

-- ============================================================
-- BUCHUNGSVORLAGEN (Geschäftsfälle aus Excel-Sheet)
-- ============================================================

INSERT INTO buchungs_vorlagen (user_id, geschaeftsfall_id, bezeichnung, soll_konto, haben_konto, mwst_konto, mwst_satz, belegordner, auto_trigger)
VALUES
  -- GF 1: Reinigung / Dienstleistungen (Barzahlung)
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', '1',    'Reinigung Barzahlung',              1000, 3400, 2200, 8.10, '010_Reinigung',          NULL),
  -- GF 1.1: Kundenrechnung gestellt
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', '1.1',  'Kundenrechnung gestellt',           1100, 3400, 2200, 8.10, '010_Reinigung',          'rechnung_erstellt_kunde'),
  -- GF 1.2: Heineken Monatsrechnung gestellt
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', '1.2',  'Heineken Monatsrechnung gestellt',  1100, 3400, 2200, 8.10, '010_Reinigung',          'rechnung_erstellt_heineken'),
  -- GF 1.9: Debitorenverlust / abgeschriebene Rechnung
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', '1.9',  'Debitorenverlust',                  3900, 1100, NULL, NULL, '010_Reinigung',          NULL),
  -- GF 2: Zahlungseingang Kunde (Bank)
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', '2',    'Zahlungseingang Kunde',             1020, 1100, NULL, NULL, '020_Zahlungen',          'zahlung_eingegangen_kunde'),
  -- GF 2.1: Zahlungseingang bar
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', '2.1',  'Zahlungseingang bar',               1020, 1000, NULL, NULL, '020_Zahlungen',          NULL),
  -- GF 2.2: Zahlungseingang Heineken
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', '2.2',  'Zahlungseingang Heineken',          1020, 1100, NULL, NULL, '020_Zahlungen',          'zahlung_eingegangen_heineken'),
  -- GF 3: Spesen
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', '3.1',  'Spesen Kasse',                      5820, 1000, 1171, 8.10, '030_Spesen',             NULL),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', '3.2',  'Spesen Bank',                       5820, 1020, 1171, 8.10, '030_Spesen',             NULL),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', '3.3',  'Spesen Privat',                     5820, 2260, 1171, 8.10, '030_Spesen',             NULL),
  -- GF 4: Tanken
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', '4.1',  'Tanken Kasse',                      6200, 1000, 1171, 8.10, '040_Fahrzeug',           NULL),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', '4.2',  'Tanken Karte/Bank',                 6200, 1020, 1171, 8.10, '040_Fahrzeug',           NULL),
  -- GF 5: Parkgebühren
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', '5.1',  'Parkgebühren Kasse',                6270, 1000, 1171, 8.10, '040_Fahrzeug',           NULL),
  -- GF 6: Bussen
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', '6.1',  'Bussen',                            6280, 1000, NULL, NULL, '040_Fahrzeug',           NULL),
  -- GF 8: Autoreparaturen
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', '8.1',  'Autoreparatur Rechnung',            6250, 2000, 1171, 8.10, '040_Fahrzeug',           NULL),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', '8.2',  'Autoreparatur Zahlung',             2000, 1020, NULL, NULL, '040_Fahrzeug',           NULL),
  -- GF 10: Werkzeug / Material
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', '10.1', 'Material/Werkzeug Einkauf Bar',     4004, 1000, 1170, 8.10, '100_Material',           NULL),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', '10.2', 'Material/Werkzeug Einkauf Bank',    4004, 1020, 1170, 8.10, '100_Material',           NULL),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', '10.3', 'Material/Werkzeug auf Rechnung',    4004, 2000, 1170, 8.10, '100_Material',           NULL),
  -- GF 11: Berufskleider
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', '11.1', 'Berufskleider Kasse',               5850, 1000, 1171, 8.10, '110_Kleider',            NULL),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', '11.2', 'Berufskleider Bank',                5850, 1020, 1171, 8.10, '110_Kleider',            NULL),
  -- GF 14: Briefmarken / Porto
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', '14.1', 'Porto Kasse',                       6510, 1000, NULL, NULL, '140_Büro',               NULL),
  -- GF 15: Internetabo
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', '15.1', 'Internetabo Dauerauftrag',          6510, 1020, 1171, 8.10, '140_Büro',               NULL),
  -- GF 16: Mobileabo
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', '16.1', 'Mobile-Abo Rechnung',               6510, 2000, 1171, 8.10, '140_Büro',               NULL),
  -- GF 17: Software
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', '17.1', 'Software/App Abo',                  6560, 1020, 1171, 8.10, '140_Büro',               NULL),
  -- GF 18: Büromiete
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', '18.1', 'Büromiete Dauerauftrag',            6000, 1020, NULL, NULL, '180_Miete',              NULL),
  -- GF 19: Franchisegebühr Heineken
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', '19',   'Franchisegebühr Heineken Rechnung', 6301, 2000, 1170, 8.10, '190_Franchise',          NULL),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', '19.1', 'Franchisegebühr Heineken Zahlung',  2000, 1020, NULL, NULL, '190_Franchise',          NULL),
  -- GF 20: Bankgebühren
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', '20.1', 'Bankgebühren',                      6940, 1020, NULL, NULL, '200_Bank',               NULL),
  -- GF 21: Buchführung
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', '21.1', 'Treuhand/Buchhaltung Rechnung',     6530, 2000, 1171, 8.10, '210_Buchhaltung',        NULL),
  -- GF 22: Lohnzahlung (vereinfacht, Einzelschritte)
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', '22',   'Bruttolohn buchen',                 5000, 2002, NULL, NULL, '220_Lohnzahlung',        NULL),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', '22.7', 'Nettolohn auszahlen',               2002, 1020, NULL, NULL, '220_Lohnzahlung',        NULL),
  -- GF 24: Haftpflicht
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', '24.1', 'Haftpflichtversicherung',           6300, 1020, NULL, NULL, '240_Versicherung',       NULL),
  -- GF 25: MWST-Abrechnung (Quartal)
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', '25.1', 'MWST-Abrechnung: Umsatzsteuer',     2200, 2202, NULL, NULL, '250_MWST',               'mwst_abrechnung'),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', '25.2', 'MWST-Abrechnung: Vorsteuer Material',2202, 1170, NULL, NULL, '250_MWST',              'mwst_abrechnung'),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', '25.3', 'MWST-Abrechnung: Vorsteuer Betrieb',2202, 1171, NULL, NULL, '250_MWST',              'mwst_abrechnung'),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', '25.4', 'MWST-Zahlung an Bund',              2202, 1020, NULL, NULL, '250_MWST',               NULL)

ON CONFLICT (user_id, geschaeftsfall_id, zahlungsweg) DO NOTHING;

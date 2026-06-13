-- 091_kontenplan_ergaenzung.sql
-- Phase 0a Follow-up (A6): 9 fehlende Konten ergaenzen, die von den neuen
-- Geschaeftsfaellen (Migration 090) referenziert werden.
-- Titel aus Excel-Kontenrahmen (00_SBS_Projer_70.xlsm), Kategorien DB-konform.
-- Zusaetzlich: 8500 'Direkte Steuern' deaktivieren (Dublette zu 8900, 0 Buchungen).

-- 1) Fehlende Konten ergaenzen (idempotent: nur wenn fuer den User noch nicht vorhanden)
INSERT INTO konten (id, user_id, kontonummer, bezeichnung, kategorie)
SELECT gen_random_uuid(), u.user_id, v.kontonummer, v.bezeichnung, v.kategorie
FROM (SELECT DISTINCT user_id FROM konten) u
CROSS JOIN (VALUES
  (2208, 'Direkte Steuern (Steuerrückstellung)',                    'Kurzfristiges Fremdkapital'),
  (2276, 'Kontokorrent Kurzarbeitsentschädigung',                   'Kurzfristiges Fremdkapital'),
  (2500, 'Coronakredit GKB',                                        'Kurzfristiges Fremdkapital'),
  (5880, 'Sonstiger Personalaufwand',                               'Lohnaufwand'),
  (6460, 'Entsorgungsaufwand',                                      'Energie-/Entsorgungsaufwand'),
  (6500, 'Büromaterial, Drucksachen',                               'Verwaltungsaufwand'),
  (6550, 'Gründungs-, Kapitalerhöhungs- und Organisationsaufwand',  'Verwaltungsaufwand'),
  (8510, 'Härtefallgelder Corona',                                  'Ausserordentliches'),
  (8900, 'Direkte Steuern',                                         'Steuern')
) AS v(kontonummer, bezeichnung, kategorie)
WHERE NOT EXISTS (
  SELECT 1 FROM konten k WHERE k.user_id = u.user_id AND k.kontonummer = v.kontonummer
);

-- 2) 8500 deaktivieren (Dublette zu 8900; keine Buchungen/Vorlagen)
UPDATE konten SET ist_aktiv = false WHERE kontonummer = 8500;

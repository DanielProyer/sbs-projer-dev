-- 092_konten_fehlend_historie.sql
-- Phase 1 Teil 2: vom Excel-Journal referenzierte, in der App fehlende Konten.
-- 8090/9100 sind Tippfehler-Konten (sollten 8900/9010 sein) → faithful importiert,
-- Korrektur in Phase 2.
INSERT INTO konten (id, user_id, kontonummer, bezeichnung, kategorie)
SELECT gen_random_uuid(), u.user_id, v.kontonummer, v.bezeichnung, v.kategorie
FROM (SELECT DISTINCT user_id FROM konten) u
CROSS JOIN (VALUES
  (2970, 'Gewinn-/Verlustvortrag',            'Eigenkapital'),
  (2980, 'Jahresgewinn/-verlust',             'Eigenkapital'),
  (5005, 'Lohnersatz (EO/KAE)',               'Lohnaufwand'),
  (8090, 'FEHLER – sollte 8900 (Phase 2)',    'Steuern'),
  (9100, 'FEHLER – sollte 9010 (Phase 2)',    'Abschluss')
) AS v(kontonummer, bezeichnung, kategorie)
WHERE NOT EXISTS (
  SELECT 1 FROM konten k WHERE k.user_id = u.user_id AND k.kontonummer = v.kontonummer
);

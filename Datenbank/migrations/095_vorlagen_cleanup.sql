-- 095_vorlagen_cleanup.sql
-- Buchungsvorlagen-Bereinigung: Dubletten entfernen, A-sozvers (falsch) raus, Titel verbessern.
-- Prinzip: camt-Booker braucht FIXE Soll/Haben → camt nur auf Fix-Vorlagen umhängen.
--   Fix-Dubletten:    20.1→F-bankgeb, 19.1→F-fran-zg (umhängen + alte deaktivieren).
--   Ausgabe-Dubletten: A-telekom/A-sachvers raus (camt behält die Fix 15.1/24.1).
--   Sozialvers:       A-sozvers raus (bucht falsch generisch 5700; 30.1/30.2/30.3 sind korrekt pro Konto).

-- 1) camt-Regeln auf die neuen Fix-Vorlagen umhängen (gleiche Soll/Haben)
UPDATE camt_regel SET buchungs_vorlage_id =
    (SELECT id FROM buchungs_vorlagen WHERE geschaeftsfall_id='F-bankgeb' AND user_id='1e1ec2dd-7836-4d8e-8256-c5649d994ee2')
 WHERE buchungs_vorlage_id =
    (SELECT id FROM buchungs_vorlagen WHERE geschaeftsfall_id='20.1' AND user_id='1e1ec2dd-7836-4d8e-8256-c5649d994ee2');

UPDATE camt_regel SET buchungs_vorlage_id =
    (SELECT id FROM buchungs_vorlagen WHERE geschaeftsfall_id='F-fran-zg' AND user_id='1e1ec2dd-7836-4d8e-8256-c5649d994ee2')
 WHERE buchungs_vorlage_id =
    (SELECT id FROM buchungs_vorlagen WHERE geschaeftsfall_id='19.1' AND user_id='1e1ec2dd-7836-4d8e-8256-c5649d994ee2');

-- 2) Redundante / falsche Vorlagen deaktivieren
UPDATE buchungs_vorlagen
   SET ist_aktiv = false,
       notizen = trim(both ' |' from coalesce(notizen,'') || ' | Vorlagen-Cleanup: Dublette/ersetzt')
 WHERE user_id='1e1ec2dd-7836-4d8e-8256-c5649d994ee2'
   AND geschaeftsfall_id IN ('20.1','19.1','A-telekom','A-sachvers','A-sozvers');

-- 3) Titel der behaltenen camt-Vorlagen klarer fassen
UPDATE buchungs_vorlagen SET bezeichnung='Internet/Telefon (Dauerauftrag)'
 WHERE user_id='1e1ec2dd-7836-4d8e-8256-c5649d994ee2' AND geschaeftsfall_id='15.1';
UPDATE buchungs_vorlagen SET bezeichnung='Sachversicherung/Haftpflicht (Dauerauftrag)'
 WHERE user_id='1e1ec2dd-7836-4d8e-8256-c5649d994ee2' AND geschaeftsfall_id='24.1';

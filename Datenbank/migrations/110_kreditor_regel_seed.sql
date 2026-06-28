-- Migration 110 (DATEN-Seed): Start-Lieferantenregeln aus den 17 Scan-Kategorien.
-- Single-User-App; user_id = Daniel (sbs.projer). Per execute_sql angewendet.
-- IBANs werden NICHT geseedet (kommen exakt aus dem QR der echten Rechnung).
-- AXA: 3 Zeilen, disambiguiert per referenz_praefix (Police-Nummern-Praefix).
INSERT INTO kreditor_regel
  (user_id, lieferant_name_pattern, referenz_praefix, aufwandskonto,
   vorsteuer_konto, mwst_satz_percent, mwst_pflichtig, prioritaet, lernquelle, gelernt_am)
VALUES
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2','Heineken',NULL,6301,1170,8.1,true,10,'seed',now()),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2','AXA','98',5720,NULL,0,false,20,'seed',now()),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2','AXA','1537129',6300,NULL,0,false,20,'seed',now()),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2','AXA','4412738',5730,NULL,0,false,20,'seed',now()),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2','Ausgleichskasse',NULL,5700,NULL,0,false,10,'seed',now()),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2','SUVA',NULL,5730,NULL,0,false,10,'seed',now()),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2','Vögele',NULL,6460,1171,8.1,true,10,'seed',now()),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2','Arpagaus',NULL,6250,1171,8.1,true,10,'seed',now()),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2','Swisscom',NULL,6510,1171,8.1,true,10,'seed',now()),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2','UPC',NULL,6510,1171,8.1,true,10,'seed',now()),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2','Sunrise',NULL,6510,1171,8.1,true,10,'seed',now()),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2','Domat','00473',6460,1171,8.1,true,5,'seed',now()),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2','Flims',NULL,6275,NULL,0,false,5,'seed',now()),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2','Strassenverkehrsamt',NULL,6275,NULL,0,false,5,'seed',now());

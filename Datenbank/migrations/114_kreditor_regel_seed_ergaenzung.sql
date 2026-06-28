-- Migration 114 (DATEN-Seed): Ergänzung der 3 fehlenden Lieferanten-Regeln.
-- Abgleich 17 Scan-Kategorien vs. 14 Seeds (Migration 110) ergab 3 Lücken:
--   Bussen (6280), Buchhalterin (6530), Software/IT (6560).
-- Namen sind Best-Guess-Patterns (im Screen "Rechnungsregeln" korrigierbar):
--   'Kantonspolizei' (häufigster Bussen-Aussteller), 'Treuhand' (Buchhalterin),
--   'Microsoft' (Office; Anthropic/Claude ggf. separat als Bezugsteuer 0%).
-- Per execute_sql angewendet (PROD pltbaqqwpnmdajwgnhpd).
INSERT INTO kreditor_regel
  (user_id, lieferant_name_pattern, referenz_praefix, aufwandskonto,
   vorsteuer_konto, mwst_satz_percent, mwst_pflichtig, prioritaet, lernquelle, gelernt_am)
VALUES
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2','Kantonspolizei',NULL,6280,NULL,0,false,5,'seed',now()),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2','Treuhand',NULL,6530,1171,8.1,true,10,'seed',now()),
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2','Microsoft',NULL,6560,1171,8.1,true,10,'seed',now());

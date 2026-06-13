-- 093_korrektur_8090_2500.sql
-- Phase 2a: mechanische Korrekturen (rückdatiert/in-place, mit notizen-Spur).
-- Ist-Stand vor Lauf: 6 Buchungen Haben 8090, 0 Soll; 2500-Rohsaldo +1.35.

-- 8090 -> 8900 (Tippfehler-Konto; Steuer-Rückerstattungen). Haben + defensiv Soll.
UPDATE buchungen
   SET haben_konto = 8900,
       notizen = trim(both ' |' from coalesce(notizen,'') || ' | Phase2-Korrektur: 8090->8900')
 WHERE user_id='1e1ec2dd-7836-4d8e-8256-c5649d994ee2'
   AND haben_konto = 8090 AND datum < '2025-12-01';
UPDATE buchungen
   SET soll_konto = 8900,
       notizen = trim(both ' |' from coalesce(notizen,'') || ' | Phase2-Korrektur: 8090->8900')
 WHERE user_id='1e1ec2dd-7836-4d8e-8256-c5649d994ee2'
   AND soll_konto = 8090 AND datum < '2025-12-01';

-- 2500 Coronakredit Restsaldo glätten: Roh-Saldo +1.35 -> 0 (Soll 6940 / Haben 2500).
INSERT INTO buchungen
  (user_id, datum, belegnummer, soll_konto, haben_konto, betrag_netto, mwst_satz, mwst_betrag, betrag_brutto, beschreibung, geschaeftsjahr, ist_storniert, notizen)
VALUES
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2','2025-11-30','KORR_2500', 6940, 2500, 1.35, 0, 0, 1.35,
   'Coronakredit Restsaldo-Glättung', 2025, false, 'Phase2-Korrektur: 2500 Restsaldo -> 0');

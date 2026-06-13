-- 094_abschlussbuchungen_storno.sql
-- Phase 2b (Modell 2): historische Abschluss-/Vortrags-Buchungen zurücknehmen.
-- Das Ergebnis wird künftig vom BilanzService berechnet (Klasse 3–8) und im EK gezeigt.
-- 2800 Stammkapital bleibt unberührt (nicht in der WHERE-Menge). 13 Buchungen betroffen.
UPDATE buchungen
   SET ist_storniert = true,
       notizen = trim(both ' |' from coalesce(notizen,'') || ' | Phase2b: Re-Close (Ergebnis wird berechnet)')
 WHERE user_id='1e1ec2dd-7836-4d8e-8256-c5649d994ee2'
   AND datum < '2025-12-01'
   AND (soll_konto IN (2970,2980,9000,9100) OR haben_konto IN (2970,2980,9000,9100));

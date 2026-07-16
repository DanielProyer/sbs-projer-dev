-- Migration 144: Zahlungsart pro Reinigung
--
-- Ursache der 38 fehlenden Rechnungen (26.06.-13.07.2026): Buchung + Rechnung
-- entstanden aus betriebe.rechnungsstellung ZUM ABSCHLUSS-ZEITPUNKT. 34 Faelle:
-- Betrieb war noch 'heineken' (Umstellung auf Tresen erst 10.07.) -> beide
-- Services fallen lautlos durch. 4 Faelle: veralteter Formular-Cache.
--
-- Ab jetzt: Die Zahlungsart wird beim Abschluss AUF DER REINIGUNG gespeichert
-- und ist allein massgebend. betriebe.rechnungsstellung bleibt als Default.
-- Altbestand bleibt NULL (Lesekette: reinigung.zahlungsart ?? betrieb).

ALTER TABLE reinigungen ADD COLUMN IF NOT EXISTS zahlungsart text;

ALTER TABLE reinigungen DROP CONSTRAINT IF EXISTS reinigungen_zahlungsart_check;
ALTER TABLE reinigungen ADD CONSTRAINT reinigungen_zahlungsart_check
  CHECK (zahlungsart IS NULL OR zahlungsart IN
    ('barzahlung','rechnung_tresen','rechnung_mail','rechnung_post',
     'jahresrechnung','heineken'));

COMMENT ON COLUMN reinigungen.zahlungsart IS
  'Zahlungsart DIESER Reinigung (beim Abschluss fixiert). Massgebend fuer Buchung+Rechnung. NULL = Altbestand vor v0.50 -> Fallback betriebe.rechnungsstellung.';

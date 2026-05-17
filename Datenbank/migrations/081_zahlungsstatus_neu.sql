-- Migration 081: Zahlungsstatus auf 7 neue Werte umstellen
-- Alt: entwurf, offen, versendet, freigegeben, teilbezahlt, bezahlt, ueberfaellig, storniert
-- Neu: gestellt, offen, bezahlt, erinnert, mahnung_1, mahnung_2, abgeschrieben

-- 1. Alten CHECK-Constraint entfernen
ALTER TABLE rechnungen DROP CONSTRAINT rechnungen_zahlungsstatus_check;

-- 2. Bestehende Daten migrieren
UPDATE rechnungen SET zahlungsstatus = 'gestellt' WHERE zahlungsstatus IN ('entwurf', 'versendet', 'freigegeben');
UPDATE rechnungen SET zahlungsstatus = 'erinnert' WHERE zahlungsstatus = 'ueberfaellig' AND mahnung_stufe = 0;
UPDATE rechnungen SET zahlungsstatus = 'mahnung_1' WHERE zahlungsstatus = 'ueberfaellig' AND mahnung_stufe = 1;
UPDATE rechnungen SET zahlungsstatus = 'mahnung_2' WHERE zahlungsstatus = 'ueberfaellig' AND mahnung_stufe >= 2;
UPDATE rechnungen SET zahlungsstatus = 'offen' WHERE zahlungsstatus = 'teilbezahlt';
UPDATE rechnungen SET zahlungsstatus = 'abgeschrieben' WHERE zahlungsstatus = 'storniert';

-- 3. Neuen CHECK-Constraint setzen
ALTER TABLE rechnungen ADD CONSTRAINT rechnungen_zahlungsstatus_check
  CHECK (zahlungsstatus IN ('gestellt', 'offen', 'bezahlt', 'erinnert', 'mahnung_1', 'mahnung_2', 'abgeschrieben'));

-- 4. View aktualisieren (offene Rechnungen = alles ausser bezahlt und abgeschrieben)
CREATE OR REPLACE VIEW view_offene_rechnungen AS
SELECT
  r.id,
  r.user_id,
  r.rechnungsnummer,
  r.rechnungstyp,
  b.name AS betrieb_name,
  r.heineken_monat,
  r.rechnungsdatum,
  r.faelligkeitsdatum,
  (CURRENT_DATE - r.faelligkeitsdatum) AS ueberfaellig_seit_tagen,
  r.betrag_brutto,
  r.zahlungsstatus,
  r.mahnung_stufe,
  r.versandart
FROM rechnungen r
LEFT JOIN betriebe b ON r.betrieb_id = b.id
WHERE r.zahlungsstatus NOT IN ('bezahlt', 'abgeschrieben')
ORDER BY r.faelligkeitsdatum;

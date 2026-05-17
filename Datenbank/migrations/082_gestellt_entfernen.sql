-- Migration 082: Status 'gestellt' entfernen → direkt 'offen'
-- Neu: offen, bezahlt, erinnert, mahnung_1, mahnung_2, abgeschrieben

ALTER TABLE rechnungen DROP CONSTRAINT rechnungen_zahlungsstatus_check;

UPDATE rechnungen SET zahlungsstatus = 'offen' WHERE zahlungsstatus = 'gestellt';

ALTER TABLE rechnungen ADD CONSTRAINT rechnungen_zahlungsstatus_check
  CHECK (zahlungsstatus IN ('offen', 'bezahlt', 'erinnert', 'mahnung_1', 'mahnung_2', 'abgeschrieben'));

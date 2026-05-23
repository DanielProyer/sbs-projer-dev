-- Migration 083: Heineken-Status 'gesendet' und 'freigegeben' wieder erlauben
-- Heineken-Workflow: gesendet → freigegeben → bezahlt
-- Kundenrechnungen nutzen weiter: offen → (versendet_am) → bezahlt / erinnert / mahnung_1 / mahnung_2 / abgeschrieben
-- Erlaubt: offen, gesendet, freigegeben, bezahlt, erinnert, mahnung_1, mahnung_2, abgeschrieben

ALTER TABLE rechnungen DROP CONSTRAINT rechnungen_zahlungsstatus_check;

ALTER TABLE rechnungen ADD CONSTRAINT rechnungen_zahlungsstatus_check
  CHECK (zahlungsstatus IN (
    'offen', 'gesendet', 'freigegeben', 'bezahlt',
    'erinnert', 'mahnung_1', 'mahnung_2', 'abgeschrieben'
  ));

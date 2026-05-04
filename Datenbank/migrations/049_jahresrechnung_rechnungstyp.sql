-- rechnungstyp CHECK erweitern um 'jahresrechnung'
ALTER TABLE rechnungen DROP CONSTRAINT IF EXISTS rechnungen_rechnungstyp_check;
ALTER TABLE rechnungen ADD CONSTRAINT rechnungen_rechnungstyp_check
  CHECK (rechnungstyp IN ('kundenrechnung', 'heineken_monat', 'jahresrechnung'));

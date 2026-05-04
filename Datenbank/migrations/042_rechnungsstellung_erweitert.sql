-- Rechnungsstellung-Werte erweitern (Flutter-Dropdown anpassen)
ALTER TABLE betriebe DROP CONSTRAINT IF EXISTS betriebe_rechnungsstellung_check;

-- Erst alte Werte migrieren
UPDATE betriebe SET rechnungsstellung = 'barzahlung' WHERE rechnungsstellung = 'barzahler';

-- Dann neuen Constraint setzen
ALTER TABLE betriebe ADD CONSTRAINT betriebe_rechnungsstellung_check
  CHECK (rechnungsstellung IN (
    'barzahlung',
    'rechnung_tresen', 'rechnung_mail', 'rechnung_post',
    'heineken', 'jahresrechnung'
  ));

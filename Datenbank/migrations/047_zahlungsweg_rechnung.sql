-- Zahlungsweg 'rechnung' für Debitoren-Buchungen (Rechnung Tresen/Mail/Post)
ALTER TABLE buchungen DROP CONSTRAINT IF EXISTS buchungen_zahlungsweg_check;
ALTER TABLE buchungen ADD CONSTRAINT buchungen_zahlungsweg_check
  CHECK (zahlungsweg IN ('kasse', 'bank', 'privat', 'rechnung'));

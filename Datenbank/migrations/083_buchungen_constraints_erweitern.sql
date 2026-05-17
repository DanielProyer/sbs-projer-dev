-- Migration 083: Buchungen CHECK-Constraints erweitern
-- beleg_typ: 'zahlung' hinzufügen (für Zahlungseingang-Buchungen)
-- zahlungsweg: 'intern' hinzufügen (für Debitorenverlust/Differenz-Buchungen)

ALTER TABLE buchungen DROP CONSTRAINT buchungen_beleg_typ_check;
ALTER TABLE buchungen ADD CONSTRAINT buchungen_beleg_typ_check
  CHECK (beleg_typ IN ('rechnung', 'eingang', 'lohn', 'mwst', 'sonstiges', 'zahlung'));

ALTER TABLE buchungen DROP CONSTRAINT buchungen_zahlungsweg_check;
ALTER TABLE buchungen ADD CONSTRAINT buchungen_zahlungsweg_check
  CHECK (zahlungsweg IN ('kasse', 'bank', 'privat', 'rechnung', 'intern'));

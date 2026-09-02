-- 181: beleg_typ um 'abschreibung' (Debitorenverlust/Delkredere, AbschreibungService)
-- und 'abschluss' (Jahresabschluss-Buchungen: Rückstellungen, Altlast-Bereinigung,
-- Umgliederungen) erweitern. Bisher scheiterte AbschreibungService.abschreiben an
-- diesem CHECK (Jahresabschluss 2025, 02.09.2026).
ALTER TABLE buchungen DROP CONSTRAINT IF EXISTS buchungen_beleg_typ_check;
ALTER TABLE buchungen ADD CONSTRAINT buchungen_beleg_typ_check
  CHECK (beleg_typ IN ('rechnung','eingang','lohn','mwst','sonstiges','zahlung','camt053','abschreibung','abschluss'));

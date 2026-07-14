-- Migration 140: beleg_typ 'camt053' erlauben.
--
-- CamtAusgabeBooker schreibt Bereich-2-Buchungen (Übriges) mit beleg_typ
-- 'camt053' als camt-Herkunfts-Marker (auch das Rollback-Runbook nutzt ihn).
-- Die Check-Constraint kannte den Wert bisher nicht → PostgrestException
-- „violates check constraint" beim Bestätigen einer Übriges-Buchung.

ALTER TABLE buchungen DROP CONSTRAINT IF EXISTS buchungen_beleg_typ_check;
ALTER TABLE buchungen ADD CONSTRAINT buchungen_beleg_typ_check
  CHECK (beleg_typ IN ('rechnung','eingang','lohn','mwst','sonstiges','zahlung','camt053'));

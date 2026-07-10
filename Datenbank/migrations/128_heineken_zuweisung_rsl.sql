-- 128: Heineken-Zuweisung 'rsl' (Anlagen-Steckbrief an RSL) erlauben.
-- Der CHECK-Constraint auf funktion liess rsl bisher nicht zu -> PostgrestException.

ALTER TABLE heineken_kontakt_zuweisungen
  DROP CONSTRAINT heineken_zuweisung_funktion_check;

ALTER TABLE heineken_kontakt_zuweisungen
  ADD CONSTRAINT heineken_zuweisung_funktion_check
  CHECK (funktion = ANY (ARRAY[
    'monatsrechnung', 'raster', 'heigenie_service', 'materialbestellung', 'rsl'
  ]));

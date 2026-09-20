-- 197: Merker «Keine Herbstpause» am Betrieb (20.09.2026)
--
-- ANLASS (Daniel, 20.09.2026): Alpenblick und Hörnlihütte in Arosa sind
-- Saisonbetriebe, machen aber im Herbst nicht zu — der Sommerbetrieb geht
-- direkt in den Winter über. Eine Pause gibt es nur im Frühling.
--
-- Das Datenmodell kennt zwei Fenster (Winter/Sommer). Zwischen Sommerende und
-- Winterstart entsteht dadurch zwangsläufig ein Loch: Bei der Hörnlihütte
-- endet der Sommer am 18.10., der Winter beginnt am 01.11. — dreizehn Tage,
-- an denen der Betrieb offen ist, im Tourenplan aber nicht erscheint.
--
-- Abbilden liesse sich das auch ohne neues Feld, indem man das Sommerende auf
-- den Tag vor dem Winterstart setzt. Das hält aber nur bis zur nächsten
-- Datumsänderung: Wer im Herbst den Winterstart verschiebt, reisst das Loch
-- wieder auf, ohne dass es jemandem auffällt. Der Merker sagt die ABSICHT und
-- überlebt jede Datumspflege.
--
-- Wirkung: Ist der Merker gesetzt und sind beide Saisons angehakt, gilt die
-- Spanne zwischen Sommerende und Winterstart als Saison
-- (`istInAktiverSaison`, lib/core/util/touren_saison.dart). Die Frühlingspause
-- zwischen Winterende und Sommerstart bleibt unangetastet — die gibt es bei
-- diesen Betrieben immer.
--
-- Bewusst KEIN Gegenstück «keine Frühlingspause»: Dafür gibt es bisher keinen
-- Fall, und ein Betrieb ohne jede Pause ist schlicht kein Saisonbetrieb.

ALTER TABLE betriebe
  ADD COLUMN IF NOT EXISTS keine_herbstpause boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN betriebe.keine_herbstpause IS
  'Saisonbetrieb ohne Herbstpause: Die Spanne zwischen Sommerende und Winterstart gilt als Saison. Frühlingspause (Winterende bis Sommerstart) bleibt bestehen.';

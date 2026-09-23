-- 201: Mahnprotokoll bleibt beim Löschen des Betriebs erhalten
--
-- ANLASS (Review 23.09.2026): Migration 200 legte `mahnschreiben.betrieb_id`
-- mit ON DELETE CASCADE an. Das Mahnprotokoll ist aber Beweismittel für
-- eine allfällige Betreibung — wer wann welches Mahnschreiben mit welcher
-- Frist erhalten hat. Es darf nicht verschwinden, nur weil ein Betrieb
-- (z. B. bei einer Bereinigung der Stammdaten) gelöscht wird. Betrieb-Löschung
-- muss stattdessen am bestehenden Mahnprotokoll scheitern.

ALTER TABLE public.mahnschreiben
  DROP CONSTRAINT IF EXISTS mahnschreiben_betrieb_id_fkey;

ALTER TABLE public.mahnschreiben
  ADD CONSTRAINT mahnschreiben_betrieb_id_fkey
  FOREIGN KEY (betrieb_id) REFERENCES public.betriebe(id) ON DELETE RESTRICT;

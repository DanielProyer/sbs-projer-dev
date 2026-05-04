-- Fix: FK bergkundenpauschalen.reinigung_id ohne ON DELETE CASCADE/SET NULL
-- verhindert das Löschen von Reinigungen mit verknüpfter Bergkundenpauschale.
-- Lösung: ON DELETE SET NULL — Pauschale bleibt bestehen, Referenz wird NULL.

ALTER TABLE bergkundenpauschalen
  DROP CONSTRAINT IF EXISTS bergkundenpauschalen_reinigung_id_fkey;

ALTER TABLE bergkundenpauschalen
  ADD CONSTRAINT bergkundenpauschalen_reinigung_id_fkey
  FOREIGN KEY (reinigung_id) REFERENCES reinigungen(id)
  ON DELETE SET NULL;

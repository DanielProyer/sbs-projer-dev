-- 179: Eissäule an der Anlage erfassen (01.09.2026)
--
-- Eine Eissäule ist KEIN Kühler, sondern eine Dekorsäule, die aussen einen
-- Eismantel ansetzt. Für den Service ist sie relevant, weil sie — wie der
-- Booster — vor der Reinigung ausgeschaltet werden muss: sonst friert das
-- Wasser oder die Lauge in der Leitung ein.
--
-- Bewusst ein eigenes Boolean-Feld und kein neuer Wert in `vorkuehler` oder
-- `durchlaufkuehler`: Beide Listen beschreiben Kühlkomponenten, und die
-- Eissäule ist keine. Ein Wert dort würde die Auswertungen verfälschen.
--
-- Befund vom 01.09.2026 (Padelta, Chur): Die Eissäule liess sich bisher
-- nirgends erfassen — weder `vorkuehler`, `durchlaufkuehler`, `typ_anlage`
-- noch `typ_saeule` kennen einen passenden Wert, und alle vier sind per
-- CHECK-Constraint geschlossen.

alter table anlagen
  add column if not exists eissaeule boolean not null default false;

comment on column anlagen.eissaeule is
  'Dekorsäule mit Eismantel. Kein Kühler — muss wie der Booster vor dem '
  'Service ausgeschaltet werden, sonst friert Wasser/Lauge in der Leitung.';

-- 198: Eigene Aufgaben in den Google Kalender (20.09.2026)
--
-- ANLASS (Daniel, 20.09.2026): Beim Bau des Service-Termins fiel auf, dass
-- eine Aufgabe mit Fälligkeitsdatum zwar in der App steht, aber **nicht** im
-- Google Kalender landet. In den Kalender gingen bisher nur `pikett`,
-- `event`, `einsatz` (Störung/Montage) und `termin`.
--
-- Diese Migration öffnet nur die CHECK-Bedingung. Die Arbeit macht die
-- Edge-Function `google-calendar-sync`:
--   * `buildEvent` baut für `aufgabe` einen Ganztages-Eintrag
--     «SBS · Aufgabe: <Titel>» — aber nur für `typ = 'eigene'` mit
--     `faellig_am` und ohne `erledigt_am`. Marker- und Snooze-Zeilen liegen
--     in derselben Tabelle, haben kein Datum und fallen auf null.
--   * Erledigt oder Datum entfernt → `buildEvent` liefert null → der
--     Kalendereintrag wird beim nächsten Push/Reconcile automatisch gelöscht.
--     Dieselbe Mechanik wie bei Störungen, Montagen und Terminen.
--
-- Der Snooze bleibt bewusst ohne Wirkung auf den Kalender: Er verschiebt die
-- Erinnerung in der Glocke, nicht den Termin selbst.

ALTER TABLE google_calendar_events
  DROP CONSTRAINT IF EXISTS google_calendar_events_entity_type_check;

ALTER TABLE google_calendar_events
  ADD CONSTRAINT google_calendar_events_entity_type_check
  CHECK (entity_type = ANY (ARRAY[
    'termin'::text, 'pikett'::text, 'event'::text,
    'betrieb_reinigung'::text, 'betrieb_manuell'::text,
    'einsatz'::text, 'aufgabe'::text
  ]));

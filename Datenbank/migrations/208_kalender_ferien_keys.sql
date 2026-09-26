-- 208: Kalender-Zuordnungen der Ferien-Reinigungen auf Datums-Schlüssel umstellen.
--
-- WARUM (Review R7, 26.09.2026): Die App bildete den Schlüssel einer
-- Ferien-Reinigung aus dem INDEX der Periode ("<betriebId>:ferien2_endreinigung").
-- Seit die Ferien aus der Tabelle `betrieb_ferien` kommen (beliebig viele,
-- sortiert nach `von`), verschiebt jede neu erfasste frühere oder gelöschte
-- Periode diesen Index — die Edge Function `google-calendar-sync` hätte
-- Kalendereinträge doppelt angelegt oder verwaist stehen lassen. Ab v0.141.0
-- trägt der Schlüssel den Ferienbeginn: "<betriebId>:ferien_2026-10-11_endreinigung".
--
-- Diese Migration schreibt die bestehenden Index-Schlüssel um, damit die
-- Einträge beim nächsten Speichern weiter aktualisiert statt doppelt angelegt
-- werden. Index N → N-te Periode des Betriebs in `betrieb_ferien` (nach `von`);
-- fehlt sie dort, wird auf die Altspalte ferien{N}_start zurückgegriffen
-- (sie war beim Anlegen die Quelle des Index). Die Edge Function räumt einen
-- Schlüssel, zu dem keine Periode mehr existiert, beim nächsten Sync selbst weg.
--
-- !! ERST DAS VORAB-SELECT LAUFEN LASSEN !! Stand 26.09.2026: 9 Zuordnungen,
-- 8 davon stimmen in Tabelle und Altspalte überein; 1c226648… (ferien1) hat
-- keine Periode mehr in der Tabelle → Altspalte 2026-07-06, wird danach
-- beim nächsten Sync als verwaist entfernt.
--
--   WITH m AS (
--     SELECT g.id, g.entity_id,
--            split_part(g.entity_id, ':', 1)::uuid AS betrieb_id,
--            substring(split_part(g.entity_id, ':', 2) FROM '^ferien(\d)_')::int AS n,
--            substring(split_part(g.entity_id, ':', 2) FROM '_(endreinigung|eroeffnung)$') AS art
--     FROM google_calendar_events g
--     WHERE g.entity_type = 'betrieb_reinigung' AND g.entity_id ~ ':ferien\d_'
--   ), f AS (
--     SELECT betrieb_id, von,
--            row_number() OVER (PARTITION BY betrieb_id ORDER BY von) AS n
--     FROM betrieb_ferien
--   )
--   SELECT m.entity_id, f.von AS tabelle_von,
--          CASE m.n WHEN 1 THEN b.ferien_start WHEN 2 THEN b.ferien2_start
--                   WHEN 3 THEN b.ferien3_start WHEN 4 THEN b.ferien4_start
--                   WHEN 5 THEN b.ferien5_start END AS altspalte_von
--   FROM m
--   LEFT JOIN f ON f.betrieb_id = m.betrieb_id AND f.n = m.n
--   JOIN betriebe b ON b.id = m.betrieb_id
--   ORDER BY 1;
--
-- Abweichungen zwischen tabelle_von und altspalte_von vorher klären.

WITH m AS (
  SELECT g.id, g.user_id, g.entity_id,
         split_part(g.entity_id, ':', 1)::uuid AS betrieb_id,
         substring(split_part(g.entity_id, ':', 2) FROM '^ferien(\d)_')::int AS n,
         substring(split_part(g.entity_id, ':', 2) FROM '_(endreinigung|eroeffnung)$') AS art
  FROM google_calendar_events g
  WHERE g.entity_type = 'betrieb_reinigung'
    AND g.entity_id ~ ':ferien\d_(endreinigung|eroeffnung)$'
), f AS (
  SELECT betrieb_id, von,
         row_number() OVER (PARTITION BY betrieb_id ORDER BY von) AS n
  FROM betrieb_ferien
), neu AS (
  SELECT m.id, m.user_id,
         m.betrieb_id::text || ':ferien_' ||
           to_char(COALESCE(
             f.von,
             CASE m.n WHEN 1 THEN b.ferien_start WHEN 2 THEN b.ferien2_start
                      WHEN 3 THEN b.ferien3_start WHEN 4 THEN b.ferien4_start
                      WHEN 5 THEN b.ferien5_start END
           ), 'YYYY-MM-DD') || '_' || m.art AS entity_id
  FROM m
  LEFT JOIN f ON f.betrieb_id = m.betrieb_id AND f.n = m.n
  JOIN betriebe b ON b.id = m.betrieb_id
)
UPDATE google_calendar_events g
SET entity_id = neu.entity_id,
    updated_at = now()
FROM neu
WHERE g.id = neu.id
  AND neu.entity_id IS NOT NULL
  -- nie auf einen schon vorhandenen Schlüssel umschreiben (Unique-Constraint)
  AND NOT EXISTS (
    SELECT 1 FROM google_calendar_events x
    WHERE x.user_id = neu.user_id
      AND x.entity_type = 'betrieb_reinigung'
      AND x.entity_id = neu.entity_id
  );

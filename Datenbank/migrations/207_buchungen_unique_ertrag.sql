-- 207: Höchstens EINE aktive Ertragsbuchung (Haben 3400) je Rechnungsbeleg.
--
-- WARUM (Review R3 / I2, 25.09.2026): `HeinekenBuchungService.createFromRechnung`
-- prüft vor dem Anlegen per Lesen, ob schon eine Hauptbuchung existiert. Zwei
-- gleichzeitige Freigaben (Doppeltipp, zwei Geräte) sehen beide «noch keine»
-- und buchen den Monatsertrag doppelt. Die App sperrt den Knopf jetzt
-- (`_freigabeLaeuft`), die Datenbank soll es aber auch verbieten. Gilt
-- ebenso für die Reinigungs-Ertragsbuchung (beleg_typ 'rechnung', Haben 3400,
-- beleg_id = Reinigung) — auch dort ist eine zweite aktive Zeile ein Fehler.
--
-- !! NOCH NICHT ANWENDEN, ERST DUPLIKATE PRÜFEN !!
-- Existieren schon Duplikate, schlägt CREATE UNIQUE INDEX fehl. Vorher:
--
--   SELECT beleg_id, count(*), array_agg(id ORDER BY created_at) AS ids,
--          array_agg(betrag_brutto ORDER BY created_at) AS betraege
--   FROM buchungen
--   WHERE beleg_typ = 'rechnung'
--     AND haben_konto = 3400
--     AND ist_storniert = false
--     AND storno_von_id IS NULL
--     AND beleg_id IS NOT NULL
--   GROUP BY beleg_id
--   HAVING count(*) > 1;
--
-- Treffer einzeln klären (stornieren statt löschen), erst dann anwenden.
-- Hinweis: Mehrere Buchungen je Beleg mit Haben 3400 können legitim sein,
-- wenn eine davon storniert ist oder eine Storno-Gegenbuchung — die sind
-- durch den WHERE-Teil ausgenommen.

CREATE UNIQUE INDEX IF NOT EXISTS buchungen_ein_ertrag_je_beleg
  ON buchungen (beleg_id)
  WHERE beleg_typ = 'rechnung'
    AND haben_konto = 3400
    AND ist_storniert = false
    AND storno_von_id IS NULL;

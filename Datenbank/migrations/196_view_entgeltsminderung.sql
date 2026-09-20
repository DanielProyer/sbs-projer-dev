-- 196: Sicht «Entgeltsminderung» (MWST Ziff. 235) — 20.09.2026
--
-- WARUM: Die MwSt-Abrechnung zeigte den Ziff.-235-Wert seit v0.116.0 aus
-- `abschreibung_laeufe`. Damit fiel jede EINZELNE Abschreibung durchs Raster
-- — etwa die von Dischma 2026-05-0579 am 20.09.2026 (69.00 netto, 5.60 MWST).
-- Wer Q3/2026 nach dem Bildschirm deklariert hätte, hätte 159.90 statt 165.50
-- zurückgeholt. Bei jeder künftigen Mahnwesen-Abschreibung dasselbe.
--
-- Die Sicht führt beide Quellen zusammen, ohne doppelt zu zählen:
--
--   a) **Jahrgangsläufe** aus `abschreibung_laeufe`. Die Rückholung kann in
--      einem anderen Quartal deklariert werden als sie gebucht wurde (der
--      2019er-Lauf wurde am 31.12.2025 gebucht, die MWST am 02.09.2026 und
--      gehört in Q3/2026) — deshalb zählen `mwst_jahr`/`mwst_quartal`, nicht
--      das Buchungsdatum.
--
--   b) **Einzelabschreibungen**: Buchungen `2200 an 1100` mit
--      `beleg_typ = 'abschreibung'`, die an einer Rechnung hängen und zu
--      KEINEM Lauf gehören. Hier ist das Buchungsdatum die Periode.
--
-- Drei Abgrenzungen, die den Doppelzähler verhindern:
--   * `beleg_typ = 'abschluss'` bleibt draussen (JA2025_B1–B4 sind die
--     MWST-Saldierung zum Jahresende, keine Entgeltsminderung).
--   * `beleg_id IS NULL` bleibt draussen — das ist die Sammelbuchung
--     `JA2025_A_MWST`, die der Lauf 2025 unter a) schon abbildet.
--   * Rechnungen, die in `abschreibung_positionen` stehen, bleiben draussen:
--     sie gehören zu einem Lauf und sind unter a) gezählt.
--
-- Der Satz kommt aus den Beträgen der Rechnung (`mwst_betrag / betrag_netto`),
-- nicht aus dem Satz des Buchungstages — 7.7 % bis 2023, 8.1 % ab 2024.
-- Formularzeile 302 (7.7 %) bzw. 303 (8.1 %).
--
-- `security_invoker` wie in Migration 146: Die Sicht liest mit den Rechten des
-- Aufrufers, die RLS der Grundtabellen greift also weiter.

CREATE OR REPLACE VIEW view_entgeltsminderung
WITH (security_invoker = true) AS
-- a) Jahrgangsläufe
SELECT l.user_id,
       l.mwst_jahr                         AS jahr,
       l.mwst_quartal                      AS quartal,
       round(l.mwst / l.netto * 100, 1)    AS satz,
       l.netto,
       l.mwst,
       l.anzahl,
       format('Abschreibung Jahrgang %s (Abschluss %s, %s Rechnungen)',
              array_to_string(l.jahrgaenge, ', '), l.geschaeftsjahr, l.anzahl) AS text
FROM abschreibung_laeufe l
WHERE l.status = 'gebucht' AND l.netto > 0

UNION ALL

-- b) Einzelabschreibungen ausserhalb eines Laufs
SELECT b.user_id,
       b.geschaeftsjahr AS jahr,
       b.quartal,
       round(r.mwst_betrag / r.betrag_netto * 100, 1) AS satz,
       sum(r.betrag_netto)   AS netto,
       sum(b.betrag_brutto)  AS mwst,
       count(*)::int         AS anzahl,
       format('Einzelabschreibungen (%s %s)', count(*),
              CASE WHEN count(*) = 1 THEN 'Rechnung' ELSE 'Rechnungen' END) AS text
FROM buchungen b
JOIN rechnungen r ON r.id = b.beleg_id
WHERE b.soll_konto = 2200
  AND b.beleg_typ = 'abschreibung'
  AND NOT b.ist_storniert
  AND b.storno_von_id IS NULL
  AND r.betrag_netto > 0
  AND NOT EXISTS (SELECT 1 FROM abschreibung_positionen p WHERE p.rechnung_id = b.beleg_id)
GROUP BY b.user_id, b.geschaeftsjahr, b.quartal,
         round(r.mwst_betrag / r.betrag_netto * 100, 1);

COMMENT ON VIEW view_entgeltsminderung IS
  'MWST Ziff. 235 je Quartal und Satz: Jahrgangslaeufe (abschreibung_laeufe, Periode aus mwst_jahr/mwst_quartal) plus Einzelabschreibungen (Buchung 2200 an 1100, beleg_typ abschreibung, nicht Teil eines Laufs). Formularzeile 302 = 7.7 %, 303 = 8.1 %.';

-- 209c: view_entgeltsminderung b) — Netto aus der 3805-Zeile derselben Rechnung
-- statt aus dem Rechnungsnetto (26.09.2026, angewendet).
--
-- WARUM: Seit ZahlungKern (209) landet auch eine erlassene Minderzahlung als
-- 3805 netto + 2200 MWST mit beleg_typ 'abschreibung' in dieser Sicht (Ziff.
-- 235). Teil b) nahm bisher `sum(r.betrag_netto)` — das Netto der GANZEN
-- Rechnung. Bei 8.10 erlassen auf 108.10 stünde dann 100.00 statt 7.49.
-- Für Einzelabschreibungen (Mahnwesen) ist das Ergebnis unverändert, weil
-- dort die 3805-Zeile das volle Rechnungsnetto trägt.
CREATE OR REPLACE VIEW view_entgeltsminderung
WITH (security_invoker = true) AS
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

SELECT b.user_id,
       b.geschaeftsjahr AS jahr,
       b.quartal,
       round(r.mwst_betrag / r.betrag_netto * 100, 1) AS satz,
       sum((SELECT coalesce(sum(n.betrag_brutto), 0)
            FROM buchungen n
            WHERE n.beleg_id = b.beleg_id
              AND n.soll_konto = 3805 AND n.haben_konto = 1100
              AND n.beleg_typ = 'abschreibung'
              AND NOT coalesce(n.ist_storniert, false) AND n.storno_von_id IS NULL
              AND n.geschaeftsjahr = b.geschaeftsjahr AND n.quartal = b.quartal)) AS netto,
       sum(b.betrag_brutto)  AS mwst,
       count(*)::int         AS anzahl,
       format('Einzelabschreibungen (%s %s)', count(*),
              CASE WHEN count(*) = 1 THEN 'Rechnung' ELSE 'Rechnungen' END) AS text
FROM buchungen b
JOIN rechnungen r ON r.id = b.beleg_id
WHERE b.soll_konto = 2200
  AND b.beleg_typ = 'abschreibung'
  AND NOT coalesce(b.ist_storniert, false)
  AND b.storno_von_id IS NULL
  AND r.betrag_netto > 0
  AND NOT EXISTS (SELECT 1 FROM abschreibung_positionen p WHERE p.rechnung_id = b.beleg_id)
GROUP BY b.user_id, b.geschaeftsjahr, b.quartal,
         round(r.mwst_betrag / r.betrag_netto * 100, 1);

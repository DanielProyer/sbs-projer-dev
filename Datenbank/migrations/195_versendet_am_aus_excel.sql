-- 195: versendet_am der Excel-Altrechnungen aus dem Excel-Stelldatum nachtragen
--
-- *** NICHT ANGEWENDET — wartet auf Entscheid Daniel (ToDo, Abschluss 2026) ***
--
-- WARUM: Der Schritt «Jahrgang abschreiben» (Migration 194, v0.116.0) teilt
-- die Vorschau in Tresen / gestellt / nie gestellt. «Gestellt» liest er aus
-- `rechnungen.versendet_am`. Beim Excel-Import (quelle = 'excel_import') blieb
-- das Feld leer, obwohl das Excel in `rechnung_gestellt` für 515 Rechnungen
-- ein Stelldatum kennt (Stand 19.09.2026; 114 davon noch offen: 2020 30,
-- 2021 32, 2022 45, 2023 7). Ohne Nachtrag zeigt die App für 2020+2021
-- «0 gestellt / 115 nie gestellt»; tatsächlich gingen rund 62 davon per
-- Mail/Post raus. Fürs Buchen ist das gleichgültig (dieselbe Buchung), für
-- die Bewertung «echter Debitorenverlust» vs. «nie fakturiert» nicht.
--
-- WAS: Für jede Excel-Rechnung ohne versendet_am das früheste Excel-Stelldatum
-- der zugehörigen Reinigung(en) eintragen. Format im Excel-Import ist Text
-- 'YYYY-MM-DD HH:MM:SS'; eine einzige Zeile trägt Freitext («Rechnung bereits
-- gestellt (Frau Utzinger)») und bleibt aussen vor. 19 Stelldaten liegen vor
-- dem Rechnungsdatum (Reinigung nachträglich erfasst) — sie werden trotzdem
-- übernommen, es ist das Datum, das im Excel steht.
--
-- WIRKUNG in der App: Rechnungsliste und -detail zeigen bei diesen 515 Rechnungen
-- neu ein Versanddatum. Das Mahnwesen und die Aufgaben-Detektoren stützen sich
-- auf zahlungsstatus/mahnung_stufe, nicht auf versendet_am — geprüft 19.09.2026.
--
-- RÜCKWEG: UPDATE rechnungen SET versendet_am = NULL WHERE id IN (SELECT id FROM
-- import.versendet_am_nachtrag_195);

CREATE TABLE IF NOT EXISTS import.versendet_am_nachtrag_195 AS
WITH e AS (
  SELECT extern_id, left(rechnung_gestellt, 10)::date AS gestellt
  FROM import.einzahlung_excel
  WHERE rechnung_gestellt ~ '^\d{4}-\d{2}-\d{2}'
)
SELECT r.id, r.rechnungsnummer, min(e.gestellt) AS versendet_am, now() AS nachgetragen_am
FROM rechnungen r
JOIN rechnungs_positionen p ON p.rechnung_id = r.id
JOIN reinigungen g ON g.id = p.service_id
JOIN e ON e.extern_id = g.extern_id
WHERE r.quelle = 'excel_import' AND r.versendet_am IS NULL
GROUP BY r.id, r.rechnungsnummer;

UPDATE rechnungen r
   SET versendet_am = n.versendet_am
  FROM import.versendet_am_nachtrag_195 n
 WHERE n.id = r.id AND r.versendet_am IS NULL;

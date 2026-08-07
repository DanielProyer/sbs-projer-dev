-- Migration 166 (07.08.2026, angewendet via MCP `mwst_view_storno_gegenbuchungen`):
-- B6-Härtung — Storno-Gegenbuchungen aus der MWST-View ausschliessen.
-- Die App setzt bei Gegenbuchungen neu mwst_konto = NULL (storno_logik.dart);
-- dieser Filter schützt zusätzlich vor Alt-Gegenbuchungen mit kopiertem
-- mwst_konto. Ausschluss-Modell: storniertes Original UND Gegenbuchung zählen
-- in keiner Auswertung.

CREATE OR REPLACE VIEW view_mwst_abrechnung WITH (security_invoker = on) AS
SELECT user_id,
    geschaeftsjahr,
    quartal,
    sum(CASE WHEN mwst_konto = 2200 THEN mwst_betrag ELSE 0::numeric END) AS umsatzsteuer,
    sum(CASE WHEN mwst_konto = 1170 THEN mwst_betrag ELSE 0::numeric END) AS vorsteuer_investitionen,
    sum(CASE WHEN mwst_konto = 1171 THEN mwst_betrag ELSE 0::numeric END) AS vorsteuer_betrieb,
    sum(CASE WHEN mwst_konto = 2200 THEN mwst_betrag ELSE 0::numeric END)
      - sum(CASE WHEN mwst_konto = ANY (ARRAY[1170, 1171]) THEN mwst_betrag ELSE 0::numeric END) AS netto_mwst_schuld,
    count(*) FILTER (WHERE NOT ist_storniert) AS anzahl_buchungen
FROM buchungen b
WHERE NOT ist_storniert
  AND storno_von_id IS NULL
  AND mwst_konto IS NOT NULL
GROUP BY user_id, geschaeftsjahr, quartal
ORDER BY geschaeftsjahr DESC, quartal DESC;

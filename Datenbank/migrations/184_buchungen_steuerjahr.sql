-- 184: Steuerzahlungen einem Steuerjahr/Steuerart zuordnen, 02.09.2026
ALTER TABLE buchungen
  ADD COLUMN IF NOT EXISTS steuerjahr INTEGER,
  ADD COLUMN IF NOT EXISTS steuerart TEXT CHECK (steuerart IS NULL OR steuerart IN ('bund','kanton','mwst','busse'));
CREATE INDEX IF NOT EXISTS idx_buchungen_steuerjahr ON buchungen(user_id, steuerjahr) WHERE steuerjahr IS NOT NULL;

-- Bezahlt je Jahr/Steuerart: Zahlung (Soll Steuerkonto / Haben Geld) positiv,
-- Rückzahlung (Soll Geld / Haben Steuerkonto) negativ.
CREATE OR REPLACE VIEW view_steuerjahr_zahlungen AS
SELECT user_id, steuerjahr, steuerart,
       ROUND(SUM(CASE
         WHEN soll_konto IN (8900,2208,2202) AND haben_konto IN (1000,1020) THEN betrag_brutto
         WHEN soll_konto IN (1000,1020) AND haben_konto IN (8900,2208,2202) THEN -betrag_brutto
         ELSE 0 END)::numeric, 2) AS bezahlt,
       COUNT(*) AS anzahl
FROM buchungen
WHERE NOT ist_storniert AND storno_von_id IS NULL AND steuerjahr IS NOT NULL
GROUP BY user_id, steuerjahr, steuerart;

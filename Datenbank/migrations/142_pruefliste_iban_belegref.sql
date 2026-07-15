-- Migration 142: camt-Prüfliste — IBAN + Beleg-Referenz der Gegenpartei sichern
--
-- Grund: Der Parser liest die IBAN der Gegenpartei (CdtrAcct/Id/IBAN bei
-- Belastungen, DbtrAcct bei Gutschriften) korrekt aus, sie wurde beim Schreiben
-- des Prüflisten-Eintrags aber verworfen. Damit fehlte sie im Dialog
-- „Regel anlegen" — obwohl der Regel-Matcher genau darauf matchen kann.
--
-- beleg_ref (AcctSvcrRef) wird gebraucht, um aus einem Prüflisten-Eintrag
-- direkt buchen zu können: die Buchung übernimmt sie als Belegnummer.

ALTER TABLE camt_pruefliste
  ADD COLUMN IF NOT EXISTS partei_iban text,
  ADD COLUMN IF NOT EXISTS beleg_ref   text;

COMMENT ON COLUMN camt_pruefliste.partei_iban IS
  'IBAN der Gegenpartei aus camt (CdtrAcct/DbtrAcct) — Vorbefüllung für camt_regel.match_iban.';
COMMENT ON COLUMN camt_pruefliste.beleg_ref IS
  'AcctSvcrRef der Transaktion — wird beim Buchen aus der Prüfliste zur Belegnummer.';

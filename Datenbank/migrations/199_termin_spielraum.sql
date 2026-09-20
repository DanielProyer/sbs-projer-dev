-- 199: Spielraum eines Termins — fix, ganze Woche, ganze Zwischensaison
--
-- ANLASS (Daniel, 20.09.2026): Wenn er bei einer Reinigung mit dem Wirt die
-- Eröffnungs- oder Endreinigung abmacht, ist das oft KEIN fixer Termin:
--   * «Dienstag um 8 Uhr»            → fix, mit Uhrzeit
--   * «die ganze Woche geht»          → woche
--   * «die ganze Zwischensaison ist jemand da» → zwischensaison
-- Bisher kannte `termine` nur ein Datum. Ein «ganze Woche möglich» sah im
-- Tourenplan aus wie ein fixer Tag — und wer sich danach richtet, steht
-- womöglich vor verschlossener Tür, obwohl drei andere Tage gepasst hätten.
--
-- `datum` bleibt der Anfang, `datum_bis` das Ende (NULL = eintägig):
--   * fix            → datum, optional uhrzeit_von/bis, datum_bis NULL
--   * woche          → datum = erster Tag, datum_bis = letzter Tag
--   * zwischensaison → datum = Tag nach Saisonende, datum_bis = Tag vor
--                      Saisonstart
--
-- Der Kalender-Eintrag folgt daraus direkt: mit Uhrzeit ein Zeitfenster, sonst
-- ein Ganztages-Eintrag von `datum` bis `datum_bis`.
--
-- Bewusst ZWEI Felder statt nur des Zeitraums: `datum_bis` sagt, wie lange es
-- gilt, `spielraum` warum. Aus einem Sieben-Tage-Eintrag allein liesse sich
-- nicht ablesen, ob der Wirt die ganze Woche Zeit hat oder ob dort eine
-- Woche lang gearbeitet wird.

ALTER TABLE termine
  ADD COLUMN IF NOT EXISTS datum_bis date,
  ADD COLUMN IF NOT EXISTS spielraum text NOT NULL DEFAULT 'fix';

ALTER TABLE termine DROP CONSTRAINT IF EXISTS termine_spielraum_check;
ALTER TABLE termine ADD CONSTRAINT termine_spielraum_check
  CHECK (spielraum = ANY (ARRAY['fix'::text, 'woche'::text, 'zwischensaison'::text]));

-- Ein Enddatum vor dem Anfang wäre ein stiller Datenfehler: Der
-- Kalender-Export würde daraus einen Eintrag mit negativer Dauer bauen.
ALTER TABLE termine DROP CONSTRAINT IF EXISTS termine_datum_bis_check;
ALTER TABLE termine ADD CONSTRAINT termine_datum_bis_check
  CHECK (datum_bis IS NULL OR datum_bis >= datum);

COMMENT ON COLUMN termine.datum_bis IS
  'Letzter Tag des Termins (NULL = eintaegig). Bei spielraum=woche/zwischensaison gesetzt.';
COMMENT ON COLUMN termine.spielraum IS
  'fix = genau dann (ggf. mit Uhrzeit) | woche = irgendwann in der Woche | zwischensaison = jederzeit waehrend der Zwischensaison.';

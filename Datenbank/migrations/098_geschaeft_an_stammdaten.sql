-- 098_geschaeft_an_stammdaten.sql
-- Arbeitnehmer-Stammdaten (AHV-Nr., Geburtsdatum) wandern ins Geschäft
-- (beim Geschäftsführer = einziger Arbeitnehmer).
ALTER TABLE geschaeft_einstellungen ADD COLUMN IF NOT EXISTS gf_ahv_nr text;
ALTER TABLE geschaeft_einstellungen ADD COLUMN IF NOT EXISTS gf_geburtsdatum date;

-- Bestehende AN-Stammdaten aus der neuesten Lohn-Einstellung übernehmen (kein Datenverlust).
UPDATE geschaeft_einstellungen g
SET gf_ahv_nr = COALESCE(g.gf_ahv_nr, le.arbeitnehmer_ahv_nr),
    gf_geburtsdatum = COALESCE(g.gf_geburtsdatum, le.arbeitnehmer_geburtsdatum)
FROM (
  SELECT DISTINCT ON (user_id) user_id, arbeitnehmer_ahv_nr, arbeitnehmer_geburtsdatum
  FROM lohn_einstellungen ORDER BY user_id, jahr DESC
) le
WHERE le.user_id = g.user_id;

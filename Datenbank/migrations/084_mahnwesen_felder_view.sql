-- Migration 084: Mahnwesen-Tracking-Felder und Dashboard-View
-- Neue Felder: erinnerung_am, mahnung_1_am, mahnung_2_am
-- Neue View: view_mahnwesen_dashboard mit empfohlene_aktion

ALTER TABLE rechnungen ADD COLUMN IF NOT EXISTS erinnerung_am DATE;
ALTER TABLE rechnungen ADD COLUMN IF NOT EXISTS mahnung_1_am DATE;
ALTER TABLE rechnungen ADD COLUMN IF NOT EXISTS mahnung_2_am DATE;

CREATE OR REPLACE VIEW view_mahnwesen_dashboard AS
SELECT
  r.id,
  r.user_id,
  r.rechnungsnummer,
  r.rechnungstyp,
  r.betrieb_id,
  b.name AS betrieb_name,
  r.rechnungsdatum,
  r.faelligkeitsdatum,
  (CURRENT_DATE - r.faelligkeitsdatum) AS ueberfaellig_seit_tagen,
  r.betrag_brutto,
  r.zahlungsstatus,
  r.mahnung_stufe,
  r.versandart,
  r.erinnerung_am,
  r.mahnung_1_am,
  r.mahnung_2_am,
  r.letzte_mahnung_am,
  CASE
    WHEN r.zahlungsstatus = 'offen'
         AND (CURRENT_DATE - r.faelligkeitsdatum) >= 5
         THEN 'erinnerung_faellig'
    WHEN r.zahlungsstatus = 'erinnert'
         AND r.erinnerung_am IS NOT NULL
         AND (CURRENT_DATE - r.erinnerung_am) >= 25
         THEN 'mahnung_1_faellig'
    WHEN r.zahlungsstatus = 'mahnung_1'
         AND r.mahnung_1_am IS NOT NULL
         AND (CURRENT_DATE - r.mahnung_1_am) >= 30
         THEN 'mahnung_2_faellig'
    WHEN r.zahlungsstatus = 'mahnung_2'
         THEN 'eskalation'
    ELSE 'warten'
  END AS empfohlene_aktion
FROM rechnungen r
LEFT JOIN betriebe b ON r.betrieb_id = b.id
WHERE r.zahlungsstatus NOT IN ('bezahlt', 'abgeschrieben')
  AND r.rechnungstyp != 'heineken_monat'
ORDER BY
  CASE r.zahlungsstatus
    WHEN 'mahnung_2' THEN 1
    WHEN 'mahnung_1' THEN 2
    WHEN 'erinnert' THEN 3
    WHEN 'offen' THEN 4
  END,
  r.faelligkeitsdatum;

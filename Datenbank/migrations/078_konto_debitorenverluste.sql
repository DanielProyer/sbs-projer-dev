-- Migration 078: Konto 3805 Debitorenverluste hinzufuegen
-- Fuer Zahlungsdifferenzen: Kunde zahlt zu wenig, Differenz wird erlassen
-- Ueberzahlungen gehen auf bestehendes Konto 8000 (Ausserordentlicher Ertrag)

INSERT INTO konten (user_id, kontonummer, bezeichnung, beschreibung, kategorie, ist_aktiv)
SELECT
  '1e1ec2dd-7836-4d8e-8256-c5649d994ee2',
  3805,
  'Debitorenverluste',
  'Verluste aus Forderungen (Kunde zahlt zu wenig, Differenz wird erlassen)',
  'Erlösminderungen',
  true
WHERE NOT EXISTS (
  SELECT 1 FROM konten
  WHERE user_id = '1e1ec2dd-7836-4d8e-8256-c5649d994ee2'
    AND kontonummer = 3805
);

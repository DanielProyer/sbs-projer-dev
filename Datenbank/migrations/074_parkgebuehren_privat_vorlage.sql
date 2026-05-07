-- ============================================================
-- Migration 074: Buchungsvorlage Parkgebühren Privat (Twint)
-- Projekt: SBS Projer App
-- Stand: 07.05.2026
-- Beschreibung: Vorlage für monatliche Sammel-Buchung Parkgebühren
--               bezahlt via Twint vom Privatkonto (Konto 2260).
--               Konto 6270 = Parkgebühren, 0% MwSt (öffentl. Parkplätze).
-- ============================================================

INSERT INTO buchungs_vorlagen (user_id, geschaeftsfall_id, bezeichnung, soll_konto, haben_konto, mwst_konto, mwst_satz, zahlungsweg, belegordner, auto_trigger)
VALUES
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', '5.2', 'Parkgebühren Privat (Twint)', 6270, 2260, NULL, 0, 'privat', '040_Fahrzeug', NULL)
ON CONFLICT (user_id, geschaeftsfall_id, zahlungsweg) DO NOTHING;

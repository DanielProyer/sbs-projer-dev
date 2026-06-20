-- 102_drop_zahlung_trigger.sql
-- Entscheidung (20.06.2026): App-Code ist die einzige Quelle für Zahlungs-
-- buchungen (verbuchenSammel / verbuchen / createZahlungseingang). Der DB-
-- Trigger buchte denselben Zahlungseingang ein ZWEITES Mal → Doppelbuchung
-- (und createZahlungseingang nutzte das Einlesedatum statt des echten Datums).
-- Der "Rechnung gestellt"-Trigger (rechnungen_auto_buchung_erstellt) bleibt
-- bestehen — nur der Zahlungs-Trigger wird abgeschaltet.
DROP TRIGGER IF EXISTS rechnungen_auto_buchung_zahlung ON rechnungen;
-- Funktion bleibt dormant erhalten (trivial reaktivierbar, falls je gewünscht).

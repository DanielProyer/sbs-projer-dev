-- Bereinigung B1 (Buchhaltungsprüfung 06.08.2026), ausgeführt 07.08.2026.
-- Entscheid Daniel: dokumentierte Migration mit Snapshot (statt Storni).
--
-- Die MwSt-/Vorsteuer-Trennbuchungen verdoppelten die MwSt: Die Hauptbuchung
-- trägt mwst_konto (SaldoExpansion teilt bereits auf), die Trennzeile buchte
-- dieselbe MwSt nochmals. Code-Ursache behoben in v0.72.7 (4 Pfade:
-- reinigung_buchung_service, heineken_buchung_service, spesen_import_service,
-- kreditor_buchung). Die DB-View view_mwst_abrechnung war immun (Trennzeilen
-- ohne mwst_konto) — sie ändert sich durch diese Löschung NICHT.
--
-- Wirkung auf die Salden (SaldoExpansion/getAllSaldi):
--   Ertrag 3400        +10'219.98  (war um die USt-Trennzeilen zu tief)
--   MwSt-Schuld 2200   −10'219.98  (war verdoppelt)
--   Vorsteuer 1171        −184.26  (war verdoppelt)
--   Aufwandkonten         +184.26  (waren doppelt um die VSt reduziert)
--
-- Rollback: INSERT INTO buchungen SELECT * FROM snapshot_mwst_trennbuchungen.geloescht;

-- 1. Snapshot
CREATE SCHEMA IF NOT EXISTS snapshot_mwst_trennbuchungen;
CREATE TABLE snapshot_mwst_trennbuchungen.geloescht AS
SELECT * FROM buchungen
WHERE NOT ist_storniert AND storno_von_id IS NULL
  AND (
    (soll_konto = 3400 AND haben_konto = 2200 AND beleg_typ = 'mwst')
    OR
    (soll_konto IN (1170, 1171) AND haben_konto BETWEEN 4000 AND 6999
     AND beschreibung LIKE 'Vorsteuer %' AND beleg_typ = 'sonstiges'
     AND notizen LIKE 'Spesen-Scanner Import%')
  );

-- 2. Löschen (identische Kriterien; buchungs_belege via ON DELETE CASCADE,
--    die Storage-Dateien bleiben als Waisen und gehen beim nächsten
--    «Speicher aufräumen»)
DELETE FROM buchungen b
USING snapshot_mwst_trennbuchungen.geloescht s
WHERE b.id = s.id;

-- 3. Verifikation (Soll: 0 / 0 / 977 = 898 USt + 79 VSt)
-- SELECT count(*) FROM buchungen WHERE soll_konto=3400 AND haben_konto=2200 AND beleg_typ='mwst';
-- SELECT count(*) FROM buchungen b JOIN snapshot_mwst_trennbuchungen.geloescht s ON s.id=b.id;
-- SELECT count(*) FROM snapshot_mwst_trennbuchungen.geloescht;

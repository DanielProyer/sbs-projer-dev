-- Korrektur B2 (Buchhaltungsprüfung 06.08.2026), ausgeführt 07.08.2026:
-- Die Heineken-Hauptbuchungen 04–06/2026 trugen ein fälschlich auf 5 Rappen
-- gerundetes Brutto → brutto ≠ netto + mwst (SaldoExpansion-Assert).
-- Heineken wird ungerundet fakturiert (Regel Daniel 15.07.2026); netto und
-- mwst der Buchungen stimmten bereits exakt mit der Rechnung überein.
-- Fix: betrag_brutto = Rechnungsbrutto. Code-Ursache behoben in v0.72.5
-- (heineken_buchung_service.dart → heinekenBuchungsBetraege, keine 5-Rp-Rundung).

-- Alt-Werte (Rollback):
--   ff45746c-f921-424a-816e-8ef57670c955  6288.60  (04/2026, neu 6288.62)
--   43251be1-38c5-4e45-9b2d-5d1ae116e53e  6198.25  (05/2026, neu 6198.24)
--   718ebedf-25a6-4680-861c-59a09d7e499e  6594.95  (06/2026, neu 6594.96)

UPDATE buchungen b
SET betrag_brutto = r.betrag_brutto
FROM rechnungen r
WHERE r.id = b.beleg_id::uuid
  AND b.id IN ('ff45746c-f921-424a-816e-8ef57670c955',
               '43251be1-38c5-4e45-9b2d-5d1ae116e53e',
               '718ebedf-25a6-4680-861c-59a09d7e499e')
  AND b.beleg_typ = 'rechnung'
  AND NOT b.ist_storniert;

-- Verifikation: darf 0 Zeilen liefern
-- SELECT count(*) FROM buchungen
-- WHERE NOT ist_storniert AND abs(betrag_netto + mwst_betrag - betrag_brutto) > 0.005;

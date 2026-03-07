-- ============================================================
-- Migration 004: Views
-- Projekt: SBS Projer App
-- Stand: 12.02.2026
-- Ausführen NACH: 003_triggers_functions.sql
-- ============================================================

-- Anlagen mit Service-Status (für Tourenplanung)
CREATE OR REPLACE VIEW view_anlagen_service_status AS
SELECT
  a.id,
  a.user_id,
  b.name AS betrieb_name,
  b.ort,
  r.name AS region_name,
  a.bezeichnung,
  a.typ_anlage,
  a.anzahl_haehne,
  a.reinigung_rhythmus,
  a.letzte_reinigung,
  a.naechste_reinigung,
  CASE
    WHEN a.naechste_reinigung < CURRENT_DATE                        THEN 'ueberfaellig'
    WHEN a.naechste_reinigung <= CURRENT_DATE + INTERVAL '7 days'  THEN 'faellig_bald'
    ELSE 'ok'
  END AS service_status,
  a.status,
  b.ist_bergkunde,
  b.ist_saisonbetrieb
FROM anlagen a
JOIN betriebe b ON a.betrieb_id = b.id
LEFT JOIN regionen r ON b.region_id = r.id
WHERE a.status = 'aktiv';

-- Bestellliste: Lager-Artikel mit Bestand unter Mindestmenge
CREATE OR REPLACE VIEW view_bestellliste AS
SELECT
  l.id,
  l.user_id,
  mk.name AS kategorie,
  l.name,
  l.dbo_nr,
  l.einheit,
  l.bestand_aktuell,
  l.bestand_mindest,
  l.bestand_optimal,
  (l.bestand_optimal - l.bestand_aktuell) AS bestellmenge,
  l.lieferant,
  l.lieferanten_artikel_nr,
  l.preis_einkauf,
  ROUND((l.bestand_optimal - l.bestand_aktuell) * COALESCE(l.preis_einkauf, 0), 2) AS bestellkosten_geschaetzt
FROM lager l
LEFT JOIN material_kategorien mk ON l.kategorie_id = mk.id
WHERE l.bestand_niedrig = TRUE AND l.ist_aktiv = TRUE
ORDER BY mk.sortierung, mk.name, l.name;

-- Offene und überfällige Rechnungen
CREATE OR REPLACE VIEW view_offene_rechnungen AS
SELECT
  r.id,
  r.user_id,
  r.rechnungsnummer,
  r.rechnungstyp,
  b.name AS betrieb_name,
  r.heineken_monat,
  r.rechnungsdatum,
  r.faelligkeitsdatum,
  (CURRENT_DATE - r.faelligkeitsdatum) AS ueberfaellig_seit_tagen,
  r.betrag_brutto,
  r.zahlungsstatus,
  r.mahnung_stufe,
  r.versandart
FROM rechnungen r
LEFT JOIN betriebe b ON r.betrieb_id = b.id
WHERE r.zahlungsstatus IN ('offen', 'ueberfaellig', 'teilbezahlt')
ORDER BY r.faelligkeitsdatum ASC;

-- MWST-Abrechnung pro Quartal
CREATE OR REPLACE VIEW view_mwst_abrechnung AS
SELECT
  b.user_id,
  b.geschaeftsjahr,
  b.quartal,
  SUM(CASE WHEN b.mwst_konto = 2200 THEN b.mwst_betrag ELSE 0 END) AS umsatzsteuer,
  SUM(CASE WHEN b.mwst_konto = 1170 THEN b.mwst_betrag ELSE 0 END) AS vorsteuer_investitionen,
  SUM(CASE WHEN b.mwst_konto = 1171 THEN b.mwst_betrag ELSE 0 END) AS vorsteuer_betrieb,
  SUM(CASE WHEN b.mwst_konto = 2200 THEN b.mwst_betrag ELSE 0 END)
  - SUM(CASE WHEN b.mwst_konto IN (1170, 1171) THEN b.mwst_betrag ELSE 0 END) AS netto_mwst_schuld,
  COUNT(*) FILTER (WHERE NOT b.ist_storniert) AS anzahl_buchungen
FROM buchungen b
WHERE NOT b.ist_storniert AND b.mwst_konto IS NOT NULL
GROUP BY b.user_id, b.geschaeftsjahr, b.quartal
ORDER BY b.geschaeftsjahr DESC, b.quartal DESC;

-- Erfolgsrechnung (Erträge / Aufwand pro Monat)
CREATE OR REPLACE VIEW view_erfolgsrechnung AS
SELECT
  b.user_id,
  b.geschaeftsjahr,
  b.monat,
  SUM(CASE WHEN b.haben_konto BETWEEN 3000 AND 3999 THEN b.betrag_netto ELSE 0 END) AS ertrag,
  SUM(CASE WHEN b.soll_konto BETWEEN 4000 AND 4999 THEN b.betrag_netto ELSE 0 END) AS materialaufwand,
  SUM(CASE WHEN b.soll_konto BETWEEN 5000 AND 5999 THEN b.betrag_netto ELSE 0 END) AS personalaufwand,
  SUM(CASE WHEN b.soll_konto BETWEEN 6000 AND 6999 THEN b.betrag_netto ELSE 0 END) AS betriebsaufwand,
  SUM(CASE WHEN b.haben_konto BETWEEN 3000 AND 3999 THEN b.betrag_netto ELSE 0 END)
  - SUM(CASE WHEN b.soll_konto BETWEEN 4000 AND 6999 THEN b.betrag_netto ELSE 0 END) AS betriebsergebnis
FROM buchungen b
WHERE NOT b.ist_storniert
GROUP BY b.user_id, b.geschaeftsjahr, b.monat
ORDER BY b.geschaeftsjahr DESC, b.monat DESC;

-- Offene Formulare (PDFs noch nicht generiert)
CREATE OR REPLACE VIEW view_offene_formulare AS
SELECT
  f.id,
  f.user_id,
  f.formular_typ,
  f.service_typ,
  f.service_id,
  f.referenz_nr,
  f.abrechnungs_monat,
  f.pdf_status,
  f.pdf_fehler,
  f.created_at
FROM formulare f
WHERE f.pdf_status IN ('ausstehend', 'fehler')
ORDER BY f.abrechnungs_monat DESC, f.formular_typ;

-- Pikett-Dienste mit ausstehender Kalender-Synchronisation
CREATE OR REPLACE VIEW view_pikett_kalender_sync AS
SELECT
  id,
  user_id,
  datum_start,
  datum_ende,
  referenz_nr,
  kalender_sync_status,
  kalender_sync_fehler,
  kalender_sync_at
FROM pikett_dienste
WHERE kalender_sync_status != 'synced'
ORDER BY datum_start ASC;

# ToDo-Liste — Daniel Projer (SBS Projer App)

**Stand:** 25.06.2026 · **Live:** v0.13.2

---

## 🔴 OFFEN — relevant

### Scharfstellung / Live-Betrieb (Buchhaltung 01.07.2026)
Strategie: **Voll-Übernahme** (kein Clean-Start) — Historie lückenlos 27.03.2019→heute im System, Bilanz geht an allen Jahresenden auf, Salden laufen weiter. „Scharfstellen" = nur noch:
- [ ] **Mail-Bereiche scharfstellen:** `bestellungScharf` + `mahnwesenScharf` in `mail_config.dart` (stehen noch auf Test-Empfänger).
- [ ] **camt-Auto-Buchung produktiv** ab Stichtag 01.07.2026 (gebaut, geht automatisch scharf). **Erster Echtlauf Anfang August** (Juli-camt): Ergebnis-Report + Prüfliste durchgehen, neue wiederkehrende Empfänger als Regel anlegen.
- [ ] **2026 gezielt** auf vereinzelte Test-Buchungen durchsehen (NICHT pauschal; echte Live-Buchungen bleiben).

### Buchhaltung — Fachfragen / Sichtprüfung (Daniel)
- [ ] **B1:** Lohnaufwand 5000 liegt ~1–2k/Jahr über Lohnausweis-Brutto — klären (AG-Beiträge/Spesen drin? oder überbucht?). Relevant für AHV-/Steuerbasis.
- [ ] **B3:** MWST-Zahllast 2023 App 8'014 vs. deklariert ≈6'635 (+1'379) — Quartals-Timing/Buchung prüfen (andere Jahre decken sich exakt).
- [ ] **Abschreibungen Alt-Forderungen:** 2019–2022 ≈50k Kandidaten (kaum eintreibbar) — wieviel/welche Kunden definitiv abschreiben (Debitoren-Hub: 3805/1100 netto + 2200 MWST-Rückholung) vs. Delkredere 5%? Daniel entscheidet selbst. (Negative Salden 2202/2273/8900 = Timing-Konten, KEINE Abschreibung.)
- [ ] **1100-Plausibilität** im Debitoren-Screen gegen die offenen CHF 105'240.95 prüfen.
- [ ] **App-Sichtprüfung Scans:** zeigen Protokoll-/Zahlbeleg-Scans an Reinigungen/Forderungen korrekt? (Bucket `reinigung-fotos`, `import/010,020/` → signed URL).
- [ ] **Optional Excel-Gegencheck:** Excel-Bilanz auf 31.12.2024 neu rechnen → bit-genauer Abgleich Kasse/Debitoren/Bank.
- [ ] **Phase 0c:** Offene-Posten-Sicht (Debitoren 1100 / Kreditoren 2000).

### camt / Code-Politur (klein, unkritisch)
- [ ] Import: statische Überschrift „Kundenzahlungen" bleibt nach „Alle verbuchen" stehen.
- [ ] Import-Archiv-Dateiname hart `camt.xml` (nur Anzeige; `picked.name` mitführen).
- [ ] `verbuche` nicht in echte DB-Transaktion geklammert (durch Idempotenz-Guard abgesichert).
- [ ] camt I2: Netzfehler nach Buchung vor Rechnung-Update → verwirrender Prüflisten-Eintrag (kein Doppelbuchen) — Transaktionalität verbessern.
- [ ] camt-Regeln beobachten/verengen: `'abschluss'` (Substring breit); Lohn „daniel proyer" ggf. → IBAN `CH7909000000870500683`; Heineken „heineken" → „heineken switzerland".
- [ ] Saldo-Parsing-Bug (vorbestehend): `OPBD/CLBD` als 0 gelesen (`CdOrPrtry` liegt unter `Tp`). Pipeline nutzt es nicht, aber falsch.
- [ ] Phase 0a Follow-up: 11 alte camt-Vorlagen `ist_aktiv=true` (FK-Schutz) — optional Regeln auf neue Geschäftsfälle umhängen, dann Alt-Vorlagen deaktivieren (tauchen sonst im manuellen Dropdown auf).
- [ ] Hub: toter Code `forderungenProvider` / `mahnwesenDashboardProvider` entfernen (invalidate auf `rechnungenStreamProvider` umbiegen).
- [ ] **App-weite UI-Vereinheitlichung** (Filter/Dropdowns) — eigener grösserer Durchgang. Referenz-Stil: schlichte `DropdownButton` im `Wrap`.

---

## 🟢 BACKLOG (kein Zeitdruck)
- [ ] **GIS Regionen-Polygone** für 15 Regionen (KML/GeoJSON, WGS84/EPSG:4326). Tools: QGIS / Google Earth Pro / My Maps.
- [ ] **Beta-Testing-Phase** (echte Geräte, Real-World, Offline-Modus Bergkunden).
- [ ] **Beleg-Foto** Ausrichtung/Zuschnitt optimieren (Deskew, Crop, Kontrast).
- [ ] **Bulk-Sync Handy-Kontakte ↔ App** (App-Kontakte priorisiert, Matching über normalisierte Nr., Bestätigung vor Übernahme).
- [ ] **Termin-Erinnerungen Folge-Tests:** Web (Browser-Notification + In-App), Android-APK (lokale Benachrichtigung bei geschlossener App, Berechtigungen).
- [ ] **A4 Wiederkehrende Buchungen** / **A5 Monatsabschluss-Checkliste** (nice-to-have; A4 teilweise via Vorlagen + camt-Regeln abgedeckt).
- [ ] **Nach MVP:** Franchise-Partner einladen · zusätzliche Regionen definieren · Partner schulen.

---

## 📌 Merksätze / Design-Entscheidungen (NICHT ändern)
- **Kein DB-Unique-Constraint auf `buchungen(camt_tx_key)`:** der Kundenzahlungs-Pfad stempelt denselben `tx_key` absichtlich auf mehrere Buchungen (Sammelzahlung). Dedup läuft über den In-App-Set (Single-User).
- **App ist alleinige Buchungsquelle** (DB-Trigger `rechnungen_auto_buchung_zahlung` abgeschaltet, Migration 102). „Rechnung gestellt"-Trigger `…_erstellt` bleibt aktiv.
- **Jede grosse Liste paginieren** (PostgREST deckelt bei 1000).
- **Reversibilität:** alle camt-Buchungen tragen `camt_tx_key` → „mach die camt-Buchungen rückgängig".
- **QR-Bill:** SCOR (RF…) wegen normaler IBAN (keine QR-IBAN); QR-Code braucht zwingend das Schweizerkreuz.
- Historie (`quelle='excel_import'`/Reinigungen/Forderungen) ist echte Daten — **NICHT löschen**.

---

## ✅ Erledigt (Chronik, neueste zuerst)
- **v0.15.0** (25.06) **Rechnungsadresse-Dialog wie Betrieb-Formular** (Firma/Betrieb/Strasse/Nr/PLZ→Ort-Lookup/Email) + **Propagierung auf den Betrieb** (Adresse gilt künftig) + **Neu-Versand** (Bestätigung → PDF neu, Mail an Kunde, **Fällig bis = heute+30** persistiert in Rechnung/Forderung). „Neue Buchung"-Kachel (v0.14.1) + Adress-Button-CanvasKit-Fix (v0.14.2) inklusive.
- **v0.14.0** (25.06) **Pro-Rechnung Rechnungsadresse** (Override/Snapshot, Migration 105 `rechnungen.rechnungsadresse` jsonb): „Adresse anpassen" im Rechnungs-Detail ändert nur diese eine Rechnung (Betrieb/andere Rechnungen unberührt); PDF/Mahnung nutzen den Override via reinem Resolver `effektiveRechnungsadresse`; „Zurücksetzen" auf Betriebsadresse.
- **v0.13.3** (25.06) Temporären Rechnungs-Nachversand-Screen entfernt (Backlog abgearbeitet).
- **v0.13.2** (25.06) QR-Referenz-Kollision robust (Suffix-Retry statt PostgrestException).
- **v0.13.1** (25.06) Schweizerkreuz im QR-Code (Rechnung+Mahnung) — QR war ohne ungültig.
- **v0.13.0** (25.06) **TP-C QR-Referenz (SCOR)**: Migration 104, Util `scor_referenz.dart`, Vergabe in `RechnungRepository.create`, SCOR in Rechnungs-/Mahnungs-PDF, Matching-Stufe 1. Plan: `docs/superpowers/plans/2026-06-25-camt-qr-referenz-scor.md`.
- **v0.12.x** (25.06) **TP-B Zahler→Betrieb-Lernen**: Aliase am Betrieb (`betriebe.zahler_aliase`, Migration 103), Matching-Stufe 2, Auto-Treffer-Lern-Schalter. Plan: `docs/superpowers/plans/2026-06-25-camt-zahler-betrieb-lernen.md`.
- **v0.11.x** (20.06) **TP-A Import+Abgleich vereint** (Stichtag 11.03, `AbgleichVorschau` geteilt), Bestätigungs-Modus, Doppelbuchung-Fix (Migration 102), Reversibilität, Lohn/Miete-Trennung.
- **v0.10.138** (20.06) camt-Forderungsabgleich **TP2** (Engine `ForderungsAbgleichService`, Archiv `camt_dateien` Migration 101, ⚪-Bucket, existsZeitraum-Dialog).
- **v0.10.133** (19.06) Forderungen-Historie **TP1** (7'786 Reinigungen + 4'438 Rechnungen, offen CHF 105'240.95, Scans verknüpft, Pagination-Fix).
- **v0.10.130** (18.06) Berichtswesen-Umbau, Geschäfts-Einstellungen (`geschaeft_einstellungen`), Lohn-Trennung, MWST-Sätze-Historie, Gast-Account deaktiviert.
- **v0.10.118** (13.06) Forderungen-Hub; Buchhaltung Phase 0b/1/2 (Excel-Voll-Import 14'552 Zeilen 2019–Nov 2025, Bilanz geht auf, Audit/Abschreibungs-Werkzeug, MWST-Bugfixes).
- **Datenkorrektur** (25.06) Phantom-Zahlung 17.05. (4 Rechnungen 2026-05-0611–0614) bereinigt.
- **Früher:** Heineken-Monatsraster + Auto-Buchung, Lohnbuchhaltung, Spesen-OCR, camt.053-Import, Material-Modul, Termine/Kalender, Störungen/Pikett, Kontakt-Sync u.v.m. → siehe git-History + Memory.

---

*Detaillierte Technik-Kontexte: Memory-Index + `docs/superpowers/` (Specs/Pläne) + git-History.*

# ToDo-Liste - Daniel Projer

**Stand**: 08.06.2026
**Für**: SBS Projer App Entwicklung

---

## 🧾 Forderungen-Hub (13.06.2026, gemergt + deployed v0.10.118)
Debitoren/Rechnungen/Mahnwesen vereint: Rechnungsliste = Hub „Forderungen" (`/rechnungen`) mit Mahnfällig-Filter + einklappbarem Debitoren-Kopf (Salden + Sammel-Abschreibung + Delkredere). `ForderungService` (empfohlene Mahn-Aktion, TDD). Mahnwesen-/Debitoren-Screens entfernt (Routen→Redirect), Tiles zu einem „Forderungen". Kritischer Re-Audit: Bilanz geht auf (Diff −0.02 Rundung), keine Strukturfehler.
- [ ] **Hub Follow-up (Minor, toter Code):** `forderungenProvider` ungenutzt; `mahnwesenDashboardProvider` nur noch invalidiert (kein watch mehr). Beide entfernen + invalidate-Aufrufe auf `rechnungenStreamProvider` umbiegen.
- [ ] **Buchungsvorlagen aufräumen (in Arbeit):** Dubletten 20.1≡F-bankgeb, 19.1≡F-fran-zg, 24.1↔A-sachvers, 15.1↔A-telekom, 30.x↔A-sozvers; A-sozvers bucht generisch 5700 (BVG sollte 5720, SUVA 5730); Titel/IDs vereinheitlichen; camt-Regeln auf neue Vorlagen umhängen, dann alte deaktivieren.

---

## 📥 camt-Auto-Buchung (Rechnungskontrolle)

**Phase 1 + Phase 2 fertig** (Branch `feature/camt-rechnungskontrolle`): Parser-Split, Stichtag 01.07.2026, Klassifizierer, Kundenzahlungs-/Heineken-Matching, Prüfliste, Auto-Booker, Ausgaben-Regelwerk (`camt_regel` + 13 Startregeln + 4 neue Vorlagen 5700/5720/5730/8900), Regel-UI + Dashboard-Einstiege. Spec/Plan unter `docs/superpowers/`. **Produktiv aktiv ab Stichtag 01.07.2026.**

Review-Follow-ups (dokumentiert, nicht kritisch — Daniel kontrolliert ohnehin jede Buchung):
- [ ] Phase-1 I2: Bei Netzfehler nach erfolgter Buchung aber vor Rechnung-Update entsteht ein verwirrender Prüflisten-Eintrag (kein Doppelbuchen). Reihenfolge/Transaktionalität verbessern.
- [ ] Phase-1 M4: `HeinekenBuchungService.createZahlungseingang` bucht mit `DateTime.now()` statt Bank-Buchungsdatum — optionalen `datum`-Parameter ergänzen.
- [ ] Saldo-Parsing-Bug (vorbestehend): `OPBD/CLBD` werden als 0 gelesen (`CdOrPrtry` liegt unter `Tp`). Nicht von der Pipeline genutzt, aber falsch.
- [ ] Phase-2: Regel `'abschluss'` ist breit (Substring) — beobachten; ggf. auf IBAN/spezifischeren Text verengen. Lohn-Regel „daniel proyer" ggf. auf IBAN (CH7909000000870500683) umstellen.
- [ ] M1: Heineken-Klassifizierung per Substring „heineken" — ggf. auf „heineken switzerland" verengen.
- [ ] **Phase 0a Follow-up:** 11 alte camt-referenzierte Vorlagen (15.1, 19.1, 2.1, 20.1, 22.7, 24.1, 25.4, 30.1–30.4) blieben bewusst `ist_aktiv=true` (FK-Schutz). Optional später: camt-Regeln auf die neuen Geschaeftsfaelle (A-sozvers/F-steuer-*/A-telekom/A-sachvers/F-bankgeb/F-fran-zg) umhaengen, dann Alt-Vorlagen deaktivieren. Tauchen aktuell zusaetzlich im manuellen Vorlagen-Dropdown auf.

**Bewusste Design-Entscheidung (NICHT ändern):** Kein DB-Unique-Constraint auf `buchungen(camt_tx_key)` — der Kundenzahlungs-Pfad stempelt denselben `tx_key` absichtlich auf mehrere Buchungen (Sammelzahlung). Dedup läuft korrekt über den In-App-Set (Single-User-App).

**Erster Echtlauf (Anfang August 2026):** Juli-camt hochladen, Ergebnis-Report + Prüfliste durchgehen. Bei neuen wiederkehrenden Empfängern „Regel anlegen" nutzen.

---

## 🔴 VOR DEVELOPMENT-START

### Daten-Vorbereitung

- [ ] **Regionen-Polygone erstellen (GIS)**
  - KML-Dateien für alle 15 Regionen erstellen:
    - Arosa
    - Chur
    - Davos
    - Domleschg
    - Flims/Laax/Falera
    - Lenzerheide
    - Oberland
    - Prättigau
    - Rheintal
    - Rheinwald
    - Innerschweiz
    - Sempach
    - Küssnacht
    - Cham
    - Engadin
  - Format: KML oder GeoJSON
  - Koordinatensystem: WGS84 (EPSG:4326)
  - **Notiz**: Evtl. ergeben sich andere Gebietsaufteilungen beim Erstellen
  - **Wann**: Kann später gemacht werden, nicht kritisch für MVP

---

## 🟡 WÄHREND DEVELOPMENT

### Testing & Feedback

- [ ] **Beta-Testing Phase**
  - App auf echten Geräten testen
  - Real-World-Szenarien durchspielen
  - Offline-Modus testen (Bergkunden ohne Netz)
  - Feedback an Entwickler

### Beleg-Digitalisierung verbessern

- [ ] **Beleg-Foto Ausrichtung/Zuschnitt optimieren**
  - Automatische Ausrichtung (Deskew) des fotografierten Belegs
  - Zuschnitt auf Beleg-Bereich (Crop)
  - Kontrast/Helligkeit optimieren für bessere Lesbarkeit

### Telefon-Kontakte Sync

- [ ] **Bulk-Sync Handy-Kontakte ↔ App-Kontakte**
  - App-Kontakte haben Priorität (alte Telefonbuch-Einträge können ungültig sein)
  - Alle Kategorien: betrieb, heineken, event
  - Telefonbuch-Labels: „SBS Kunden", „SBS Heineken", „SBS Event"
  - Matching über normalisierte Telefonnummer
  - Ergebnisse zur Bestätigung anzeigen bevor Änderungen übernommen werden
  - Basis: bestehende `PhoneContactService` + `flutter_contacts`

### Daten-Migration

- [ ] **Excel-Daten vorbereiten**
  - Aktuelle Excel-Datei sichern
  - Letzte Änderungen eintragen
  - Bereit für Import

### Termin-Erinnerungen — Folge-Tests
- [ ] **Web-Test**: Termin mit Erinnerung (~2 Min Zukunft, „Pünktlich") → Browser-Notification + In-App-Hinweis prüfen
- [ ] **Android-Test** beim nächsten APK-Build: lokale Benachrichtigung feuert (auch bei geschlossener App); Berechtigungen (Benachrichtigung, exakter Alarm) prüfen

### Temporäres aufräumen

- [ ] **Rechnungs-Nachversand-Screen entfernen** (wenn Backlog ab 18.02.2026 abgearbeitet)
  - Datei `rechnungen_nachversand_screen.dart` löschen
  - Route in `router.dart` entfernen
  - Tile in `buchhaltung_dashboard_screen.dart` entfernen
- [ ] **Restliche Mail-Bereiche scharfstellen**: `bestellungScharf` + `mahnwesenScharf` (in `mail_config.dart`) — aktuell noch Test-Empfänger

---

## 🔵 BUCHHALTUNG SCHARFSTELLEN (01.07.2026)

**Detailplan**: `.claude/plans/snuggly-frolicking-pine.md`
**Strategie**: Sauberer Start — Test-Buchungen loeschen, Eroeffnungsbilanz erfassen

### Features entwickeln (Mai/Juni)

- [ ] **A1: Eroeffnungsbilanz-Screen** (KRITISCH)
  - Anfangssalden aller Bilanzkonten (Klasse 1+2) per 01.07. erfassen
  - Gegenkonto 9100 "Eroeffnungsbilanz" anlegen
  - Soll/Haben-Buchungen automatisch erstellen

- [x] **A2: Heineken-Rechnung → automatische Buchung** (KRITISCH) ✅ 29.05.2026
  - Status 'freigegeben' → HeinekenBuchungService.createFromRechnung (Debitoren/Ertrag + MwSt)
  - Status-Workflow: offen → gesendet → freigegeben → bezahlt

- [x] **A3: Zahlungseingang → automatische Buchung** (KRITISCH) ✅ 29.05.2026
  - Status 'bezahlt' → HeinekenBuchungService.createZahlungseingang (Soll Bank / Haben Debitoren)

- [ ] **A4: Wiederkehrende Buchungen** (WICHTIG)
  - Monatliche Standard-Buchungen mit 1 Klick (Lohn, AHV, Miete, etc.)
  - Konfigurierbare Liste, Duplikat-Check

- [ ] **A5: Monatsabschluss-Checkliste** (NICE-TO-HAVE)
  - Automatisch berechnete Checkliste pro Monat
  - Alle Services gebucht? Heineken-Rechnung? Spesen? Bank-Import?

- [ ] **A6: Kontenplan pruefen & ergaenzen** (KRITISCH)
  - Konto 9100 (Eroeffnungsbilanz) hinzufuegen
  - Pruefen ob alle Konten fuer Vollbetrieb vorhanden (Loehne, Sozialversicherungen, etc.)
  - ✅ 4 Lohn-Konten hinzugefuegt: 5710 FAK, 5720 BVG AG, 5730 UVG AG, 5740 KTG AG
  - ✅ 1109 Delkredere + 3805 Debitorenverluste (Migration 089)
  - ✅ 9 fehlende Konten ergaenzt (Migration 091, Titel aus Excel-Kontenrahmen): 2208 Direkte Steuern (Rueckstellung), 2276 KAE-Kontokorrent, 2500 Coronakredit GKB, 5880 Sonstiger Personalaufwand, 6460 Entsorgungsaufwand, 6500 Bueromaterial, 6550 Gruendungskosten, 8510 Haertefallgelder, 8900 Direkte Steuern. Dublette 8500 deaktiviert (0 Buchungen).
  - ✅ 0b-Check: alle Klasse-1/2-Konten mappen in eine Bilanz-Gruppe (Final-Review bestaetigt). Kategorie-Feinnormalisierung auf Excel-Untergruppen optional/spaeter.

## 📊 Phase 0b Auswertungen — FERTIG (13.06.2026, gemergt)

Bilanz-Screen (neu, /buchhaltung/bilanz), Erfolgsrechnung auf KMU-Stufengliederung umgestellt, MWST-Vorschau-Bugfix (Umsatz 3400 statt 3000 → war immer 0). Reine Services BilanzService/ErfolgsrechnungService (TDD), Gliederung = Excel-Sheets. Plan: docs/superpowers/plans/2026-06-13-phase0b-auswertungen.md. 43 Tests gruen.

- [x] **MwSt-Vorschau Vorsteuer-Bug** (`mwstQuartalDetailProvider`) — behoben in Phase 2c (Task 4): Provider rechnet jetzt über `SaldoExpansion` (Umsatzsteuer = −Saldo 2200, Vorsteuer = Saldo 1170+1171), erfasst zugleich Abschreibungs-Rückholungen.
- [ ] **Phase 0c:** Offene-Posten-Sicht (Debitoren 1100 / Kreditoren 2000) — eigener Plan, dann Phase 1 (Excel-Import 2019–2025 + camt-Abgleich).
- [x] **Phase 1 Teil 1** (MWST-korrekte Saldo-Expansion) — gemergt.
- [x] **Phase 1 Teil 2** (Excel-Import 14'552 Zeilen 2019–Nov 2025) — gemergt; Treue-Gate alle Jahre 0 Diff. Skripte: Datenbank/import/.
- [x] **Phase 2a** (Audit-Screen + mechanische Korrekturen) — gemergt: Audit-Screen `/buchhaltung/audit` (4 Kategorien), 8090→8900 (6 Zeilen, rückdatiert), 2500-Restsaldo→0. Migration 093.
- [x] **Phase 2b** (Jahresabschluss-Reconciliation, Modell 2) — gemergt: BilanzService rechnet kumuliertes Ergebnis → EK-Split (Gewinnvortrag + Jahresergebnis), Bilanz geht auf (Differenz 0 an allen Jahresenden); Abschlussbuchungen 2970/2980/9000/9100 storniert (Migration 094). ER unverändert.
- [x] **Phase 2c** (Abschreibungs-Werkzeug) — gemergt: `AbschreibungService` (korrekte 2-Buchungs-Logik 3805 netto + 2200 MWST-Rückholung / 1100, rückdatiert), Mahnwesen-Abschreibung gefixt (GF-1.9 behoben), MWST-Vorschau über SaldoExpansion (erfasst Rückholung + **Vorsteuer-Bug behoben**), Debitoren-Hub `/buchhaltung/debitoren` (Sammel-Abschreibung + Delkredere 5%). Daniel entscheidet selbst, jederzeit. 63 Tests grün.
- [ ] ~~Phase 2c mit Treuhänder~~ — Daniel arbeitet ohne Treuhänder (Memory), entscheidet selbst über Abschreibungs-Beträge im Debitoren-Hub. Analyse (13.06.2026): Offen-Bestand wächst ~15–22k/Jahr; alte Jahrgänge **2019–2022 ≈ 50k = Abschreibungs-Kandidaten** (kaum eintreibbar), 2024–25 eher teilweise eintreibbar. **Treuhänder-Fragen:** (a) Wieviel der alten ~50k definitiv uneinbringlich abschreiben (3805/1100 netto + 2200 MWST-Rückholung) vs. Delkredere 5%? (b) Welche konkreten Kunden? (c) Verlust → Verlustvortrag. Negative Salden 2202 (MWST-Abrechnung)/2273 (KTG)/8900 (Steuern) sind Verrechnungs-/Timing-Konten, KEINE Abschreibung — nur bestätigen.
- [ ] **Kritische Gesamtprüfung (13.06.2026, Report: docs/buchhaltung-kritische-gesamtpruefung-2026-06-13.md):**
  - [ ] **B1 (mit Daniel):** Lohnaufwand 5000 liegt durchgängig ~1–2k/Jahr ÜBER dem Lohnausweis-Brutto — klären (AG-Beiträge/Spesen in 5000? oder überbucht?). Relevant für AHV-/Steuerbasis.
  - [ ] **B3 (mit Daniel):** MWST-Zahllast 2023 App 8'014 vs. deklariert ≈6'635 (+1'379) — Quartals-Timing/Buchung prüfen (andere Jahre decken sich exakt).
  - ✅ Bestätigt: Sozialvers = nur AG-Anteil (BVG-Doppelzähl entkräftet); MWST gesamt plausibel; Franchise konsistent; Corona-Hilfen korrekt; Bilanz geht auf.
- [ ] **Optional Excel-Gegencheck:** Daniel setzt Excel-Bilanz auf 31.12.2024, rechnet neu + speichert → bit-genauer externer Abgleich Kasse/Debitoren/Bank (Excel-Sheets sind sonst gecachte Werte, unzuverlässig).
- [ ] **Phase-1-Vorbereitung (aus 0b-Final-Review):** Jahres-Abschlussbuchungen (Gewinnvortrag→2850/2970) beim Excel-Import zwingend mitnehmen, sonst Bilanz-Differenz. betragBrutto=Bruttomethode (passt). Bei sehr vielen Buchungen ggf. jahresgefilterte DB-Query statt getAll().

### Umstellung (25.-30. Juni 2026)

- [ ] **B1: Test-Buchungen loeschen** (nur buchungen + buchungs_belege, NICHT Servicedaten!)
- [ ] **B2: Eroeffnungsbilanz erfassen** (Daniel: Bank-Saldo, Kasse, Debitoren, MwSt, Eigenkapital etc.)
- [ ] **B3: Kontroll-Check** (Aktiven = Passiven, Saldi korrekt, Erfolgsrechnung = 0)

---

## 🟢 NACH MVP-LAUNCH

### Erweiterungen

- [ ] **Andere Franchise-Partner einladen**
  - Kontakte sammeln
  - Interesse abklären
  - Onboarding planen

- [ ] **Zusätzliche Regionen definieren**
  - Regionen der anderen Partner erfassen
  - KML-Dateien erstellen

### Schulung

- [ ] **Andere Partner schulen**
  - Training-Sessions organisieren
  - Dokumentation teilen
  - Support anbieten

---

## 📝 NOTIZEN

### GIS / Regionen-Polygone

**Warum Polygone?**
- Präzise Abgrenzung der Regionen
- "Liegt Betrieb X in meiner Region?" → Automatische Prüfung
- Bessere Visualisierung auf Karte

**Workflow:**
1. QGIS oder Google Earth Pro öffnen
2. Regionen-Grenzen nachzeichnen
3. Als KML exportieren
4. In App importieren

**Tools:**
- QGIS (Open Source)
- Google Earth Pro (kostenlos)
- Google My Maps (Online)

---

## ✅ ERLEDIGT

- [x] Post-Rechnungen: beim Abschluss Mail mit Rechnung+Protokoll an Daniel (zum Ausdrucken) + versendet_am = Abschlusstag; 3 heutige nachgemailt (02.06.2026)
- [x] Nachversand: Rechnungs-PDF live neu generieren mit aktuellem Fälligkeitsdatum (Versand+30); Rechnungen Jatzmeder + Milez auf unversendet (neue Adresse) (02.06.2026)
- [x] Tourenplanung: Fälligkeitsstufen bald fällig 4W / fällig 5W / überfällig 6W (relativ zum Rhythmus) (02.06.2026)
- [x] Kalender: Saison-/Ferien-Vorschläge synchronisieren (veraltete entfernen) + keine Eröffnungsreinigung nach Endreinigung; 39 veraltete Vorschläge bereinigt (02.06.2026)
- [x] Termin-Erinnerungen (Popup/Alarm): pro Termin aktivierbar + Vorlaufzeit; Android lokale Benachrichtigung, Web Browser-Notification + In-App, kein Push-Server (Migration 086, v0.10.106) (01.06.2026)
- [x] Heineken WE/AG-Nummern für 155 Betriebe aus DBO-Kundenliste ergänzt (Name+Ort-Matching, eindeutige Treffer) (01.06.2026)
- [x] Mail-Versand Reinigung + Montage/HeiGenie scharfgestellt (echte Kunden- bzw. RSL-Empfänger) (30.05.2026)
- [x] Nachversand-Screen: Testmodus-Respekt, Reinigungsprotokoll-Anhang, versendet-Markierung aus DB, Piaggio Dosch ausgeblendet (30.05.2026)
- [x] Mail-Adressen-Bereinigung: Zero-Width-Zeichen entfernen (MailConfig.bereinige + DB-Fix Padelta) + IDN-Punycode in Edge Function v7 (teehütte-klosters.ch) (30.05.2026)
- [x] versendet_am nur bei scharfem Versand (MailConfig.istScharf); DB-Korrektur Mountain Plaza + Padelta (30.05.2026)
- [x] Heineken-Monatsrechnung: Status-Workflow (offen → gesendet → freigegeben → bezahlt) + automatische Buchungen (29.05.2026)
- [x] Buchhaltung: Rechnungs-Nachversand-Screen (PDF on-demand neu signieren, betriebe.email-Fallback, 5-Rappen-Rundung) (29.05.2026)
- [x] Projekt-Review Opus 4.8: Reinigung-/Anfahrtspauschale-Bugfix, Kontakt-Isar-Integration (Native-Build wieder lauffähig), Lint-Cleanup (0 Errors) (29.05.2026)
- [x] Geschäftsabläufe dokumentiert (alle 9 Abschnitte)
- [x] Excel-Daten analysiert
- [x] Regionen-Liste erstellt (11 Regionen)
- [x] Tech-Stack-Entscheidung (Flutter + Supabase)
- [x] Datenmodell entworfen
- [x] Spesen-Scanner mit OCR (Claude Haiku) — Beleg fotografieren → automatische Buchung
- [x] camt.053 Bankimport — XML-Import, Duplikat-Erkennung, Auto-Betrieb-Matching
- [x] Vorsteuer-Buchungen (separate MwSt-Einträge auf Konto 1171)
- [x] TWINT/Karte Zahlungsweg-Erkennung (automatisch aus Beleg)
- [x] Beleg-Viewer (Belege direkt öffnen statt URL anzeigen)
- [x] Termine-Modul (Kalender, CRUD, Betrieb-Zuordnung)
- [x] Störungen UI komplett überarbeitet (Anlagentyp-Filter, Monatsgruppierung, Störungsnummer-Avatar)
- [x] Störungs-Formular: Anlagentyp-Auswahl mit Betrieb-Vorauswahl
- [x] Material-Dropdown öffnet nach oben (Mobile-Tastatur-Fix)
- [x] Uhrzeiten HH:mm statt HH:mm:ss überall
- [x] Betrieb: Saison ohne Datum anzeigen, Mein-Kunde-Logik bei Zapfsystemen
- [x] 5-Rappen-Rundung für alle CHF-Beträge
- [x] Reinigung-Buchung: Automatische Buchung bei Tresen/Mail/Post
- [x] Performance: Shared Betrieb-Provider (8 Screens refactored)
- [x] Performance: Home Screen Sub-ConsumerWidgets (weniger Rebuilds)
- [x] Home Screen: 2x5 Kachel-Grid optimiert für Pixel 9
- [x] Montage: HeiGenie Protokoll-Anzeige full width
- [x] Belegscanner: Rundungsdifferenzen ≤0.05 CHF automatisch mergen
- [x] Buchungsvorlage Parkgebühren Privat/Twint
- [x] Heineken Monatsrechnung: km-Abrechnungen ohne Bereich
- [x] Kontakt-Rolle «Vertreter» für Heineken
- [x] Kontakt-Sync Stufe 1: App-Kontakte aufs Handy pushen (Bulk-Push mit Labels)
- [x] Buchungsvorlagen: 37 Duplikate bereinigt
- [x] Beleg-Erfassung im Buchungsformular (PDF/Foto/Kamera Upload)
- [x] Lohnbuchhaltung komplett (flexible Auszahlungen, Versicherungs-Sätze konfigurierbar, Lohnausweis-PDF)
- [x] Betrieb: WE-Nummer + AG-Nummer Felder (Nummern-Kategorie in Form/Detail)
- [x] Betrieb: Region in Detail-Ansicht anzeigen
- [x] Heineken Monatsraster: PDF-Generierung (Querformat, gruppiert nach Regionen)
- [x] Heineken Monatsraster: Mail-Versand via Edge Function (send-raster-mail)
- [x] Heineken Monatsraster: Storage Bucket + Upload
- [x] Heineken Monatsraster: Jede Region auf eigener Seite
- [x] Heineken Monatsraster: PDF-Cache pro Jahr (Jahreswechsel behält PDF)
- [x] Heineken Monatsraster: Servicezeiten-Bindestrich fix (Sonderzeichen → normaler Bindestrich)
- [x] Heineken Monatsraster: Layout mobilfreundlich (Button + Wrap)
- [x] Betrieb: WE/AG-Nummern mit Zahlentastatur
- [x] Betrieb: Servicezeiten (Morgen/Nachmittag) hinzugefügt
- [x] Service Worker deaktiviert — Webapp sofort aktuell nach Refresh
- [x] 3 neue Regionen: Sempach, Küssnacht, Cham
- [x] Heineken Monatsraster: Cache-Buster auf PDF-Download-URL
- [x] Heineken Monatsraster: PDF Layout-Verbesserungen
- [x] Heineken Raster-Mail: Text mit aktuellem Datum
- [x] Zahlungsdifferenz-Handling bei Rechnungen + Pikett-Formular anpassen
- [x] Heineken Störungsformular: Pikett KW Sonderzeichen-Fix + Km-System
- [x] Pikett-Monatszuordnung nach Montag der KW
- [x] Eröffnung/Endreinigung: Störungsnummer + Art im Formular anzeigen
- [x] Heineken Monatsrechnung: Gratisreinigungen fehlen nach Neuerstellen — Fix
- [x] Heineken PDF: 5 Verbesserungen (Layout, Formatierung)
- [x] Pikett-Dienste Kachel: Gruppierung nach Montag der KW
- [x] DST-Bug in Kalenderwochen-Berechnung behoben (UTC statt lokale Zeit)
- [x] Heineken PDF: Seitenumbruch-Fix + verbrauchtes Material anzeigen
- [x] Material-Formular: Heineken-Beschreibung + Foto-Optimierung
- [x] Material-Foto: Supabase INSERT-Policy erstellt (Upload funktionierte nicht)
- [x] Material-Foto: Crop-Editor (crop_your_image, Rotation, fixCropRect, Dark Theme)
- [x] Material-Foto: Zwei-Datei Upload (HighRes + Preview 400px/60%)
- [x] Material-Foto: Lazy HighRes Loading (Preview auf Detailseite, HighRes on-demand)
- [x] Material-Foto: Lade-Spinner beim Foto-Ändern
- [x] Material-Liste: Subtitle DBO + Kategorie (ohne Einheit), einzeilig
- [x] Material: bestand_niedrig Fix (< statt <=) — Bestand = Mindest kein Warnsignal mehr
- [x] Material: Foto-Spinner beim Ändern bestehender Fotos
- [x] Material: "Auf Optimal auffüllen" Button im Bestand-Dialog
- [x] Material-Liste: Sortierung nach DBO-Nummer
- [x] Material: Stück pro Packung Feld (bei Einheit „Packung")
- [x] Materialbestellung komplett (PDF, Mail, Vormerken, Sektionen, Bestellhistorie, Edge Function)
- [x] Material-Suche: durchsucht auch Beschreibung, Notizen, Lieferant
- [x] Material +/- Buttons in Detailscreen (statt Liste), Bestellliste-Screen entfernt
- [x] Materialbestellung: Dropdown-Auswahl, Reihenfolge/Sortierung verbessert
- [x] Manual-PDF Upload/Anzeige für Material (nur relevante Kategorien)
- [x] Material-Auswahl speichert auch ohne Dropdown-Klick (Montage/Störung/Eigenauftrag)
- [x] Material-Bestand aktualisiert nach Service-Speicherung (Provider-Invalidierung)
- [x] Material-Filter zeigt nur Kategorien mit Einträgen

---

**Zuletzt aktualisiert**: 02.06.2026

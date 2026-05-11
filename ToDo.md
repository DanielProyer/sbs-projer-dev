# ToDo-Liste - Daniel Projer

**Stand**: 11.05.2026
**Für**: SBS Projer App Entwicklung

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

---

## 🔵 BUCHHALTUNG SCHARFSTELLEN (01.07.2026)

**Detailplan**: `.claude/plans/snuggly-frolicking-pine.md`
**Strategie**: Sauberer Start — Test-Buchungen loeschen, Eroeffnungsbilanz erfassen

### Features entwickeln (Mai/Juni)

- [ ] **A1: Eroeffnungsbilanz-Screen** (KRITISCH)
  - Anfangssalden aller Bilanzkonten (Klasse 1+2) per 01.07. erfassen
  - Gegenkonto 9100 "Eroeffnungsbilanz" anlegen
  - Soll/Haben-Buchungen automatisch erstellen

- [ ] **A2: Heineken-Rechnung → automatische Buchung** (KRITISCH)
  - Bei Erstellung Heineken-Monatsrechnung: Soll 1100 / Haben 3400 + MwSt
  - Aktuell werden KEINE Buchungen erstellt

- [ ] **A3: Zahlungseingang → automatische Buchung** (KRITISCH)
  - "Als bezahlt markieren" → Soll 1020 (Bank) / Haben 1100 (Debitoren)
  - Vorlage GF "2" existiert bereits

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
- [x] Material-Foto: Supabase INSERT-Policy erstellt (Upload funktionierte nicht)
- [x] Material-Foto: Crop-Editor (crop_your_image, Rotation, fixCropRect, Dark Theme)
- [x] Material-Foto: Zwei-Datei Upload (HighRes + Preview 400px/60%)
- [x] Material-Foto: Lazy HighRes Loading (Preview auf Detailseite, HighRes on-demand)
- [x] Material-Foto: Lade-Spinner beim Foto-Ändern
- [x] Material-Liste: Subtitle DBO + Kategorie (ohne Einheit), einzeilig

---

**Zuletzt aktualisiert**: 11.05.2026

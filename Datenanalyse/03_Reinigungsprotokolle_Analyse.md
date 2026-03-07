# Analyse: Reinigungsprotokolle (4 Beispiele)

**Analysedatum**: 12.02.2026
**Analysierte Protokolle**: 4
**Format**: Heineken-Standardformular (FOR 1220/Vers.04)

---

## Übersicht der analysierten Protokolle

| Dateiname | Kunden-Nr. | Datum | Absatzstelle | Ort | PLZ |
|-----------|------------|-------|--------------|-----|-----|
| 010_2026_01_29_0137_00009405 | 0137 | 29.01.2026 | Küche | Tar | 7015 |
| 011_2026_02_03_0147_00010700 | 0147 | 03.02.2026 | Ahorn (Soldan) | Kesser | 7265 |
| 011_2026_02_05_0158_00013295 | 0158 | 05.02.2026 | T. Ria | Loar | - |
| 010_2026_02_06_0210_00007460 | 0210 | 06.02.2026 | Rialuz | Thuss | - |

### Dateinamen-Muster
```
[Reinigungsnr]_[Jahr]_[Monat]_[Tag]_[Kunden-Nr]_[8-stellige ID]
Beispiel: 010_2026_01_29_0137_00009405

Aufschlüsselung:
- 010 = Reinigungsnummer/Laufnummer
- 2026_01_29 = Datum (29. Januar 2026)
- 0137 = Kunden-Nr.
- 00009405 = Eindeutige ID (möglicherweise aus Excel?)
```

---

## Protokollstruktur (Heineken-Standard FOR 1220/Vers.04)

### 1. Kopfbereich

```
┌─────────────────────────────────────────────────────────────┐
│  [HEINEKEN LOGO]         Swiss Beverage Services            │
│                                                              │
│  Reinigungsprotokoll Quittung/Faktura                       │
│                                                              │
│  SBS Projer GmbH                    O Heigenie O Traditional│
│  7013 Domat / Ems                                           │
│                           Kunden-Nr.:  [0137]               │
│  Telefon: 076 566 58 06                                     │
│                           Absatzstelle: [Küche]             │
│  CHE-413.083.919 MWST                                       │
│                           Name/Vorname: [Tori]              │
│  Ansatz MWST: 8.1%                                          │
│                           PLZ/Ortschaft: [7015]             │
└─────────────────────────────────────────────────────────────┘
```

**Felder:**
- **Kunden-Nr.**: 4-stellig (z.B. 0137)
- **Absatzstelle**: Name der Anlage/Standort im Betrieb
- **Name/Vorname**: Kontaktperson (handschriftlich)
- **PLZ/Ortschaft**: Ort (handschriftlich)
- **Checkboxen**: "O Heigenie O Traditional" (Auswahl des Produkttyps)

---

### 2. Arbeits-Checkliste (17 Punkte)

**Format**: Jede Zeile hat 3 Optionen: **Ja** | **Nein** | **Beanstandung**

| # | Ausgeführte Arbeiten | Beschreibung |
|---|---------------------|--------------|
| 1 | **Durchlaufkühler** | Durchlaufkühler überprüft |
| 2 | **Buffetanstisch** | Buffetanstisch kontrolliert |
| 3 | **Kühlkeller** | Kühlkeller überprüft |
| 4 | **Fasskühler** | Fasskühler kontrolliert |
| 5 | **Begleitkühlung kontrolliert** | Begleitkühlung geprüft |
| 6 | **Installation allg. kontrolliert** | Gesamtanlage visuell überprüft |
| 7 | **Allgel Anschlüsse kontrolliert** | Alle Anschlüsse kontrolliert |
| 8 | **Durchlaufkühler ausgeblasen** | Durchlaufkühler gereinigt/ausgeblasen |
| 9 | **Wasserstand kontrolliert** | Wasserstand geprüft |
| 10 | **Wasser im Durchlaufkühler gewechselt** | Wasserwechsel durchgeführt |
| 11 | **Leitung mit Wasser vorgespült** | Leitungen vorgespült |
| 12 | **Leitungsreinigung mit Reinigungsmittel** | Leitungen chemisch gereinigt |
| 13 | **Förderdruck kontrolliert** | Druck überprüft |
| 14 | **Zapfhahn zerlegt und gereinigt** | Zapfhahn demontiert und gesäubert |
| 15 | **Zapfkopf zerlegt, gereinigt** | Zapfkopf demontiert und gesäubert |
| 16 | **Servicekarte ausgefüllt** | Dokumentation vervollständigt |
| 17 | *(Leere Zeile für zusätzliche Bemerkungen)* | - |

**Typisches Muster (aus den 4 Protokollen):**
- Fast alle Punkte werden mit **Ja** (✓) markiert
- Standard-Service umfasst alle 16 Punkte
- **Beanstandung**-Spalte bleibt meist leer (keine Probleme)

**Erkenntnisse:**
- Sehr detaillierte, standardisierte Checkliste
- Qualitätssicherung durch Heineken-Vorgaben
- Dokumentation jedes Arbeitsschritts
- Beanstandungen werden separat erfasst (für Nachverfolgung)

---

### 3. Material- und Leistungsabrechnung

**Artikelliste (Heineken-Standard):**

| Art. Nr. | Artikelbezeichnung | Zweck | Menge | Preis |
|----------|-------------------|-------|-------|-------|
| **38457** | **Reinigung Bier** | Hauptleistung (Service) | 1 | 69 CHF (Standard) |
| **28001** | **Grundtarif Reinigung Orion Bier** | Basispreis Orion | - | - |
| **6000** | **Service Offenausschank Heigenie** | Heigenie-Pauschale | - | Gem. Leihvertrag |
| **28001** | **Grundtarif Reinigung fremd** | Fremdprodukte (Nicht-Heineken) | - | - |
| **28001** | **Zusätzlicher Hähnen Orion** | Extra Hahn Orion | - | - |
| **28001** | **Zusätzlicher Hähnen fremd** | Extra Hahn Fremdprodukt | - | - |
| **28001** | **Grundtarif Wein** | Weinanlage | - | - |
| **28001** | **Zusätzlicher Hahn Wein** | Extra Hahn Wein | - | - |
| **28001** | **Zusätzlicher Hahn zweite Anlage anderer Standort** | Weitere Anlage | - | - |
| **28001** | **Weitere zusätzliche Leitungen** | Zusatzleitungen | - | - |

**Preislogik (erkennbar aus Protokollen):**
```
Grundpreis:     69 CHF (1 Hahn, Standard-Service)
Zusatzhahn:     +24-48 CHF (je nach Typ)
Bergkunde:      +180 CHF (Anfahrtspauschale, nicht im Protokoll)
MWST:           8.1% (automatisch)
```

**Total-Zeile:**
```
Total (inkl. 8.1% Mwst.): [Handschriftlich eingetragen]
```

**Erkenntnisse:**
- Alle Artikelnummern sind vordefiniert (Heineken-System)
- Art. Nr. 38457 und 28001 sind die Hauptpositionen
- Menge und Preis werden **handschriftlich** eingetragen
- Total wird am Ende berechnet und eingetragen

---

### 4. Zahlungsinformationen

**Zahlungsoptionen** (Checkboxen):

```
☐ Auf Rechnung: O
  Zahlbar innert 30 Tagen netto
  Datum: ____________________

☐ Auf Barzahlung: O
  Betrag dankend erhalten
  Datum: ____________________
```

**Aus den 4 Protokollen:**
- **Protokoll 1**: ☑ Auf Barzahlung, ☑ Betrag dankend erhalten
- **Protokoll 2**: ☑ Auf Rechnung, Zahlbar innert 30 Tagen netto, Auf Barzahlung: O
- **Protokoll 3**: ☑ Auf Rechnung, Zahlbar innert 30 Tagen netto, Auf Barzahlung: O
- **Protokoll 4**: Auf Rechnung: O, Zahlbar innert 30 Tagen netto, ☑ Auf Barzahlung

**Verteilung:**
- Barzahlung: 2 (50%)
- Auf Rechnung: 2 (50%)

**Erkenntnisse:**
- Flexible Zahlungsoptionen vor Ort
- Barzahlung wird sofort quittiert
- Rechnungen mit 30 Tagen Zahlungsziel
- Zahlungsart wird direkt beim Service festgelegt

---

### 5. Unterschriften

**Zwei Unterschriftenfelder:**

```
Unterschrift Kunde: _________________________________

Unterschrift Servicemonteur: _________________________________
```

**Zweck:**
- **Kunde**: Bestätigt die Durchführung und akzeptiert die Abrechnung
- **Servicemonteur**: Bestätigt die ordnungsgemäße Ausführung

**Aus den Protokollen:**
- Alle 4 Protokolle haben **beide Unterschriften**
- Kunde unterschreibt in der Regel den Vornamen oder Kürzel
- Servicemonteur (Daniel Projer) unterschreibt sein Kürzel

**Rechtliche Bedeutung:**
- Vertragliche Bestätigung der Leistungserbringung
- Grundlage für Rechnungsstellung
- Nachweis bei Reklamationen

---

### 6. Footer

```
FOR 1220/Vers.04        1/1        30.10.2012/Ch. Nüssl
```

**Bedeutung:**
- **FOR 1220/Vers.04**: Formularnummer und Version
- **1/1**: Seitenzahl (einseitig)
- **30.10.2012/Ch. Nüssl**: Erstellungsdatum und Autor (Heineken)

---

## Workflow: Von Protokoll bis Rechnung

### 1. Vor-Ort-Service
```
1. Service durchführen
2. Checkliste durchgehen (17 Punkte abarbeiten)
3. Material verbrauchen (Reinigungsmittel, etc.)
4. Protokoll handschriftlich ausfüllen:
   - Kunden-Nr., Absatzstelle, Name/Vorname eintragen
   - Alle Checkboxen markieren (Ja/Nein/Beanstandung)
   - Artikel und Preise eintragen
   - Total berechnen (inkl. MWST 8.1%)
5. Zahlungsart festlegen (Bar oder Rechnung)
6. Unterschriften einholen (Kunde + Servicemonteur)
```

### 2. Nach dem Service
```
1. Durchschlag-Exemplar dem Kunden geben
2. Original-Exemplar mitnehmen
3. Protokoll einscannen (aktuell manuell)
4. Daten ins Excel-Blatt "Reinigung" eintragen:
   - ID Reinigung
   - ID Betrieb (aus Kunden-Nr.)
   - Datum
   - Betrieb, Ort, Adresse
   - Hähne 1-4 (Anzahl und Total)
   - Bergkunde (falls zutreffend)
   - Total Service
   - Bezahlt (falls Barzahlung)
5. Gescanntes Protokoll ablegen (für Archivierung)
```

### 3. Rechnungsstellung (falls nicht Bar bezahlt)
```
1. Monatlich oder direkt nach Service
2. Rechnung erstellen basierend auf Protokoll
3. Rechnung versenden (Post oder Email)
4. Zahlungseingang überwachen (30 Tage)
5. Bei Nicht-Zahlung: Mahnung (aktuell manuell)
```

---

## Schmerzpunkte und Verbesserungspotenziale

### Aktuelle Probleme

1. **Doppelte Datenpflege** ⏰ ~10-15 min pro Service
   - Protokoll wird handschriftlich ausgefüllt
   - Danach manuell ins Excel übertragen
   - Fehleranfällig (Tippfehler, vergessene Einträge)

2. **Scannen und Archivierung** ⏰ ~5 min pro Service
   - Protokolle müssen einzeln eingescannt werden
   - Dateiverwaltung manuell
   - Suche nach alten Protokollen zeitaufwändig

3. **Keine Vor-Ort-Validierung**
   - Preise werden handschriftlich eingetragen
   - Rechenfehler bei Total-Berechnung möglich
   - Keine automatische MWST-Berechnung

4. **Keine Echtzeit-Übersicht**
   - Tageseinnahmen erst nach Excel-Eintrag sichtbar
   - Offene Rechnungen nicht sofort ersichtlich
   - Keine Statistiken während der Tour

5. **Papier-basiert**
   - Durchschläge können verblassen
   - Papier kann verloren gehen
   - Unleserliche Handschrift

**Geschätzte Zeitverschwendung:**
```
15 min Doppelpflege + 5 min Scannen = 20 min pro Service
× 4 Services pro Tag = 80 min/Tag
× 20 Arbeitstage/Monat = 1.600 min = 26 Stunden/Monat!
```

---

## App-Lösung: Digitales Reinigungsprotokoll

### Funktionen der App

#### 1. Service-Erfassung (Mobile App)

**Vor-Ort auf dem Smartphone:**

```
┌─────────────────────────────────────────────┐
│  📱 Service-Protokoll - Betrieb: Hotel Zur  │
│     Krone, Arosa (0137)                     │
├─────────────────────────────────────────────┤
│                                             │
│  Datum: 29.01.2026  Uhrzeit: 10:15         │
│  Absatzstelle: Küche                        │
│  Kontakt: Herr Meier                        │
│                                             │
│  ☐ Heigenie  ☑ Traditional                  │
│                                             │
│  ──────────────────────────────────────────│
│  CHECKLISTE (17 Punkte)                     │
│  ──────────────────────────────────────────│
│                                             │
│  ☑ Durchlaufkühler                          │
│  ☑ Buffetanstisch                           │
│  ☑ Kühlkeller                               │
│  ☑ Fasskühler                               │
│  ☑ Begleitkühlung kontrolliert              │
│  ... (alle 17 Punkte mit ☑/☐/⚠️)            │
│                                             │
│  ──────────────────────────────────────────│
│  ABRECHNUNG                                 │
│  ──────────────────────────────────────────│
│                                             │
│  Grundpreis (1 Hahn):           69.00 CHF   │
│  Zusatzhahn Orion (1):          24.00 CHF   │
│                                             │
│  Zwischensumme:                 93.00 CHF   │
│  MWST (8.1%):                    7.53 CHF   │
│  ──────────────────────────────────────────│
│  TOTAL:                        100.53 CHF   │
│                                             │
│  Zahlungsart:  ⚪ Rechnung  ⚫ Bar           │
│                                             │
│  ──────────────────────────────────────────│
│  UNTERSCHRIFTEN                             │
│  ──────────────────────────────────────────│
│                                             │
│  Kunde: [____Unterschrift-Pad____]          │
│                                             │
│  Servicemonteur: [Automatisch: D. Projer]   │
│                                             │
│  [PDF Erstellen & Versenden]                │
│  [Als Entwurf Speichern]                    │
│                                             │
└─────────────────────────────────────────────┘
```

**Features:**
- ✅ Alle Felder vorausgefüllt aus Stammdaten (Kunde, Anlage)
- ✅ Checkliste mit Swipe (✓/✗/⚠️)
- ✅ Automatische Preisberechnung basierend auf Hahn-Anzahl
- ✅ MWST automatisch berechnet (8.1%)
- ✅ Digitale Unterschrift (Touch-Screen)
- ✅ Offline-fähig (bei schlechtem Empfang auf Baustellen)
- ✅ GPS-Koordinaten automatisch gespeichert (Nachweis)
- ✅ Foto-Upload möglich (Beanstandungen dokumentieren)

#### 2. PDF-Generierung (automatisch)

**Sofort nach Abschluss:**
- PDF wird automatisch erstellt (exakt wie Heineken-Vorlage)
- Per Email an Kunde versenden (optional)
- Im System gespeichert (keine manuelle Ablage)
- Filename: `Reinigungsprotokoll - [ID]_[Datum]_[Kunden-Nr]_[Protokoll-ID].pdf`

#### 3. Synchronisation (automatisch)

**Nach jedem Service (oder Ende der Tour):**
- Daten werden automatisch ins System übertragen
- Excel-Eintrag entfällt komplett (App = Single Source of Truth)
- Rechnung wird automatisch erstellt (falls "Auf Rechnung")
- Tageseinnahmen in Echtzeit sichtbar

#### 4. Dashboard (Desktop/Mobile)

**Übersicht:**
- Heutige Services: 4 (2 bar bezahlt, 2 auf Rechnung)
- Einnahmen heute: 412.00 CHF
- Offene Rechnungen: 12 (Total: 1'234.00 CHF)
- Nächste Mahnungen: 3 (überfällig seit >30 Tagen)

---

## Datenmodell-Erweiterungen

### Neue Entität: Service_Protokoll

```sql
Service_Protokoll {
  ID: INT (Primary Key)
  Reinigung_ID: INT (Foreign Key zu Reinigung-Tabelle)
  Betrieb_ID: INT (Foreign Key)
  Anlage_ID: INT (Foreign Key)
  Datum: DATE
  Uhrzeit: TIME
  Absatzstelle: VARCHAR(100)
  Kontakt_Name: VARCHAR(100)

  -- Produkttyp
  Heigenie: BOOLEAN
  Traditional: BOOLEAN

  -- Checkliste (17 Punkte, jeweils: 0=Nein, 1=Ja, 2=Beanstandung)
  Check_Durchlaufkuehler: INT
  Check_Buffetanstisch: INT
  Check_Kuehlkeller: INT
  Check_Fasskuehler: INT
  Check_Begleitkuehlung: INT
  Check_Installation: INT
  Check_Anschluesse: INT
  Check_Ausgeblasen: INT
  Check_Wasserstand: INT
  Check_Wasserwechsel: INT
  Check_Vorgespuelt: INT
  Check_Leitungsreinigung: INT
  Check_Foerderdruck: INT
  Check_Zapfhahn: INT
  Check_Zapfkopf: INT
  Check_Servicekarte: INT
  Check_Sonstiges: INT

  -- Artikel/Material
  Artikel_38457_Menge: INT (Reinigung Bier)
  Artikel_38457_Preis: DECIMAL(10,2)
  Artikel_28001_Orion_Menge: INT
  Artikel_28001_Orion_Preis: DECIMAL(10,2)
  Artikel_28001_Fremd_Menge: INT
  Artikel_28001_Fremd_Preis: DECIMAL(10,2)
  ... (weitere Artikel)

  -- Abrechnung
  Zwischensumme: DECIMAL(10,2)
  MWST_Betrag: DECIMAL(10,2)
  Total_Inkl_MWST: DECIMAL(10,2)

  -- Zahlung
  Zahlungsart: ENUM('Rechnung', 'Bar')
  Zahlungsdatum: DATE
  Bezahlt: BOOLEAN

  -- Unterschriften (als Base64-Bilder)
  Unterschrift_Kunde: TEXT
  Unterschrift_Servicemonteur: TEXT

  -- PDF
  PDF_Pfad: VARCHAR(500)
  PDF_Erstellt_Am: DATETIME

  -- Metadaten
  Erstellt_Am: DATETIME
  Erstellt_Von: INT (User-ID)
  GPS_Latitude: DECIMAL(10,8)
  GPS_Longitude: DECIMAL(11,8)
  Offline_Modus: BOOLEAN
}
```

### Integration mit bestehenden Tabellen

```
Betrieb (451)
  └─> Anlage (487)
       └─> Reinigung (4.144)
            └─> Service_Protokoll (4.144) [NEU]
```

**Beziehung:**
- Jede Reinigung hat genau 1 Service-Protokoll
- Service-Protokoll speichert alle Details aus dem Papier-Protokoll
- PDF wird automatisch generiert und verlinkt

---

## Zeitersparnis-Berechnung

### Aktueller Workflow (manuell)

| Schritt | Zeit | Pro Tag (4 Services) | Pro Monat (20 Tage) |
|---------|------|----------------------|---------------------|
| Handschriftlich ausfüllen | 5 min | 20 min | 6h 40min |
| Einscannen | 5 min | 20 min | 6h 40min |
| Excel-Eintrag | 10 min | 40 min | 13h 20min |
| Rechnung erstellen (50%) | 5 min | 10 min | 3h 20min |
| **TOTAL** | **25 min** | **90 min** | **30 Stunden** |

### Mit App (automatisiert)

| Schritt | Zeit | Pro Tag (4 Services) | Pro Monat (20 Tage) |
|---------|------|----------------------|---------------------|
| App ausfüllen (schneller als Papier) | 3 min | 12 min | 4h |
| Unterschrift (digital) | 1 min | 4 min | 1h 20min |
| PDF automatisch erstellt | 0 min | 0 min | 0h |
| Synchronisation automatisch | 0 min | 0 min | 0h |
| **TOTAL** | **4 min** | **16 min** | **5h 20min** |

### Zeitersparnis

```
30h - 5h 20min = 24h 40min pro Monat
= 296 Stunden pro Jahr!

Bei 4.144 Services pro Jahr:
21 Minuten gespart pro Service
× 4.144 Services = 87.024 Minuten
= 1.450 Stunden = 181 Arbeitstage (à 8h)!
```

**Das ist mehr als ein halbes Jahr Vollzeitarbeit!**

---

## Zusätzliche Vorteile

### 1. Fehlerreduktion
- ✅ Keine Rechenfehler mehr (automatische Berechnung)
- ✅ Keine vergessenen Einträge (Pflichtfelder)
- ✅ Keine unleserliche Handschrift
- ✅ Keine verlorenen Protokolle

### 2. Qualitätssicherung
- ✅ Checkliste kann nicht übersprungen werden
- ✅ Beanstandungen werden dokumentiert (Foto möglich)
- ✅ GPS-Nachweis (wann wo Service durchgeführt)
- ✅ Vollständige Historie pro Anlage

### 3. Kundenzufriedenheit
- ✅ PDF sofort per Email (kein Warten auf Rechnung)
- ✅ Professionelleres Erscheinungsbild (digital)
- ✅ Kunde kann Rechnung direkt zahlen (QR-Code)
- ✅ Transparente Leistungsdokumentation

### 4. Compliance
- ✅ DSGVO-konform (digitale Speicherung)
- ✅ Revisionssicher (Änderungen nachvollziehbar)
- ✅ 10-jährige Aufbewahrung automatisch
- ✅ Backup automatisch

---

## Must-Have Features für die App

### Mobile App (Android)

1. **Offline-Fähigkeit** (kritisch!)
   - Bergkunden haben oft kein Netz
   - Daten werden lokal gespeichert
   - Synchronisation sobald Netz verfügbar

2. **Digitale Unterschrift**
   - Touch-Screen Signature Pad
   - Kunde unterschreibt direkt auf Smartphone/Tablet

3. **Checkliste mit Swipe-Gesten**
   - Schnelles Durchgehen aller Punkte
   - ✓ = Wischen nach rechts
   - ✗ = Wischen nach links
   - ⚠️ = Langer Tap (für Beanstandung mit Kommentar)

4. **Foto-Upload**
   - Beanstandungen fotografieren
   - Vorher/Nachher-Bilder
   - Automatisch mit Protokoll verknüpft

5. **GPS-Tracking**
   - Automatische Standorterfassung
   - Nachweis der Serviceerbringung
   - Route des Tages nachvollziehbar

6. **Barcode/QR-Scanner**
   - Anlage-ID scannen (falls QR-Code an Anlage)
   - Artikel scannen (Material)

7. **Sprachnotizen**
   - Bemerkungen diktieren statt tippen
   - Automatische Transkription

### Desktop-App / Web-App

1. **Dashboard**
   - Tagesübersicht (Services, Einnahmen)
   - Offene Rechnungen
   - Überfällige Mahnungen

2. **PDF-Archiv**
   - Alle Protokolle durchsuchbar
   - Filter nach Kunde, Datum, Zahlungsart
   - Export möglich

3. **Reporting**
   - Monatliche Auswertungen
   - Vergleich Vorjahr
   - Einnahmen pro Kunde

4. **Mahnwesen**
   - Automatische Mahnung nach 30 Tagen
   - 1., 2., 3. Mahnstufe
   - Mahngebühren automatisch

---

## Technische Anforderungen

### Hardware
- **Smartphone**: Android (mind. Version 10)
- **Optional**: Tablet (10 Zoll) für bessere Unterschriften
- **Optional**: Mobiler Drucker (Bluetooth) für Vor-Ort-Ausdruck

### Software
- **Mobile App**: Flutter oder React Native (Cross-Platform)
- **Backend**: Supabase oder Firebase (Offline-Support!)
- **PDF-Generator**: PDFKit oder jsPDF
- **Unterschrift**: Signature Pad Library
- **GPS**: Native GPS-API

### Datenspeicherung
- **Lokal**: SQLite (für Offline-Modus)
- **Cloud**: PostgreSQL (Supabase) oder Firestore
- **Sync**: Automatisch bei Netzverbindung
- **Konfliktlösung**: Timestamp-basiert (neueste Version gewinnt)

---

## Implementierungsplan

### Phase 1: Basis-Funktionalität (MVP)
- ✅ Service-Erfassung (Checkliste, Abrechnung)
- ✅ Digitale Unterschrift
- ✅ PDF-Generierung
- ✅ Offline-Fähigkeit
- ✅ Synchronisation

### Phase 2: Erweiterte Features
- ✅ Foto-Upload
- ✅ GPS-Tracking
- ✅ Dashboard
- ✅ PDF-Archiv

### Phase 3: Automatisierung
- ✅ Automatische Rechnungsstellung
- ✅ Mahnwesen
- ✅ Reporting

### Phase 4: Optimierung
- ✅ Sprachnotizen
- ✅ Barcode-Scanner
- ✅ Routenoptimierung
- ✅ KI-gestützte Preisvorschläge

---

## Kosten-Nutzen-Analyse

### Kosten
- **Entwicklung**: (mit dir zusammen, ~200 CHF/Monat Budget)
- **Hosting**: Supabase Free Tier (0 CHF) → später ~25 CHF/Monat
- **Smartphone**: Bereits vorhanden
- **Optional Tablet**: ~300 CHF (einmalig)

### Nutzen
- **Zeitersparnis**: 296 Stunden/Jahr = ~30.000 CHF (bei 100 CHF/h Stundenlohn)
- **Fehlerreduktion**: ~5% weniger Reklamationen = ~2.000 CHF/Jahr
- **Mahnwesen**: Schnellerer Zahlungseingang = ~3.000 CHF/Jahr (besserer Cashflow)
- **Skalierung**: Andere Franchisen können App nutzen (12 weitere!)

**ROI: > 10.000% im ersten Jahr!**

---

## Nächste Schritte

1. ✅ Struktur verstanden - Reinigungsprotokoll ist klar
2. ⏭️ **Geschäftsabläufe dokumentieren** - Wie läuft ein typischer Servicetag ab?
3. ⏭️ **Datenmodell finalisieren** - Alle Entitäten und Beziehungen
4. ⏭️ **Wireframes/Mockups** - Wie soll die App aussehen?
5. ⏭️ **Tech-Stack-Entscheidung** - Flutter vs. React Native?

---

## Anhang: Heineken-Artikelnummern

### Quick Reference

| Art. Nr. | Bezeichnung | Typ | Notizen |
|----------|------------|-----|---------|
| **38457** | Reinigung Bier | Service | Hauptposition (69 CHF Standard) |
| **28001** | Grundtarif Reinigung Orion Bier | Tarif | Basispreis |
| **6000** | Service Offenausschank Heigenie | Pauschale | Gem. Leihvertrag |
| **28001** | Grundtarif Reinigung fremd | Tarif | Fremdprodukte |
| **28001** | Zusätzlicher Hähnen Orion | Zusatz | Pro Hahn |
| **28001** | Zusätzlicher Hähnen fremd | Zusatz | Pro Hahn |
| **28001** | Grundtarif Wein | Tarif | Weinanlage |
| **28001** | Zusätzlicher Hahn Wein | Zusatz | Pro Wein-Hahn |
| **28001** | Zusätzlicher Hahn zweite Anlage anderer Standort | Zusatz | Mehrere Anlagen |
| **28001** | Weitere zusätzliche Leitungen | Zusatz | Extra Leitungen |

**Hinweis**: Art. Nr. 28001 wird mehrfach verwendet für verschiedene Positionen (Heineken-interne Kategorisierung).

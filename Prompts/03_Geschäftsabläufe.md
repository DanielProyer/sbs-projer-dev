# Geschäftsabläufe - Daniel Projer (SBS Projer GmbH)

**Dokumentiert**: 12.02.2026
**Methode**: Interview mit Claude

---

## 📅 TYPISCHER SERVICE-TAG

### 1. TOURENPLANUNG (Abend vorher oder Wochenende)

**Zeitpunkt:**
- Meist am Abend vorher (z.B. Sonntag für Montag)
- Teilweise am Wochenende für die ganze kommende Woche

**Methode:**
1. **Referenz-Monat**: Nimmt die Tour von vor ~1 Monat als Ausgangspunkt
   - Grund: 4-Wochen-Service-Rhythmus bei den meisten Kunden
   - Beispiel: "Montag, 13.01. als Vorlage für Montag, 10.02."

2. **Region filtern**: Schaut welche Betriebe in dieser Region noch offen sind
   - "Offen" = nicht in Betriebsferien, Saisonbetriebe geöffnet

3. **Excel-basiert**: Planung erfolgt in Excel
   - Keine fixen Routen
   - Ähnliche Routen mit Anpassungen

**Dynamische Anpassungen:**
- ⚠️ Störungen (kurzfristig, höchste Priorität)
- 🏗️ Montageaufträge (von Heineken beauftragt)
- 🎿 Eröffnungen (Saisonstart, meist Dezember)
- 📅 Endreinigungen (Saisonende, meist April/Mai)

→ **Planung ist flexibel, wird oft angepasst!**

---

**ERKENNTNISSE FÜR APP:**
- ✅ App sollte "Tour von vor 1 Monat" als Vorschlag anzeigen
- ✅ Filter: "Nur offene Betriebe" (Saisonbetriebe, keine Ferien)
- ✅ Störungen müssen in Tagesplanung eingefügt werden können (Priorität)
- ✅ Route sollte visuell anzeigbar sein (Karte)
- ✅ Drag & Drop für Anpassungen

---

---

### DETAILS ZUR TOURENPLANUNG (Vertiefung)

#### a) Regionen
**Wie sind Regionen definiert?**
- Alle Kunden sind in Regionen aufgeteilt
- **Excel**: Sheet "Anlage", Spalte AT = Region
- Beispiele für Regionen: _(noch zu erfassen)_

#### b) Excel-Filterung
**Wie filterst du konkret?**
- **Excel**: Sheet "Anlage"
- **Spalte P**: "Letzte Reinigung" (Datum)
- **Filter**: Anlagen mit letzter Reinigung > 4 Wochen
- **Zusatzfilter**: Nur "Status = Aktiv" (nicht geschlossen)

#### c) Kunden pro Tag
**Wie viele Kunden schaffst du?**
- **Normal**: 8-10 Kunden pro Tag
- **Abhängig von**:
  - Störungen (ungeplant, höchste Priorität)
  - Montageaufträge (länger als Services)
  - Fahrzeiten zwischen Kunden (variabel, Bergkunden!)

#### d) Routenoptimierung
**Wie optimierst du die Reihenfolge?**
- **Im Kopf** (Ortskenntnis, Jahre Erfahrung)
- Keine Software-Unterstützung (Google Maps nur für Navigation, nicht Optimierung)

#### e) Status-Verwaltung
**"Geschlossen" = dauerhaft geschlossen**
- **Sheet "Betrieb"**, Spalte "Status"
  - Aktiv / Inaktiv / Potenziell / ???
- **Sheet "Anlage"**, Spalte "Status"
  - Aktiv / Inaktiv / Projekt / ???

---

### ⚠️ WICHTIG: Betrieb vs. Anlage

**Hierarchie:**
```
Betrieb (z.B. Hotel Zur Krone)
  ├─ Anlage 1 (Bar)
  ├─ Anlage 2 (Restaurant)
  └─ Anlage 3 (Terrasse)
```

**Unterscheidung:**
- **1 Betrieb** = 1 Kunde (Adresse, Kontakt, Rechnung)
- **Mehrere Anlagen** pro Betrieb möglich
- **Jede Anlage** hat eigenen Service-Rhythmus

**Anlagentypen:**
- Nicht alle Anlagentypen werden von Daniel geserviced
- Nur bestimmte Typen im Vertrag mit Heineken
- _(Details zu Anlagentypen folgen)_

---

**ERKENNTNISSE FÜR APP:**
- ✅ Datenmodell: Betrieb → Anlage (1:n Beziehung)
- ✅ Service-Planung auf Anlagen-Ebene, nicht Betrieb-Ebene
- ✅ Filter: Region (Spalte AT), Letzte Reinigung (Spalte P), Status (Aktiv)
- ✅ 8-10 Anlagen pro Tag = realistische Tagesplanung
- ✅ Routenoptimierung: Unterstützung anbieten (Google Maps API?)

---

---

### ANLAGENTYPEN (4 Typen bei Heineken)

#### Übersicht

| Typ | Service-Rhythmus | Von Daniel serviciert? | Abrechnung |
|-----|------------------|----------------------|------------|
| **Konventionell** | 4 Wochen | ✅ Ja | Normal (Grundtarif eigen/fremd) |
| **Orion (Großtank)** | 4 Wochen | ✅ Ja | Orion-Tarif (92 CHF) |
| **Heigenie** | 6 Monate | ⚠️ Meist Heineken-Monteur, manchmal Daniel | Wenn Daniel: Über Montage (80 CHF/h) |
| **David** | - | ❌ Nein, kein Service nötig | - |

#### Details

**Konventionelle Anlagen:**
- Standard-Zapfanlagen
- 4-Wochen-Service-Rhythmus
- Grundtarif: 69 CHF (eigen) oder 92 CHF (fremd)

**Orion (Großtank-Anlagen):**
- Spezielle Anlagen mit 500 oder 1'000 Liter Tanks
- 4-Wochen-Service-Rhythmus
- Grundtarif: 92 CHF

**Heigenie:**
- 6-Monate-Service-Rhythmus (nicht 4 Wochen!)
- Kunden haben Serviceverträge direkt mit Heineken
- Meist von Heineken-Monteur serviciert
- **Manchmal von Daniel**: Dann Abrechnung über **Montage** (Stundensatz 80 CHF/h)
- Grund: Spezialschulung erforderlich

**David:**
- Keine Services erforderlich
- Selbstwartend oder anderes System
- Nicht relevant für Daniel

#### Excel-Struktur

**Sheet "Anlage":**
- Enthält **nur** die für Daniel relevanten Anlagen
- Also: Konventionell, Orion, (manchmal Heigenie)
- **KEINE** David-Anlagen

**Sheet "Betrieb":**
- Enthält **alle** Betriebe und **alle** Anlagen
- **Spalte G**: Typbezeichnung (Konventionell / Orion / Heigenie / David)

**Wichtig:**
- Ein Betrieb kann **verschiedene Anlagentypen** haben!
- Beispiel: Hotel mit Orion-Anlage (Restaurant) + Konventionell (Bar)

---

### MEHRERE ANLAGEN PRO BETRIEB (Praktische Umsetzung)

#### Szenario: Hotel mit Bar und Restaurant (2 Anlagen)

**Standard-Vorgehen:**
- Meist **alle Anlagen nacheinander** am gleichen Tag
- Zeit: z.B. Restaurant 10:00-10:30, Bar 10:30-11:00
- **1 Rechnung** für beide Anlagen zusammen

**Flexibilität:**

**Fall 1: Anlage nicht in Betrieb**
- Restaurant geschlossen (Umbau), Bar geöffnet
- Nur Bar wird serviciert
- Restaurant später, wenn wieder in Betrieb

**Fall 2: Zeitgründe / Öffnungszeiten**
- Restaurant: Service 10:00 Uhr (vor Mittagsöffnung)
- Bar: Service 12:30 Uhr (öffnet erst 15:00 Uhr, Zugang früher)
- **Grund**: Bar noch nicht zugänglich um 10:00

**Fall 3: Zeitdruck**
- Viele Kunden an einem Tag
- Restaurant heute, Bar nächste Woche
- Selten, aber möglich

#### Abrechnung & Tracking

**Rechnung:**
- **1 Rechnung** pro Betrieb (egal wie viele Anlagen)
- Positionen auf Rechnung:
  - Anlage 1 (Restaurant): 69 CHF
  - Anlage 2 (Bar): 69 CHF
  - Total: 138 CHF (+ MWST)

**Excel-Tracking:**
- **Separate Einträge** pro Anlage im Sheet "Reinigung"
- Grund: Genau sehen, **wann welche Anlage** zuletzt serviciert wurde
- Wichtig für 4-Wochen-Rhythmus pro Anlage

**Beispiel Excel:**
```
Reinigung-Sheet:
  ID | Datum | Betrieb | Anlage | Preis
  1  | 10.01 | Hotel X | Restaurant | 69 CHF
  2  | 10.01 | Hotel X | Bar | 69 CHF

→ 2 Einträge, aber 1 Rechnung
```

---

**ERKENNTNISSE FÜR APP:**
- ✅ Datenmodell: Anlagentyp speichern (Konventionell/Orion/Heigenie/David)
- ✅ Filter: Nur relevante Typen für Daniel anzeigen
- ✅ Service-Rhythmus: 4 Wochen (Standard), 6 Monate (Heigenie)
- ✅ Rechnung: Auf Betriebs-Ebene, aber Service-Tracking auf Anlagen-Ebene
- ✅ Flexible Planung: Einzelne Anlagen eines Betriebs später servicieren möglich
- ✅ Heigenie-Service: Wenn Daniel macht → als Montage abrechnen (nicht normaler Service)

---

---

## 2. SERVICE-DURCHFÜHRUNG BEIM KUNDEN

### a) Ankunft beim Kunden

**Standard-Vorgehen:**
- Meist kurze Begrüssung des Kunden
- **Bei Hotels**: Anmeldung am Empfang
- **Bei Restaurants/Bars**: Direkter Zugang
- **Teilweise**: Schlüsselcodes für autonomen Zugang (keine Person vor Ort nötig)

### b) Service-Ablauf

**Vorgehensweise:**
- Feste Vorgehensweise etabliert
- Deckt sich **mehrheitlich mit den 17-Punkten** aus dem Heineken-Reinigungsprotokoll
- Routiniert, nach jahrelanger Erfahrung automatisiert

**Checkliste (orientiert an 17-Punkt-Protokoll):**
1. Sichtkontrolle der gesamten Anlage
2. Zapfhahn demontieren und reinigen
3. Leitungen spülen
4. Kühlsystem prüfen
5. Fassanschlüsse kontrollieren
6. CO2/Gas-System prüfen
7. ... _(vollständige Liste siehe Reinigungsprotokolle)_

### c) Zeitaufwand

**Durchschnittliche Service-Dauer:**

| Anlage | Dauer |
|--------|-------|
| **1 Hahn** | 25-30 Minuten |
| **2-3 Hähne** | ca. 45 Minuten |
| **4-5 Hähne** | ca. 1 Stunde |
| **Orion-Anlage** | +20 Minuten (zusätzlich) |

**Faktoren, die Zeit beeinflussen:**
- Anzahl Zapfhähne
- Verschmutzungsgrad
- Zugänglichkeit der Anlage
- Probleme/Störungen (siehe unten)

### d) Probleme während Service

**Häufigkeit:**
- Bei ca. **1 von 20 Services** wird ein Problem entdeckt
- Meist kleinere technische Defekte

**Vorgehen:**
- Problem wird **sofort behoben**
- Wird als **Eigenauftrag** erfasst (nicht in Rechnung gestellt)
- Grund: Kulanz, Kundenbindung, Teil des Service

**Wenn nicht sofort behebbar:**
- Wird als separater Störungsauftrag angelegt
- Kunde wird informiert
- Separater Termin oder Ersatzteile müssen bestellt werden

### e) Protokoll-Ausfüllung

**Während des Service:**
- Protokoll wird **zwischen den Arbeitschritten** ausgefüllt
- Nicht am Ende auf einmal, sondern laufend
- Hilft, nichts zu vergessen

**Am Ende:**
- Protokoll wird von **Daniel und Kunde/Mitarbeiter unterschrieben**
- Kunde erhält Kopie (physisch oder als Foto per WhatsApp)
- Original bleibt bei Daniel

**Aktueller Zeitaufwand:**
- Ca. **25 Minuten** pro Service nur für Papierkram
- Großes Optimierungspotenzial für App!

### f) Preis-Berechnung vor Ort

**Standard-Preise:**
- Daniel kennt **Standardpreise auswendig**
- Beispiele:
  - Konventionelle Anlage eigen: 69 CHF
  - Konventionelle Anlage fremd: 92 CHF
  - Orion-Anlage: 92 CHF
  - Bergkunde-Zuschlag: +100 CHF

**Zusatz-Berechnungen:**
- Für komplexere Berechnungen: **Smartphone als Taschenrechner**
- Beispiel: Mehrere Anlagen + Zusatzarbeiten + Bergkunde-Zuschlag

**Rechnung:**
- Wird **nicht vor Ort erstellt**
- Protokoll enthält nur Preis-Information
- Rechnung wird später im Büro erstellt (siehe "Ende des Tages")

---

**ERKENNTNISSE FÜR APP:**
- ✅ Digitales Protokoll: 17-Punkt-Checkliste als interaktive Checkboxen
- ✅ Zeitmessung: Automatische Erfassung von Start- und Endzeit
- ✅ Problem-Erfassung: Schnelle Möglichkeit, Eigenauftrag anzulegen
- ✅ Unterschrift-Funktion: Digital auf Smartphone/Tablet
- ✅ Preis-Kalkulator: Automatische Berechnung basierend auf Anlagentyp, Hähne, Bergkunde
- ✅ Offline-Fähigkeit: Muss ohne Internet funktionieren (Bergkunden!)
- ✅ Foto-Funktion: Probleme dokumentieren
- ✅ Zeitersparnis: Von 25 Min auf ~4 Min Papierkram → 21 Min gespart pro Service

---

---

## 3. FAHRT ZWISCHEN KUNDEN

### Navigation
**Standard:**
- Meist aufgrund eigener **Ortskenntnisse** (jahrelange Erfahrung)
- **Bei Neukunden**: Google Maps zur Navigation

**Fahrzeiten:**
- Werden **NICHT** notiert
- Keine systematische Erfassung

### Pausen / Mittagessen
- **Sehr selten** Pausen
- Mittagessen meist während Fahrt oder übersprungen
- Fokus: Möglichst viele Kunden pro Tag

---

**ERKENNTNISSE FÜR APP:**
- ✅ Navigation: Google Maps Integration für Neukunden
- ✅ Optional: Fahrzeiten automatisch tracken (Hintergrund-GPS)
- ✅ Routenoptimierung: Vorschlag optimaler Reihenfolge
- ✅ Pausenerinnerung: Optional, für gesetzliche Arbeitszeiten

---

---

## 4. ENDE DES TAGES / WOCHE

### Protokolle digitalisieren & Rechnungen

**Frequenz:**
- **Einmal pro Woche** (nicht täglich!)
- Grund: Hoher Zeitaufwand

**Ablauf:**
- Gesammelte Papier-Protokolle der Woche
- Eingabe in Excel (Sheet "Reinigung", "Störung", "Montage", etc.)
- Rechnungen erstellen (einzeln pro Betrieb)
- Rechnungen versenden

**Zeitaufwand:**
- Mehrere Stunden pro Woche
- **Größter Zeitfresser** (siehe Punkt 9)

### Materialnachbestellung

**Frequenz:**
- **Einmal pro Monat**
- Aus dem Kopf (was aufgebraucht wurde)

**Lagerung:**
- **Alles Material lagert im Auto**
- Immer griffbereit für Services und Störungen

**Problem:**
- Keine systematische Erfassung von Materialverbrauch
- Risiko: Material geht aus während Service

---

**ERKENNTNISSE FÜR APP:**
- ✅ **WICHTIG**: Materialverwaltung in App
  - Material-Bestand im Auto tracken
  - Bei Service: Material verbraucht → automatisch von Bestand abziehen
  - Warnung bei niedrigem Bestand
  - Bestellliste automatisch generieren
- ✅ Digitale Rechnungserstellung direkt in App
- ✅ Automatische Rechnungs-Aggregation pro Betrieb
- ✅ Zeitersparnis: Von mehreren Stunden pro Woche auf wenige Minuten

---

---

## 5. STÖRUNGEN (Kein typischer "Störungs-Tag")

### Wichtig: Keine fixen Störungs-Tage!
- Störungen werden **flexibel dazwischengeschoben**
- Oder **nach regulären Services** erledigt
- **Höchste Priorität**: Kunde ohne Bier = Umsatzausfall

### Störungsmeldung

**2 Wege:**

1. **Normal (ohne Pikett):**
   - Meldung von **regionalem Servicedienstleiter Heineken**
   - Heineken vergibt **Störungsnummer** (wichtig für Abrechnung!)

2. **Bei Pikett:**
   - Kunde ruft **direkt** an (Umleitung Piketttelefon)
   - Daniel bekommt ebenfalls Störungsnummer von Heineken

### Ablauf vor Ort

1. **Optional**: Zuerst telefonisch anmelden (damit jemand vor Ort ist)
2. Zum Kunden fahren
3. Störung beheben (mit Material aus Auto)
4. Protokoll ausfüllen
5. Material wird verwendet → muss später nachbestellt werden

### Abrechnung

- **NICHT** direkt an Kunden (außer bei Eigenaufträgen)
- Abrechnung über **Monatsrechnung an Heineken**
- Störungsnummer ist Pflicht für Abrechnung

---

**ERKENNTNISSE FÜR APP:**
- ✅ Störungsauftrag mit Störungsnummer erfassen
- ✅ Flexible Einfügung in Tagesplanung (Drag & Drop)
- ✅ Materialverbrauch bei Störung tracken
- ✅ Automatische Zuordnung zu Monatsrechnung Heineken

---

---

## 6. MONTAGEN

### Ablauf

**Auftragseingang:**
- Von **Heineken** (telefonisch oder per Mail)
- Werden **zwischendurch** erledigt (wie Störungen)
- Keine fixen Montage-Tage

**Durchführung:**
- Ähnlich wie Störungen: flexibel in Tagesplanung integrieren
- Meist länger als normale Services
- Spezialwerkzeug/Material erforderlich

**Abrechnung:**
- Über **Monatsrechnung an Heineken**
- Stundensatz: 80 CHF/h (siehe Preissystem)

---

**ERKENNTNISSE FÜR APP:**
- ✅ Montage-Aufträge aus E-Mail/Telefon erfassen
- ✅ Zeiterfassung (Start/Ende) für Stundenabrechnung
- ✅ Material/Werkzeug-Checkliste
- ✅ Automatische Zuordnung zu Monatsrechnung Heineken

---

---

## 7. PIKETT-DIENST

### Pikettplan

**Frequenz:**
- **Ein Wochenende pro Monat** (meist)
- Fixer Plan (voraussichtlich von Heineken vorgegeben)

**Pikett-Einsätze:**
- **In letzter Zeit sehr wenig**
- Etwa **jedes zweite Mal** ein Einsatz (50%)
- = Ca. alle 2 Monate ein Einsatz

**Ablauf bei Pikett-Einsatz:**
- Kunde ruft an (Umleitung Piketttelefon)
- Sofortiger Einsatz erforderlich
- Ablauf wie Störung (siehe Punkt 5)

**Abrechnung:**
- **160 CHF pauschal** für 2 Tage Pikett (Wochenende)
- Unabhängig davon, ob Einsatz stattfindet
- Über Monatsrechnung an Heineken

---

**ERKENNTNISSE FÜR APP:**
- ✅ Pikettplan anzeigen (Kalender-Integration)
- ✅ Pikett-Status sichtbar ("Ich bin jetzt im Pikett")
- ✅ Schnellerfassung bei Pikett-Einsatz
- ✅ Automatische Abrechnung Pikett-Pauschale

---

---

## 8. ERÖFFNUNGEN / ENDREINIGUNGEN

### Unterschied zu normalem Service?

**KEIN Unterschied!**
- Ablauf identisch zu normalen Services
- Nur saisonaler Kontext anders

**Saisonale Planung:**
- **Eröffnungen**: Meist Dezember (Saisonstart Winter)
- **Endreinigungen**: Meist April/Mai (Saisonende Winter)

### Problem: Totzeit

**Planung meist schwierig:**
- Viele Saisonbetriebe öffnen/schließen zur gleichen Zeit
- Konzentriert sich auf wenige Wochen
- Führt zu **Totzeit** (entweder zu viel oder zu wenig Arbeit)

**Beispiel:**
- Dezember: 30 Eröffnungen in 2 Wochen → kaum zu schaffen
- Januar/Februar: Weniger Services (viele Betriebe haben Ferien)

---

**ERKENNTNISSE FÜR APP:**
- ✅ Saisonale Planung: Betriebe nach Saison-Öffnung/-Schliessung filtern
- ✅ Erinnerung vor Saison: "20 Betriebe öffnen nächste Woche"
- ✅ Kapazitätsplanung: Warnung bei Überlastung

---

---

## 9. TOP 5 ZEITFRESSER / FRUSTRATIONEN

### 1. Administration
**Problem:**
- Größter Zeitfresser insgesamt
- 5-10 Stunden pro Woche
- Protokolle digitalisieren, Rechnungen erstellen, Excel-Eingabe

**Lösung durch App:**
- Digitale Protokolle → kein Abtippen
- Automatische Rechnungserstellung
- Zeitersparnis: 80%+

---

### 2. Rechnungsstellung, Kontrolle, Mahnwesen
**Problem:**
- Sehr viel Zeit erforderlich
- Rechnungen einzeln erstellen
- Zahlungen kontrollieren
- Mahnungen verschicken

**Lösung durch App:**
- Automatische Rechnungserstellung
- Zahlungsstatus-Tracking
- Automatische Mahnungen

---

### 3. Betrieb verwehrt Service
**Problem:**
- Daniel fährt zum Kunden
- Kunde will Service nicht (z.B. "Haben gerade keine Zeit")
- Verlorene Fahrzeit

**Lösung durch App:**
- Erinnerung an Kunden vor Service (SMS/E-Mail)
- Bestätigung durch Kunden
- Verhindert Leerfahrten

---

### 4. Betrieb hat Ferien ohne zu informieren
**Problem:**
- Daniel fährt zum Kunden
- Betrieb geschlossen (Ferien)
- Niemand hat informiert
- Verlorene Fahrzeit

**Lösung durch App:**
- **Internet-Abgleich**: Google Business, Öffnungszeiten-APIs
- Warnung: "Betrieb X ist laut Google geschlossen"
- Kunde um Bestätigung bitten

---

### 5. Fehler passieren nicht viele
**Positiv:**
- System funktioniert grundsätzlich gut
- Wenig Fehler im Arbeitsablauf
- Hauptproblem ist **Zeitaufwand**, nicht Fehler

---

**ERKENNTNISSE FÜR APP:**
- ✅ **HÖCHSTE PRIORITÄT**: Administration automatisieren
- ✅ Rechnungs- und Mahnwesen integrieren
- ✅ Kunden-Erinnerungen vor Service
- ✅ Internet-Abgleich für Öffnungszeiten/Ferien
- ✅ Materialverwaltung (aus Punkt 4)

---

---

## ✅ DOKUMENTATION ABGESCHLOSSEN

**Status:** Alle Geschäftsabläufe dokumentiert

**Nächste Schritte:**
1. Datenmodell erstellen (basierend auf allen Erkenntnissen)
2. Feature-Priorisierung (MVP vs. Nice-to-Have)
3. Tech-Stack-Entscheidung
4. Wireframes/Mockups

---

**Zusammenfassung der wichtigsten App-Features:**

| Kategorie | Feature | Zeitersparnis | Priorität |
|-----------|---------|---------------|-----------|
| **Protokolle** | Digitale 17-Punkt-Checkliste | 21 Min/Service | 🔴 Hoch |
| **Rechnungen** | Auto-Rechnungserstellung | 3-4h/Woche | 🔴 Hoch |
| **Material** | Materialverwaltung & Bestellliste | 1-2h/Monat | 🔴 Hoch |
| **Planung** | Tour von vor 1 Monat | 30 Min/Woche | 🟡 Mittel |
| **Störungen** | Flexible Einfügung in Tagesplan | 15 Min/Tag | 🟡 Mittel |
| **Kunden** | Erinnerungen vor Service | Verhindert Leerfahrten | 🟡 Mittel |
| **Ferien** | Internet-Abgleich Öffnungszeiten | Verhindert Leerfahrten | 🟢 Niedrig |

**Geschätzte Gesamtzeitersparnis:** 6-8 Stunden pro Woche = 300-400 Stunden pro Jahr

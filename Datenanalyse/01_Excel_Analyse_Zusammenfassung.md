# Excel-Analyse: SBS_Projer_Hauptexcel.xlsm

**Analysedatum**: 12.02.2026
**Datei**: SBS_Projer_Hauptexcel.xlsm
**Anzahl Tabellenblätter**: 37

---

## Zusammenfassung

Die Excel-Datei ist ein **vollständiges, selbstgebautes ERP-System** mit:
- ✅ Wochenplanung & Routenmanagement
- ✅ Auftragserfassung (6 verschiedene Auftragstypen)
- ✅ Vollständige Buchhaltung (Journal, Hauptbuch, Bilanz, Erfolgsrechnung)
- ✅ Stammdatenverwaltung (Kunden, Anlagen, Artikel)
- ✅ Rechnungsstellung & MWST-Abrechnung

**Gesamtdatenvolumen**:
- ~1.026 Kontakte/Kunden
- ~451 Betriebe (aktive Kunden)
- ~487 Anlagen mit Detailinformationen
- ~8.780+ erfasste Aufträge (alle Typen zusammen)
- ~1.265 Buchhaltungsvorgänge

---

## 1. WOCHENPLANUNG (6 Blätter)

### Zweck
Planung der wöchentlichen Service-Routen pro Wochentag

### Struktur

| Blatt | Zeilen | Spalten | Inhalt |
|-------|--------|---------|--------|
| **Mo** | 158 | 15 | Route, Montag-Datum, Einträge |
| **Di** | 158 | 15 | Route, Dienstag-Datum, Einträge |
| **Mi** | 158 | 15 | Route, Mittwoch-Datum, Einträge |
| **Do** | 158 | 15 | Route, Donnerstag-Datum, Einträge |
| **Fr** | 158 | 15 | Route, Freitag-Datum, Einträge |
| **Sa** | 2.709 | 52 | Route, Samstag-Datum, Einträge (erweiterte Historie!) |

### Wichtige Spalten
- **Route**: Routenbezeichnung (140 Einträge pro Blatt)
- **[Wochentag] [Datum]**: Tatsächliche Service-Einträge für den Tag
- Aktuell geplant: Woche vom 09.02.-13.02.2026

### Erkenntnisse
- ⚠️ **Samstag-Blatt hat 2.709 Zeilen**: Enthält offenbar historische Daten oder erweiterte Informationen
- Konsistente Struktur über alle Wochentage
- 140 verschiedene Routen definiert

---

## 2. AUFTRAGSTYPEN (6 Blätter)

### 2.1 Störung (1.029 Aufträge)
**Hauptblatt für Störungseinsätze**

**Schlüsselspalten** (36 Spalten total):
- `ID Störung` (eindeutige ID)
- `ID Betrieb` (Referenz zu Betrieb-Blatt)
- `Datum` (Einsatzdatum)
- `Betrieb`, `Ort`, `Bergkunde`
- `Störungsnummer` (989 von 1.029 ausgefüllt)
- `SN Kühler` (Seriennummer)
- `Anlagentyp`
- `Bemerkung`
- **Störungsarten 1-7**: Jeweils mit Anzahl und Total (7 verschiedene Störungstypen!)
- `Total Störung` (Gesamtbetrag)
- `Woche` (Kalenderwoche)

**Besonderheiten**:
- Detaillierte Erfassung von bis zu 7 verschiedenen Störungsarten pro Einsatz
- Automatische Preisberechnung
- Verknüpfung mit Betrieben

---

### 2.2 Reinigung (4.144 Aufträge) ⭐ HAUPTGESCHÄFT
**Größtes Blatt mit periodischen Services**

**Schlüsselspalten** (24 Spalten total):
- `ID Reinigung` (eindeutige ID)
- `ID Betrieb` (Referenz)
- `Datum` (Service-Datum)
- `Betrieb`, `Ort`, `Adresse`
- `Jahr`, `Kalenderw`, `Datum.1`
- **Hähne 1-4**: Anzahl und Total (bis zu 4 verschiedene Hahn-Typen!)
- `Bergkunde` (Bergkundenpauschale)
- `Reisespesen`, `HK-Service`, `Diverses`
- `Datum Rechnung`, `Rechnungsnummer`
- `Bezahlt`
- `Total Service` (Gesamtbetrag)

**Besonderheiten**:
- 4.144 erfasste Services = Kerngeschäft!
- Verschiedene Hahn-Typen mit unterschiedlichen Preisen
- Bergkundenpauschale integriert
- Rechnungsverfolgung (Datum, Nummer, Bezahlt-Status)

---

### 2.3 Eigenauftrag (201 Aufträge)
**Spezielle Aufträge außerhalb des Heineken-Systems**

**Schlüsselspalten** (22 Spalten):
- `ID Eigenauftrag`
- `ID Betrieb`, `Datum`, `Betrieb`, `Ort`
- `Aufwand_h` (Stunden), `Aufwand_min` (Minuten)
- `Aufwand_total_h` (Gesamt Stunden)
- `Stundenansatz`, `Total_Stunden`
- `KM`, `KM_Ansatz`, `Total_KM`
- `Material`
- `Total Eigenauftrag`
- `Woche`

**Besonderheiten**:
- Stunden- und Kilometerabrechnung
- Materialkosten separat erfasst
- Flexibles Abrechnungssystem

---

### 2.4 Pikett (1.025 Aufträge)
**Pikettdienst-Erfassung**

**Schlüsselspalten** (32 Spalten):
- `ID Pikett`
- `Datum`, `Jahr`, `Kalenderw`
- `Pikett_Art` (Wochentag/Wochenende)
- `Pikettdienst`, `Pikettdienst_WE` (Wochenende)
- **Störungsarten 1-7**: Anzahl und Total
- `Total Pikett`
- `Woche`

**Besonderheiten**:
- Unterscheidung Wochentag/Wochenende (unterschiedliche Tarife!)
- Bis zu 7 verschiedene Störungsarten erfassbar
- 1.025 Pikettdienste erfasst

---

### 2.5 EE_Reinigung (179 Aufträge)
**Eröffnungs- und Endreinigungen bei Saisonbetrieben**

**Schlüsselspalten** (19 Spalten):
- `ID EE_Reinigung`
- `ID Betrieb`, `Datum`, `Betrieb`, `Ort`
- `Jahr`, `Kalenderw`
- `Art` (Eröffnung/Endreinigung)
- **Hähne 1-4**: Anzahl und Total
- `Total EE_Reinigung`
- `Woche`

**Besonderheiten**:
- Spezialfall für Saisonbetriebe (Hotels, Skigebiete)
- Unterscheidung Eröffnung vs. Endreinigung
- Gleiche Hahn-Struktur wie normale Reinigungen

---

### 2.6 Montage (1.203 Aufträge)
**Montage-, Demontage- und Umbauarbeiten**

**Schlüsselspalten** (26 Spalten):
- `ID Montage`
- `ID Betrieb`, `Datum`, `Betrieb`, `Ort`
- `Jahr`, `Kalenderw`
- `Art` (Montage, Demontage, Umbau, etc.)
- `Aufwand_h`, `Aufwand_min`, `Aufwand_total_h`
- `Stundenansatz`, `Total_Stunden`
- `KM`, `KM_Ansatz`, `Total_KM`
- `Material`
- `Total Montage`
- `Woche`

**Besonderheiten**:
- Ähnlich wie Eigenauftrag, aber für Heineken-Montagen
- Stunden-, Kilometer- und Materialabrechnung
- 1.203 Montageaufträge erfasst

---

## 3. FORMULARE (6 Blätter)

**Template-Blätter für Auftragserfassung**:
- `F_Störung` (85 Zeilen)
- `F_Eigenauftrag` (77 Zeilen)
- `F_EE_Reinigung` (43 Zeilen)
- `F_Montage` (43 Zeilen)
- `F_Pikett` (85 Zeilen)
- `F_Pauschale` (25 Zeilen)

**Zweck**: Vordefinierte Eingabeformulare für schnelle Auftragserfassung

---

## 4. BUCHHALTUNG (6 Blätter)

### 4.1 Journal (1.265 Geschäftsfälle)
**Chronologisches Hauptjournal**

**Spalten** (12 Spalten):
- `Datum`, `Beleg`, `Text`
- `Soll_Konto`, `Haben_Konto`
- `Betrag`, `MWST_Code`, `MWST`
- `Total`

**Besonderheiten**:
- 1.265 Buchungen erfasst
- Vollständige Doppelte Buchhaltung
- MWST-Integration

---

### 4.2 Hauptbuch (96 Zeilen)
**Konten-Zusammenfassung**

**Spalten** (11 Spalten):
- `Konto`, `Bezeichnung`, `Typ`
- Monatsspalten (Januar-Dezember)
- Saldo-Berechnungen

---

### 4.3 Bilanz (76 Zeilen)
**Aktiven und Passiven**

**Struktur**:
- Aktiven: Umlaufvermögen, Anlagevermögen
- Passiven: Fremdkapital, Eigenkapital
- Automatische Saldierung

---

### 4.4 Erfolgsrechnung (80 Zeilen)
**Ertrag und Aufwand**

**Struktur**:
- Betriebsertrag (aufgeschlüsselt nach Auftragstypen)
- Betriebsaufwand (Material, Personal, etc.)
- Jahresgewinn/-verlust

---

### 4.5 Geschäftsfälle (38 Zeilen)
**Standard-Buchungsvorlagen**

**Spalten**:
- `Geschäftsfall`, `Soll`, `Haben`, `Text`, `MWST Code`

**Beispiele**:
- Einzahlung Kunde
- Material Heineken
- Franchisegebühr
- etc.

---

### 4.6 Kontenrahmen (117 Zeilen)
**Vollständiger Kontenplan**

**Spalten**:
- `Konto`, `Bezeichnung`, `Typ`, `Kategorie`
- Strukturiert nach Aktiven, Passiven, Ertrag, Aufwand

---

## 5. STAMMDATEN (6 Blätter)

### 5.1 Kontakt (1.026 Kontakte)
**Alle Kontaktpersonen**

**Schlüsselspalten** (13 Spalten):
- `ID Kontakt`, `ID Betrieb`
- `Name`, `Vorname`, `Funktion`
- `Telefon`, `Mobile`, `E-Mail`
- `Status` (Aktiv/Inaktiv)
- `Bemerkung`

**Besonderheiten**:
- 1.026 Kontakte erfasst
- Verknüpfung mit Betrieben
- Multiple Kontakte pro Betrieb möglich

---

### 5.2 Betrieb (451 Betriebe) ⭐ KUNDENSTAMM
**Hauptkundenliste**

**Schlüsselspalten** (18 Spalten):
- `ID Betrieb`, `Betrieb`, `Betrieb_Typ`
- `Strasse`, `PLZ`, `Ort`
- `Status` (Aktiv/Inaktiv/Potenziell)
- `Verrechnungsart` (Direkt/Heineken/Gemischt)
- `Saison` (Ganzjahr/Winter/Sommer/Saisonal)
- `Bemerkung`, `Region`, `Maps`
- `Anzahl_Anlagen`

**Besonderheiten**:
- 451 Betriebe = Kundenstamm
- Verschiedene Betriebstypen (Restaurant, Hotel, Bar, etc.)
- Status-Verwaltung
- Saisonalität erfasst
- Google Maps Integration vorbereitet

---

### 5.3 Leitung (1.117 Zeilen)
**Leitungs-/Schlauchinformationen**

**Schlüsselspalten** (13 Spalten):
- `ID Leitung`, `ID Anlage`
- `Reihenfolge`, `Hahn`, `Fass`, `Bier`
- `Leitung_Typ`, `Länge_m`, `Durchmesser_mm`
- `Anzahl_Schellen`, `Bemerkung`

**Besonderheiten**:
- 1.117 Leitungen erfasst
- Detaillierte technische Informationen
- Verknüpfung mit Anlagen

---

### 5.4 Anlage (487 Anlagen) ⭐ SEHR DETAILLIERT
**Anlagen-Stammdaten mit umfassenden Informationen**

**Schlüsselspalten** (50 Spalten!):
- `ID Anlage`, `ID Betrieb`
- `Standort`, `Standortbeschreibung`
- `Status` (Aktiv/Inaktiv/Projekt)
- `Anzahl_Häne`, `Servicepreis`, `Reinigungsintervall`

**Technische Details**:
- `Anlagentyp`, `Vorkühler`, `Durchlaufkühler`, `Backpython`, `Booster`, `Fob-Stop`
- `Gas`, `Gas Bemerkung`, `Druck Hauptverteiler`
- `Winterbetrieb`, `Saisonbetrieb`, `Reinigungen pro Jahr`

**Saisonale Planung** (12 Monatsspalten!):
- Januar-Dezember (Planung pro Monat)

**Betriebszeiten**:
- `WS von/bis` (Wintersaison)
- `SS von/bis` (Sommersaison)
- `Ferien`, `Anfangskunde`

**Routenplanung**:
- `Region`, `Tour`, `Woche`, `Tag`, `Zeit`
- `Winter` (Wintertouren)
- `W_01` bis `W_10` (Wochen-Planung)
- `Unregelmässig`

**Besonderheiten**:
- 487 Anlagen mit extrem detaillierten Informationen
- Vollständige technische Dokumentation
- Integrierte Routenplanung
- Saisonale Betriebs- und Ferienzeiten

---

### 5.5 Artikel Heineken (885 Artikel)
**Heineken-Artikelstamm**

**Schlüsselspalten** (13 Spalten):
- `Kategorie`, `Unterkategorie`, `Nummer`
- `SAP Nr.`, `DBO Nr.`, `Kurztext`
- `Foto 1-3`, `Bemerkung`
- `di`, `da`, `h` (Dimensionen?)

**Besonderheiten**:
- 885 Artikel
- Heineken SAP-Integration vorbereitet
- Mehrere Nummernsysteme (SAP, DBO)

---

### 5.6 Listen (19 Zeilen)
**Dropdown-Listen und Stammdaten-Kategorien**

**Kategorien** (16 Listen):
- `Betrieb_Typ` (11 Typen: Restaurant, Hotel, Bar, etc.)
- `Betrieb_Status` (4: Aktiv, Inaktiv, Potenziell, etc.)
- `Betrieb_Saison` (6: Ganzjahr, Winter, Sommer, etc.)
- `Verrechnungsart` (8 Arten)
- `Anlage_Status` (5 Status)
- `Anlage_Typ` (9 Typen)
- `Anlage_Reinigungsintervall` (9 Intervalle)
- `Kontakt_Status` (3 Status)
- `Termin_Art` (11 Arten)
- `Stoerung_Anlage_Typ` (6 Typen)
- `Montage_Typ` (5 Typen)
- `Service_Art` (5 Arten)
- `Vorkueler_Typ` (8 Typen)
- `Durchlaufkuehler_Typ` (19 Typen!)
- `Termin_Status` (4 Status)
- `Hahn_Typ` (16 Typen!)

**Zweck**: Zentrale Definition aller Dropdown-Werte für konsistente Dateneingabe

---

## 6. WEITERE BLÄTTER (8 Blätter)

### 6.1 Einzahlungen (17 Zeilen)
**Zahlungseingänge**
- Vermutlich für Kassenabstimmung

### 6.2 K - MWST (31 Zeilen, 17 Spalten)
**MWST-Kontrolle und Quartalsabrechnung**
- Vorsteuer, Mehrwertsteuer, Zahllast

### 6.3 Kontrolle (35 Zeilen, 16 Spalten)
**Daten-Konsistenzprüfungen**
- Vergleiche zwischen verschiedenen Blättern
- Abweichungsmeldungen

### 6.4 Info (45 Zeilen)
**Informations- und Hilfeblatt**
- Erklärungen zur Buchhaltung
- Nutzungshinweise

### 6.5 Auswertung (92 Zeilen, 24 Spalten)
**Jahresauswertungen und Statistiken**

**Spalten**:
- `Jahr`, `Total (inkl. MWST)`, `Reinigung`, `Rechnung HK`
- Aufgeschlüsselt nach Auftragstypen
- `BK Pauschale`, `Reinigung HK`, `Störung`, `Eigenauftrag`, etc.

**Besonderheiten**:
- 91 Einträge (vermutlich monatliche Auswertungen über mehrere Jahre)
- Vollständige Umsatzübersicht

### 6.6 Rechnung (146 Zeilen, 6 Spalten)
**Rechnungsformular-Template**
- Vorlage für Rechnungserstellung

### 6.7 Rechnung Service (44 Zeilen, 4 Spalten)
**Aktuelle Rechnung**
- Enthält aktuelle Rechnung: `0068_2026_02_10`
- 12 Positionen

---

## Erkenntnisse und Bewertung

### 🎯 Stärken der aktuellen Lösung
1. **Vollständigkeit**: Alle Geschäftsprozesse sind abgebildet
2. **Datenqualität**: Sehr detaillierte und strukturierte Datenerfassung
3. **Konsistenz**: Einheitliche Namenskonventionen und ID-Systeme
4. **Integration**: Alle Bereiche sind miteinander verknüpft (IDs!)
5. **Buchhaltung**: Vollständige doppelte Buchhaltung integriert

### ⚠️ Probleme der Excel-Lösung
1. **Komplexität**: 37 Tabellenblätter = schwierig zu navigieren
2. **Performance**: 8.780+ Einträge = langsam
3. **Fehleranfälligkeit**: Manuelle Formeln können kaputt gehen
4. **Multi-User**: Keine parallele Nutzung möglich
5. **Mobile**: Nicht mobil nutzbar
6. **Automatisierung**: Begrenzte Möglichkeiten (Makros)
7. **Backup**: Risiko von Datenverlust

### 💡 Migrationsstrategie

**Phase 1: Stammdaten** (Foundation)
- Betriebe (451)
- Anlagen (487)
- Kontakte (1.026)
- Listen (Dropdown-Werte)

**Phase 2: Aufträge** (Core Business)
- Reinigung (4.144) ⭐ Priorität 1
- Störung (1.029)
- Montage (1.203)
- Pikett (1.025)
- EE_Reinigung (179)
- Eigenauftrag (201)

**Phase 3: Buchhaltung**
- Journal (1.265)
- Kontenrahmen
- Automatische Buchungserstellung

**Phase 4: Planung**
- Wochenplanung
- Routenoptimierung

### 📊 Datenmodell-Highlights

**Kern-Entitäten**:
```
Betrieb (451)
  ├─> Anlage (487) [1:n]
  │    ├─> Leitung (1.117) [1:n]
  │    └─> Reinigung (4.144) [1:n]
  ├─> Kontakt (1.026) [1:n]
  ├─> Störung (1.029) [1:n]
  ├─> Montage (1.203) [1:n]
  ├─> Pikett (1.025) [1:n]
  ├─> EE_Reinigung (179) [1:n]
  └─> Eigenauftrag (201) [1:n]

Alle Aufträge -> Journal (Buchhaltung) [1:n]
```

**Wichtige Beziehungen**:
- Jeder Auftrag hat `ID Betrieb` (Foreign Key)
- Anlagen haben `ID Betrieb`
- Kontakte haben `ID Betrieb`
- Leitungen haben `ID Anlage`

### 🔑 Kritische Features für die App

**Must-Have (aus Daten ersichtlich)**:
1. ✅ Betriebsverwaltung mit Statusverfolgung
2. ✅ Anlagenverwaltung mit technischen Details
3. ✅ 6 verschiedene Auftragstypen mit spezifischen Feldern
4. ✅ Flexible Preisberechnung (Festpreise, Stundensätze, Pauschalen)
5. ✅ Bergkundenpauschale-Handling
6. ✅ Saisonalität (Winter/Sommer, Betriebsferien)
7. ✅ Rechnungsverfolgung (Datum, Nummer, Bezahlt-Status)
8. ✅ MWST-Behandlung
9. ✅ Buchhaltungsintegration
10. ✅ Wochenplanung & Routenmanagement

**Erkannte Automatisierungen**:
- Automatische Preisberechnung basierend auf Hahn-Anzahl
- Bergkundenpauschale automatisch zuweisen
- Rechnungsnummern-Generierung (Format: `XXXX_YYYY_MM_DD`)
- MWST-Berechnung
- Automatische Buchungen im Journal

---

## Nächste Schritte

1. **Detaillierte Geschäftsabläufe dokumentieren** (03_Geschäftsabläufe.md)
   - Wie läuft ein Service ab? (von Planung bis Rechnung)
   - Wie funktioniert die Heineken-Monatsabrechnung?
   - Wie läuft Störungseinsatz ab?

2. **Weitere Dokumente analysieren**
   - Heineken-Vorlagen
   - Rechnungsvorlagen
   - Vertragsunterlagen

3. **Datenmodell entwerfen**
   - Basierend auf Excel-Struktur
   - Normalisierung wo nötig
   - API-Design

4. **Tech-Stack-Entscheidung**
   - Frontend: React/Next.js oder Flutter?
   - Backend: Supabase, Firebase oder Custom?
   - Hosting: Vercel, Firebase, AWS?
   - Budget-Constraint: 200 CHF/Monat!

---

## Technische Anmerkungen

**Datenmigration**:
- Python-Script mit pandas/openpyxl erstellen
- IDs beibehalten (wichtig für Konsistenz!)
- Historische Daten: ~8.780 Aufträge migrieren
- Validierung nach Migration

**Datenintegrität**:
- Foreign Keys prüfen (ID Betrieb, ID Anlage existieren?)
- Dropdown-Werte validieren
- Datum-Formate normalisieren

**Performance**:
- Indizes auf häufig genutzte Felder (ID Betrieb, Datum, etc.)
- Pagination für große Listen
- Caching für Stammdaten

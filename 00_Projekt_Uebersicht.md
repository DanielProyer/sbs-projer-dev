# SBS Projer App - Projekt-Übersicht

**Projekt**: Service-Management App für Zapfanlagen-Service
**Kunde**: Daniel Projer, SBS Projer GmbH
**Stand**: 15.03.2026
**Tech-Stack**: Flutter + Supabase

---

## 📊 PROJEKT-STATUS

### Aktueller Stand: **Phase 4 - Polish & Testing** 📅

| Phase | Status | Fortschritt | Fertig am |
|-------|--------|-------------|-----------|
| **Phase 0: Planung & Analyse** | ✅ Abgeschlossen | 100% | 12.02.2026 |
| **Phase 1: Setup & Grundlagen** | ✅ Abgeschlossen | 100% | 20.02.2026 |
| **Phase 2: Core Features (MVP)** | ✅ Abgeschlossen | 100% | 14.03.2026 |
| **Phase 3: Administration** | ✅ Abgeschlossen | 100% | 15.03.2026 |
| **Phase 4: Polish & Testing** | 📅 Nächste Phase | 0% | - |
| **Phase 5: Deployment & Launch** | 🔄 Vorgezogen | 20% | - |

---

## ✅ ERLEDIGTE ARBEITSPAKETE

### 1. Geschäftsanalyse & Dokumentation

#### ✅ Geschäftsbeschreibung
- **Datei**: `Prompts/02_Geschäftsbeschreibung.md`
- **Status**: Komplett ausgefüllt
- **Inhalt**:
  - Firmendetails (One-man operation, Heineken-Franchise)
  - 250 Kunden, 4-Wochen-Rhythmus
  - Budget: 200 CHF/Monat max
  - Ziel: 80% Zeitersparnis bei Administration

#### ✅ Excel-Analyse
- **Datei**: `Datenanalyse/01_Excel_Analyse_Zusammenfassung.md`
- **Status**: Vollständige Analyse von 37 Excel-Sheets
- **Key Findings**:
  - 4,144 Reinigungen (Hauptgeschäft)
  - 1,029 Störungen
  - 1,203 Montagen
  - Komplettes ERP-System in Excel

#### ✅ Heineken Monatsrechnungen
- **Datei**: `Datenanalyse/02_Heineken_Monatsrechnungen_Analyse.md`
- **Status**: 3 Monate analysiert (Okt-Dez 2025)
- **Key Findings**:
  - 8 Abrechnungskategorien
  - Q4 2025: 20,593 CHF an Heineken
  - 5 Störungsbereiche identifiziert

#### ✅ Reinigungsprotokolle
- **Datei**: `Datenanalyse/03_Reinigungsprotokolle_Analyse.md`
- **Status**: 4 PDFs analysiert
- **Key Findings**:
  - 17-Punkt-Checkliste dokumentiert
  - Zeitersparnis: 25 Min → 4 Min pro Service
  - Potenzial: 1,450 Stunden/Jahr sparen

#### ✅ Störungsbereiche
- **Datei**: `Datenanalyse/04_Störungsbereiche_Analyse.md`
- **Status**: Heineken-Diagramm analysiert
- **Key Findings**:
  - 5 technische Bereiche mit unterschiedlichen Preisen
  - Bereich 3 (Kühlsystem) = 40% aller Störungen

#### ✅ Preisliste Heineken
- **Datei**: `Datenanalyse/05_Preisliste_Heineken_Analyse.md`
- **Status**: Offizielle Preisliste analysiert
- **Key Findings**:
  - Alle Preise excl. MWST (8.1%)
  - Bergkunden vs. Normalkunden-Unterscheidung

#### ✅ Preissystem Final
- **Datei**: `Datenanalyse/06_Preissystem_Final.md`
- **Status**: Alle Preisregeln geklärt
- **Key Findings**:
  - Pikett = 160 CHF (2 Tage)
  - Bergkunden zahlen ~2.4× mehr
  - Ersatzteile immer kostenlos für Kunden

#### ✅ Geschäftsabläufe
- **Datei**: `Prompts/03_Geschäftsabläufe.md`
- **Status**: Vollständig dokumentiert (9 Abschnitte)
- **Inhalt**:
  1. Tourenplanung (Tour von vor 1 Monat)
  2. Service-Durchführung beim Kunden
  3. Fahrt zwischen Kunden
  4. Ende des Tages/Woche
  5. Störungen (flexibel dazwischengeschoben)
  6. Montagen
  7. Pikett-Dienst (1 Wochenende/Monat)
  8. Eröffnungen/Endreinigungen
  9. Top 5 Zeitfresser/Frustrationen

**Wichtigste Erkenntnisse:**
- Betrieb → Anlage (1:n) ist KRITISCH
- Offline-Fähigkeit MUSS funktionieren
- Administration = größter Zeitfresser (5-10h/Woche)
- Materialverwaltung im Auto = kritisches Feature
- Zeitersparnis-Potenzial: 6-8 Stunden/Woche

---

### 2. Technische Architektur

#### ✅ Tech-Stack-Analyse
- **Datei**: `Architektur/01_Tech_Stack_Analyse.md`
- **Status**: 4 Optionen verglichen, Entscheidung getroffen
- **Entscheidung**: **Flutter + Supabase** (56/60 Punkte)
- **Begründung**:
  - Beste Offline-Fähigkeit
  - Eine Codebase (Web + iOS + Android)
  - PostgreSQL perfekt für Betrieb→Anlage
  - Kosten: 0-23 CHF/Monat (weit unter Budget)
  - Multi-Tenant-ready

#### ✅ Datenmodell (Finalisiert & Live)
- **Datei**: `Architektur/02_Datenmodell.md`
- **Status**: Finalisiert und in Supabase ausgeführt (17.02.2026)
- **Inhalt**:
  - 24 Tabellen live in Supabase
  - 24 RLS Policies aktiv
  - 20 Trigger/Functions aktiv
  - 7 Views erstellt
  - Seed-Daten: 11 Regionen, 20 Kategorien, 43 Konten, 74 Buchungsvorlagen, 883 Artikel
- **DB-Zugriff**: Direkter Zugriff via Python (`Datenbank/db_query.py`)

---

## 📋 OFFENE ARBEITSPAKETE

### Phase 1: Setup & Grundlagen (Woche 1-2)

| Aufgabe | Status | Priorität | Abhängigkeiten |
|---------|--------|-----------|----------------|
| ✅ Supabase Account | Vorhanden | - | - |
| ✅ GitHub Account | Vorhanden | - | - |
| ✅ Datenmodell finalisieren | Abgeschlossen | 🔴 Hoch | 12.02.2026 |
| ✅ Supabase Projekt Setup | Abgeschlossen | 🔴 Hoch | 17.02.2026 |
| ✅ Migration Scripts ausführen | Abgeschlossen | 🔴 Hoch | 17.02.2026 |
| ✅ DB-Direktzugriff (Python) | Abgeschlossen | 🔴 Hoch | 17.02.2026 |
| ✅ Flutter Projekt initialisieren | Abgeschlossen | 🔴 Hoch | 17.02.2026 |
| ✅ Packages installieren (25+) | Abgeschlossen | 🔴 Hoch | 17.02.2026 |
| ✅ Projekt-Struktur aufsetzen | Abgeschlossen | 🔴 Hoch | 17.02.2026 |
| ✅ Supabase Client konfigurieren | Abgeschlossen | 🔴 Hoch | 17.02.2026 |
| ✅ Isar DB einrichten (13 Collections) | Abgeschlossen | 🔴 Hoch | 20.02.2026 |
| ✅ Sync-Service (komplett, 12 Entitäten) | Abgeschlossen | 🔴 Hoch | 20.02.2026 |
| ✅ ConnectivityService (Online/Offline) | Abgeschlossen | 🔴 Hoch | 20.02.2026 |
| ✅ 12 Mapper + 4 Repositories + 3 Providers | Abgeschlossen | 🔴 Hoch | 20.02.2026 |
| 🔄 Authentication (Login ✅, Provider ausstehend) | Teilweise | 🔴 Hoch | 17.02.2026 |
| ✅ Navigation (GoRouter, 16 Routes + Auth-Guard) | Abgeschlossen | 🔴 Hoch | 20.02.2026 |
| ✅ Design System / Theme (Material 3, AppColors) | Abgeschlossen | 🟡 Mittel | 20.02.2026 |

### Phase 2: Core Features (MVP) (Woche 3-8)

| Feature | Status | Priorität | Zeitschätzung |
|---------|--------|-----------|---------------|
| ✅ Datenmodell in Code (24 DTOs + 13 Isar) | Abgeschlossen | 🔴 Hoch | 20.02.2026 |
| ✅ Offline-Sync-Logik (12 Entitäten) | Abgeschlossen | 🔴 Hoch | 20.02.2026 |
| ✅ Authentication (Supabase Auth) | Abgeschlossen | 🔴 Hoch | 11.03.2026 |
| ✅ Betriebe CRUD (Liste, Detail, Form, Providers) | Abgeschlossen | 🔴 Hoch | 20.02.2026 |
| ✅ Betrieb MVP (Kontakte, Rechnungsadresse, Form-Erweiterungen) | Abgeschlossen | 🔴 Hoch | 07.03.2026 |
| ✅ Anlagen CRUD (Liste, Detail, Form, Providers, Bierleitungen) | Abgeschlossen | 🔴 Hoch | 20.02.2026 |
| ✅ Anlagen MVP (Dropdown-Fixes, Bierleitung CRUD, Gas-Validierung) | Abgeschlossen | 🔴 Hoch | 07.03.2026 |
| ✅ Reinigungen CRUD (Liste, Detail, Form, Providers, Service-Flow) | Abgeschlossen | 🔴 Hoch | 20.02.2026 |
| ✅ Störungen CRUD (Liste, Detail, Form, Providers, Störungsnummer) | Abgeschlossen | 🔴 Hoch | 20.02.2026 |
| ✅ Web-Deployment (GitHub Pages) | Abgeschlossen | 🔴 Hoch | 07.03.2026 |
| ✅ Android APK (Emulator getestet) | Abgeschlossen | 🔴 Hoch | 07.03.2026 |
| ✅ Isar Extension Bug Fix + Repository Refactoring | Abgeschlossen | 🔴 Hoch | 07.03.2026 |
| ✅ Tourenplanung (Basis) | Abgeschlossen | 🔴 Hoch | 11.03.2026 |
| ✅ Service-Protokoll (Unterschriften, Fotos, Preis) | Abgeschlossen | 🔴 Hoch | 11.03.2026 |
| ✅ Unterschriften-Funktion | Abgeschlossen | 🔴 Hoch | 11.03.2026 |
| ✅ Foto-Upload | Abgeschlossen | 🔴 Hoch | 11.03.2026 |
| ✅ Preis-Kalkulator | Abgeschlossen | 🟡 Mittel | 11.03.2026 |
| ✅ Reinigungsprotokoll-PDF (Heineken FOR 1220) | Abgeschlossen | 🔴 Hoch | 12.03.2026 |

### Phase 3: Administration (Woche 9-12)

| Feature | Status | Priorität | Zeitschätzung |
|---------|--------|-----------|---------------|
| ✅ Kundenrechnung-Generierung (PDF + QR-Einzahlungsschein) | Abgeschlossen | 🔴 Hoch | 12.03.2026 |
| ✅ Materialverwaltung (CRUD, Bestellliste, Material-Picker) | Abgeschlossen | 🔴 Hoch | 12.03.2026 |
| ✅ Störungs-Management (Entkopplung, Vereinfachung, MwSt-Entfernung) | Abgeschlossen | 🔴 Hoch | 13.03.2026 |
| ✅ Montage-Management (CRUD, Betrieb-Autocomplete, Material) | Abgeschlossen | 🔴 Hoch | 13.03.2026 |
| ✅ Pikett-Dienste (CRUD, Pauschale 80 CHF) | Abgeschlossen | 🔴 Hoch | 13.03.2026 |
| ✅ Eigenaufträge (CRUD, 30 CHF Pauschale, Material) | Abgeschlossen | 🔴 Hoch | 13.03.2026 |
| ✅ Eröffnungsreinigungen (CRUD, Bergkunde auto-detect, Preise aus DB) | Abgeschlossen | 🔴 Hoch | 14.03.2026 |
| ✅ Betrieb-Verbesserungen (Ferien, Ruhetage, Saison→Datum) | Abgeschlossen | 🟡 Mittel | 14.03.2026 |
| ✅ Heineken Monatsrechnung (8 Kategorien, Combined PDF) | Abgeschlossen | 🔴 Hoch | 15.03.2026 |
| ✅ Heineken PDF-Formulare (6 Rapport-Typen als Beilagen) | Abgeschlossen | 🔴 Hoch | 15.03.2026 |
| ✅ Mahnwesen (Überfällige Rechnungen, Mahnstufen 0-3) | Abgeschlossen | 🟡 Mittel | 15.03.2026 |
| ✅ Buchhaltung komplett (Dashboard, Kontenplan, Journal, Buchungen, Berichte) | Abgeschlossen | 🔴 Hoch | 15.03.2026 |

### Phase 4: Polish & Testing (Woche 13-16)

| Aufgabe | Status | Priorität | Zeitschätzung |
|---------|--------|-----------|---------------|
| 📅 UI/UX Verbesserungen | Ausstehend | 🟡 Mittel | 5 Tage |
| 📅 Offline-Sync Testing | Ausstehend | 🔴 Hoch | 3 Tage |
| 📅 Performance-Optimierung | Ausstehend | 🟡 Mittel | 3 Tage |
| 📅 Beta-Testing mit Daniel | Ausstehend | 🔴 Hoch | 5 Tage |
| 📅 Bug-Fixes | Ausstehend | 🔴 Hoch | 5 Tage |

### Phase 5: Deployment & Launch (Woche 17-18)

| Aufgabe | Status | Priorität | Zeitschätzung |
|---------|--------|-----------|---------------|
| 📅 App Store Submission (iOS) | Ausstehend | 🔴 Hoch | 2 Tage |
| 📅 Google Play Submission (Android) | Ausstehend | 🔴 Hoch | 2 Tage |
| ✅ Web Deployment (GitHub Pages) | Abgeschlossen | 🔴 Hoch | 07.03.2026 |
| 📅 Dokumentation (Benutzerhandbuch) | Ausstehend | 🟡 Mittel | 2 Tage |
| 📅 Training für Daniel | Ausstehend | 🔴 Hoch | 1 Tag |
| 📅 Excel-Daten-Migration | Ausstehend | 🟡 Mittel | 2 Tage |

---

## 🎯 MVP FEATURES (Must-Have für Launch)

| Feature | Beschreibung | Status |
|---------|--------------|--------|
| **Betriebe & Anlagen** | CRUD, Suche, Filter | ✅ Erledigt |
| **Tourenplanung** | Tour von vor 1 Monat, Drag & Drop | ✅ Erledigt |
| **Service-Protokoll** | 17-Punkt-Checkliste + PDF | ✅ Erledigt |
| **Unterschriften** | Digital auf Smartphone | ✅ Erledigt |
| **Fotos** | Probleme dokumentieren | ✅ Erledigt |
| **Offline-Sync** | Funktioniert ohne Internet | ✅ Erledigt |
| **Rechnungen** | PDF mit QR-Einzahlungsschein | ✅ Erledigt |
| **Materialverwaltung** | Bestand tracken, Bestellliste | ✅ Erledigt |
| **Störungen** | Mit Störungsnummer, flexibel | ✅ Erledigt |
| **Montagen** | Zeiterfassung, 80 CHF/h | ✅ Erledigt |
| **Pikett** | Pauschale 80 CHF, Datum | ✅ Erledigt |
| **Eigenaufträge** | 30 CHF Pauschale, Material | ✅ Erledigt |
| **Eröffnungsreinigungen** | Bergkunde auto-detect, 60/135 CHF | ✅ Erledigt |

**Geschätzte MVP-Entwicklungszeit**: 12-16 Wochen

---

## 🔮 POST-MVP FEATURES (Nice-to-Have)

| Feature | Beschreibung | Priorität |
|---------|--------------|-----------|
| **Mahnwesen** | Automatische Mahnungen | 🟡 Mittel |
| **Internet-Abgleich** | Google Business API für Öffnungszeiten | 🟢 Niedrig |
| **GPS-Tracking** | Automatische Fahrzeiten | 🟢 Niedrig |
| **Routenoptimierung** | Optimale Reihenfolge vorschlagen | 🟡 Mittel |
| **Statistiken** | Dashboard mit KPIs | 🟡 Mittel |
| **Multi-User** | Für Franchise-Partner | 🟡 Mittel |
| **Push-Notifications** | Erinnerungen, Pikett-Benachrichtigungen | 🟢 Niedrig |

---

## 📁 DOKUMENTE-ÜBERSICHT

### Projektbeschreibung
- `Prompts/01_Projektansatz.md` - Initialer Projektansatz
- `Prompts/02_Geschäftsbeschreibung.md` - Ausgefüllte Geschäftsbeschreibung
- `Prompts/03_Geschäftsabläufe.md` - Detaillierte Workflow-Dokumentation

### Datenanalyse
- `Datenanalyse/01_Excel_Analyse_Zusammenfassung.md`
- `Datenanalyse/02_Heineken_Monatsrechnungen_Analyse.md`
- `Datenanalyse/03_Reinigungsprotokolle_Analyse.md`
- `Datenanalyse/04_Störungsbereiche_Analyse.md`
- `Datenanalyse/05_Preisliste_Heineken_Analyse.md`
- `Datenanalyse/06_Preissystem_Final.md`

### Architektur
- `Architektur/01_Tech_Stack_Analyse.md` - Tech-Stack-Entscheidung
- `Architektur/02_Datenmodell.md` - PostgreSQL-Schema (In Review)
- `Architektur/03_Roadmap.md` - Detaillierter Zeitplan

### Projekt-Management
- `00_Projekt_Uebersicht.md` - **Diese Datei** (Dashboard)

---

## 💰 BUDGET-ÜBERSICHT

### Entwicklungskosten
- **Self-Development**: 0 CHF (Daniel entwickelt mit Claude)

### Betriebskosten (Monatlich)

| Jahr | Monat | Details |
|------|-------|---------|
| **Ab 20.02.2026** | **23 CHF** | Supabase Pro (25 USD ≈ 23 CHF) |

### Einmalige Kosten

| Posten | Kosten | Wann |
|--------|--------|------|
| Apple Developer Account | 99 USD (~90 CHF) | Jahr 1 |
| Google Play Developer | 25 USD (~23 CHF) | Jahr 1 (einmalig) |
| **Total einmalig** | **~113 CHF** | |

**→ Weit unter Budget von 200 CHF/Monat!**

---

## 📊 ZEITERSPARNIS-POTENZIAL

### Aktueller Zeitaufwand (pro Woche)

| Aufgabe | Aktuell | Mit App | Ersparnis |
|---------|---------|---------|-----------|
| Protokolle digitalisieren | 2-3h | 0h | 2-3h |
| Rechnungen erstellen | 2-3h | 0.5h | 1.5-2.5h |
| Excel-Eingabe | 1-2h | 0h | 1-2h |
| Materialnachbestellung | 0.5h | 0.1h | 0.4h |
| Papierkram pro Service (21 Min × 40 Services/Woche) | 14h | 2.7h | 11.3h |
| **TOTAL pro Woche** | **19.5-20.5h** | **3.3h** | **16.2-17.2h** |

**Jährliche Zeitersparnis**: ~840 Stunden = **105 Arbeitstage!**

**ROI**: Bei 80 CHF/h Stundensatz = **67,200 CHF/Jahr gespart**

---

## 🚀 NÄCHSTE SCHRITTE

### Erledigt am 17.02.2026
1. ✅ Supabase DB komplett live (24 Tabellen, alle Seeds)
2. ✅ Direkter DB-Zugriff via Python eingerichtet
3. ✅ Flutter 3.41.1 + Android Studio installiert
4. ✅ Flutter Projekt erstellt (`sbs_projer_app`)
5. ✅ 25+ Packages installiert & konfiguriert
6. ✅ Projekt-Struktur (Clean Architecture) aufgesetzt
7. ✅ Supabase Client konfiguriert & getestet
8. ✅ Login Screen – funktioniert mit Supabase Auth
9. ✅ GoRouter mit Auth-Guard
10. ✅ Isar Core-Collections (Betrieb, Anlage, Region, Reinigung)
11. ✅ Supabase DTOs (Betrieb, Anlage, Region)

### Erledigt am 20.02.2026
12. ✅ Alle 24 Supabase DTOs erstellt (fromJson/toJson)
13. ✅ Alle 12 Isar Local-Models + SyncMetaLocal (13 Collections total)
14. ✅ `@Index()` auf serverId + isSynced für alle 12 Local-Models
15. ✅ 12 Mapper-Klassen (Local ↔ DTO Konvertierung)
16. ✅ ConnectivityService (Online/Offline-Erkennung, Stream)
17. ✅ SyncService (~580 Zeilen, Push/Pull für alle 12 Entitäten)
    - Push: isSynced=false → Supabase upsert
    - Pull: Incremental (updated_at > lastPullAt), Bierleitung: Full-Pull
    - Konflikt: Last Write Wins (Timestamp-Vergleich)
    - Auto-Sync bei Connectivity-Change
    - Tier-basierte Sync-Reihenfolge (FK-Abhängigkeiten)
18. ✅ 4 Core-Repositories (Region, Betrieb, Anlage, Reinigung)
19. ✅ 3 Riverpod Providers (Connectivity, Sync, Betrieb)
20. ✅ Login-Integration (SyncService startet nach Login)
21. ✅ `flutter analyze` – 0 eigene Issues
22. ✅ Design System (AppColors, AppTheme.light, Material 3)
23. ✅ Dashboard / Home Screen (Kacheln mit Live-Counts, Sync-Banner, Menü)
24. ✅ Betriebe CRUD (Liste mit Suche/Filter, Detail mit Sektionen, Form)
25. ✅ Betrieb-Provider (Stream, List, Count)
26. ✅ Anlagen CRUD (Liste, Detail mit Bierleitungen, Form)
27. ✅ Anlagen-Provider (Stream, List, Count, byBetrieb Family)
28. ✅ BierleitungRepository (CRUD + watchByAnlage)
29. ✅ Betrieb-Detail mit Anlagen-Sektion (Stream, "Neue Anlage"-Button)
30. ✅ GoRouter: 12 Routes (Login, Home, 4× Betriebe, 4× Anlagen, 4× Reinigungen)
31. ✅ Supabase auf Pro-Plan upgraded
32. ✅ Reinigungen CRUD (Liste mit Suche/Status-Filter, Detail mit Checkliste+Progress-Ring, Form mit Service-Flow)
33. ✅ Reinigung-Provider (Stream, List, Count, byAnlage, byBetrieb)
34. ✅ Reinigungen in Anlage-Detail (Sektion mit Stream, "Neue Reinigung"-Button)
35. ✅ Service-Flow: 4 Anlagen-Checks + 12 Service-Punkte + Zeiterfassung + Abschliessen
36. ✅ Störungen CRUD (Liste mit Suche/Status-Filter, Detail mit Bereich 1-5/Preis/Material, Form mit Pikett/Bergkunde)
37. ✅ Störung-Provider (Stream, List, Count, byAnlage, byBetrieb)
38. ✅ Störungen in Anlage-Detail (Sektion mit Stream, "Neue Störung"-Button)
39. ✅ Störungsnummer-Generator (STR-YYYYMM-NNN)
40. ✅ GoRouter: 16 Routes (Login, Home, 4× Betriebe, 4× Anlagen, 4× Reinigungen, 4× Störungen)
41. ✅ Navigation: context.go() → context.push() (27 Stellen, Back-Buttons überall)
42. ✅ Windows Desktop Build (Visual Studio C++, Developer Mode)

### Erledigt am 07.03.2026
43. ✅ Web-Deployment auf GitHub Pages (Conditional Exports, kIsWeb-Branching)
44. ✅ Alle 6 Repositories mit Web-Support (Supabase direkt auf Web, Isar auf Native)
45. ✅ `routeId` Getter auf allen Local Models (Web: serverId, Native: id)
46. ✅ String-basierte IDs im Router und allen 12 Screens
47. ✅ Web-Stubs für Isar Models (`*_local_web.dart`)
48. ✅ Web-Shortcuts für Connectivity/Sync Provider
49. ✅ Android APK Build + Emulator-Test (Sync funktioniert)
50. ✅ Isar Extension Bug behoben (Extensions funktionieren nicht auf `dynamic`)
51. ✅ IsarService mit typed Query Methods (alle Isar-Queries zentral gewrappt)
52. ✅ 6 Repositories auf `IsarService.xxxMethod()` Pattern refactored
53. ✅ Web-Build + Native-Build beide fehlerfrei (`flutter analyze`)
54. ✅ Betrieb-Formular erweitert (Heineken-Nr → Betrieb Nr, Rechnungsstellung-Dropdown, Saison-Details, Region-Dropdown)
55. ✅ DB Migration 008 (betrieb_nr, rechnungsstellung Enum, saison_start/ende)
56. ✅ BetriebKontakt CRUD komplett (Repository, Form-Screen, Detail-Section, Web-Stubs, Sync)
57. ✅ BetriebRechnungsadresse CRUD komplett (Isar Model, Mapper, Repository, Form-Screen, Detail-Section, Web-Stubs, Sync)
58. ✅ 8 Repositories (+ BetriebKontakt, BetriebRechnungsadresse)
59. ✅ 19 Routes im GoRouter (+ Kontakt-Create/Edit, Rechnungsadresse)
60. ✅ Betrieb MVP abgeschlossen
61. ✅ Anlage-Formular: Vorkühler-Dropdown korrigiert ('nass'/'trocken' → DB-Werte 'Fasskühler'/'Kühlzelle'/'Buffet')
62. ✅ Anlage-Formular: Durchlaufkühler Freitext → Dropdown (9 DB-Optionen)
63. ✅ Anlage-Formular: Säulen-Typ Freitext → Dropdown (14 DB-Optionen)
64. ✅ Anlage-Formular: Gas-Typ 1/2 Freitext → Dropdown (3 DB-Optionen) + Cross-Validierung
65. ✅ Anlage-Formular: Reinigung-Rhythmus korrigiert (8 korrekte DB-Optionen)
66. ✅ Anlage-Formular: Status 'stillgelegt' hinzugefügt
67. ✅ Anlage-Detail: Vorkühler-Label Fix
68. ✅ Bierleitung CRUD komplett (Form-Screen, Auto-Nummer, Add/Edit/Delete im Detail)
69. ✅ 21 Routes im GoRouter (+ Bierleitung-Create/Edit)
70. ✅ Anlagen MVP abgeschlossen
71. ✅ Gast-User in Supabase erstellt (`gast@sbsprojer.ch`)
72. ✅ DB Migration 009: RLS SELECT-Policies für Gast auf 9 Tabellen
73. ✅ SupabaseService erweitert: `isGuest`, `dataUserId` (Gast sieht Daniels Live-Daten)
74. ✅ 8 Repositories: `_userId` → `SupabaseService.dataUserId`
75. ✅ GoRouter: Redirect-Guard für Form-Routes (Gast kann keine `/neu`/`/bearbeiten`-URLs aufrufen)
76. ✅ 5 UI-Screens: Create/Edit/Delete-Buttons für Gast ausgeblendet (3-Schicht-Sicherheit: DB + Router + UI)
77. ✅ Web-Build + Deploy auf GitHub Pages mit Gastzugang

### Erledigt am 11.03.2026
78. ✅ Auth Provider (authStateProvider, isAuthenticatedProvider, currentUserProvider)
79. ✅ Passwort vergessen (Dialog mit Reset-Link, redirectTo Web-App)
80. ✅ Reaktiver Auth-Guard (GoRouter refreshListenable, automatischer Redirect)
81. ✅ Session-Refresh beim App-Start (bei Fehler automatisch signOut)
82. ✅ Passwort-Recovery-Dialog (Neues Passwort setzen nach Reset-Link)
83. ✅ Tourenplanung Basis (Kalender-Wochenansicht, Tour-Vorschlag ±2 Tage, Drag & Drop, Filter, Dashboard-Kachel)
84. ✅ Unterschriften (Signature-Widget, Techniker + Kunde, Base64-PNG)
85. ✅ Fotos (image_picker, Supabase Storage, Max 4/Anlage, Grid + Vollbild)
86. ✅ Preis-Kalkulator (Reinigung + Störung, Live-Preview, Preisliste aus DB)
87. ✅ Betriebe-Filter erweitert (Meine Kunden, Region Multi-Select, Status Default Aktiv)
88. ✅ Bierleitung-Delete Refresh-Fix + Hahn-Typ Dropdown
89. ✅ BackButton-Fix (context.pop statt Navigator.maybePop)
90. ✅ Löschen-Funktion für Betriebe, Anlagen, Reinigungen & Störungen (Cascade)
91. ✅ Checkliste-Notizen pro Punkt (Migration 013)

### Erledigt am 12.03.2026
92. ✅ Reinigungsprotokoll-PDF (Heineken FOR 1220/Vers.04, Supabase Storage, Printing)
93. ✅ Kundenrechnung komplett:
    - RechnungRepository + RechnungsPositionRepository (Supabase-only)
    - RechnungService (Auto-Erstellung bei Reinigung-Abschluss)
    - RechnungPdfService (A4-PDF mit Swiss QR-Einzahlungsschein)
    - RechnungPdfStorage (Bucket: rechnung-pdfs)
    - Rechnungen-Liste + Detail-Screen (Suche, Status-Filter, PDF-Druck)
    - Rechnung-Providers (Stream, Count, offene, byBetrieb)
    - Dashboard-Kachel ("X offen")
    - Routes: /rechnungen, /rechnungen/:id

### Erledigt am 12.03.2026 (Abend)
94. ✅ Materialverwaltung komplett:
    - 4 Repositories (Lager, MaterialKategorie, MaterialArtikel, MaterialVerbrauch)
    - Material-Providers (materialienStream, materialCount, niedrigCount)
    - Materialien-Liste (Suche, Kategorie-Filter, Bestand-Filter niedrig)
    - Material-Detail (Bestand-Visualisierung, Info, Verbrauchshistorie, Quick-Bestand-Anpassung)
    - Material-Formular (Kategorie, Einheit, Bestand aktuell/mindest/optimal, Lieferant, Heineken-Artikel-Picker)
    - Bestellliste (niedrige Bestände, Fehlmenge, Zwischenablage-Export)
    - Dashboard-Kachel "Material" mit "X niedrig" Badge
    - Material-Picker in Störungs-Formular (5 progressive Slots)
    - Störung-Detail: Lager-Namen statt UUIDs
    - 5 Routes (/materialien, /bestellliste, /neu, /:id, /:id/bearbeiten)

### Erledigt am 13.03.2026
95. ✅ Montage CRUD komplett (Liste, Detail, Form, Router, Home, Betrieb-Detail Section, Sync)
96. ✅ Montage vereinfacht (Beschreibung als Pflichtfeld, Datum, Uhrzeit, Betrieb-Autocomplete, Material 3 Slots)
97. ✅ Betrieb: Ruhetage + Ferien-Management für alle Betriebe (DB Migration 014)
98. ✅ Pikett-Dienste CRUD komplett (Liste, Detail, Form, Router, Home, Sync, Pauschale 80 CHF)
99. ✅ Störungen von Anlage entkoppelt (DB Migration 016, anlage_id optional, betrieb_id direkt)
100. ✅ Störungs-Formular vereinfacht (Betrieb-Autocomplete, MwSt entfernt, Preis-Keys fix)
101. ✅ Störungen-Section auf Betrieb-Detail + Autocomplete im Form
102. ✅ Eigenauftrag CRUD komplett (Migration 017, Model, Local, Mapper, IsarService, Repository, Providers, 3 Screens, Router, Home, Betrieb-Detail Section, Sync)
103. ✅ Eigenauftrag: Lösung + Notizen Felder entfernt (nicht benötigt)

### Erledigt am 14.03.2026
104. ✅ Saison-Felder von Monat (int) zu Datum umgestellt (DB Migration 018, DatePicker statt Dropdown)
105. ✅ Eröffnungsreinigung CRUD komplett:
    - DB Migration 019 (eroeffnungsreinigungen Tabelle + RLS)
    - DTO, Isar Local Model, Web-Stub, Conditional Export, Mapper
    - IsarService Methoden + Web-Stubs (8 Methoden)
    - Repository + Providers
    - 3 Screens (Liste, Detail, Form)
    - Betrieb-Autocomplete → automatische Bergkunde-Erkennung
    - Preis automatisch aus Preistabelle (Normal 60 CHF, Bergkunde 135 CHF)
    - Eröffnungsreinigungen-Section auf Betrieb-Detail
    - Router (4 Routes) + Home Tile + Sync

### Erledigt am 15.03.2026
106. ✅ Heineken Monatsrechnung komplett:
    - HeinekenRechnungService (8 Kategorien aggregieren, Supabase-Queries)
    - HeinekenPdfService (Übersicht + Detail im Heineken-Format)
    - HeinekenMonatsDaten Model (Summen + Raw Data)
    - 3 Screens: Liste, Generierung (Monats-Picker + Vorschau), Detail
    - Heineken Providers + Router + Home-Kachel
107. ✅ 6 Heineken Rapport-PDFs:
    - HeinekenRapportService: F_Störung, F_Eigenauftrag, F_EE_Reinigung, F_Montage, F_Pikett, F_Pauschale
    - buildXPage() + generateX() Pattern für Wiederverwendung
108. ✅ Rapport-PDFs an Monatsrechnung angehängt:
    - Combined PDF: Hauptrechnung + alle Rapport-Beilagen in einem Dokument
    - _addRapportPages() mit 6 Sektionen
109. ✅ Buchhaltung komplett:
    - 3 Repositories: KontoRepository, BuchungRepository, BuchungsVorlageRepository
    - 4 Provider-Dateien (Konten, Buchungen, Vorlagen, Buchhaltung-Aggregate)
    - BuchungService (Buchung aus Vorlage, Kontosaldo-Berechnung)
    - 7 Screens: Dashboard, Kontenplan, Journal, Buchung-Detail, Buchung-Formular, Berichte, Mahnwesen
    - Berichte: Erfolgsrechnung (monatlich/jährlich) + MwSt-Abrechnung (quartalsweise) aus DB-Views
    - Mahnwesen: Überfällige Rechnungen, Mahnstufen 0-3
    - 7 neue Routes unter /buchhaltung/*
    - Home-Kachel "Buchhaltung"

### Nächste Schritte (Phase 4: Polish & Testing)
1. ☐ Heineken Monatsrechnung testen (wenn mehr Aufträge erfasst sind)
2. ☐ Heineken Rapport-PDFs Layout-Fehler beheben
3. ☐ Buchhaltung Screens testen und Fehler beheben
4. ☐ Betriebe nach System-Typ unterscheiden (Konventionell/Buffet/Orion/David/Heigenie)
5. ☐ Materialbestellung / Materialliste kontrollieren
6. ☐ UI/UX Verbesserungen (alle Screens durchgehen)
7. ☐ Beta-Testing mit Daniel (reale Umgebung)
8. ☐ Bug-Fixes
9. ☐ App Store Submissions (iOS + Android)

---

## 📞 KONTAKTE & RESSOURCEN

### Accounts
- **Supabase**: ✅ Vorhanden
- **GitHub**: ✅ Vorhanden
- **Apple Developer**: ⏳ Benötigt für iOS-Deployment
- **Google Play Developer**: ⏳ Benötigt für Android-Deployment

### Links
- Supabase Dashboard: [https://supabase.com/dashboard](https://supabase.com/dashboard)
- Flutter Docs: [https://flutter.dev/docs](https://flutter.dev/docs)
- Supabase Docs: [https://supabase.com/docs](https://supabase.com/docs)

---

**Zuletzt aktualisiert**: 15.03.2026 – Phase 3 abgeschlossen! Heineken Monatsrechnung (8 Kategorien, 6 Rapport-PDFs), Buchhaltung komplett (Dashboard, Kontenplan, Journal, Buchungen, Berichte, Mahnwesen). Alle Features implementiert.
**Nächstes Update**: Nach Phase 4 (Polish & Testing)

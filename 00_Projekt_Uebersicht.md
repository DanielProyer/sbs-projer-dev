# SBS Projer App - Projekt-Übersicht

**Projekt**: Service-Management App für Zapfanlagen-Service
**Kunde**: Daniel Projer, SBS Projer GmbH
**Stand**: 20.02.2026
**Tech-Stack**: Flutter + Supabase

---

## 📊 PROJEKT-STATUS

### Aktueller Stand: **Phase 1 - Setup & Grundlagen** 🔄

| Phase | Status | Fortschritt | Fertig am |
|-------|--------|-------------|-----------|
| **Phase 0: Planung & Analyse** | ✅ Abgeschlossen | 100% | 12.02.2026 |
| **Phase 1: Setup & Grundlagen** | ✅ Abgeschlossen | 100% | 20.02.2026 |
| **Phase 2: Core Features (MVP)** | 🔄 Laufend | 40% | - |
| **Phase 3: Administration** | 📅 Geplant | 0% | - |
| **Phase 4: Polish & Testing** | 📅 Geplant | 0% | - |
| **Phase 5: Deployment & Launch** | 📅 Geplant | 0% | - |

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
| 🔄 Authentication (Supabase Auth) | Basis-Login ✅ | 🔴 Hoch | 2 Tage |
| ✅ Betriebe CRUD (Liste, Detail, Form, Providers) | Abgeschlossen | 🔴 Hoch | 20.02.2026 |
| ✅ Anlagen CRUD (Liste, Detail, Form, Providers, Bierleitungen) | Abgeschlossen | 🔴 Hoch | 20.02.2026 |
| ✅ Reinigungen CRUD (Liste, Detail, Form, Providers, Service-Flow) | Abgeschlossen | 🔴 Hoch | 20.02.2026 |
| ✅ Störungen CRUD (Liste, Detail, Form, Providers, Störungsnummer) | Abgeschlossen | 🔴 Hoch | 20.02.2026 |
| 📅 Tourenplanung (Basis) | Ausstehend | 🔴 Hoch | 5 Tage |
| 📅 Service-Protokoll (Erweiterung: Unterschriften, Fotos) | Ausstehend | 🔴 Hoch | 4 Tage |
| 📅 Unterschriften-Funktion | Ausstehend | 🔴 Hoch | 2 Tage |
| 📅 Foto-Upload | Ausstehend | 🔴 Hoch | 2 Tage |
| 📅 Preis-Kalkulator | Ausstehend | 🟡 Mittel | 3 Tage |

### Phase 3: Administration (Woche 9-12)

| Feature | Status | Priorität | Zeitschätzung |
|---------|--------|-----------|---------------|
| 📅 Rechnung-Generierung (PDF) | Ausstehend | 🔴 Hoch | 5 Tage |
| 📅 Materialverwaltung | Ausstehend | 🔴 Hoch | 5 Tage |
| 📅 Störungs-Management | Ausstehend | 🔴 Hoch | 3 Tage |
| 📅 Montage-Management | Ausstehend | 🔴 Hoch | 3 Tage |
| 📅 Monatsrechnung Heineken | Ausstehend | 🔴 Hoch | 4 Tage |
| 📅 Mahnwesen (Basis) | Ausstehend | 🟡 Mittel | 3 Tage |

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
| 📅 Web Deployment (Vercel/Netlify) | Ausstehend | 🔴 Hoch | 1 Tag |
| 📅 Dokumentation (Benutzerhandbuch) | Ausstehend | 🟡 Mittel | 2 Tage |
| 📅 Training für Daniel | Ausstehend | 🔴 Hoch | 1 Tag |
| 📅 Excel-Daten-Migration | Ausstehend | 🟡 Mittel | 2 Tage |

---

## 🎯 MVP FEATURES (Must-Have für Launch)

| Feature | Beschreibung | Status |
|---------|--------------|--------|
| **Betriebe & Anlagen** | CRUD, Suche, Filter | ✅ Erledigt |
| **Tourenplanung** | Tour von vor 1 Monat, Drag & Drop | 📅 Geplant |
| **Service-Protokoll** | 17-Punkt-Checkliste digital | ✅ Basis-CRUD |
| **Unterschriften** | Digital auf Smartphone | 📅 Geplant |
| **Fotos** | Probleme dokumentieren | 📅 Geplant |
| **Offline-Sync** | Funktioniert ohne Internet | 📅 Geplant |
| **Rechnungen** | PDF generieren, versenden | 📅 Geplant |
| **Materialverwaltung** | Bestand tracken, Bestellliste | 📅 Geplant |
| **Störungen** | Mit Störungsnummer, flexibel | ✅ Basis-CRUD |
| **Montagen** | Zeiterfassung, Stundensatz | 📅 Geplant |

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

### Nächste Schritte (KW 9)
1. ☐ Tourenplanung (Basis)
2. ☐ Auth Provider (Riverpod)
3. ☐ Löschen-Funktion für Betriebe, Anlagen, Reinigungen & Störungen
4. ☐ Unterschriften-Widget

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

**Zuletzt aktualisiert**: 20.02.2026 – Betriebe ✅, Anlagen ✅, Reinigungen ✅, Störungen ✅. 6 Repos, 7 Providers, 16 Routes. Navigation mit Back-Buttons. Windows Desktop Build funktioniert. Phase 2 bei 40%.
**Nächstes Update**: Nach Tourenplanung & Unterschriften

# Roadmap - SBS Projer App

**Projekt**: Service-Management App für Zapfanlagen-Service
**Geplanter Start**: KW 8, 2026 (17. Februar 2026)
**Geschätztes MVP-Launch**: KW 25, 2026 (15. Juni 2026)
**Gesamtdauer MVP**: 18 Wochen

---

## 📅 PHASEN-ÜBERSICHT

```
Phase 0: Planung & Analyse         ████████████████████ 100% (Abgeschlossen ✅)
Phase 1: Setup & Grundlagen        ████████████████████ 100% (Abgeschlossen ✅)
Phase 2: Core Features (MVP)       ████████░░░░░░░░░░░░  40% (Laufend 🔄)
Phase 3: Administration            ░░░░░░░░░░░░░░░░░░░░   0% (4 Wochen)
Phase 4: Polish & Testing          ░░░░░░░░░░░░░░░░░░░░   0% (4 Wochen)
Phase 5: Deployment & Launch       ░░░░░░░░░░░░░░░░░░░░   0% (2 Wochen)

                                   └─────────────────────────────────────┘
                                         18 Wochen (MVP)
```

---

## PHASE 0: PLANUNG & ANALYSE ✅

**Dauer**: 4 Wochen (09.01.2026 - 12.02.2026)
**Status**: Abgeschlossen
**Fortschritt**: 100%

### Deliverables ✅
- [x] Geschäftsbeschreibung dokumentiert
- [x] Excel-Daten analysiert (37 Sheets, 8,780 Einträge)
- [x] Heineken Monatsrechnungen analysiert (3 Monate)
- [x] Reinigungsprotokolle analysiert (17-Punkt-Checkliste)
- [x] Störungsbereiche analysiert (5 technische Bereiche)
- [x] Preissystem vollständig dokumentiert
- [x] Geschäftsabläufe detailliert erfasst (9 Abschnitte)
- [x] Tech-Stack-Entscheidung (Flutter + Supabase)
- [x] Heineken Artikelstamm analysiert (885 Artikel, 20 Kategorien, DBO-Nummern)
- [x] PDF-Formulare analysiert (6 Typen: F_Störung, F_Eigenauftrag, F_EE_Reinigung, F_Montage, F_Pikett, F_Pauschale)
- [x] Datenmodell entworfen & finalisiert (23 Tabellen, SQL mit Triggern & RLS)
  - Material/Lager-Architektur (Katalog + Fahrzeugbestand getrennt)
  - Google Calendar Integration (Pikett-Dienste)
  - Automatische PDF-Generierung (formulare-Tabelle)
  - Heineken Artikelstamm (07_Artikelstamm_Heineken.sql, 885 Inserts)

### Key Findings
- 840 Stunden Zeitersparnis/Jahr möglich
- Offline-Fähigkeit kritisch für Bergkunden
- Betrieb → Anlage (1:n) ist Kern-Beziehung
- Administration = größter Zeitfresser (5-10h/Woche)
- Heineken erwartet 6 verschiedene PDF-Formulare pro Monatsabrechnung

---

## PHASE 1: SETUP & GRUNDLAGEN

**Dauer**: 2 Wochen (KW 8-9, 17.02. - 02.03.2026)
**Status**: Abgeschlossen ✅
**Fortschritt**: 100%

### Woche 1 (KW 8): Setup & Konfiguration

#### Tag 1-2 (Mo-Di, 17-18.02.)
- [x] **Datenmodell finalisieren** ✅
  - Datenmodell mit Daniel besprochen & freigegeben
  - 23 Tabellen, Trigger, RLS, Views – vollständig dokumentiert
  - Sign-Off erhalten: 12.02.2026

- [x] **Supabase Projekt erstellt** ✅ (17.02.2026)
  - Projekt in Supabase Dashboard angelegt
  - DB-Connection String gesichert
  - Direkter DB-Zugriff via Python (`db_query.py`) eingerichtet

- [x] **Migration Scripts vorbereitet & ausgeführt** ✅ (17.02.2026)
  - `001_initial_schema.sql` → 24 Tabellen erstellt
  - `002_rls_policies.sql` → 24 RLS Policies aktiv
  - `003_triggers_functions.sql` → 20 Functions/Triggers aktiv
  - `004_views.sql` → 7 Views erstellt
  - `setup_user_seed.sql` → Regionen (11), Kategorien (20), Konten (43), Buchungsvorlagen (74), Preise 2026
  - `007_artikelstamm_heineken.sql` → 883 Heineken-Artikel importiert

- [x] **Flutter Projekt initialisieren** ✅ (17.02.2026)
  - `flutter create --org ch.sbsprojer --project-name sbs_projer_app`
  - Flutter 3.41.1 (Dart 3.11.0) installiert
  - `.gitignore` angepasst (.env geschützt)
  - Android Studio + SDK eingerichtet
  - Edge als CHROME_EXECUTABLE gesetzt

#### Tag 4-5 (Do-Fr, 20-21.02.)
- [x] **Packages installieren** ✅ (17.02.2026)
  - `pubspec.yaml` mit 25+ Dependencies konfiguriert
  - Versionskonflikt `intl` gelöst (Flutter SDK pinned 0.20.2)
  - `flutter pub get` erfolgreich
  - Build Runner für Isar Code-Generierung ausgeführt

- [x] **Projekt-Struktur aufsetzen** ✅ (17.02.2026)
  ```
  lib/
  ├── main.dart
  ├── app.dart
  ├── core/
  │   └── config/          # GoRouter
  ├── data/
  │   ├── models/          # Supabase DTOs (24 Entitäten)
  │   ├── local/           # Isar Models (13 Collections)
  │   ├── mappers/         # Local↔DTO Mapper (12 Entitäten)
  │   └── repositories/    # Data Access Layer (6 Repos: Region, Betrieb, Anlage, Reinigung, Bierleitung, Störung)
  ├── presentation/
  │   ├── screens/
  │   │   ├── home_screen.dart        # Dashboard mit Kacheln & Sync
  │   │   ├── login_screen.dart
  │   │   ├── betriebe/               # Liste, Detail, Form
  │   │   ├── anlagen/                # Liste, Detail, Form
  │   │   ├── reinigungen/            # Liste, Detail, Form
  │   │   └── stoerungen/             # Liste, Detail, Form
  │   ├── providers/       # Riverpod Providers (7: Connectivity, Sync, Betrieb, Anlage, Reinigung, Störung)
  │   └── widgets/
  └── services/
      ├── supabase/        # SupabaseService
      ├── storage/         # IsarService
      ├── sync/            # SyncService (Push/Pull, 12 Entitäten)
      └── connectivity/    # ConnectivityService (Online/Offline)
  ```

- [x] **Supabase Client konfigurieren** ✅ (17.02.2026)
  - `SupabaseService` erstellt (Client, Auth, isAuthenticated)
  - API Keys aus `.env` via `flutter_dotenv`
  - Initialisierung in `main.dart` mit Riverpod `ProviderScope`
  - Login getestet und funktioniert

### Woche 2 (KW 9): Grundlagen & Infrastruktur

#### Tag 1-2 (Mo-Di, 24-25.02.)
- [x] **Isar DB einrichten (Offline)** ✅ (20.02.2026)
  - [x] Isar Schema definiert (13 Collections: 12 Entitäten + SyncMeta)
  - [x] Code-Generierung ausgeführt (`build_runner`)
  - [x] `IsarService` erstellt (initialize, close, singleton, 13 Schemas)
  - [x] `@Index()` auf `serverId` + `isSynced` für alle 12 Local-Models
  - [x] Alle 12 Isar Collections implementiert

- [x] **Sync-Service (Komplett)** ✅ (20.02.2026)
  - [x] `SyncService` erstellt (~580 Zeilen, Push/Pull für alle 12 Entitäten)
  - [x] `ConnectivityService` erstellt (Online/Offline-Erkennung, Stream)
  - [x] `SyncMetaLocal` erstellt (lastPullAt, lastPushAt pro Entität)
  - [x] 12 Mapper-Klassen (Local ↔ DTO Konvertierung)
  - [x] Push: isSynced=false → Supabase upsert
  - [x] Pull: Incremental via updated_at > lastPullAt (Bierleitung: Full-Pull)
  - [x] Conflict Resolution: Last Write Wins (Timestamp-Vergleich)
  - [x] Auto-Sync bei Connectivity-Change (offline → online)
  - [x] SyncState Stream (idle/syncing/error) für UI
  - [x] Tier-basierte Sync-Reihenfolge (FK-Abhängigkeiten)
  - [x] 4 Core-Repositories (Region, Betrieb, Anlage, Reinigung)
  - [x] 3 Riverpod Providers (Connectivity, Sync, Betrieb)
  - [x] Login-Integration (SyncService.startListening + syncAll nach Login)

#### Tag 3-4 (Mi-Do, 26-27.02.)
- [x] **Design System / Theme** ✅ (20.02.2026)
  - [x] AppColors definiert (Heineken-Grün #008200 als Primary)
  - [x] AppTheme.light mit vollem Material 3 Theme
  - [x] AppBar, Card, Input, Button, ListTile, FAB, SearchBar, SnackBar Themes
  - [x] Status-Farben (aktiv, inaktiv, saisonpause, online, offline, syncing)

- [x] **Navigation Setup (go_router)** ✅ (20.02.2026)
  - [x] GoRouter konfiguriert (router.dart)
  - [x] Auth-Guard (redirect bei nicht eingeloggt)
  - [x] Basis-Routes: `/login`, `/`
  - [x] Betriebe-Routes: `/betriebe`, `/betriebe/neu`, `/betriebe/:id`, `/betriebe/:id/bearbeiten`
  - [x] Anlagen-Routes: `/anlagen`, `/anlagen/neu`, `/anlagen/:id`, `/anlagen/:id/bearbeiten`
  - [x] Reinigungen-Routes: `/reinigungen`, `/reinigungen/neu`, `/reinigungen/:id`, `/reinigungen/:id/bearbeiten`
  - [x] Störungen-Routes: `/stoerungen`, `/stoerungen/neu`, `/stoerungen/:id`, `/stoerungen/:id/bearbeiten`
  - [x] Stack-Navigation (context.push) mit Back-Buttons auf allen Screens
  - [ ] Deep-Links

#### Tag 5 (Fr, 28.02.)
- [~] **Authentication (Supabase Auth)** 🔄 (Basis, 17.02.2026)
  - [x] Login Screen (E-Mail/Passwort)
  - [x] SupabaseService mit Auth-Integration
  - [x] Session Management (isAuthenticated)
  - [x] Login getestet – funktioniert ✅
  - [ ] Auth Provider (Riverpod)
  - [ ] Passwort vergessen
  - [ ] Auto-Login bei bestehendem Token

### Deliverables Phase 1
- [x] Supabase Projekt mit Datenbank-Schema ✅ (17.02.2026)
- [x] Flutter Projekt mit Basis-Architektur ✅ (17.02.2026)
- [x] Offline-Sync-Infrastruktur (komplett) ✅ (20.02.2026)
- [x] Design System implementiert ✅ (20.02.2026)
- [~] Authentication funktioniert (Basis-Login ✅, Riverpod Provider ausstehend)

---

## PHASE 2: CORE FEATURES (MVP)

**Dauer**: 6 Wochen (KW 10-15, 03.03. - 13.04.2026)
**Status**: Laufend 🔄
**Fortschritt**: 40%

### Woche 3 (KW 10): Datenmodell in Code

- [x] **Supabase Models** ✅ (vorgezogen, 20.02.2026)
  - [x] 24 Supabase DTOs erstellt (fromJson/toJson)
  - Betrieb, Anlage, Region, Reinigung, Störung, Montage, Eigenauftrag,
    PikettDienst, BetriebKontakt, Bierleitung, Preis, Lager,
    + Admin-Models (Rechnung, RechnungsPosition, Formular, Konto,
    BuchungsVorlage, Buchung, MaterialArtikel, MaterialKategorie,
    MaterialVerbrauch, UserProfile, BetriebRechnungsadresse, AnlageFoto)

- [x] **Isar Models** ✅ (vorgezogen, 20.02.2026)
  - [x] 12 Isar Collections mit Sync-Felder (serverId, isSynced, lastModifiedAt)
  - [x] + SyncMetaLocal Collection (Sync-Timestamps)
  - [x] Alle mit `@Index()` auf serverId + isSynced

### Woche 4 (KW 11): Betriebe & Anlagen

- [x] **Betriebe CRUD** ✅ (20.02.2026)
  - [x] Dashboard / Home Screen (Kacheln, Sync-Banner, Menü)
  - [x] Betriebe-Liste (mit Suche, Status-Filter, Sync-Indicator)
  - [x] Betrieb-Detail-Screen (Sektionen: Adresse, Kontakt, Details, Saison, Notizen, Anlagen)
  - [x] Betrieb erstellen/bearbeiten (Formular mit Validierung)
  - [x] Betrieb-Provider (betriebeStream, betriebeProvider, betriebCount)
  - [ ] Betrieb löschen

- [x] **Anlagen CRUD** ✅ (20.02.2026)
  - [x] Anlagen-Liste (globale Ansicht mit Suche, Status-Filter, Betrieb-Name)
  - [x] Anlagen in Betrieb-Detail (Sektion mit Stream, "Neue Anlage"-Button)
  - [x] Anlage-Detail-Screen (Grunddaten, Kühlung/Gas, Service, Reinigung, Bierleitungen)
  - [x] Anlage erstellen/bearbeiten (Formular mit allen Feldern)
  - [x] Anlage-Provider (anlagenStream, anlagenProvider, anlageCount, anlagenByBetrieb)
  - [x] Bierleitung-Repository (CRUD + watchByAnlage)
  - [ ] Anlage löschen

- [x] **Reinigungen CRUD** ✅ (20.02.2026)
  - [x] Reinigungen-Liste (globale Ansicht, Suche, Status-Filter, Betrieb-Name, Datum sortiert)
  - [x] Reinigung-Detail-Screen (Zeiterfassung, Checkliste mit Progress-Ring, Preis, Unterschriften)
  - [x] Reinigung-Form-Screen (Service-Flow: 4 Anlagen-Checks + 12 Service-Punkte, Abschliessen-Button)
  - [x] Reinigung-Provider (Stream, List, Count, byAnlage Family, byBetrieb Family)
  - [x] Reinigungen in Anlage-Detail (Sektion mit Stream, "Neue Reinigung"-Button, max 5 Anzeige)
  - [ ] Reinigung löschen

- [x] **Störungen CRUD** ✅ (20.02.2026)
  - [x] Störungen-Liste (Suche, Status-Filter, Betrieb-Name, Pikett-Badge, Störungsnummer)
  - [x] Störung-Detail-Screen (Zeiterfassung, Bereich 1-5, Problem/Lösung, Preis, Material, Zusatzinfos)
  - [x] Störung-Form-Screen (Bereichs-Dropdown, Problem/Lösung, Pikett/Bergkunde/Wochenende, Abschliessen)
  - [x] Störung-Provider (Stream, List, Count, byAnlage Family, byBetrieb Family)
  - [x] Störungen in Anlage-Detail (Sektion mit Stream, "Neue Störung"-Button, max 5 Anzeige)
  - [x] Auto-generierte Störungsnummer (STR-YYYYMM-NNN)
  - [ ] Störung löschen

### Woche 5 (KW 12): Tourenplanung

- [ ] **Tourenplanung (Basis)** (5 Tage)
  - Kalender-View (Wochen-Ansicht)
  - "Tour von vor 1 Monat" Funktion
  - Drag & Drop für Reihenfolge
  - Filter: Region, Anlagentyp, Status
  - Anlagen fällig/überfällig anzeigen

### Woche 6-7 (KW 13-14): Service-Protokoll

- [ ] **Service-Protokoll erstellen** (4 Tage)
  - Service-Flow UI
  - Start/Stop Zeit-Tracking
  - 17-Punkt-Checkliste (JSONB)
  - Notizen pro Punkt
  - Service abschließen

- [ ] **Unterschriften** (2 Tage)
  - Signature-Widget integrieren
  - Techniker unterschreibt
  - Kunde unterschreibt
  - Als Base64 speichern

- [ ] **Fotos** (2 Tage)
  - Kamera-Integration
  - Foto aufnehmen
  - Lokal speichern
  - Bei Online: Upload zu Supabase Storage
  - Galerie-View

- [ ] **Preis-Kalkulator** (2 Tage)
  - Automatische Preisberechnung
  - Anlagentyp → Grundtarif
  - Bergkunde-Zuschlag (+100 CHF)
  - Zusatzkosten manuell
  - Total anzeigen

### Woche 8 (KW 15): Offline-Sync & Testing

- [ ] **Offline-Sync finalisieren** (3 Tage)
  - Alle Entitäten syncen
  - Background-Sync bei Verbindung
  - Sync-Status anzeigen
  - Fehlerbehandlung

- [ ] **Testing Core Features** (2 Tage)
  - Manuelles Testing aller Features
  - Offline-Modus testen
  - Bug-Fixes

### Deliverables Phase 2
- [x] Betriebe & Anlagen vollständig verwaltbar
- [x] Tourenplanung funktioniert
- [x] Service-Protokoll digital
- [x] Unterschriften & Fotos funktionieren
- [x] Offline-Sync stabil

---

## PHASE 3: ADMINISTRATION

**Dauer**: 4 Wochen (KW 16-19, 14.04. - 11.05.2026)
**Status**: Geplant
**Fortschritt**: 0%

### Woche 9 (KW 16): Rechnungen

- [ ] **Rechnungs-Generierung** (5 Tage)
  - Rechnung aus Services erstellen
  - PDF generieren (pdf Package)
  - Rechnungsnummer automatisch
  - MWST-Berechnung (8.1%)
  - Rechnungs-Positionen
  - PDF teilen (E-Mail, WhatsApp)

### Woche 10 (KW 17): Material

- [ ] **Materialverwaltung** (5 Tage)
  - Material-Katalog
  - Material anlegen/bearbeiten
  - Bestand tracken
  - Materialverbrauch erfassen
  - Automatisch abziehen bei Service
  - Warnung bei niedrigem Bestand
  - Bestellliste generieren

### Woche 11 (KW 18): Störungen & Montagen

- [x] **Störungs-Management** ✅ (vorgezogen, 20.02.2026 — CRUD in Phase 2)
  - [x] Störung erfassen (mit Störungsnummer STR-YYYYMM-NNN)
  - [x] Störungsbereich auswählen (5 Bereiche)
  - [ ] Flexible Einfügung in Tagesplan
  - [ ] Ablauf wie Service (Protokoll, Unterschrift)

- [ ] **Montage-Management** (2 Tage)
  - Montage erfassen
  - Zeiterfassung (Start/Ende)
  - Automatische Berechnung (80 CHF/h)
  - Material/Werkzeug-Checkliste

- [ ] **Pikett-Einsätze** (1 Tag)
  - Pikett-Plan anzeigen
  - Pikett-Status
  - Pauschale (160 CHF) automatisch

### Woche 12 (KW 19): Monatsrechnung Heineken & PDF-Formulare

- [ ] **Heineken PDF-Formulare** (3 Tage)
  - PDF-Template-Engine einrichten (z.B. `pdf` Package)
  - F_Störung generieren (Anlagetyp, Bereich, Material 3 Pos.)
  - F_Eigenauftrag generieren (30 CHF Pauschale, Material 3 Pos.)
  - F_EE_Reinigung generieren (135 CHF Bergkunde)
  - F_Montage generieren (Stunden × 80 CHF, Material 7 Pos.)
  - F_Pikett generieren (160 CHF + Feiertag 80 CHF, KW-Format)
  - F_Pauschale generieren (180 CHF Anfahrt Bergrestaurant)
  - PDFs in Supabase Storage ablegen (bucket: `formulare`)
  - referenz_nr automatisch generieren

- [ ] **Monatsrechnung Heineken** (2 Tage)
  - Alle Services eines Monats aggregieren
  - PDFs der zugehörigen Formulare anhängen
  - Gesamtrechnung PDF generieren
  - An Heineken senden

- [ ] **Mahnwesen (Basis)** (1 Tag)
  - Überfällige Rechnungen anzeigen
  - Mahnung erstellen (PDF)
  - Optional: Automatische Erinnerung

### Deliverables Phase 3
- [x] Rechnungen automatisch erstellen & versenden
- [x] Materialverwaltung funktioniert
- [x] Störungen & Montagen erfassbar
- [x] Heineken-Monatsrechnung automatisch

---

## PHASE 4: POLISH & TESTING

**Dauer**: 4 Wochen (KW 20-23, 12.05. - 08.06.2026)
**Status**: Geplant
**Fortschritt**: 0%

### Woche 13 (KW 20): UI/UX Verbesserungen

- [ ] **UI-Polish** (5 Tage)
  - Alle Screens durchgehen
  - Spacing, Alignment, Farben
  - Loading-States
  - Error-States
  - Empty-States
  - Animationen (subtle)

### Woche 14 (KW 21): Testing

- [ ] **Offline-Sync Testing** (2 Tage)
  - Verschiedene Szenarien testen
  - Konflikt-Resolution testen
  - Daten-Integrität prüfen

- [ ] **Performance-Optimierung** (2 Tage)
  - Langsame Queries optimieren
  - Bilder komprimieren
  - Lazy Loading
  - Caching

- [ ] **Bug-Fixes** (1 Tag)
  - Bekannte Bugs beheben

### Woche 15-16 (KW 22-23): Beta-Testing

- [ ] **Beta-Testing mit Daniel** (10 Tage)
  - Daniel testet in realer Umgebung
  - Feedback sammeln
  - Prioritäten für Fixes setzen
  - Bugs beheben
  - Usability-Anpassungen

### Deliverables Phase 4
- [x] App ist stabil und performant
- [x] Offline-Sync funktioniert zuverlässig
- [x] Daniel ist zufrieden mit Usability
- [x] Alle kritischen Bugs behoben

---

## PHASE 5: DEPLOYMENT & LAUNCH

**Dauer**: 2 Wochen (KW 24-25, 09.06. - 22.06.2026)
**Status**: Geplant
**Fortschritt**: 0%

### Woche 17 (KW 24): App Store Submissions

- [ ] **iOS Vorbereitung** (2 Tage)
  - App Icons (alle Größen)
  - Screenshots (alle Geräte)
  - App Store Listing Text
  - Build für Release

- [ ] **iOS Submission** (1 Tag)
  - Apple Developer Account (99 USD/Jahr)
  - App Store Connect Upload
  - Review-Prozess starten (7-14 Tage)

- [ ] **Android Vorbereitung** (1 Tag)
  - Play Store Icons
  - Screenshots
  - Store Listing Text
  - Build signieren

- [ ] **Android Submission** (1 Tag)
  - Google Play Developer Account (25 USD einmalig)
  - Play Console Upload
  - Review-Prozess starten (1-3 Tage)

### Woche 18 (KW 25): Web & Dokumentation

- [ ] **Web Deployment** (1 Tag)
  - Flutter Web Build
  - Deployment zu Vercel/Netlify
  - Custom Domain (optional)

- [ ] **Dokumentation** (2 Tage)
  - Benutzerhandbuch erstellen (PDF)
  - Video-Tutorial aufnehmen (optional)
  - FAQ

- [ ] **Training für Daniel** (1 Tag)
  - Walk-Through aller Features
  - Best Practices
  - Troubleshooting

- [ ] **Excel-Daten-Migration** (1 Tag)
  - Historische Daten importieren
  - Betriebe & Anlagen
  - Letzte 12 Monate Services (optional)
  - Daten-Qualität prüfen

### Deliverables Phase 5
- [x] App in iOS App Store (pending review)
- [x] App in Google Play Store (approved)
- [x] Web-App live
- [x] Dokumentation & Training komplett
- [x] Historische Daten importiert

---

## 🎯 MILESTONES

| Milestone | Datum | Beschreibung |
|-----------|-------|--------------|
| **M0: Planung abgeschlossen** | ✅ 12.02.2026 | Alle Analysen, Datenmodell (23 Tab.), PDF-Formulare, Artikelstamm |
| **M0.5: Datenbank live** | ✅ 17.02.2026 | Supabase DB komplett: 24 Tabellen, Seeds, RLS, Triggers, Views |
| **M1: Setup komplett** | ✅ 20.02.2026 | Supabase + Flutter + Design System + Sync-Service komplett |
| **M2: Core Features MVP** | 🔄 13.04.2026 | Betriebe ✅, Anlagen ✅, Reinigungen ✅, Störungen ✅, Tourenplanung ausstehend |
| **M3: Administration komplett** | 📅 11.05.2026 | Rechnungen, Material, PDF-Formulare, Heineken-Monatsrechnung |
| **M4: Beta-Testing** | 📅 08.06.2026 | App stabil, Daniel testet |
| **M5: Launch** | 📅 22.06.2026 | App in Stores, Web live |

---

## 🚧 RISIKEN & ABHÄNGIGKEITEN

### Risiken

| Risiko | Wahrscheinlichkeit | Impact | Mitigation |
|--------|-------------------|--------|------------|
| Offline-Sync komplexer als erwartet | 🟡 Mittel | 🔴 Hoch | Früh testen, Fallback-Strategie |
| Datenmodell muss angepasst werden | 🟢 Niedrig | 🟡 Mittel | Review vor Start Phase 2 |
| Apple/Google Review-Ablehnung | 🟡 Mittel | 🟡 Mittel | Guidelines genau befolgen |
| Performance-Probleme | 🟡 Mittel | 🟡 Mittel | Frühzeitig auf echten Geräten testen |
| Supabase Free Tier Limits | ✅ Erledigt | - | Upgrade zu Pro am 20.02.2026 |

### Kritische Abhängigkeiten

1. **Datenmodell finalisiert** → Phase 1 kann starten
2. **Supabase Setup** → Flutter kann Daten laden
3. **Offline-Sync funktioniert** → Bergkunden können App nutzen
4. **Daniel testet** → Feedback für Usability
5. **Review-Prozess** → Launch-Datum fixiert

---

## 📊 ZEITAUFWAND-SCHÄTZUNG

### Pro Phase (in Personentagen)

| Phase | Dauer | Personentage | Stunden (à 8h) |
|-------|-------|--------------|----------------|
| Phase 0: Planung | 4 Wochen | - | - (bereits gemacht) |
| Phase 1: Setup | 2 Wochen | 8 | 64h |
| Phase 2: Core Features | 6 Wochen | 24 | 192h |
| Phase 3: Administration | 4 Wochen | 16 | 128h |
| Phase 4: Polish & Testing | 4 Wochen | 16 | 128h |
| Phase 5: Deployment | 2 Wochen | 8 | 64h |
| **TOTAL MVP** | **18 Wochen** | **72 Tage** | **576h** |

### Bei 4h/Tag Entwicklungszeit

- **144 Tage** (ca. 7 Monate Kalenderzeit)
- **Realistisches Launch**: September 2026

### Bei 8h/Tag Entwicklungszeit (Vollzeit)

- **72 Tage** (ca. 3.5 Monate Kalenderzeit)
- **Realistisches Launch**: Juni 2026

**Empfehlung**: 4-6h/Tag als realistisches Ziel für Nebenprojekt

---

## 🔄 POST-MVP ROADMAP

### Phase 6: Skalierung für Franchise-Partner (Q3-Q4 2026)

- [ ] Multi-Tenant UI (Benutzer wechseln)
- [ ] Admin-Panel (für Daniel als Franchise-Coordinator)
- [ ] Statistiken & Reporting
- [ ] Performance-Optimierung für mehr User

### Phase 7: Advanced Features (2027)

- [ ] Internet-Abgleich (Google Business API)
- [ ] GPS-Tracking & Routenoptimierung
- [ ] Push-Notifications
- [ ] Erweiterte Statistiken & Analytics
- [ ] CRM-Features (Kundenkommunikation)

---

## 📅 NÄCHSTE TERMINE

| Datum | Termin | Beschreibung |
|-------|--------|--------------|
| ~~**13.02.2026**~~ | ~~Datenmodell-Review~~ | ✅ Vorgezogen auf 12.02. – Datenmodell freigegeben |
| **17.02.2026** | Kickoff Phase 1 | Supabase Projekt anlegen, Migration Scripts |
| **19.02.2026** | Migration Scripts ausführen | Schema in Supabase einspielen & testen |
| **19.02.2026** | Flutter Projekt initialisieren | Projekt-Setup, Packages, Ordnerstruktur |
| **02.03.2026** | M1: Setup komplett | Supabase + Flutter + Auth + Offline-Sync bereit |
| **13.04.2026** | M2: Core Features MVP | Betriebe, Anlagen, Service-Protokoll |

---

**Hinweis**: Diese Roadmap ist eine Schätzung und wird während der Entwicklung angepasst. Nach jeder Phase erfolgt eine Review und ggf. Neu-Planung der nächsten Phase.

**Zuletzt aktualisiert**: 20.02.2026 – Betriebe ✅, Anlagen ✅, Reinigungen ✅, Störungen ✅. 16 Routen mit Stack-Navigation (Back-Buttons), 7 Providers, 6 Repositories. Windows Desktop Build funktioniert. Phase 2 bei 40%. Nächste Schritte: Tourenplanung, Löschen-Funktionen, Unterschriften.

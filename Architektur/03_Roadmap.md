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
Phase 2: Core Features (MVP)       ████████████████████ 100% (Abgeschlossen ✅)
Phase 3: Administration            ████████████████████ 100% (Abgeschlossen ✅)
Phase 4: Polish & Testing          ░░░░░░░░░░░░░░░░░░░░   0% (3-4 Wochen)
Phase 5: Deployment & Launch       ████░░░░░░░░░░░░░░░░  20% (Vorgezogen 🔄)

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
  │   └── repositories/    # Data Access Layer (12 Repos: Region, Betrieb, Anlage, Reinigung, Bierleitung, Störung, BetriebKontakt, BetriebRechnungsadresse, Rechnung, Lager, MaterialKategorie, MaterialArtikel, MaterialVerbrauch)
  ├── presentation/
  │   ├── screens/
  │   │   ├── home_screen.dart        # Dashboard mit Kacheln & Sync
  │   │   ├── login_screen.dart
  │   │   ├── betriebe/               # Liste, Detail, Form, Kontakte, Rechnungsadresse
  │   │   ├── anlagen/                # Liste, Detail, Form, Bierleitungen
  │   │   ├── reinigungen/            # Liste, Detail, Form
  │   │   ├── stoerungen/             # Liste, Detail, Form
  │   │   ├── rechnungen/             # Liste, Detail (PDF-Druck)
  │   │   ├── materialien/           # Liste, Detail, Form, Bestellliste
  │   │   └── touren/                 # Kalender, Vorschläge
  │   ├── providers/       # Riverpod Providers (10: Connectivity, Sync, Auth, Betrieb, Anlage, Reinigung, Störung, Rechnung, Tour, Material)
  │   └── widgets/
  └── services/
      ├── supabase/        # SupabaseService
      ├── storage/         # IsarService
      ├── sync/            # SyncService (Push/Pull, 12 Entitäten)
      ├── connectivity/    # ConnectivityService (Online/Offline)
      ├── pdf/             # ReinigungPdfService, RechnungPdfService, Storage
      └── rechnung/        # RechnungService (Business-Logic)
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
- [x] **Authentication (Supabase Auth)** ✅ (Basis 17.02.2026, Erweitert 11.03.2026)
  - [x] Login Screen (E-Mail/Passwort)
  - [x] SupabaseService mit Auth-Integration
  - [x] Session Management (isAuthenticated)
  - [x] Login getestet – funktioniert ✅
  - [x] Auth Provider (Riverpod) — authStateProvider, isAuthenticatedProvider, currentUserProvider ✅ 11.03.2026
  - [x] Passwort vergessen — Dialog mit Reset-Link, redirectTo Web-App ✅ 11.03.2026
  - [x] Reaktiver Auth-Guard — GoRouter refreshListenable, automatischer Redirect ✅ 11.03.2026
  - [x] Session-Refresh beim App-Start — bei Fehler automatisch signOut ✅ 11.03.2026
  - [x] Passwort-Recovery-Dialog — Neues Passwort setzen nach Reset-Link ✅ 11.03.2026
  - [ ] **TODO: Auth-Verbesserungen testen** (Passwort vergessen, Recovery-Dialog, Session-Ablauf)

### Deliverables Phase 1
- [x] Supabase Projekt mit Datenbank-Schema ✅ (17.02.2026)
- [x] Flutter Projekt mit Basis-Architektur ✅ (17.02.2026)
- [x] Offline-Sync-Infrastruktur (komplett) ✅ (20.02.2026)
- [x] Design System implementiert ✅ (20.02.2026)
- [x] Authentication funktioniert ✅ (Login, Passwort vergessen, reaktiver Auth-Guard, Session-Refresh)

---

## PHASE 2: CORE FEATURES (MVP)

**Dauer**: 6 Wochen (KW 10-15, 03.03. - 13.04.2026)
**Status**: Laufend 🔄
**Fortschritt**: 95%

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

- [x] **Betriebe CRUD** ✅ (20.02.2026, MVP 07.03.2026)
  - [x] Dashboard / Home Screen (Kacheln, Sync-Banner, Menü)
  - [x] Betriebe-Liste (mit Suche, Status-Filter, Sync-Indicator)
  - [x] Betrieb-Detail-Screen (Sektionen: Adresse, Kontakt, Details, Saison, Notizen, Anlagen)
  - [x] Betrieb erstellen/bearbeiten (Formular mit Validierung)
  - [x] Betrieb-Provider (betriebeStream, betriebeProvider, betriebCount)
  - [x] BetriebKontakt CRUD (Kontaktpersonen, Hauptkontakt, Kontaktmethode) ✅ 07.03.2026
  - [x] BetriebRechnungsadresse CRUD (Firma, Adresse, 1 pro Betrieb) ✅ 07.03.2026
  - [x] Betrieb-Formular erweitert (Betrieb Nr, Rechnungsstellung-Dropdown, Saison-Details, Region-Dropdown) ✅ 07.03.2026
  - [x] DB Migration 008 (Betrieb: heineken_nr → betrieb_nr, rechnungsstellung Enum, saison_start/ende)
  - [x] Betrieb löschen (Cascade: Anlagen, Reinigungen, Störungen, Kontakte, Rechnungsadressen) ✅
  - [x] Betriebe BackButton-Fix (context.pop statt Navigator.maybePop für GoRouter) ✅ 11.03.2026
  - [x] Betriebe-Filter erweitert ✅ 11.03.2026
    - Default "Nur meine Kunden" (istMeinKunde Toggle)
    - Status-Filter: Saisonpause entfernt, Default Aktiv
    - Region Multi-Select (Checkbox-Auswahl, 2-Spalten-Layout)
    - ModalBottomSheet statt PopupMenu
    - Aktive Filter als Chips unter Suchleiste

- [x] **Anlagen CRUD** ✅ (20.02.2026, MVP 07.03.2026)
  - [x] Anlagen-Liste (globale Ansicht mit Suche, Status-Filter, Betrieb-Name)
  - [x] Anlagen in Betrieb-Detail (Sektion mit Stream, "Neue Anlage"-Button)
  - [x] Anlage-Detail-Screen (Grunddaten, Kühlung/Gas, Service, Reinigung, Bierleitungen)
  - [x] Anlage erstellen/bearbeiten (Formular mit allen Feldern)
  - [x] Anlage-Provider (anlagenStream, anlagenProvider, anlageCount, anlagenByBetrieb)
  - [x] Bierleitung-Repository (CRUD + watchByAnlage)
  - [x] Anlage-Formular Dropdown-Fixes (Vorkühler, Durchlaufkühler, Säulen-Typ, Gas-Typ, Reinigung-Rhythmus, Status) ✅ 07.03.2026
  - [x] Bierleitung CRUD komplett (Form-Screen, Detail-Integration, Add/Edit/Delete) ✅ 07.03.2026
  - [x] Gas-Typ Cross-Validierung (gas_typ_1 ≠ gas_typ_2) ✅ 07.03.2026
  - [x] Anlage löschen (Cascade: Bierleitungen, Reinigungen, Störungen) ✅
  - [x] Bierleitung-Delete Refresh-Fix (StatefulWidget + _refreshKey Pattern) ✅ 11.03.2026
  - [x] Hahn-Typ Dropdown (Kompensator, Kolben, Schieber statt Freitext) ✅ 11.03.2026

- [x] **Reinigungen CRUD** ✅ (20.02.2026)
  - [x] Reinigungen-Liste (globale Ansicht, Suche, Status-Filter, Betrieb-Name, Datum sortiert)
  - [x] Reinigung-Detail-Screen (Zeiterfassung, Checkliste mit Progress-Ring, Preis, Unterschriften)
  - [x] Reinigung-Form-Screen (Service-Flow: 4 Anlagen-Checks + 12 Service-Punkte, Abschliessen-Button)
  - [x] Reinigung-Provider (Stream, List, Count, byAnlage Family, byBetrieb Family)
  - [x] Reinigungen in Anlage-Detail (Sektion mit Stream, "Neue Reinigung"-Button, max 5 Anzeige)
  - [x] Reinigung löschen ✅

- [x] **Störungen CRUD** ✅ (20.02.2026)
  - [x] Störungen-Liste (Suche, Status-Filter, Betrieb-Name, Pikett-Badge, Störungsnummer)
  - [x] Störung-Detail-Screen (Zeiterfassung, Bereich 1-5, Problem/Lösung, Preis, Material, Zusatzinfos)
  - [x] Störung-Form-Screen (Bereichs-Dropdown, Problem/Lösung, Pikett/Bergkunde/Wochenende, Abschliessen)
  - [x] Störung-Provider (Stream, List, Count, byAnlage Family, byBetrieb Family)
  - [x] Störungen in Anlage-Detail (Sektion mit Stream, "Neue Störung"-Button, max 5 Anzeige)
  - [x] Auto-generierte Störungsnummer (STR-YYYYMM-NNN)
  - [x] Störung löschen ✅

### Zwischenschritt: Web & Android Deployment (vorgezogen, 07.03.2026)

- [x] **Web-Deployment (GitHub Pages)** ✅ (07.03.2026)
  - Conditional Exports (`kIsWeb`) in allen Repositories (Web → Supabase direkt, Native → Isar)
  - Conditional Exports für Isar Models (`*_local_export.dart` → Web-Stubs)
  - `routeId` Getter auf allen Local Models (Web: serverId, Native: id)
  - String-basierte IDs im Router und allen Screens
  - Web-Shortcuts für Connectivity/Sync Provider
  - `flutter build web --release --base-href "/sbs-projer-dev/"`
  - Live unter: `https://danielproyer.github.io/sbs-projer-dev/`

- [x] **Android APK Build** ✅ (07.03.2026)
  - Debug-APK erfolgreich auf Emulator (sdk gphone64 x86 64)
  - Sync funktioniert (Push/Pull alle 12 Entitäten)
  - Daten werden korrekt in Isar gespeichert und angezeigt

- [x] **Isar Extension Bug behoben** ✅ (07.03.2026)
  - Problem: Dart Extension Methods (`.betriebLocals`, `.findAll()`, `.watch()` etc.) funktionieren nicht auf `dynamic` Typen
  - Durch Conditional Exports war der Isar-Typ in Repositories `dynamic`
  - Lösung: Alle Isar-Queries als typed static Methods in `IsarService` (native) gewrappt
  - 6 Repositories komplett refactored auf `IsarService.xxxMethod()` Pattern
  - Matching Web-Stubs in `isar_service_web.dart`

- [x] **Gastzugang (Read-Only)** ✅ (07.03.2026)
  - Gast-User in Supabase erstellt (`gast@sbsprojer.ch`)
  - DB Migration 009: RLS SELECT-Policies für Gast auf 9 Tabellen (Daniels Live-Daten)
  - `SupabaseService` erweitert: `isGuest`, `dataUserId` (Gast sieht Daniels Daten)
  - 8 Repositories: `_userId` → `SupabaseService.dataUserId`
  - GoRouter: Redirect-Guard für Form-Routes (`/neu`, `/bearbeiten`, `/rechnungsadresse`)
  - 5 UI-Screens: Alle Create/Edit/Delete-Buttons für Gast ausgeblendet
  - Deployed auf GitHub Pages

### Woche 5 (KW 12): Tourenplanung

- [x] **Tourenplanung (Basis)** ✅ (11.03.2026)
  - [x] Kalender-View (Wochen-Ansicht mit KW-Navigation)
  - [x] "Tour von vor 1 Monat" Funktion (Vorschlag-Tab, ±2 Tage)
  - [x] Drag & Drop für Reihenfolge (ReorderableListView)
  - [x] Filter: Region, Anlagentyp
  - [x] Anlagen fällig/überfällig anzeigen (Farbcodierung rot/orange/grün)
  - [x] Betrieb-Offen-Check (Ferien, Saison, Ruhetage)
  - [x] Dashboard-Kachel mit "X fällig" Badge

### Woche 6-7 (KW 13-14): Service-Protokoll

- [x] **Service-Protokoll erstellen** ✅ (11.03.2026)
  - [x] Service-Flow UI (Reinigung-Formular mit 4 Anlagen-Checks + 12 Service-Punkte)
  - [x] Start/Stop Zeit-Tracking
  - [x] 17-Punkt-Checkliste (JSONB)
  - [x] Notizen pro Punkt (Migration 013)
  - [x] Service abschließen (Abschliessen-Button)
  - [x] **Reinigungsprotokoll PDF** ✅ (12.03.2026)
    - Heineken FOR 1220/Vers.04 Layout
    - PDF nach Reinigung-Abschluss generiert
    - Upload zu Supabase Storage (Bucket: reinigung-pdfs)
    - Im Detail-Screen anzeigen/drucken (Printing Package)

- [x] **Unterschriften** ✅ (11.03.2026)
  - Signature-Widget integriert (signature Package)
  - Techniker unterschreibt (SignaturePad im Formular)
  - Kunde unterschreibt (SignaturePad + Name-Feld)
  - Als Base64-PNG gespeichert
  - Anzeige als Bild im Detail-Screen

- [x] **Fotos** ✅ (11.03.2026)
  - image_picker Integration (Kamera + Galerie)
  - Upload zu Supabase Storage (Bucket: anlagen-fotos)
  - Max 4 Fotos pro Anlage (Slot 1-4)
  - Foto-Grid im Anlage-Detail mit Vollbild-Ansicht
  - Löschen mit Bestätigung

- [x] **Preis-Kalkulator** ✅ (11.03.2026)
  - Reinigung: ServiceTyp, Hähne-Zählung (auto aus Bierleitungen), Bergkunde (auto aus Betrieb)
  - Störung: Anfahrt-km, Zusatzkosten, Bereich-basierte Basis, Wochenende-Zuschlag
  - Live-Preview Card mit Netto/MwSt/Brutto in beiden Formularen
  - Preisliste aus Supabase `preise`-Tabelle geladen

### Woche 8 (KW 15): Offline-Sync & Testing

- [ ] **Testing Core Features** (2 Tage)
  - Manuelles Testing aller Features
  - Bug-Fixes

- [ ] **Offline-Sync finalisieren** (verschoben auf später)
  - Alle Entitäten syncen
  - Background-Sync bei Verbindung
  - Sync-Status anzeigen
  - Fehlerbehandlung
  - Offline-Modus testen

### Deliverables Phase 2
- [x] Betriebe & Anlagen vollständig verwaltbar
- [x] Tourenplanung funktioniert
- [x] Service-Protokoll digital
- [x] Unterschriften & Fotos funktionieren
- [x] Offline-Sync stabil

---

## PHASE 3: ADMINISTRATION

**Dauer**: 4 Wochen (KW 10-12, vorgezogen)
**Status**: Abgeschlossen ✅
**Fortschritt**: 100%

### Woche 9 (KW 16): Rechnungen

- [x] **Service-Protokoll PDF** ✅ (12.03.2026, vorgezogen aus Phase 2)
  - Heineken FOR 1220/Vers.04 Layout (professionelles Reinigungsprotokoll)
  - PDF nach Reinigung-Abschluss generiert
  - Upload zu Supabase Storage (Bucket: reinigung-pdfs)
  - Im Detail-Screen anzeigen/drucken (Printing Package)

- [x] **Kundenrechnung-Generierung** ✅ (12.03.2026, vorgezogen)
  - Auto-Erstellung bei Reinigung-Abschluss (Betriebe mit rechnung_mail/post/tresen)
  - Rechnung + Positionen in Supabase (Modelle: Rechnung, RechnungsPosition)
  - Rechnungsnummer automatisch ({betriebNr}_{YYYY}_{MM}_{DD})
  - MWST-Berechnung (8.1%) + 5-Rappen-Rundung
  - Positionen aus Reinigung: Grundtarif, Zusatz-Hähne (Orion/Fremd/Wein/Standort/Eigen), Bergkunden-Zuschlag
  - Professionelles A4-PDF mit Swiss QR-Einzahlungsschein (QR-Rechnung)
  - QR-Zahlteil: Empfangsschein (62mm) + Zahlteil (148mm) gemäss Swiss Payment Standards
  - PDF Upload zu Supabase Storage (Bucket: rechnung-pdfs)
  - Rechnungen-Liste (Suche, Status-Filter: offen/bezahlt/überfällig/storniert)
  - Rechnung-Detail-Screen (PDF drucken, "Als bezahlt markieren")
  - Dashboard-Kachel mit "X offen" Badge
  - Routes: /rechnungen, /rechnungen/:id
  - Providers: rechnungenStream, rechnungCount, offeneRechnungenCount, rechnungenByBetrieb

### Woche 10 (KW 17): Material

- [x] **Materialverwaltung** ✅ (12.03.2026, vorgezogen)
  - Lager-CRUD (Fahrzeugbestand: erstellen/bearbeiten/löschen)
  - Materialien-Liste (Suche, Kategorie-Filter, Bestand-Filter: alle/niedrig)
  - Material-Detail (Bestand-Visualisierung, Info, Verbrauchshistorie, Quick-Bestand-Anpassung)
  - Material-Formular (Name, Kategorie, Einheit, Bestand aktuell/mindest/optimal, Lieferant, Einkaufspreis)
  - Heineken-Artikel verknüpfen (Server-side Search über 885 Artikel, DBO-Nr.)
  - Bestandswarnung (bestand_niedrig GENERATED Column, rot/grün Ampel)
  - Bestellliste (niedrige Bestände, Fehlmenge, Zwischenablage-Export für WhatsApp/Email)
  - Dashboard-Kachel "Material" mit "X niedrig" Badge
  - Material-Picker in Störungs-Formular (5 progressive Slots, Lager-Dropdown + Menge)
  - Störung-Detail: Lager-Namen statt UUIDs bei Material-Anzeige
  - Verbrauchshistorie pro Lager-Eintrag (via DB-Trigger sync_stoerung_material)
  - 4 Repositories (Lager, MaterialKategorie, MaterialArtikel, MaterialVerbrauch)
  - Providers (materialienStream, materialCount, niedrigCount)
  - 5 Routes (/materialien, /materialien/bestellliste, /materialien/neu, /:id, /:id/bearbeiten)

### Woche 11 (KW 18): Störungen & Montagen & Weitere

- [x] **Störungs-Management** ✅ (CRUD 20.02.2026, Entkopplung 13.03.2026, Vereinfachung 13.03.2026)
  - [x] Störung erfassen (mit Störungsnummer STR-YYYYMM-NNN)
  - [x] Störungsbereich auswählen (5 Bereiche)
  - [x] Störung von Anlage entkoppelt (betrieb_id direkt, anlage_id optional) ✅ 13.03.2026
  - [x] Betrieb-Autocomplete im Formular ✅ 13.03.2026
  - [x] MwSt entfernt (Heineken ohne MwSt) ✅ 13.03.2026
  - [x] Störungen-Section auf Betrieb-Detail ✅ 13.03.2026

- [x] **Montage-Management** ✅ (13.03.2026)
  - [x] Montage CRUD (Liste, Detail, Form)
  - [x] Zeiterfassung (Datum, Uhrzeit)
  - [x] Automatische Berechnung (80 CHF/h)
  - [x] Betrieb-Autocomplete
  - [x] Material (3 Slots)
  - [x] Montage-Section auf Betrieb-Detail
  - [x] Router + Home Tile

- [x] **Pikett-Einsätze** ✅ (13.03.2026)
  - [x] Pikett CRUD (Liste, Detail, Form)
  - [x] Pauschale 80 CHF
  - [x] Datum + Zeiterfassung (Von/Bis)
  - [x] Router + Home Tile

- [x] **Eigenaufträge** ✅ (13.03.2026)
  - [x] Eigenauftrag CRUD (Liste, Detail, Form)
  - [x] Betrieb-Autocomplete + Störungsnummer (Heineken)
  - [x] Pauschale 30 CHF × Anzahl
  - [x] Material (3 Slots)
  - [x] Eigenaufträge-Section auf Betrieb-Detail
  - [x] Router + Home Tile

- [x] **Eröffnung/Endreinigung** ✅ (14.03.2026)
  - [x] Eröffnungsreinigung CRUD (Liste, Detail, Form)
  - [x] Betrieb-Autocomplete → automatische Bergkunde-Erkennung
  - [x] Preis automatisch aus Preistabelle (Normal 60 CHF, Bergkunde 135 CHF)
  - [x] Störungsnummer (Heineken), Datum
  - [x] Keine MwSt (Heineken-Monatsrechnung)
  - [x] Eröffnungsreinigungen-Section auf Betrieb-Detail
  - [x] Router + Home Tile + Sync

- [x] **Betrieb-Verbesserungen** ✅ (13-14.03.2026)
  - [x] Ruhetage + Ferien-Management für alle Betriebe ✅ 13.03.2026
  - [x] Saison von Monat zu Datum umgestellt (Migration 018) ✅ 14.03.2026

### Woche 12 (KW 12): Monatsrechnung Heineken & PDF-Formulare

- [x] **Heineken PDF-Formulare** ✅ (15.03.2026)
  - 6 Rapport-PDFs: F_Störung, F_Eigenauftrag, F_EE_Reinigung, F_Montage, F_Pikett, F_Pauschale
  - HeinekenRapportService mit buildXPage() + generateX() Pattern
  - Alle 6 Rapport-PDFs werden automatisch an Hauptrechnung angehängt

- [x] **Monatsrechnung Heineken** ✅ (15.03.2026)
  - HeinekenRechnungService: Aggregation aller 8 Kategorien
  - HeinekenPdfService: Übersicht + Detail-Seiten (exaktes Heineken-Format)
  - HeinekenMonatsDaten Model (Summen + Raw Data für Rapporte)
  - 3 Screens: Liste, Generierung (Monats-Picker + Vorschau), Detail
  - Combined PDF: Hauptrechnung + alle Rapport-Beilagen in einem Dokument
  - Heineken Providers + Router + Home-Kachel

- [x] **Mahnwesen (Basis)** ✅ (15.03.2026)
  - MahnwesenScreen: Überfällige Rechnungen mit Tagen überfällig
  - Mahnstufen 0-3, "Mahnung erstellen" Button
  - Zusammenfassung: Offener Gesamtbetrag + Anzahl überfällige

### Woche 12 (KW 12, Fortsetzung): Buchhaltung

- [x] **Buchhaltung komplett** ✅ (15.03.2026)
  - 3 Repositories: KontoRepository, BuchungRepository, BuchungsVorlageRepository
  - 4 Provider-Dateien: Konten, Buchungen, Vorlagen, Buchhaltung-Aggregate
  - BuchungService: Buchung aus Vorlage, Kontosaldo-Berechnung
  - 7 Screens:
    - Dashboard (Kennzahlen: Umsatz, offene Rechnungen, MwSt, letzte Buchungen)
    - Kontenplan (61 Konten nach Kategorie, Saldi)
    - Journal (Buchungsliste mit Filter: Jahr/Monat/Konto)
    - Buchung-Detail (alle Felder, Storno-Funktion)
    - Buchung-Formular (44 Vorlagen oder freie Buchung, MwSt-Vorschau)
    - Berichte (Erfolgsrechnung monatlich/jährlich + MwSt-Abrechnung quartalsweise)
    - Mahnwesen (überfällige Rechnungen, Mahnstufen)
  - 7 neue Routes unter /buchhaltung/*
  - Home-Kachel "Buchhaltung"

### Deliverables Phase 3
- [x] Kundenrechnungen automatisch erstellen (mit QR-Einzahlungsschein) ✅
- [x] Materialverwaltung funktioniert ✅
- [x] Störungen, Montagen, Pikett, Eigenaufträge, Eröffnungsreinigungen erfassbar ✅
- [x] Heineken-Monatsrechnung automatisch (inkl. 6 Rapport-PDFs als Beilagen) ✅
- [x] Buchhaltung (Kontenplan, Journal, Buchungen, Berichte, Mahnwesen) ✅

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
**Status**: Teilweise vorgezogen 🔄
**Fortschritt**: 20%

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

- [x] **Web Deployment** ✅ (07.03.2026)
  - Flutter Web Build (`flutter build web --release`)
  - Deployment zu GitHub Pages (gh-pages Branch)
  - Live: `https://danielproyer.github.io/sbs-projer-dev/`

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
| **M1.5: Multi-Platform** | ✅ 07.03.2026 | Web (GitHub Pages) + Android (Emulator) + Windows Desktop funktionieren |
| **M1.6: Gastzugang** | ✅ 07.03.2026 | Read-Only Gastzugang für Web-App (Live-Daten, 3-Schicht-Sicherheit) |
| **M2: Core Features MVP** | ✅ 14.03.2026 | Betriebe ✅, Anlagen ✅, Reinigungen ✅, Störungen ✅, Tourenplanung ✅, PDF-Protokoll ✅ |
| **M2.5: Rechnungen** | ✅ 12.03.2026 | Kundenrechnung auto-generiert, QR-Einzahlungsschein, Liste+Detail, Dashboard |
| **M2.6: Materialverwaltung** | ✅ 12.03.2026 | Lager-CRUD, Bestandswarnung, Bestellliste, Material-Picker Störung, Dashboard |
| **M2.7: Heineken Monatsrechnung** | ✅ 15.03.2026 | 8 Kategorien aggregiert, 6 Rapport-PDFs, Combined PDF |
| **M2.8: Buchhaltung** | ✅ 15.03.2026 | Kontenplan, Journal, Buchungen, Berichte, Mahnwesen |
| **M3: Administration komplett** | ✅ 15.03.2026 | Alle Service-Typen, Heineken, Buchhaltung, Mahnwesen |
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

**Zuletzt aktualisiert**: 18.03.2026 – Tourenplanung Fällig-Tab überarbeitet (dynamische Fälligkeit aus Rhythmus, neue Anlagen sichtbar, Ruhetag-Check entfernt), Dropdown-Erweiterungen (Higenie, Orion, V100, Cola Säule), Kontakt-Handysync, Rechnungsadresse-Verbesserung. 5 offene DB-Migrationen (026-030).

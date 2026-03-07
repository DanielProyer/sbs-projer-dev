# Technische Architektur - SBS Projer App

**Erstellt**: 12.02.2026
**Status**: In Entscheidung

---

## ANFORDERUNGEN (aus Geschäftsbeschreibung & Geschäftsabläufen)

### Funktionale Anforderungen

| Kategorie | Anforderung | Priorität |
|-----------|-------------|-----------|
| **Plattformen** | Web + Mobile (iOS + Android) | 🔴 Kritisch |
| **Offline-Fähigkeit** | Muss offline funktionieren (Bergkunden ohne Netz!) | 🔴 Kritisch |
| **Daten-Sync** | Automatische Synchronisation wenn online | 🔴 Kritisch |
| **Unterschriften** | Digital auf Touchscreen | 🔴 Kritisch |
| **Fotos** | Kamera-Integration für Probleme dokumentieren | 🔴 Kritisch |
| **GPS/Navigation** | Optional: Routenplanung, Fahrzeiten tracken | 🟡 Mittel |
| **Rechnungserstellung** | PDF generieren | 🔴 Kritisch |
| **Multi-Tenant** | Später skalierbar für 12 andere Franchise-Partner | 🟢 Zukunft |

### Nicht-Funktionale Anforderungen

| Kategorie | Anforderung | Begründung |
|-----------|-------------|------------|
| **Budget** | Max. 200 CHF/Monat Betriebskosten | One-man operation, kleines Budget |
| **Wartbarkeit** | Einfach zu warten (keine komplexen Deployments) | Daniel ist alleine, kein Dev-Team |
| **Skalierbarkeit** | Starten mit 1 User, später ~13 User | Franchise-Partner später integrieren |
| **Entwicklungszeit** | MVP in 3-6 Monaten realistisch | Zeitbudget begrenzt |
| **Datenvolumen** | ~10.000 Services/Jahr, 250 Kunden | Mittelgroße Datenbank |

---

## TECH-STACK OPTIONEN

### Option 1: Flutter + Supabase ⭐ **EMPFOHLEN**

#### Stack-Übersicht
- **Frontend**: Flutter (Dart)
- **Backend**: Supabase (PostgreSQL, Auth, Storage, Edge Functions)
- **Hosting**: Supabase Cloud + Flutter Web (Vercel/Netlify)
- **Offline**: Supabase Offline-First SDK + Hive/Isar

#### Vorteile ✅
- **Eine Codebase** für Web, iOS, Android → weniger Code zu warten
- **Offline-First**: Exzellente Offline-Unterstützung mit Supabase Realtime
- **Kosten**:
  - Supabase Free Tier: 0 CHF (bis 500 MB Datenbank, 1 GB Transfer)
  - Supabase Pro: 25 USD/Monat (~23 CHF) wenn mehr benötigt
  - Flutter Web Hosting: 0 CHF (Vercel/Netlify Free Tier)
  - **Total: 0-23 CHF/Monat** → weit unter Budget!
- **PostgreSQL**: Mächtige relationale Datenbank (gut für Betrieb→Anlage Struktur)
- **Row Level Security**: Eingebaute Sicherheit auf Datenbank-Ebene
- **Echtzeit-Sync**: Automatische Synchronisation wenn online
- **PDF-Generierung**: Mit pdf Package oder Edge Functions
- **Community**: Große Flutter & Supabase Community
- **Multi-Tenant Ready**: PostgreSQL + RLS perfekt für Multi-Tenant

#### Nachteile ❌
- Dart ist weniger verbreitet als JavaScript/TypeScript
- Flutter Web noch etwas weniger ausgereift als Mobile
- Supabase relativ jung (aber sehr aktiv entwickelt)

#### Kosten-Breakdown (12 Monate)
```
Jahr 1:
- Supabase Free Tier: 0 CHF/Monat
- Hosting: 0 CHF/Monat
- Total: 0 CHF/Monat

Jahr 2+ (bei Skalierung mit Franchise-Partnern):
- Supabase Pro: 23 CHF/Monat
- Total: 23 CHF/Monat
```

#### Offline-Strategie
1. **Lokale Datenbank**: Hive oder Isar (beide sehr schnell, offline-first)
2. **Sync-Logik**:
   - Alle Änderungen lokal speichern
   - Bei Online-Verbindung: Sync zu Supabase
   - Conflict Resolution: "Last Write Wins" oder Custom Logic
3. **Bilder/PDFs**: Lokal speichern, später zu Supabase Storage hochladen

---

### Option 2: React Native + Firebase

#### Stack-Übersicht
- **Frontend**: React Native (JavaScript/TypeScript)
- **Backend**: Firebase (Firestore, Auth, Storage, Cloud Functions)
- **Hosting**: Firebase Hosting
- **Offline**: Firestore Offline Persistence

#### Vorteile ✅
- **Eine Codebase** für iOS, Android, (Web mit React Native Web)
- **JavaScript/TypeScript**: Weiter verbreitet als Dart
- **Firebase Offline**: Eingebaute Offline-Unterstützung in Firestore
- **Kosten**:
  - Firebase Spark (Free): 0 CHF (begrenzt)
  - Firebase Blaze (Pay-as-you-go): ~10-50 CHF/Monat geschätzt
- **Google-Integration**: Gut für Google Business API (Öffnungszeiten)
- **Mature Ecosystem**: Firebase existiert seit 2011

#### Nachteile ❌
- **Firestore**: NoSQL → komplexere Queries (Betrieb→Anlage Struktur schwieriger)
- **Kosten unpredictable**: Pay-as-you-go kann überraschend teuer werden
- **React Native Web**: Weniger ausgereift als Flutter Web
- **Vendor Lock-in**: Stark an Google gebunden
- **PDF-Generierung**: Komplizierter (Cloud Functions erforderlich)

#### Kosten-Breakdown (12 Monate)
```
Jahr 1:
- Firebase Spark: 0 CHF (wenn unter Limits)
- Sonst Blaze: ~20-50 CHF/Monat (unpredictable)

Jahr 2+:
- Firebase Blaze: ~50-100 CHF/Monat (mit Franchise-Partnern)
```

---

### Option 3: Next.js PWA + Supabase

#### Stack-Übersicht
- **Frontend**: Next.js (React) als Progressive Web App (PWA)
- **Backend**: Supabase
- **Hosting**: Vercel
- **Offline**: Service Workers + IndexedDB

#### Vorteile ✅
- **Web-First**: Beste Web-Performance
- **React/TypeScript**: Sehr verbreitet
- **Kosten**:
  - Supabase Free: 0 CHF
  - Vercel Free Tier: 0 CHF
  - Total: 0 CHF/Monat
- **PWA**: Installierbar auf Mobile (wie native App)
- **SEO-freundlich**: Falls später Marketing-Website benötigt

#### Nachteile ❌
- **Mobile Experience**: Nicht so gut wie echte native Apps
- **Offline**: Service Workers komplexer als native Offline-Datenbanken
- **Kamera/Unterschrift**: Weniger nahtlos als native Apps
- **App Store**: Nicht in App Stores verfügbar (nur als PWA installierbar)

#### Kosten-Breakdown
```
Alle Jahre: 0 CHF/Monat
```

---

### Option 4: Native Apps (Swift + Kotlin) + Supabase

#### Stack-Übersicht
- **iOS**: Swift + SwiftUI
- **Android**: Kotlin + Jetpack Compose
- **Web**: Separate Next.js App
- **Backend**: Supabase

#### Vorteile ✅
- **Beste Performance**: Native ist immer am schnellsten
- **Beste Mobile UX**: Plattform-spezifische Features
- **Offline**: Native Datenbanken (CoreData, Room)

#### Nachteile ❌
- **3 Codebases**: iOS, Android, Web → 3x Entwicklung, 3x Wartung
- **Hoher Aufwand**: Unrealistisch für One-Man-Operation
- **Kosten**: Mehr Entwicklungszeit = mehr Kosten
- **Nicht empfohlen** für dieses Projekt

---

## EMPFEHLUNG: Flutter + Supabase ⭐

### Begründung

| Kriterium | Flutter + Supabase | React Native + Firebase | Next.js PWA |
|-----------|-------------------|------------------------|-------------|
| **Offline-Fähigkeit** | ⭐⭐⭐⭐⭐ Exzellent | ⭐⭐⭐⭐ Sehr gut | ⭐⭐⭐ Gut (Service Workers) |
| **Kosten** | ⭐⭐⭐⭐⭐ 0-23 CHF | ⭐⭐⭐ 20-100 CHF | ⭐⭐⭐⭐⭐ 0 CHF |
| **Eine Codebase** | ⭐⭐⭐⭐⭐ Web+Mobile | ⭐⭐⭐⭐ Web+Mobile | ⭐⭐⭐ Nur Web (PWA) |
| **Mobile UX** | ⭐⭐⭐⭐⭐ Native-ähnlich | ⭐⭐⭐⭐ Native-ähnlich | ⭐⭐⭐ Web-feeling |
| **Datenbank** | ⭐⭐⭐⭐⭐ PostgreSQL (relational) | ⭐⭐⭐ Firestore (NoSQL) | ⭐⭐⭐⭐⭐ PostgreSQL |
| **Wartbarkeit** | ⭐⭐⭐⭐ Gut | ⭐⭐⭐⭐ Gut | ⭐⭐⭐⭐ Gut |
| **Multi-Tenant** | ⭐⭐⭐⭐⭐ RLS eingebaut | ⭐⭐⭐ Firestore Rules | ⭐⭐⭐⭐⭐ RLS eingebaut |
| **Community** | ⭐⭐⭐⭐ Groß & wachsend | ⭐⭐⭐⭐⭐ Sehr groß | ⭐⭐⭐⭐⭐ Sehr groß |
| **PDF-Generierung** | ⭐⭐⭐⭐ Einfach (pdf Package) | ⭐⭐⭐ Komplexer | ⭐⭐⭐⭐ Einfach |
| **Unterschriften** | ⭐⭐⭐⭐⭐ Native Widget | ⭐⭐⭐⭐ Canvas API | ⭐⭐⭐ Canvas API |
| **Kamera** | ⭐⭐⭐⭐⭐ Native Plugin | ⭐⭐⭐⭐ Native Module | ⭐⭐⭐ Web API |
| **Total Score** | **🏆 56/60** | 45/60 | 46/60 |

### Entscheidende Faktoren für Flutter + Supabase:

1. **Offline-First**: Kritischste Anforderung → Flutter + Hive/Isar + Supabase perfekt
2. **Kosten**: 0 CHF für Jahre 1-2, dann 23 CHF/Monat → weit unter Budget
3. **PostgreSQL**: Relationale Datenbank ideal für Betrieb→Anlage Struktur
4. **Eine Codebase**: Web + iOS + Android aus einer Hand
5. **Mobile UX**: Echte native Apps, nicht Web-Wrapper
6. **Skalierbarkeit**: Row Level Security für Multi-Tenant ready

---

## TECHNOLOGIE-DETAILS

### Flutter Packages (Empfehlung)

#### Core
```yaml
dependencies:
  flutter: sdk: flutter

  # Backend & Auth
  supabase_flutter: ^2.0.0  # Supabase Client

  # Lokale Datenbank (Offline)
  isar: ^4.0.0  # Schnelle lokale DB
  isar_flutter_libs: ^4.0.0

  # State Management
  riverpod: ^2.5.0  # Moderne State Management
  flutter_riverpod: ^2.5.0

  # Navigation
  go_router: ^14.0.0  # Deklaratives Routing

  # UI
  flutter_svg: ^2.0.0
  cached_network_image: ^3.3.0

  # Formulare & Validierung
  flutter_form_builder: ^9.0.0
  form_builder_validators: ^9.0.0

  # Datum & Zeit
  intl: ^0.19.0  # Internationalisierung

  # PDF
  pdf: ^3.10.0  # PDF generieren
  printing: ^5.12.0  # PDF drucken/teilen

  # Unterschrift
  signature: ^5.4.0  # Unterschriften-Widget

  # Kamera & Bilder
  image_picker: ^1.0.0  # Fotos aufnehmen

  # GPS & Maps
  geolocator: ^11.0.0  # GPS Position
  google_maps_flutter: ^2.5.0  # Google Maps

  # HTTP & APIs
  dio: ^5.4.0  # HTTP Client (für externe APIs)

  # Utilities
  uuid: ^4.3.0  # UUIDs generieren
  path_provider: ^2.1.0  # App Directories

dev_dependencies:
  flutter_test: sdk: flutter
  flutter_lints: ^3.0.0
  build_runner: ^2.4.0  # Code-Generierung
  isar_generator: ^4.0.0  # Isar Code-Gen
```

### Supabase Setup

#### Projekt-Struktur
```
supabase/
├── migrations/           # Datenbank-Migrationen
│   ├── 001_initial_schema.sql
│   ├── 002_add_rls_policies.sql
│   └── ...
├── functions/           # Edge Functions (optional)
│   ├── generate-invoice-pdf/
│   └── check-business-hours/
└── seed.sql            # Test-Daten
```

#### Datenbank-Schema (Vorschau)
```sql
-- Wird im Datenmodell detailliert
CREATE TABLE betriebe (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  adresse TEXT,
  region TEXT,
  ist_bergkunde BOOLEAN DEFAULT FALSE,
  ...
);

CREATE TABLE anlagen (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  betrieb_id UUID REFERENCES betriebe(id),
  typ TEXT CHECK (typ IN ('Konventionell', 'Orion', 'Heigenie', 'David')),
  anzahl_haehne INTEGER,
  letzte_reinigung DATE,
  ...
);

-- Row Level Security für Multi-Tenant
ALTER TABLE betriebe ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can only see their own customers"
  ON betriebe FOR SELECT
  USING (auth.uid() = user_id);
```

---

## ARCHITEKTUR-DIAGRAMM

```
┌─────────────────────────────────────────────────────────────┐
│                         CLIENT LAYER                         │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Flutter    │  │   Flutter    │  │   Flutter    │      │
│  │   Web App    │  │   iOS App    │  │  Android App │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                  │                  │               │
│         └──────────────────┼──────────────────┘              │
│                            │                                  │
└────────────────────────────┼──────────────────────────────────┘
                             │
                   ┌─────────▼─────────┐
                   │  Riverpod State   │
                   │    Management     │
                   └─────────┬─────────┘
                             │
           ┌─────────────────┼─────────────────┐
           │                 │                 │
    ┌──────▼──────┐   ┌─────▼──────┐   ┌─────▼──────┐
    │   Isar DB   │   │  Supabase  │   │   Local    │
    │  (Offline)  │   │   Client   │   │  Storage   │
    └─────────────┘   └─────┬──────┘   └────────────┘
                            │
                            │ HTTPS
                            │
┌───────────────────────────▼─────────────────────────────────┐
│                      SUPABASE CLOUD                          │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  PostgreSQL  │  │     Auth     │  │   Storage    │      │
│  │   Database   │  │   (JWT)      │  │   (Files)    │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│                                                               │
│  ┌──────────────┐  ┌──────────────┐                        │
│  │   Realtime   │  │     Edge     │                        │
│  │  (Sync)      │  │  Functions   │                        │
│  └──────────────┘  └──────────────┘                        │
│                                                               │
└─────────────────────────────────────────────────────────────┘
                             │
                             │ API Calls
                             │
┌───────────────────────────▼─────────────────────────────────┐
│                    EXTERNE SERVICES                          │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Google Maps  │  │ Google       │  │   E-Mail     │      │
│  │     API      │  │ Business API │  │   Service    │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

---

## OFFLINE-SYNC-STRATEGIE (Detailliert)

### Konzept: Optimistic UI + Background Sync

#### 1. Daten-Flow (Offline)
```
Benutzer macht Änderung (z.B. Service erstellen)
  ↓
Änderung wird SOFORT in Isar DB gespeichert
  ↓
UI aktualisiert sich SOFORT (Optimistic Update)
  ↓
Änderung wird in "Pending Sync Queue" eingetragen
  ↓
App versucht regelmäßig Sync (wenn online)
```

#### 2. Daten-Flow (Online)
```
App erkennt Online-Verbindung
  ↓
"Pending Sync Queue" wird abgearbeitet
  ↓
Änderungen werden zu Supabase hochgeladen
  ↓
Bei Erfolg: Aus Queue entfernen, "synced" Flag setzen
  ↓
Bei Fehler: In Queue behalten, später erneut versuchen
```

#### 3. Conflict Resolution
```
Lokale Änderung hochladen
  ↓
Supabase prüft: Wurde Datensatz inzwischen geändert?
  ↓
  ├─ Nein → Erfolg, Änderung übernehmen
  │
  └─ Ja → Konflikt!
       ↓
       Strategie wählen:
       ├─ "Last Write Wins" (einfach)
       ├─ "Server Wins" (sicher)
       └─ "Custom Logic" (komplex, aber flexibel)
```

**Empfehlung**: "Last Write Wins" für MVP (einfachste Lösung, da Daniel alleine arbeitet)

#### 4. Daten-Strukturen

**Isar Modell (Beispiel Service)**
```dart
@collection
class LocalService {
  Id id = Isar.autoIncrement;

  String? serverId;  // Supabase UUID (null wenn noch nicht synced)
  DateTime createdAt;
  bool isSynced;     // false = pending upload
  bool isDeleted;    // Soft delete

  // Service-Daten
  String betriebId;
  String anlageId;
  DateTime serviceDatum;
  String protokoll;  // JSON
  String? unterschriftBase64;

  // Conflict Resolution
  DateTime lastModifiedAt;
}
```

#### 5. Bilder & PDFs

**Strategie**:
- Speichern lokal im App Directory (`path_provider`)
- Referenz in Isar DB speichern
- Bei Online-Verbindung: Upload zu Supabase Storage
- Nach erfolgreichem Upload: Lokale Datei optional löschen (oder Cache behalten)

```dart
// Beispiel
Future<void> uploadPendingImages() async {
  final pendingImages = await isar.localImages
    .filter()
    .isUploadedEqualTo(false)
    .findAll();

  for (final img in pendingImages) {
    try {
      final bytes = await File(img.localPath).readAsBytes();
      final url = await supabase.storage
        .from('service-images')
        .uploadBinary('${img.serviceId}/${img.filename}', bytes);

      img.isUploaded = true;
      img.remoteUrl = url;
      await isar.writeTxn(() => isar.localImages.put(img));
    } catch (e) {
      // Später erneut versuchen
    }
  }
}
```

---

## ENTWICKLUNGS-ROADMAP

### Phase 1: Setup (Woche 1-2)
- [ ] Supabase Projekt erstellen
- [ ] Flutter Projekt initialisieren
- [ ] Packages installieren
- [ ] Basis-Architektur aufsetzen (Riverpod, Go Router)
- [ ] Isar DB einrichten
- [ ] Supabase Auth einrichten
- [ ] Design System / Theme definieren

### Phase 2: Core Features (Woche 3-8)
- [ ] Datenmodell implementieren (Supabase + Isar)
- [ ] Offline-Sync-Logik
- [ ] Betriebe & Anlagen CRUD
- [ ] Service-Protokoll (17-Punkt-Checkliste)
- [ ] Unterschriften-Funktion
- [ ] Foto-Upload
- [ ] Tour-Planung (Basis)

### Phase 3: Administration (Woche 9-12)
- [ ] Rechnung-Generierung (PDF)
- [ ] Materialverwaltung
- [ ] Störungs-Management
- [ ] Montage-Management
- [ ] Monatsrechnung Heineken

### Phase 4: Polish & Testing (Woche 13-16)
- [ ] UI/UX Verbesserungen
- [ ] Offline-Sync Testing
- [ ] Performance-Optimierung
- [ ] Beta-Testing mit Daniel
- [ ] Bug-Fixes

### Phase 5: Deployment (Woche 17-18)
- [ ] App Store Submission (iOS)
- [ ] Google Play Submission (Android)
- [ ] Web Deployment (Vercel/Netlify)
- [ ] Dokumentation
- [ ] Training für Daniel

---

## KOSTEN-KALKULATION (3 Jahre)

### Jahr 1 (MVP Development)
| Posten | Kosten/Monat | Kosten/Jahr |
|--------|--------------|-------------|
| Supabase Free Tier | 0 CHF | 0 CHF |
| Flutter Web Hosting (Vercel) | 0 CHF | 0 CHF |
| Apple Developer Account | - | 99 USD (~90 CHF) |
| Google Play Developer | - | 25 USD (~23 CHF) einmalig |
| **Total Jahr 1** | **0 CHF/Monat** | **~113 CHF** |

### Jahr 2-3 (Production + Skalierung)
| Posten | Kosten/Monat | Kosten/Jahr |
|--------|--------------|-------------|
| Supabase Pro | 25 USD (~23 CHF) | 276 CHF |
| Flutter Web Hosting | 0 CHF | 0 CHF |
| Apple Developer Account | - | 90 CHF |
| **Total Jahr 2-3** | **23 CHF/Monat** | **~366 CHF/Jahr** |

**→ Weit unter Budget von 200 CHF/Monat!**

Bei 13 Benutzern (Daniel + 12 Franchise-Partner) später:
- Supabase Pro oder Team: ~50-100 CHF/Monat
- Kosten können auf Partner umgelegt werden

---

## NÄCHSTE SCHRITTE

1. ✅ **Entscheidung bestätigen**: Flutter + Supabase OK?
2. ⏳ **Datenmodell erstellen**: Detaillierte DB-Schema basierend auf Geschäftsabläufen
3. ⏳ **Feature-Priorisierung**: MVP Features vs. Nice-to-Have
4. ⏳ **Wireframes**: UI/UX Mockups erstellen
5. ⏳ **Development starten**: Setup & Phase 1

---

**Frage an Daniel**: Bist du einverstanden mit Flutter + Supabase? Oder möchtest du noch eine andere Option genauer betrachten?

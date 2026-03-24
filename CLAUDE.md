# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Sprache

Kommunikation auf Deutsch. Projekt-Dokumentation auf Deutsch.

## Projekt

Service-Management App für Zapfanlagen-Service (SBS Projer GmbH). Flutter + Supabase + Riverpod + GoRouter + Isar (offline-first).

## Umgebung & Build

```bash
# Flutter PATH in Bash setzen
export PATH="$PATH:/c/flutter/bin"

# App-Verzeichnis
cd sbs_projer_app

# Web-Build (MSYS_NO_PATHCONV nötig in Git Bash!)
export MSYS_NO_PATHCONV=1 && flutter build web --base-href "/sbs-projer-dev/"

# Web lokal testen
flutter run -d edge

# Analyse
flutter analyze

# Isar-Code generieren nach Änderungen an @Collection-Klassen
dart run build_runner build
```

## Deployment (GitHub Pages)

Branch `gh-pages`, Source: Root (`/`), NICHT `docs/`. Dateien aus `sbs_projer_app/build/web/` direkt in Root kopieren:

```bash
git stash && git checkout gh-pages && rm -rf assets canvaskit icons main.dart.js* flutter*.js index.html manifest.json favicon.png version.json && cp -r sbs_projer_app/build/web/* . && touch .nojekyll && git add index.html main.dart.js* flutter*.js manifest.json favicon.png version.json .nojekyll assets/ canvaskit/ icons/ && git commit -m "deploy" && git push origin gh-pages && git checkout main && git stash pop
```

Live: `https://danielproyer.github.io/sbs-projer-dev/`

## Verzeichnisstruktur

```
Architektur/          # Datenmodell, Roadmap, Tech-Stack-Analyse
Datenbank/            # db_query.py (psycopg2), migrations/ (35 SQL-Dateien)
sbs_projer_app/       # Flutter-App
  lib/
    core/config/      # router.dart (40+ Routen mit Auth-Guard)
    core/theme/       # Material 3, Heineken-Grün (#008200)
    data/models/      # Supabase-DTOs (24 Models, fromJson/toJson)
    data/local/       # Isar-Models (13 Collections) + web/ Stubs + *_export.dart
    data/mappers/     # Local ↔ DTO Konverter (13 Mapper)
    data/repositories/# Datenzugriff (19 Repos, kIsWeb-Branching)
    presentation/
      screens/        # UI pro Feature (betriebe/, anlagen/, reinigungen/, ...)
      providers/      # Riverpod-Provider (19 Dateien)
      widgets/        # Wiederverwendbare UI-Komponenten
    services/
      storage/        # isar_service.dart (typed Queries) + Web-Stubs
      sync/           # sync_service.dart (Push/Pull, Last-Write-Wins)
      pdf/            # PDF-Generierung (Reinigung, Rechnung, Heineken)
      supabase/       # supabase_service.dart (Client, Auth)
```

## Kritisches Architektur-Pattern: Conditional Exports (Isar ↔ Web)

Jede gesynkte Entity hat 3 Dateien:

```
data/local/betrieb_local.dart          → Native: @Collection mit Isar-Annotationen
data/local/betrieb_local_export.dart   → export 'betrieb_local.dart' if (dart.library.html) 'web/betrieb_local_web.dart'
data/local/web/betrieb_local_web.dart  → Web: Plain Dart-Klasse (kein Isar)
```

**Alle Imports** in Repositories/Screens über `*_export.dart`, nie direkt.

### Gotcha: Isar Extensions + dynamic

Dart Extension Methods (`.betriebLocals`, `.where()`, `.watch()`) funktionieren **NICHT** auf `dynamic`. Da Conditional Exports den Typ zu `dynamic` machen, müssen **ALLE Isar-Queries** in `isar_service.dart` gewrappt werden, wo `package:isar/isar.dart` direkt importiert ist.

## Repository-Pattern

Repositories nutzen `kIsWeb`-Branching:
- **Web**: Supabase-Direktzugriff (`SupabaseService.client.from('tabelle')...`)
- **Native**: `IsarService.entityMethod()` (typed static Methods)

```dart
static Future<List<BetriebLocal>> getAll() async {
  if (kIsWeb) {
    final rows = await SupabaseService.client.from('betriebe').select()...;
    return rows.map((r) => BetriebMapper.fromDto(Betrieb.fromJson(r))).toList();
  }
  return IsarService.betriebFindAll();
}
```

## Neue Entity hinzufügen (Checkliste)

1. Supabase-DTO: `data/models/entity.dart`
2. Isar Local Model: `data/local/entity_local.dart` (@Collection)
3. Conditional Export: `data/local/entity_local_export.dart`
4. Web Stub: `data/local/web/entity_local_web.dart`
5. Mapper: `data/mappers/entity_mapper.dart` (fromDto, toJson)
6. IsarService: Typed Query-Methods hinzufügen
7. Repository: `data/repositories/entity_repository.dart` (kIsWeb)
8. Providers: `presentation/providers/entity_providers.dart`
9. Screens: `presentation/screens/entities/` (list, detail, form)
10. Routen: `core/config/router.dart`
11. Dashboard-Tile: `home_screen.dart`
12. DB-Migration: `Datenbank/migrations/XXX_entity.sql`
13. SyncService: Push/Pull-Logik ergänzen

## Datenbank

- 24 Tabellen, 24 RLS Policies, 20 Triggers/Functions, 7 Views
- Connection-String in `.env` (Root), Supabase API-Keys in `sbs_projer_app/.env`
- Direktzugriff: `python Datenbank/db_query.py`
- Migrationen: `Datenbank/migrations/001_initial_schema.sql` bis `032_...`

## Sync-Architektur (Offline-First, nur Native)

- Push: `isSynced=false` → Supabase upsert
- Pull: Inkrementell via `updated_at > lastPullAt`
- Konflikte: Last-Write-Wins
- Reihenfolge: Region → Betrieb → Anlage → Services (FK-Dependencies)
- Auto-Sync bei Connectivity-Wechsel (offline → online)

## Bekannte Einschränkungen

- `intl` Version wird von Flutter SDK gepinnt (0.20.2) → `any` in pubspec
- `.env` muss in `pubspec.yaml` unter `assets:` stehen für flutter_dotenv
- `flutter doctor --android-licenses` braucht PowerShell (nicht Bash)
- CHROME_EXECUTABLE: Edge (`C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe`)

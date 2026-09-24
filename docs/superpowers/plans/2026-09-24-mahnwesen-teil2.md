# Mahnwesen Teil 2 — Eskalation (Heineken, Betreibung) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Nach der letzten Mahnung führt die App den Fall weiter: Heineken einschalten (Mail an den Heineken-Kontakt «Mahnwesen»), eines von vier Ergebnissen erfassen, bei Bedarf die Betreibung mit Datenblatt und datierten Schritten begleiten — mit Fristen in der Glocke. Release v0.135.0.

**Architecture:** Neue Tabelle `mahnfaelle` (ein Fall je Betrieb und Eskalation). Reine Regeln in `lib/core/util/mahnfall_regeln.dart` (wann eskalieren, Aufgaben, Kostenvorschuss, Fortsetzungsfenster). `MahnfallService` für alle schreibenden Schritte, `MahnfallScreen` (`/rechnungen/mahnfall/:id`) als Arbeitsblatt. Der Mahnlauf nimmt Rechnungen eines offenen Falls aus und zeigt eine neue Sektion «Heineken einschalten». Alles bleibt im Testmodus (`MailConfig.mahnwesenScharf = false`).

**Tech Stack:** Flutter Web (CanvasKit), Riverpod, GoRouter, Supabase (Postgres, Storage `rechnung-pdfs`, Edge Function `send-rechnung-mail`), `pdf` via `pdfDokument()`.

**Spec:** `docs/superpowers/specs/2026-09-23-mahnwesen-design.md` Abschnitt 5 und 8. Recherche: `docs/buchhaltung/mahnwesen-recherche-2026-09-23.md`.

**Bewusste Abweichung von der Spec (Entscheid Daniel 23.09.: «beim ersten echten Fall gemeinsam prüfen»):** Das Ergebnis «Heineken übernimmt» wird nur **erfasst** (Fall erledigt, Erledigung `uebernommen`) und erzeugt eine dringende Aufgabe «Heineken-Übernahme verbuchen — mit Daniel prüfen». Keine automatische Umbuchung, keine automatische Position auf der Heineken-Monatsrechnung, Rechnungsstatus unverändert. Grund: Buchung und Rechnungsposition (ohne MWST) sind noch nicht festgelegt; ein falscher Automatismus in der Buchhaltung ist schlimmer als ein Handgriff im seltenen Fall.

**Allgemeine Regeln für alle Tasks** (aus `CLAUDE.md` im Projekt-Root — lesen!):
- Arbeitsverzeichnis App: `sbs_projer_app/`. Flutter in Bash: `export PATH="$PATH:/c/flutter/bin"`.
- Seitenweise Abfragen immer mit `.order('id')` als letztem Sortierschlüssel.
- CanvasKit: keine `FilledButton`/`OutlinedButton`/`ElevatedButton`/`ListTile`/`ExpansionTile(dense)`/`TabBar` in neuen Widgets; Aktionen über `TapKnopf` (`lib/presentation/widgets/tap_knopf.dart`: `text`, `onTap`, `primaer`, `icon`, `laeuft`, `gefahr`), unumkehrbare Aktionen über `TapKnopf(gefahr: true)`.
- PDFs nur über `pdfDokument()`.
- Nie `.neq()` auf nullbaren Spalten (filtert NULL weg) — Ausschlüsse in Dart.
- Datumsdifferenzen in UTC-Tagen rechnen.
- Kein `git stash`. Commits enden mit `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Nach jedem Task: `flutter test` grün (Stand vor Teil 2: 2046) und `flutter analyze` nicht mehr als 56 Befunde.

---

## Dateiübersicht

| Datei | Neu/Ändern | Verantwortung |
|---|---|---|
| `Datenbank/migrations/204_mahnfaelle.sql` | neu | Tabelle `mahnfaelle`, RLS, Zuweisung `mahnwesen` |
| `sbs_projer_app/lib/data/models/mahnfall.dart` | neu | DTO `Mahnfall` |
| `sbs_projer_app/lib/data/repositories/mahnfall_repository.dart` | neu | CRUD `mahnfaelle` |
| `sbs_projer_app/lib/core/util/mahnfall_regeln.dart` | neu | reine Regeln |
| `sbs_projer_app/test/mahnfall_regeln_test.dart` | neu | Tests der Regeln |
| `sbs_projer_app/lib/core/util/mahnregeln.dart` | ändern | `eskalationFaellig` |
| `sbs_projer_app/lib/presentation/providers/mahnlauf_provider.dart` | ändern | Fälle laden, Sektionen |
| `sbs_projer_app/lib/presentation/screens/rechnungen/mahnlauf_screen.dart` | ändern | Sektionen «Heineken einschalten», «Offene Fälle» |
| `sbs_projer_app/lib/data/repositories/kontakt_repository.dart` | ändern | Zuweisung `mahnwesen` |
| `sbs_projer_app/lib/presentation/screens/heineken/heineken_zuweisungen_screen.dart` | ändern | Funktion «Mahnwesen» |
| `sbs_projer_app/lib/services/rechnung/mahnfall_service.dart` | neu | Fall eröffnen, Heineken-Mail, Ergebnisse, Betreibungsschritte |
| `sbs_projer_app/lib/presentation/providers/mahnfall_providers.dart` | neu | Provider je Fall / offene Fälle |
| `sbs_projer_app/lib/presentation/screens/rechnungen/mahnfall_screen.dart` | neu | Arbeitsblatt des Falls |
| `sbs_projer_app/lib/core/config/router.dart` | ändern | Route `/rechnungen/mahnfall/:id` |
| `sbs_projer_app/lib/core/util/aufgaben_regeln.dart` + `presentation/providers/aufgaben_detektoren_provider.dart` | ändern | Fristen in der Glocke |
| `sbs_projer_app/test/mahnwesen_testmodus_waechter_test.dart`, `test/canvaskit_sichere_widgets_test.dart` | ändern | Wächter erweitern |

---

### Task 1: Migration 204, Model, Repository

**Files:**
- Create: `Datenbank/migrations/204_mahnfaelle.sql`
- Create: `sbs_projer_app/lib/data/models/mahnfall.dart`
- Create: `sbs_projer_app/lib/data/repositories/mahnfall_repository.dart`
- Test: `sbs_projer_app/test/mahnfall_model_test.dart`

- [ ] **Step 1: Migration schreiben** (wird vom Controller per `apply_migration` angewendet — der Implementer wendet sie NICHT an)

```sql
-- 204: Mahnfälle — Eskalation nach der letzten Mahnung (Mahnwesen Teil 2, 24.09.2026)
-- Ein Fall je Betrieb und Eskalation: Heineken einschalten → Ergebnis →
-- ggf. Betreibung. Spec docs/superpowers/specs/2026-09-23-mahnwesen-design.md §5.

create table if not exists mahnfaelle (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) default auth.uid(),
  betrieb_id uuid not null references betriebe(id) on delete restrict,
  rechnung_ids uuid[] not null,
  eroeffnet_am date not null default current_date,
  status text not null default 'heineken'
    check (status in ('heineken','heineken_frist','betreibung','erledigt')),
  test boolean not null default true,
  -- Heineken
  heineken_kontakt_am date,
  heineken_empfaenger text,
  heineken_ergebnis text
    check (heineken_ergebnis in ('vermittelt','uebernommen','konkurs','betreibung')),
  heineken_ergebnis_am date,
  heineken_frist_bis date,
  -- Betreibung
  schuldner_name text,
  schuldner_adresse text,
  rechtsform text check (rechtsform in ('einzelfirma','gmbh','ag','andere')),
  betreibungsamt text,
  eingereicht_am date,
  zahlungsbefehl_am date,
  rechtsvorschlag boolean,
  fortsetzung_am date,
  kosten_vorschuss numeric(10,2),
  -- Abschluss
  erledigt_am date,
  erledigung text
    check (erledigung in ('bezahlt','abgeschrieben','zurueckgezogen','uebernommen')),
  notiz text,
  erstellt_am timestamptz not null default now(),
  aktualisiert_am timestamptz not null default now()
);

create index if not exists mahnfaelle_betrieb_idx on mahnfaelle(betrieb_id);
create index if not exists mahnfaelle_rechnungen_idx on mahnfaelle using gin(rechnung_ids);

alter table mahnfaelle enable row level security;
create policy mahnfaelle_eigene on mahnfaelle
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Heineken-Kontakt für Mahnfälle
alter table heineken_kontakt_zuweisungen drop constraint if exists heineken_zuweisung_funktion_check;
alter table heineken_kontakt_zuweisungen add constraint heineken_zuweisung_funktion_check
  check (funktion in ('monatsrechnung','raster','heigenie_service','materialbestellung','rsl','mahnwesen'));
```

- [ ] **Step 2: Failing test für das Model schreiben** — `test/mahnfall_model_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/mahnfall.dart';

void main() {
  test('Mahnfall.fromJson liest alle Felder, Datumswerte als UTC-Tage', () {
    final f = Mahnfall.fromJson({
      'id': 'f1',
      'user_id': 'u',
      'betrieb_id': 'b1',
      'rechnung_ids': ['r1', 'r2'],
      'eroeffnet_am': '2026-10-20',
      'status': 'betreibung',
      'test': true,
      'heineken_kontakt_am': '2026-10-20',
      'heineken_empfaenger': 'x@heineken.ch',
      'heineken_ergebnis': 'betreibung',
      'heineken_ergebnis_am': '2026-11-05',
      'heineken_frist_bis': null,
      'schuldner_name': 'Muster GmbH',
      'schuldner_adresse': 'Bahnhofstr. 1, 7000 Chur',
      'rechtsform': 'gmbh',
      'betreibungsamt': 'Betreibungsamt Plessur',
      'eingereicht_am': '2026-11-06',
      'zahlungsbefehl_am': '2026-11-20',
      'rechtsvorschlag': false,
      'fortsetzung_am': null,
      'kosten_vorschuss': 40,
      'erledigt_am': null,
      'erledigung': null,
      'notiz': 'n',
      'erstellt_am': '2026-10-20T10:00:00Z',
      'aktualisiert_am': '2026-10-20T10:00:00Z',
    });
    expect(f.rechnungIds, ['r1', 'r2']);
    expect(f.status, 'betreibung');
    expect(f.zahlungsbefehlAm, DateTime.utc(2026, 11, 20));
    expect(f.kostenVorschuss, 40.0);
    expect(f.rechtsvorschlag, isFalse);
    expect(f.offen, isTrue);
  });

  test('offen ist false bei status erledigt', () {
    final f = Mahnfall.fromJson({
      'id': 'f1', 'user_id': 'u', 'betrieb_id': 'b1', 'rechnung_ids': <String>[],
      'eroeffnet_am': '2026-10-20', 'status': 'erledigt', 'test': false,
      'erstellt_am': '2026-10-20T10:00:00Z', 'aktualisiert_am': '2026-10-20T10:00:00Z',
    });
    expect(f.offen, isFalse);
  });
}
```

- [ ] **Step 3: Test laufen lassen, er schlägt fehl**

Run: `cd sbs_projer_app && flutter test test/mahnfall_model_test.dart`
Expected: FAIL (Datei `mahnfall.dart` fehlt)

- [ ] **Step 4: Model schreiben** — `lib/data/models/mahnfall.dart`

```dart
/// Ein Mahnfall (Migration 204, v0.135.0): Eskalation nach der letzten
/// Mahnung — Heineken einschalten, Ergebnis, ggf. Betreibung. Ein Fall je
/// Betrieb und Eskalation; die Rechnungen des Falls stehen in [rechnungIds].
class Mahnfall {
  final String id;
  final String userId;
  final String betriebId;
  final List<String> rechnungIds;
  final DateTime eroeffnetAm;

  /// 'heineken' | 'heineken_frist' | 'betreibung' | 'erledigt'
  final String status;
  final bool test;

  final DateTime? heinekenKontaktAm;
  final String? heinekenEmpfaenger;

  /// 'vermittelt' | 'uebernommen' | 'konkurs' | 'betreibung'
  final String? heinekenErgebnis;
  final DateTime? heinekenErgebnisAm;
  final DateTime? heinekenFristBis;

  final String? schuldnerName;
  final String? schuldnerAdresse;

  /// 'einzelfirma' | 'gmbh' | 'ag' | 'andere'
  final String? rechtsform;
  final String? betreibungsamt;
  final DateTime? eingereichtAm;
  final DateTime? zahlungsbefehlAm;
  final bool? rechtsvorschlag;
  final DateTime? fortsetzungAm;
  final double? kostenVorschuss;

  final DateTime? erledigtAm;

  /// 'bezahlt' | 'abgeschrieben' | 'zurueckgezogen' | 'uebernommen'
  final String? erledigung;
  final String? notiz;
  final DateTime erstelltAm;
  final DateTime aktualisiertAm;

  const Mahnfall({
    required this.id,
    required this.userId,
    required this.betriebId,
    required this.rechnungIds,
    required this.eroeffnetAm,
    required this.status,
    required this.test,
    this.heinekenKontaktAm,
    this.heinekenEmpfaenger,
    this.heinekenErgebnis,
    this.heinekenErgebnisAm,
    this.heinekenFristBis,
    this.schuldnerName,
    this.schuldnerAdresse,
    this.rechtsform,
    this.betreibungsamt,
    this.eingereichtAm,
    this.zahlungsbefehlAm,
    this.rechtsvorschlag,
    this.fortsetzungAm,
    this.kostenVorschuss,
    this.erledigtAm,
    this.erledigung,
    this.notiz,
    required this.erstelltAm,
    required this.aktualisiertAm,
  });

  bool get offen => status != 'erledigt';

  static DateTime? _tag(dynamic v) {
    if (v == null) return null;
    final d = DateTime.parse(v as String);
    return DateTime.utc(d.year, d.month, d.day);
  }

  factory Mahnfall.fromJson(Map<String, dynamic> j) => Mahnfall(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        betriebId: j['betrieb_id'] as String,
        rechnungIds: List<String>.from(j['rechnung_ids'] as List? ?? const []),
        eroeffnetAm: _tag(j['eroeffnet_am'])!,
        status: j['status'] as String,
        test: j['test'] as bool? ?? true,
        heinekenKontaktAm: _tag(j['heineken_kontakt_am']),
        heinekenEmpfaenger: j['heineken_empfaenger'] as String?,
        heinekenErgebnis: j['heineken_ergebnis'] as String?,
        heinekenErgebnisAm: _tag(j['heineken_ergebnis_am']),
        heinekenFristBis: _tag(j['heineken_frist_bis']),
        schuldnerName: j['schuldner_name'] as String?,
        schuldnerAdresse: j['schuldner_adresse'] as String?,
        rechtsform: j['rechtsform'] as String?,
        betreibungsamt: j['betreibungsamt'] as String?,
        eingereichtAm: _tag(j['eingereicht_am']),
        zahlungsbefehlAm: _tag(j['zahlungsbefehl_am']),
        rechtsvorschlag: j['rechtsvorschlag'] as bool?,
        fortsetzungAm: _tag(j['fortsetzung_am']),
        kostenVorschuss: j['kosten_vorschuss'] == null
            ? null
            : double.parse(j['kosten_vorschuss'].toString()),
        erledigtAm: _tag(j['erledigt_am']),
        erledigung: j['erledigung'] as String?,
        notiz: j['notiz'] as String?,
        erstelltAm: DateTime.parse(j['erstellt_am'] as String),
        aktualisiertAm: DateTime.parse(j['aktualisiert_am'] as String),
      );
}
```

- [ ] **Step 5: Repository schreiben** — `lib/data/repositories/mahnfall_repository.dart`

```dart
import 'package:sbs_projer_app/data/models/mahnfall.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Web-only wie `MahnschreibenRepository` — Mahnfälle gibt es nur online.
class MahnfallRepository {
  static const _tabelle = 'mahnfaelle';

  static String dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<Mahnfall> insert(Map<String, dynamic> json) async {
    final row = await SupabaseService.client.from(_tabelle).insert(json).select().single();
    return Mahnfall.fromJson(row);
  }

  static Future<Mahnfall?> getById(String id) async {
    final row = await SupabaseService.client.from(_tabelle).select().eq('id', id).maybeSingle();
    return row == null ? null : Mahnfall.fromJson(row);
  }

  /// Offene Fälle (status != erledigt). Wenige Zeilen — Filter in Dart,
  /// nicht per .neq() (NULL-Falle, CLAUDE.md), eindeutig sortiert.
  static Future<List<Mahnfall>> getOffene() async {
    final rows = await SupabaseService.client
        .from(_tabelle)
        .select()
        .order('eroeffnet_am', ascending: false)
        .order('id');
    return rows.map((r) => Mahnfall.fromJson(r)).where((f) => f.offen).toList();
  }

  static Future<List<Mahnfall>> getByRechnung(String rechnungId) async {
    final rows = await SupabaseService.client
        .from(_tabelle)
        .select()
        .contains('rechnung_ids', [rechnungId])
        .order('eroeffnet_am', ascending: false)
        .order('id');
    return rows.map((r) => Mahnfall.fromJson(r)).toList();
  }

  static Future<Mahnfall> update(String id, Map<String, dynamic> felder) async {
    final row = await SupabaseService.client
        .from(_tabelle)
        .update({...felder, 'aktualisiert_am': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .select()
        .single();
    return Mahnfall.fromJson(row);
  }

  /// Nur für den Testmodus: einen frisch eröffneten Fall ohne Ergebnis
  /// wieder entfernen (siehe MahnfallService.zuruecknehmen).
  static Future<void> delete(String id) async {
    await SupabaseService.client.from(_tabelle).delete().eq('id', id);
  }
}
```

- [ ] **Step 6: Test laufen lassen, er besteht**

Run: `cd sbs_projer_app && flutter test test/mahnfall_model_test.dart`
Expected: PASS (2 Tests)

- [ ] **Step 7: Commit**

```bash
git add Datenbank/migrations/204_mahnfaelle.sql sbs_projer_app/lib/data/models/mahnfall.dart sbs_projer_app/lib/data/repositories/mahnfall_repository.dart sbs_projer_app/test/mahnfall_model_test.dart
git commit -m "feat(mahnwesen): Migration 204 mahnfaelle, Model und Repository"
```

---

### Task 2: Reine Regeln

**Files:**
- Modify: `sbs_projer_app/lib/core/util/mahnregeln.dart` (Fall `mahnung_2` in `faelligeStufe` bleibt `null`; neue Funktion daneben)
- Create: `sbs_projer_app/lib/core/util/mahnfall_regeln.dart`
- Test: `sbs_projer_app/test/mahnfall_regeln_test.dart`, `sbs_projer_app/test/mahnregeln_test.dart`

- [ ] **Step 1: Failing tests** — an `test/mahnregeln_test.dart` anhängen (Helfer `_r` existiert dort schon):

```dart
  group('eskalationFaellig', () {
    test('mahnung_2, Frist + 5 Tage vor dem Puffer-Stichtag → true', () {
      final r = _r(
          datum: DateTime.utc(2026, 6, 1),
          status: 'mahnung_2',
          mahnung2: DateTime.utc(2026, 9, 1),
          frist: DateTime.utc(2026, 9, 11));
      // Frist 11.09. + 5 = 16.09.; Stichtag 19.09. − 3 = 16.09. → erreicht
      expect(eskalationFaellig(r, stichtag: DateTime.utc(2026, 9, 19)), isTrue);
      expect(eskalationFaellig(r, stichtag: DateTime.utc(2026, 9, 18)), isFalse);
    });
    test('ohne mahn_frist_bis zählt mahnung_2_am + 10', () {
      final r = _r(
          datum: DateTime.utc(2026, 6, 1),
          status: 'mahnung_2',
          mahnung2: DateTime.utc(2026, 9, 1));
      expect(eskalationFaellig(r, stichtag: DateTime.utc(2026, 9, 19)), isTrue);
    });
    test('andere Stufe oder bezahlt → false', () {
      final r = _r(datum: DateTime.utc(2026, 6, 1), status: 'mahnung_1',
          mahnung1: DateTime.utc(2026, 8, 1));
      expect(eskalationFaellig(r, stichtag: DateTime.utc(2026, 12, 1)), isFalse);
      final b = _r(datum: DateTime.utc(2026, 6, 1), status: 'mahnung_2',
          mahnung2: DateTime.utc(2026, 8, 1), zahlungEingegangen: DateTime.utc(2026, 8, 5));
      expect(eskalationFaellig(b, stichtag: DateTime.utc(2026, 12, 1)), isFalse);
    });
  });
```

`test/mahnfall_regeln_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/mahnfall_regeln.dart';

void main() {
  group('betreibungsKostenvorschuss (GebV SchKG Art. 16)', () {
    test('Stufen', () {
      expect(betreibungsKostenvorschuss(94.05), 7);
      expect(betreibungsKostenvorschuss(100), 7);
      expect(betreibungsKostenvorschuss(100.05), 20);
      expect(betreibungsKostenvorschuss(470.25), 20);
      expect(betreibungsKostenvorschuss(999), 40);
      expect(betreibungsKostenvorschuss(5000), 60);
      expect(betreibungsKostenvorschuss(50000), 90);
      expect(betreibungsKostenvorschuss(500000), 190);
      expect(betreibungsKostenvorschuss(2000000), 400);
    });
  });

  group('fortsetzungsFenster (SchKG 88)', () {
    test('frühestens 20 Tage nach Zahlungsbefehl, verwirkt nach 1 Jahr', () {
      final f = fortsetzungsFenster(DateTime.utc(2026, 11, 20));
      expect(f.ab, DateTime.utc(2026, 12, 10));
      expect(f.bis, DateTime.utc(2027, 11, 20));
    });
  });

  group('mahnfallAufgaben', () {
    final heute = DateTime.utc(2026, 12, 15);
    test('Heineken seit 20 Tagen ohne Ergebnis → Aufgabe', () {
      final a = mahnfallAufgaben(
        fallId: 'f1', betrieb: 'Hemingway, Chur', status: 'heineken',
        heinekenKontaktAm: DateTime.utc(2026, 11, 20), heute: heute);
      expect(a.single.key, 'mahnfall:f1:heineken');
    });
    test('Heineken erst 10 Tage → keine Aufgabe', () {
      final a = mahnfallAufgaben(
        fallId: 'f1', betrieb: 'X', status: 'heineken',
        heinekenKontaktAm: DateTime.utc(2026, 12, 5), heute: heute);
      expect(a, isEmpty);
    });
    test('Vermittlungsfrist abgelaufen → dringend', () {
      final a = mahnfallAufgaben(
        fallId: 'f1', betrieb: 'X', status: 'heineken_frist',
        heinekenFristBis: DateTime.utc(2026, 12, 10), heute: heute);
      expect(a.single.key, 'mahnfall:f1:frist');
      expect(a.single.dringend, isTrue);
    });
    test('Zahlungsbefehl ohne Rechtsvorschlag, +20 Tage → Fortsetzung möglich', () {
      final a = mahnfallAufgaben(
        fallId: 'f1', betrieb: 'X', status: 'betreibung',
        zahlungsbefehlAm: DateTime.utc(2026, 11, 20), rechtsvorschlag: false,
        heute: heute);
      expect(a.single.key, 'mahnfall:f1:fortsetzung');
    });
    test('Fortsetzung schon gestellt → keine Aufgabe', () {
      final a = mahnfallAufgaben(
        fallId: 'f1', betrieb: 'X', status: 'betreibung',
        zahlungsbefehlAm: DateTime.utc(2026, 11, 20), rechtsvorschlag: false,
        fortsetzungAm: DateTime.utc(2026, 12, 12), heute: heute);
      expect(a, isEmpty);
    });
    test('11 Monate nach Zahlungsbefehl ohne Fortsetzung → dringende Warnung', () {
      final a = mahnfallAufgaben(
        fallId: 'f1', betrieb: 'X', status: 'betreibung',
        zahlungsbefehlAm: DateTime.utc(2026, 1, 10), rechtsvorschlag: true,
        heute: DateTime.utc(2026, 12, 15));
      expect(a.single.key, 'mahnfall:f1:verwirkung');
      expect(a.single.dringend, isTrue);
    });
    test('Übernahme durch Heineken → dringende Buchungsaufgabe', () {
      final a = mahnfallAufgaben(
        fallId: 'f1', betrieb: 'X', status: 'erledigt',
        erledigung: 'uebernommen', uebernahmeVerbucht: false, heute: heute);
      expect(a.single.key, 'mahnfall:f1:uebernahme');
      expect(a.single.dringend, isTrue);
    });
  });

  test('alleBezahlt: nur wenn jede Rechnung bezahlt oder abgeschrieben', () {
    expect(alleBezahlt(['bezahlt', 'abgeschrieben']), isTrue);
    expect(alleBezahlt(['bezahlt', 'mahnung_2']), isFalse);
    expect(alleBezahlt(const []), isFalse);
  });
}
```

- [ ] **Step 2: Tests laufen lassen, sie schlagen fehl**

Run: `cd sbs_projer_app && flutter test test/mahnfall_regeln_test.dart test/mahnregeln_test.dart`
Expected: FAIL (Funktionen fehlen)

- [ ] **Step 3: `eskalationFaellig` in `mahnregeln.dart`** direkt unter `faelligeStufe` einfügen:

```dart
/// Ist die Frist der letzten Mahnung + [kNaechsteStufeNachFrist] Tage vor dem
/// Puffer-Stichtag vorbei? Dann schlägt die App vor, Heineken einzuschalten
/// (Mahnwesen Teil 2, Spec §2/§5). Gleicher Stichtag wie [faelligeStufe]:
/// Ende des letzten Bankauszugs, nicht heute.
bool eskalationFaellig(Rechnung r, {required DateTime stichtag}) {
  if (!imMahnbereich(r) || r.zahlungsstatus != 'mahnung_2') return false;
  final frist = r.mahnFristBis ??
      (r.mahnung2Am != null ? _plus(r.mahnung2Am!, kMahnFristTage) : null);
  if (frist == null) return false;
  final grenze = _plus(stichtag, -kPufferVorStichtagTage);
  return !_plus(frist, kNaechsteStufeNachFrist).isAfter(grenze);
}
```

- [ ] **Step 4: `lib/core/util/mahnfall_regeln.dart` schreiben**

```dart
import 'package:sbs_projer_app/core/util/aufgaben_regeln.dart';

/// Reine Regeln der Eskalation (Mahnwesen Teil 2, Spec §5). Keine DB, keine
/// Widgets — alles hier ist mit Tests abgesichert.

/// Tage ohne Heineken-Ergebnis, nach denen die Glocke nachfragt.
const kHeinekenNachfrageTage = 20;

/// Standardfrist, wenn Heineken vermittelt hat und der Kunde zahlen will.
const kVermittlungsFristTage = 20;

/// SchKG 88 Abs. 1: Fortsetzung frühestens 20 Tage nach Zustellung des
/// Zahlungsbefehls; Abs. 2: das Recht erlischt nach einem Jahr.
const kFortsetzungAbTage = 20;

DateTime _tag(DateTime d) => DateTime.utc(d.year, d.month, d.day);
DateTime _plus(DateTime d, int tage) => _tag(d).add(Duration(days: tage));

/// Kostenvorschuss für den Zahlungsbefehl nach GebV SchKG Art. 16 Abs. 1.
double betreibungsKostenvorschuss(double forderung) {
  if (forderung <= 100) return 7;
  if (forderung <= 500) return 20;
  if (forderung <= 1000) return 40;
  if (forderung <= 10000) return 60;
  if (forderung <= 100000) return 90;
  if (forderung <= 1000000) return 190;
  return 400;
}

/// Zeitfenster für das Fortsetzungsbegehren ab Zustellung des Zahlungsbefehls.
({DateTime ab, DateTime bis}) fortsetzungsFenster(DateTime zahlungsbefehlAm) {
  final z = _tag(zahlungsbefehlAm);
  return (
    ab: _plus(z, kFortsetzungAbTage),
    bis: DateTime.utc(z.year + 1, z.month, z.day),
  );
}

/// Alle Rechnungen eines Falls beglichen (bezahlt/abgeschrieben)?
bool alleBezahlt(List<String> zahlungsstatus) =>
    zahlungsstatus.isNotEmpty &&
    zahlungsstatus.every((s) => s == 'bezahlt' || s == 'abgeschrieben');

/// Glocken-Aufgaben eines Mahnfalls. Schlüssel `mahnfall:<id>:<art>`.
List<Aufgabe> mahnfallAufgaben({
  required String fallId,
  required String betrieb,
  required String status,
  DateTime? heinekenKontaktAm,
  DateTime? heinekenFristBis,
  DateTime? zahlungsbefehlAm,
  bool? rechtsvorschlag,
  DateTime? fortsetzungAm,
  String? erledigung,
  bool uebernahmeVerbucht = true,
  required DateTime heute,
}) {
  final h = _tag(heute);
  final route = '/rechnungen/mahnfall/$fallId';
  final a = <Aufgabe>[];
  switch (status) {
    case 'heineken':
      if (heinekenKontaktAm != null &&
          !_plus(heinekenKontaktAm, kHeinekenNachfrageTage).isAfter(h)) {
        a.add(Aufgabe(
            key: 'mahnfall:$fallId:heineken',
            titel: 'Mahnfall $betrieb: Heineken seit $kHeinekenNachfrageTage Tagen ohne Ergebnis',
            route: route));
      }
    case 'heineken_frist':
      if (heinekenFristBis != null && heinekenFristBis.isBefore(h)) {
        a.add(Aufgabe(
            key: 'mahnfall:$fallId:frist',
            titel: 'Mahnfall $betrieb: Zahlungsfrist nach Vermittlung abgelaufen',
            dringend: true,
            route: route));
      }
    case 'betreibung':
      if (zahlungsbefehlAm != null && fortsetzungAm == null) {
        final f = fortsetzungsFenster(zahlungsbefehlAm);
        final warnAb = DateTime.utc(f.bis.year, f.bis.month - 1, f.bis.day);
        if (!warnAb.isAfter(h)) {
          a.add(Aufgabe(
              key: 'mahnfall:$fallId:verwirkung',
              titel: 'Mahnfall $betrieb: Betreibung verfällt am '
                  '${f.bis.day}.${f.bis.month}.${f.bis.year}',
              dringend: true,
              route: route));
        } else if (rechtsvorschlag == false && !f.ab.isAfter(h)) {
          a.add(Aufgabe(
              key: 'mahnfall:$fallId:fortsetzung',
              titel: 'Mahnfall $betrieb: Fortsetzungsbegehren möglich',
              route: route));
        }
      }
    case 'erledigt':
      if (erledigung == 'uebernommen' && !uebernahmeVerbucht) {
        a.add(Aufgabe(
            key: 'mahnfall:$fallId:uebernahme',
            titel: 'Mahnfall $betrieb: Heineken-Übernahme verbuchen — mit Daniel prüfen',
            dringend: true,
            route: route));
      }
  }
  return a;
}
```

Hinweis: Die Klasse `Aufgabe` (`lib/core/util/aufgaben_regeln.dart`, Z. 21) hat die Felder `key`, `titel`, `dringend` (Default false), `route`, `manuellErledigbar`, `istVorrat`. Konstruktor dort prüfen und Parameternamen genau übernehmen.

- [ ] **Step 5: Tests laufen lassen, sie bestehen**

Run: `cd sbs_projer_app && flutter test test/mahnfall_regeln_test.dart test/mahnregeln_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add sbs_projer_app/lib/core/util/mahnregeln.dart sbs_projer_app/lib/core/util/mahnfall_regeln.dart sbs_projer_app/test/mahnfall_regeln_test.dart sbs_projer_app/test/mahnregeln_test.dart
git commit -m "feat(mahnwesen): Regeln fuer Eskalation, Kostenvorschuss, Fristen"
```

Die Aufgabe «Übernahme verbuchen» braucht ein Kennzeichen, ob die Übernahme schon verbucht ist. Dafür reicht in Teil 2 das Feld `notiz`: Der Service schreibt beim Ergebnis `uebernommen` die Zeile `[UEBERNAHME OFFEN]` in die Notiz; der Knopf «Übernahme verbucht» im Fall-Screen entfernt sie. Provider übergibt `uebernahmeVerbucht: !(fall.notiz ?? '').contains('[UEBERNAHME OFFEN]')`.

---

### Task 3: Mahnlauf nimmt Fall-Rechnungen aus, neue Sektionen

**Files:**
- Modify: `sbs_projer_app/lib/presentation/providers/mahnlauf_provider.dart` (`MahnlaufDaten`, `baueMahnlauf`, `mahnlaufProvider`)
- Modify: `sbs_projer_app/lib/presentation/screens/rechnungen/mahnlauf_screen.dart`
- Test: `sbs_projer_app/test/mahnlauf_provider_test.dart`

- [ ] **Step 1: Failing tests** in `test/mahnlauf_provider_test.dart` (dort existierende Helfer für Rechnungen/Betriebe und den bestehenden `baueMahnlauf`-Aufruf wiederverwenden; neuer benannter Parameter `faelleRechnungIds: Set<String>`):
  1. Eine `mahnung_2`-Rechnung mit abgelaufener Frist+5 (vor Puffer-Stichtag) erscheint in `daten.eskalation` (Liste `MahnBetrieb` mit dieser Rechnung in `faellig`) und NICHT in `inFrist`.
  2. Dieselbe Rechnung, deren Id in `faelleRechnungIds` steht, erscheint weder in `eskalation`, `betriebe`, `inFrist` noch `erstZustellen`, sondern in `daten.imFall`.
  3. Eine `mahnung_1`-Rechnung in `faelleRechnungIds` taucht ebenfalls nur in `imFall` auf (ein Fall friert alle seine Rechnungen ein).
  4. Die Bank-Sperre gilt auch für `eskalation` (bei `bankGesperrt` ist `eskalation` leer, wie `betriebe`).

- [ ] **Step 2: Test laufen lassen → FAIL**

Run: `cd sbs_projer_app && flutter test test/mahnlauf_provider_test.dart`

- [ ] **Step 3: Implementieren**
  - `MahnlaufDaten`: neue Felder `final List<MahnBetrieb> eskalation;` und `final List<Rechnung> imFall;` (Konstruktor, Default `const []`).
  - `baueMahnlauf(...)`: neuer Parameter `Set<String> faelleRechnungIds = const {}`. Zu Beginn: Rechnungen mit Id in `faelleRechnungIds` in `imFall` sammeln und aus der weiteren Verarbeitung entfernen. Beim Einteilen: `eskalationFaellig(r, stichtag: letzterAuszug)` → in eine Map je Betrieb für `eskalation` (gleiche `MahnBetrieb`-Bildung wie für `betriebe`, gleiche Sperren: Gutschrift-, Zahlungs-Sperre setzen `sperrgrund`); bei Bank-Sperre leer lassen. `mahnung_2` ohne fällige Eskalation bleibt in `inFrist`.
  - `mahnlaufProvider`: zusätzlich `MahnfallRepository.getOffene()` parallel laden, `faelleRechnungIds = {for (f in faelle) ...f.rechnungIds}` übergeben.
  - Screen: nach «Mahnfällig» zwei Sektionen:
    - **«Heineken einschalten (N)»**: je Betrieb eine Karte wie `_betriebKarte`, aber mit einem `TapKnopf(text: 'Mahnfall eröffnen', primaer: true, onTap: ...)` (ruft in Task 5 `MahnfallService.eroeffnen`, bis dahin `onTap: null` und Hinweistext «folgt»). Gesperrte Betriebe zeigen `sperrgrund` wie bei «Mahnfällig».
    - **«Offene Mahnfälle (N)»**: je offener Fall eine Zeile (Betrieb, Status-Text, Anzahl Rechnungen, Summe) als `InkWell` + `Container` + `Row`, Tap → `context.push('/rechnungen/mahnfall/${fall.id}')`. Dafür lädt der Provider die offenen Fälle zusätzlich in `MahnlaufDaten.offeneFaelle` (`List<Mahnfall>`).
  - Status-Texte zentral als Top-Level-Funktion im Screen: `heineken` → «Bei Heineken», `heineken_frist` → «Kunde zahlt bis …», `betreibung` → «Betreibung», `erledigt` → «Erledigt».

- [ ] **Step 4: Tests + analyze**

Run: `cd sbs_projer_app && flutter test && flutter analyze`
Expected: alle grün, analyze ≤ 56

- [ ] **Step 5: Commit**

```bash
git commit -am "feat(mahnwesen): Mahnlauf zeigt Eskalation und offene Mahnfaelle"
```

---

### Task 4: Heineken-Zuweisung «Mahnwesen»

**Files:**
- Modify: `sbs_projer_app/lib/data/repositories/kontakt_repository.dart` (Map-Vorbelegung in `getAllHeinekenZuweisungen`, ca. Z. 110–116)
- Modify: `sbs_projer_app/lib/presentation/screens/heineken/heineken_zuweisungen_screen.dart` (Liste `_funktionen`, Z. 23–29)

- [ ] **Step 1:** In `getAllHeinekenZuweisungen` den Schlüssel `'mahnwesen': null` zur Vorbelegung ergänzen.
- [ ] **Step 2:** In `_funktionen` ergänzen: `('mahnwesen', 'Mahnwesen', '<Icon wie die anderen Einträge, z. B. Icons.gavel>')` — das Tupel-Format der bestehenden Einträge exakt übernehmen (drittes Element prüfen).
- [ ] **Step 3:** `flutter test && flutter analyze` → grün, ≤ 56.
- [ ] **Step 4: Commit**

```bash
git commit -am "feat(heineken): Kontakt-Zuweisung Mahnwesen"
```

---

### Task 5: MahnfallService

**Files:**
- Create: `sbs_projer_app/lib/services/rechnung/mahnfall_service.dart`
- Modify: `sbs_projer_app/test/mahnwesen_testmodus_waechter_test.dart` (zweite Datei prüfen)
- Test: `sbs_projer_app/test/mahnfall_service_test.dart` (reine Teile)

API (alle `static`):

```dart
class MahnfallFehler implements Exception {
  final String meldung;
  MahnfallFehler(this.meldung);
  @override
  String toString() => meldung;
}

class MahnfallService {
  /// Fall eröffnen + Heineken-Mail. Prüft vorher frisch aus der DB, dass jede
  /// Rechnung noch `mahnung_2` und im Mahnbereich ist (sonst MahnfallFehler
  /// «Rechnung … wurde inzwischen geändert»), und dass keine der Rechnungen
  /// schon in einem offenen Fall steckt.
  static Future<Mahnfall> eroeffnen({
    required BetriebLocal betrieb,
    required List<Rechnung> rechnungen,
    DateTime? heute,
  });

  /// Nur bei status 'heineken' ohne Ergebnis: Fall löschen (Testmodus-Rückweg).
  static Future<void> zuruecknehmen(Mahnfall fall);

  /// Ergebnis erfassen:
  /// - 'vermittelt'  → status heineken_frist, heineken_frist_bis = heute + 20
  /// - 'uebernommen' → status erledigt, erledigung uebernommen,
  ///                   notiz += '[UEBERNAHME OFFEN]' (keine Buchung, Plan-Kopf)
  /// - 'konkurs'     → je Rechnung MahnwesenService.abschreiben(r),
  ///                   status erledigt, erledigung abgeschrieben
  /// - 'betreibung'  → status betreibung, kosten_vorschuss vorbelegt mit
  ///                   betreibungsKostenvorschuss(summe offen),
  ///                   schuldner_name/-adresse vorbelegt aus Rechnungsadresse
  ///                   (firma ?? betrieb.name; strasse nr, plz ort)
  static Future<Mahnfall> ergebnis(Mahnfall fall, String ergebnis, {DateTime? heute});

  /// Betreibungsfelder speichern (Datenblatt und Schritte).
  static Future<Mahnfall> betreibungSpeichern(Mahnfall fall, Map<String, dynamic> felder);

  /// Fall abschliessen: 'bezahlt' | 'abgeschrieben' | 'zurueckgezogen'.
  static Future<Mahnfall> erledigen(Mahnfall fall, String erledigung, {DateTime? heute});

  /// Nach «vermittelt» ohne Zahlung: zurück zu status 'heineken' mit
  /// heineken_ergebnis 'betreibung' → gleich wie ergebnis(fall,'betreibung').

  /// Markierung [UEBERNAHME OFFEN] entfernen, sobald Daniel verbucht hat.
  static Future<Mahnfall> uebernahmeVerbucht(Mahnfall fall);

  /// Reiner Text der Heineken-Mail (testbar).
  static String heinekenMailText({
    required String betrieb,
    required List<Rechnung> rechnungen,
    required Map<String, List<DateTime>> mahnDaten, // rechnungId → [Erinnerung, 1., letzte]
  });
}
```

- [ ] **Step 1: Failing test für `heinekenMailText`** — `test/mahnfall_service_test.dart`: Text enthält «Hemingway, Chur», jede Rechnungsnummer mit Datum und Betrag, das Total (z. B. «CHF 470.25»), die Mahndaten und den Satz «Könnt ihr mit dem Betrieb Kontakt aufnehmen?». Kein Verzugszins, keine Gebühren.
- [ ] **Step 2: Test → FAIL**, dann `heinekenMailText` implementieren, Test → PASS.
- [ ] **Step 3: `eroeffnen` implementieren**
  1. Frischer Abgleich: `RechnungRepository.getById(id)` je Rechnung; `imMahnbereich` und `zahlungsstatus == 'mahnung_2'` prüfen; `MahnfallRepository.getOffene()` → keine Überschneidung der Rechnung-Ids.
  2. Kontakt: `KontaktRepository.getHeinekenZuweisung('mahnwesen')`. Fehlt er oder hat keine Mail → `MahnfallFehler('Kein Heineken-Kontakt «Mahnwesen» hinterlegt — unter Heineken → Zuweisungen erfassen')`.
  3. `final muster = !MailConfig.istScharf('mahnwesen');`
  4. Fall anlegen: `MahnfallRepository.insert({'user_id': SupabaseService.dataUserId, 'betrieb_id': betrieb.serverId, 'rechnung_ids': ids, 'eroeffnet_am': dateStr(heute), 'status': 'heineken', 'test': muster, 'heineken_kontakt_am': dateStr(heute), 'heineken_empfaenger': kontakt.email})`.
  5. Kontoauszug des laufenden Jahres erzeugen: `KontoauszugPdfService.generate(betrieb: betrieb, rechnungen: <alle Rechnungen des Betriebs im Jahr, frisch geladen wie im MahnlaufService>, rechnungsadresse: ra, jahr: heute.year, muster: muster, mitZahlteil: false)` und hochladen nach `'<dataUserId>/mahnfaelle/<fallId>/kontoauszug.pdf'` (neue Methode `RechnungPdfStorage.uploadMahnfallPdf(fallId, datei, bytes)` nach dem Vorbild `uploadMahnlaufPdf`, Ordner `mahnfaelle` statt `mahnungen`).
  6. Mail: 
     ```dart
     final empfaenger = MailConfig.empfaenger(kontakt.email, bereich: 'mahnwesen');
     var subject = 'Offene Rechnungen ${betrieb.name}, ${betrieb.ort} — Bitte um Unterstützung';
     if (muster) subject = 'TEST an: ${kontakt.email} — $subject';
     await SupabaseService.client.functions.invoke('send-rechnung-mail', body: {
       'to': empfaenger,
       'subject': subject,
       'bodyText': heinekenMailText(...),
       'userId': SupabaseService.dataUserId,
       'zusatzPdfs': [
         {'pfad': '$uid/mahnfaelle/${fall.id}/kontoauszug.pdf', 'dateiname': 'Kontoauszug.pdf', 'pflicht': true},
         for (final r in rechnungen)
           {'pfad': '$uid/${r.id}/rechnung.pdf', 'dateiname': 'Rechnung_${r.rechnungsnummer}.pdf', 'pflicht': false},
       ],
     });
     ```
     Kein `rechnungId`/`markiereVersandt` (sonst schlägt `versandvermerk_waechter_test` an bzw. der Versandvermerk würde überschrieben).
  7. Schlägt die Mail fehl: Fall bleibt bestehen (Protokoll), `MahnfallFehler('Fall angelegt, Mail an Heineken fehlgeschlagen: …')` — im Screen mit Knopf «Mail erneut senden» (ruft eine private Funktion `_heinekenMail(fall)` erneut; als öffentliche Methode `mailErneutSenden(Mahnfall fall)` exportieren).
- [ ] **Step 4: Übrige Methoden** gemäss API-Kommentaren implementieren. `ergebnis('konkurs')` ruft je Rechnung `MahnwesenService.abschreiben(r, heute: heute)` (Signatur `static Future<void> abschreiben(Rechnung rechnung, {DateTime? heute})`) — vorher frisch laden und nur Rechnungen abschreiben, die nicht bezahlt/abgeschrieben sind.
- [ ] **Step 5: Wächter erweitern** — in `test/mahnwesen_testmodus_waechter_test.dart` einen dritten Test ergänzen, der dieselben beiden Bedingungen (`MailConfig.empfaenger(…bereich: 'mahnwesen')` und `'TEST an: `) für `lib/services/rechnung/mahnfall_service.dart` prüft.
- [ ] **Step 6:** `flutter test && flutter analyze` → grün, ≤ 56.
- [ ] **Step 7: Commit**

```bash
git add sbs_projer_app/lib/services/rechnung/mahnfall_service.dart sbs_projer_app/lib/services/pdf/rechnung_pdf_storage.dart sbs_projer_app/test/mahnfall_service_test.dart sbs_projer_app/test/mahnwesen_testmodus_waechter_test.dart
git commit -m "feat(mahnwesen): MahnfallService mit Heineken-Mail, Ergebnissen, Betreibung"
```

---

### Task 6: Mahnfall-Screen und Route

**Files:**
- Create: `sbs_projer_app/lib/presentation/providers/mahnfall_providers.dart`
- Create: `sbs_projer_app/lib/presentation/screens/rechnungen/mahnfall_screen.dart`
- Modify: `sbs_projer_app/lib/core/config/router.dart` (Route unter `/rechnungen`, wie `/rechnungen/mahnlauf`)
- Modify: `sbs_projer_app/lib/presentation/screens/rechnungen/mahnlauf_screen.dart` (Knopf «Mahnfall eröffnen» verdrahten)
- Modify: `sbs_projer_app/lib/presentation/screens/rechnungen/widgets/mahnverlauf.dart` (Hinweis «Im Mahnfall» mit Link)
- Modify: `sbs_projer_app/test/canvaskit_sichere_widgets_test.dart` (neue Datei in die Liste)

- [ ] **Step 1: Provider**

```dart
final mahnfallProvider = FutureProvider.autoDispose.family<Mahnfall?, String>(
    (ref, id) => MahnfallRepository.getById(id));
final mahnfaelleZuRechnungProvider = FutureProvider.autoDispose.family<List<Mahnfall>, String>(
    (ref, rechnungId) => MahnfallRepository.getByRechnung(rechnungId));
```

- [ ] **Step 2: Route** `GoRoute(path: '/rechnungen/mahnfall/:id', builder: (c, s) => MahnfallScreen(id: s.pathParameters['id']!))` — Detailroute (`/:`), der Erreichbarkeits-Wächter verlangt dafür keinen Eintrag.

- [ ] **Step 3: Screen** — `ConsumerStatefulWidget`, `ListView` bei 360 px ohne horizontales Scrollen, Titel «Mahnfall · v$kAppVersion» (Version sichtbar, CLAUDE.md). Blöcke als `_kasten`-artige Container (Muster aus `mahnlauf_screen.dart` Z. 772 kopieren, nicht importieren):
  1. **Kopf:** Betrieb, Ort, Status-Text, eröffnet am, Testmodus-Zeile wenn `fall.test`.
  2. **Rechnungen:** je Rechnung Nummer, Datum, Betrag, Status; Tap → `/rechnungen/<id>`; Total. Sind alle bezahlt (`alleBezahlt`), grüner Hinweis mit `TapKnopf('Fall abschliessen (bezahlt)')` → `erledigen(fall,'bezahlt')`.
  3. **Heineken** (status `heineken`/`heineken_frist`): Kontakt am, Empfänger; bei `heineken`: vier Knöpfe untereinander — `TapKnopf('Vermittelt — Kunde zahlt')`, `TapKnopf('Heineken übernimmt')`, `TapKnopf('Kunde in Konkurs — abschreiben', gefahr: true)`, `TapKnopf('Betreibung auslösen')`; jeder mit Bestätigungsdialog (Dialog-Knöpfe als `TapKnopf`, der Konkurs-Knopf `gefahr: true`). Bei `heineken_frist`: «Kunde zahlt bis <Datum>» + `TapKnopf('Keine Zahlung — Betreibung auslösen')`. Ohne Ergebnis und `fall.test`: `TapKnopf('Fall zurücknehmen', gefahr: true)` → `zuruecknehmen`. Wenn die Mail beim Eröffnen fehlschlug: `TapKnopf('Mail an Heineken erneut senden')`.
  4. **Betreibung** (status `betreibung`):
     - **Datenblatt zum Abtippen in EasyGov** (Textfelder, speichern über `betreibungSpeichern`): Schuldner Name, Adresse, Rechtsform (kompaktes `DropdownButton<String>` mit einzelfirma/gmbh/ag/andere; bei Einzelfirma Hinweis «Wohnsitz des Inhabers angeben»), Betreibungsamt (Freitext, Hinweis «zuständig: Amt am Sitz bzw. Wohnsitz des Schuldners»).
     - **Forderung** je Rechnung (Nummer, Betrag) + Zeile «nebst Zins zu 5 % seit <Datum der Zahlungserinnerung der ältesten Rechnung>» (Erinnerungsdatum aus `rechnung.erinnerungAm`).
     - **Kostenvorschuss** (vorbelegt, änderbar).
     - Link-Zeile «EasyGov öffnen» → `https://www.easygov.swiss` (über den im Projekt üblichen URL-Launcher; per Grep nach `launchUrl` das Muster finden).
     - **Schritte mit Datum** (Datumsauswahl über das im Projekt übliche Datumsfeld; Zeitauswahl nicht nötig): eingereicht am, Zahlungsbefehl zugestellt am, Rechtsvorschlag ja/nein (zwei Chips als `GestureDetector`), Fortsetzungsbegehren am. Unter dem Zahlungsbefehl: «Fortsetzung möglich ab <fenster.ab>, spätestens bis <fenster.bis>».
     - **Bei Rechtsvorschlag:** Hinweis aus der Recherche (Abschnitt 7): «Unterschriebene Reinigungsprotokolle helfen, sind aber keine Schuldanerkennung — Rechtsöffnung unsicher, ggf. Fachperson beiziehen», plus je Rechnung ein Link «Protokoll» (Weg: `rechnungs_positionen.service_id` → `reinigungen.protokoll_foto_pfad`, analog `rechnung_detail_screen.dart` `_findProtokollPfad`, Z. 691–713 — für ALLE Reinigungspositionen, nicht nur die erste).
     - Abschluss: `TapKnopf('Erledigt: bezahlt')`, `TapKnopf('Erledigt: abgeschrieben', gefahr: true)` (ruft zusätzlich je offene Rechnung `MahnwesenService.abschreiben`), `TapKnopf('Betreibung zurückgezogen')`.
  4b. **Konkurs** (erledigt/abgeschrieben nach Ergebnis `konkurs`): Hinweis «Forderung kann beim Konkursamt angemeldet werden (Eingabe innert der publizierten Frist, SHAB)».
  5. **Übernahme** (erledigt/uebernommen): orange Karte «Heineken hat übernommen — Buchung und Position auf der Monatsrechnung mit Daniel prüfen» + `TapKnopf('Übernahme ist verbucht')` → `uebernahmeVerbucht`.
  6. **Notiz:** mehrzeiliges Textfeld, speichern über `betreibungSpeichern(fall, {'notiz': …})`.
  - Nach jeder Aktion `ref.invalidate(mahnfallProvider(id))` und `ref.invalidate(mahnlaufProvider)`.
- [ ] **Step 4: Mahnlauf verdrahten:** «Mahnfall eröffnen» → Vorschau-Dialog (Empfänger Heineken, Testmodus-Hinweis, Rechnungen) → `MahnfallService.eroeffnen` → bei Erfolg `context.push('/rechnungen/mahnfall/${fall.id}')`; bei `MahnfallFehler` Meldung im Dialog (keine rohe Exception).
- [ ] **Step 5: Mahnverlauf:** Steht die Rechnung in einem Fall (`mahnfaelleZuRechnungProvider`), oben eine Zeile «Im Mahnfall seit <Datum> · <Status>», Tap → Fall-Screen.
- [ ] **Step 6:** `mahnfall_screen.dart` in die Dateiliste von `test/canvaskit_sichere_widgets_test.dart` aufnehmen.
- [ ] **Step 7:** `flutter test && flutter analyze` → grün, ≤ 56.
- [ ] **Step 8: Commit**

```bash
git commit -am "feat(mahnwesen): Mahnfall-Screen mit Heineken-Ergebnissen und Betreibung"
```

(Neue Dateien vorher mit `git add` aufnehmen.)

---

### Task 7: Glocke

**Files:**
- Modify: `sbs_projer_app/lib/presentation/providers/aufgaben_detektoren_provider.dart` (neben `mahnlaufAufgabeProvider`)
- Modify: `sbs_projer_app/lib/presentation/providers/aufgaben_providers.dart` (`aufgabenListeProvider`, parallel einbinden)

- [ ] **Step 1:** Neuer `mahnfallAufgabenProvider = FutureProvider<List<Aufgabe>>`: lädt `MahnfallRepository.getOffene()` **und** erledigte Fälle mit Notiz `[UEBERNAHME OFFEN]` (dafür im Repository `getMitOffenerUebernahme()` ergänzen: alle Fälle laden, in Dart auf `status == 'erledigt' && (notiz ?? '').contains('[UEBERNAHME OFFEN]')` filtern, sortiert mit `.order('id')`), Betriebsnamen über `betriebeProvider`, ruft je Fall `mahnfallAufgaben(...)` und gibt die flache Liste zurück. Fehler per try/catch + `debugPrint` → leere Liste (wie die übrigen Detektoren).
- [ ] **Step 2:** In `aufgabenListeProvider` den neuen Provider parallel mit dem Mahnlauf und den Detektoren abwarten (`.wait`) und die Aufgaben anhängen. `aufgaben_eine_quelle_waechter_test.dart` muss grün bleiben.
- [ ] **Step 3:** Test in `test/aufgaben_providers_test.dart` analog zur Mahnlauf-Aufgabe: überschriebener `mahnfallAufgabenProvider` mit einer Aufgabe → erscheint in der Liste.
- [ ] **Step 4:** `flutter test && flutter analyze` → grün, ≤ 56.
- [ ] **Step 5: Commit**

```bash
git commit -am "feat(mahnwesen): Mahnfall-Fristen in der Glocke"
```

---

### Task 8: Release v0.135.0 (Controller)

- [ ] Migration 204 per `apply_migration` anwenden (Controller, vor dem Browser-Test).
- [ ] `pubspec.yaml` Zeile 4 → `version: 0.135.0+788`, `kAppVersion` in `lib/core/app_version.dart` → `'0.135.0'`.
- [ ] `flutter test`, `flutter analyze`.
- [ ] Browser 360 px (localhost:8080, Build `--base-href "/"`): Heineken → Zuweisungen zeigt «Mahnwesen»; Test-Fall durchspielen, dafür Test-Rechnung vorbereiten und danach sauber zurücksetzen:
  1. Eine echte, unbezahlte Rechnung (Hemingway) per SQL testweise auf `mahnung_2` mit `mahn_frist_bis` weit vor dem Stichtag setzen (Vorher-Werte notieren).
  2. Mahnlauf → «Heineken einschalten» → Fall eröffnen → Mail kommt nur an Daniel («TEST an: …», Kontoauszug + Rechnungen).
  3. Ergebnis «Betreibung auslösen» → Datenblatt, Kostenvorschuss 20.00 bei 470.25, Schritte speichern.
  4. Fall per SQL löschen und Rechnung auf die notierten Vorher-Werte zurücksetzen (DB prüfen).
- [ ] Docs: `docs/chronik.md` (Eintrag v0.135.0), `ToDo.md` (Klicktests v0.135.0; Heineken-Kontakt «Mahnwesen» erfassen), `Projekt.md` (Mahnlauf-Absatz: «Heineken-Schritt und Betreibung seit v0.135.0»).
- [ ] Commit, Push, Deploy nach `CLAUDE.md`, Live-Version prüfen.

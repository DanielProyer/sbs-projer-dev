# Aufgaben-Erinnerungen (Dashboard + Glocke) — Implementierungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pflichten (Heineken-Monatsrechnung, MWST, Mahnlauf, Saisondaten) + eigene Aufgaben erscheinen als Dashboard-Karte und globale Glocke, bis sie erledigt sind.

**Architecture:** Vier client-seitige Detektoren (reine Dart-Funktionen, rechnen bei jedem Laden frisch) + Supabase-Tabelle `aufgaben` nur für eigene Aufgaben, Snoozes und den MWST-Marker. Ein `aufgabenProvider` kombiniert beides; UI = Dashboard-Karte, Glocken-Overlay via `MaterialApp.builder`, gemeinsames Bottom-Sheet.

**Tech Stack:** Flutter Web (Riverpod, GoRouter), Supabase (PostgREST, RLS). Kein Isar, kein Sync-Vertical, kein Cron.

**Spec:** `docs/superpowers/specs/2026-07-22-aufgaben-erinnerungen-design.md` (inkl. Korrektur: Glocke unten links).

**Projekt-Konventionen:** Arbeit direkt auf `main`. Flutter in Git Bash: `export PATH="$PATH:/c/flutter/bin"`, App-Ordner `sbs_projer_app`. Supabase via MCP (project_id `pltbaqqwpnmdajwgnhpd`) — Migrationen wendet der Controller an. UI-Texte Deutsch. Commit ist eigener Schritt (Spec-Reviewer: fehlender Commit ≠ Verletzung).

---

## Datei-Landkarte

| Datei | Verantwortung | Task |
|---|---|---|
| `Datenbank/migrations/150_aufgaben.sql` | Tabelle aufgaben + RLS | AE-1 |
| `sbs_projer_app/lib/core/util/aufgaben_regeln.dart` | Aufgabe-Modell + 4 Detektoren + Sicht-/Sortier-Logik | AE-2 |
| `sbs_projer_app/test/aufgaben_regeln_test.dart` | TDD für alles in aufgaben_regeln | AE-2 |
| `sbs_projer_app/lib/data/repositories/aufgaben_repository.dart` | CRUD auf Tabelle aufgaben | AE-3 |
| `sbs_projer_app/lib/presentation/providers/aufgaben_providers.dart` | aufgabenProvider (kombiniert alles) | AE-3 |
| `sbs_projer_app/lib/presentation/widgets/aufgaben_sheet.dart` | Bottom-Sheet + Neue-Aufgabe-Dialog | AE-4 |
| `sbs_projer_app/lib/presentation/widgets/aufgaben_glocke.dart` | Overlay-Glocke (builder) | AE-4 |
| `sbs_projer_app/lib/app.dart:148-155` | MaterialApp.builder einhängen | AE-4 |
| `sbs_projer_app/lib/presentation/screens/home_screen.dart:46-55` | Dashboard-Karte zuoberst | AE-4 |
| `sbs_projer_app/lib/presentation/screens/buchhaltung/mwst_abrechnung_screen.dart` | «Als abgerechnet markieren» | AE-5 |
| Version/Deploy/ToDo | v0.53.0+592 | AE-6 |

Verifizierte Anker: Routen `/heineken`, `/buchhaltung/mwst`, `/buchhaltung/mahnwesen`, `/touren`; `MaterialApp.router` in `lib/app.dart:148` (globales `router` aus `core/config/router.dart`); Home-ListView-children beginnen mit `_TagesUebersicht` (home_screen.dart:49); Heineken-Rechnung trägt `rechnungstyp='heineken_monat'` und Spalte `heineken_monat` = 1. des Leistungsmonats (ISO-Datum); Mahnschwellen in `ForderungService.istMahnfaellig` (lib/services/rechnung/forderung_service.dart); Saisondaten-Zähler: `saisonAnkerFehltProvider` in `lib/presentation/providers/tour_providers.dart`; MWST-Abgabefristen-Map in `mwst_abrechnung_screen.dart:19`.

---

### Task AE-1: Migration 150 — Tabelle `aufgaben`

**Files:**
- Create: `Datenbank/migrations/150_aufgaben.sql`

- [ ] **Step 1: Migration anwenden** — Controller via MCP `apply_migration`, name `150_aufgaben`:

```sql
-- 150: Aufgaben-Erinnerungen (Spec 2026-07-22)
-- Persistenz NUR fuer eigene Aufgaben, Snoozes und manuelle Erledigt-Marker.
-- Die 4 automatischen Regeln (Heineken/MWST/Mahnlauf/Saisondaten) rechnen
-- client-seitig frisch und erzeugen KEINE Zeilen.
CREATE TABLE public.aufgaben (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id),
  typ text NOT NULL CHECK (typ IN ('eigene','marker','snooze')),
  key text,                    -- Detektor-Schluessel (marker/snooze); NULL bei eigene
  titel text,                  -- nur eigene
  faellig_am date,             -- nur eigene (optional)
  snooze_bis date,             -- nur snooze
  erledigt_am timestamptz,     -- eigene: Abhaken; marker: Zeitpunkt
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX aufgaben_user_typ_key_uniq
  ON public.aufgaben (user_id, typ, key) WHERE key IS NOT NULL;
ALTER TABLE public.aufgaben ENABLE ROW LEVEL SECURITY;
CREATE POLICY aufgaben_select ON public.aufgaben
  FOR SELECT USING (user_id = auth.uid());
CREATE POLICY aufgaben_insert ON public.aufgaben
  FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY aufgaben_update ON public.aufgaben
  FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY aufgaben_delete ON public.aufgaben
  FOR DELETE USING (user_id = auth.uid());
CREATE TRIGGER aufgaben_updated_at BEFORE UPDATE ON public.aufgaben
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
```

- [ ] **Step 2: Datei im Repo ablegen** — gleicher Inhalt nach `Datenbank/migrations/150_aufgaben.sql`.

- [ ] **Step 3: Verifizieren** — `execute_sql`: `SELECT count(*) FROM aufgaben` → 0; RLS-Check via Advisor entfällt (RLS + Policies gesetzt).

- [ ] **Step 4: Commit**

```bash
git add Datenbank/migrations/150_aufgaben.sql && git commit -m "feat(aufgaben): Migration 150 — Tabelle aufgaben (eigene/marker/snooze, RLS)"
```

---

### Task AE-2: Detektoren + Sicht-Logik (TDD)

**Files:**
- Create: `sbs_projer_app/lib/core/util/aufgaben_regeln.dart`
- Test: `sbs_projer_app/test/aufgaben_regeln_test.dart`

- [ ] **Step 1: Fehlschlagende Tests schreiben** — kompletter Testinhalt:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/aufgaben_regeln.dart';

void main() {
  group('heinekenAufgabe', () {
    // heute 05.08.2026 -> Vormonat Juli 2026
    final heute = DateTime(2026, 8, 5);
    test('keine Rechnung -> Stufe erstellen', () {
      final a = heinekenAufgabe(heute: heute, rechnungExistiert: false, rechnungOffen: false);
      expect(a, isNotNull);
      expect(a!.key, 'heineken:2026-07');
      expect(a.titel, contains('erstellen'));
      expect(a.titel, contains('Juli'));
    });
    test('Rechnung offen -> Stufe versenden', () {
      final a = heinekenAufgabe(heute: heute, rechnungExistiert: true, rechnungOffen: true);
      expect(a!.titel, contains('versenden'));
    });
    test('Rechnung gesendet -> erledigt (null)', () {
      expect(heinekenAufgabe(heute: heute, rechnungExistiert: true, rechnungOffen: false), isNull);
    });
    test('Färbung: bis 10. orange, danach rot', () {
      expect(heinekenAufgabe(heute: DateTime(2026, 8, 10), rechnungExistiert: false, rechnungOffen: false)!.dringend, isFalse);
      expect(heinekenAufgabe(heute: DateTime(2026, 8, 11), rechnungExistiert: false, rechnungOffen: false)!.dringend, isTrue);
    });
    test('Jahreswechsel: Januar erinnert an Dezember', () {
      final a = heinekenAufgabe(heute: DateTime(2027, 1, 2), rechnungExistiert: false, rechnungOffen: false);
      expect(a!.key, 'heineken:2026-12');
      expect(a.titel, contains('Dezember'));
    });
  });

  group('mwstAufgabe', () {
    test('Q2 vorbei -> Aufgabe ab 01.07., Frist 31.08.', () {
      final a = mwstAufgabe(heute: DateTime(2026, 7, 22), markerKeys: const {});
      expect(a!.key, 'mwst:2026-Q2');
      expect(a.titel, contains('Q2'));
      expect(a.dringend, isFalse); // 31.08. ist > 14 Tage entfernt
    });
    test('14 Tage vor Frist -> dringend', () {
      expect(mwstAufgabe(heute: DateTime(2026, 8, 18), markerKeys: const {})!.dringend, isTrue);
    });
    test('nach Frist -> weiterhin sichtbar und dringend', () {
      expect(mwstAufgabe(heute: DateTime(2026, 9, 15), markerKeys: const {})!.dringend, isTrue);
    });
    test('Marker unterdrückt', () {
      expect(mwstAufgabe(heute: DateTime(2026, 7, 22), markerKeys: const {'mwst:2026-Q2'}), isNull);
    });
    test('Q4: Frist 28.02. im Folgejahr, key mit altem Jahr', () {
      final a = mwstAufgabe(heute: DateTime(2027, 1, 10), markerKeys: const {});
      expect(a!.key, 'mwst:2026-Q4');
    });
  });

  group('mahnlauf/saisondaten', () {
    test('Zähler > 0 -> Aufgabe mit Anzahl, = 0 -> null', () {
      expect(mahnlaufAufgabe(3)!.titel, contains('3'));
      expect(mahnlaufAufgabe(0), isNull);
      expect(saisondatenAufgabe(15)!.titel, contains('15'));
      expect(saisondatenAufgabe(0), isNull);
    });
  });

  group('Snooze + eigene + Sortierung', () {
    final heute = DateTime(2026, 7, 22);
    test('snoozeAktiv: bis heute inkl., abgelaufen nicht', () {
      expect(snoozeAktiv(DateTime(2026, 7, 22), heute), isTrue);
      expect(snoozeAktiv(DateTime(2026, 7, 21), heute), isFalse);
      expect(snoozeAktiv(null, heute), isFalse);
    });
    test('eigeneSichtbar: ohne Datum sofort, mit Datum ab Fällig-7', () {
      expect(eigeneSichtbar(null, heute), isTrue);
      expect(eigeneSichtbar(DateTime(2026, 7, 29), heute), isTrue);  // genau 7 Tage
      expect(eigeneSichtbar(DateTime(2026, 7, 30), heute), isFalse); // 8 Tage
    });
    test('sortiereAufgaben: dringend zuerst, dann Rest stabil', () {
      final l = [
        const Aufgabe(key: 'a', titel: 'A', dringend: false),
        const Aufgabe(key: 'b', titel: 'B', dringend: true),
        const Aufgabe(key: 'c', titel: 'C', dringend: false),
      ];
      final s = sortiereAufgaben(l);
      expect(s.map((a) => a.key).toList(), ['b', 'a', 'c']);
    });
  });
}
```

- [ ] **Step 2: RED** — `flutter test test/aufgaben_regeln_test.dart` → Compile-Fehler (Datei fehlt).

- [ ] **Step 3: Implementierung** — `lib/core/util/aufgaben_regeln.dart`:

```dart
/// Aufgaben-Erinnerungen: Modell + die 4 automatischen Detektoren +
/// Sicht-/Sortier-Logik. Reine Funktionen, `heute` injizierbar (Spec
/// 2026-07-22). Detektoren erzeugen KEINE Persistenz — sie rechnen frisch.
library;

const _monate = [
  'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli',
  'August', 'September', 'Oktober', 'November', 'Dezember',
];

class Aufgabe {
  final String key;          // deterministisch: 'heineken:2026-07', 'mwst:2026-Q2', 'mahnlauf', 'saisondaten', 'eigene:<uuid>'
  final String titel;
  final bool dringend;       // rot statt orange
  final String? route;       // «Dorthin»-Ziel
  final bool manuellErledigbar; // Haken zeigen (mwst + eigene)
  const Aufgabe({
    required this.key,
    required this.titel,
    this.dringend = false,
    this.route,
    this.manuellErledigbar = false,
  });
}

/// Heineken-Monatsrechnung für den Vormonat. null = erledigt/nicht fällig.
Aufgabe? heinekenAufgabe({
  required DateTime heute,
  required bool rechnungExistiert,
  required bool rechnungOffen,
}) {
  final vormonat = DateTime(heute.year, heute.month - 1, 1);
  if (rechnungExistiert && !rechnungOffen) return null;
  final name = '${_monate[vormonat.month - 1]} ${vormonat.year}';
  final key =
      'heineken:${vormonat.year}-${vormonat.month.toString().padLeft(2, '0')}';
  return Aufgabe(
    key: key,
    titel: rechnungExistiert
        ? 'Heineken-Monatsrechnung $name versenden'
        : 'Heineken-Monatsrechnung $name erstellen',
    dringend: heute.day > 10,
    route: '/heineken',
  );
}

/// MWST fürs zuletzt abgelaufene Quartal. Erledigung NUR per Marker.
Aufgabe? mwstAufgabe({
  required DateTime heute,
  required Set<String> markerKeys,
}) {
  // Zuletzt abgelaufenes Quartal.
  var jahr = heute.year;
  var quartal = ((heute.month - 1) ~/ 3); // 0 = Q4 Vorjahr
  if (quartal == 0) {
    jahr -= 1;
    quartal = 4;
  }
  final key = 'mwst:$jahr-Q$quartal';
  if (markerKeys.contains(key)) return null;
  // Abgabefristen wie mwst_abrechnung_screen: Q1 31.05., Q2 31.08.,
  // Q3 30.11., Q4 28.02. Folgejahr.
  final frist = switch (quartal) {
    1 => DateTime(jahr, 5, 31),
    2 => DateTime(jahr, 8, 31),
    3 => DateTime(jahr, 11, 30),
    _ => DateTime(jahr + 1, 2, 28),
  };
  final tageBisFrist = frist.difference(DateTime(heute.year, heute.month, heute.day)).inDays;
  return Aufgabe(
    key: key,
    titel: 'MWST Q$quartal $jahr abrechnen (Frist '
        '${frist.day.toString().padLeft(2, '0')}.${frist.month.toString().padLeft(2, '0')}.${frist.year})',
    dringend: tageBisFrist <= 14,
    route: '/buchhaltung/mwst',
    manuellErledigbar: true,
  );
}

Aufgabe? mahnlaufAufgabe(int anzahl) => anzahl <= 0
    ? null
    : Aufgabe(
        key: 'mahnlauf',
        titel: 'Mahnlauf: $anzahl Rechnungen fällig',
        route: '/buchhaltung/mahnwesen',
      );

Aufgabe? saisondatenAufgabe(int anzahl) => anzahl <= 0
    ? null
    : Aufgabe(
        key: 'saisondaten',
        titel: 'Saisondaten fehlen bei $anzahl Betrieben',
        route: '/touren',
      );

/// Snooze gilt bis EINSCHLIESSLICH snooze_bis.
bool snoozeAktiv(DateTime? snoozeBis, DateTime heute) {
  if (snoozeBis == null) return false;
  final h = DateTime(heute.year, heute.month, heute.day);
  return !DateTime(snoozeBis.year, snoozeBis.month, snoozeBis.day).isBefore(h);
}

/// Eigene Aufgabe sichtbar: ohne Datum sofort, sonst ab Fälligkeit − 7 Tage.
bool eigeneSichtbar(DateTime? faelligAm, DateTime heute) {
  if (faelligAm == null) return true;
  final h = DateTime(heute.year, heute.month, heute.day);
  return faelligAm.difference(h).inDays <= 7;
}

/// Dringende zuerst, sonst stabile Reihenfolge.
List<Aufgabe> sortiereAufgaben(List<Aufgabe> aufgaben) {
  final dringend = aufgaben.where((a) => a.dringend).toList();
  final rest = aufgaben.where((a) => !a.dringend).toList();
  return [...dringend, ...rest];
}
```

- [ ] **Step 4: GREEN** — `flutter test test/aufgaben_regeln_test.dart` → alle grün.

- [ ] **Step 5: Commit**

```bash
git add lib/core/util/aufgaben_regeln.dart test/aufgaben_regeln_test.dart && git commit -m "feat(aufgaben): Detektoren + Sicht-Logik (TDD, AE-2)"
```

---

### Task AE-3: Repository + aufgabenProvider

**Files:**
- Create: `sbs_projer_app/lib/data/repositories/aufgaben_repository.dart`
- Create: `sbs_projer_app/lib/presentation/providers/aufgaben_providers.dart`

- [ ] **Step 1: Repository** — `aufgaben_repository.dart`:

```dart
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// CRUD für die Tabelle aufgaben (Supabase only, kein Isar — Spec 22.07.).
class AufgabenRepository {
  static String get _uid => SupabaseService.currentUser!.id;

  static Future<List<Map<String, dynamic>>> alleZeilen() async =>
      List<Map<String, dynamic>>.from(
          await SupabaseService.client.from('aufgaben').select().eq('user_id', _uid));

  static Future<void> markerSetzen(String key) async =>
      SupabaseService.client.from('aufgaben').upsert({
        'user_id': _uid,
        'typ': 'marker',
        'key': key,
        'erledigt_am': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,typ,key');

  static Future<void> markerLoeschen(String key) async =>
      SupabaseService.client.from('aufgaben').delete()
          .eq('user_id', _uid).eq('typ', 'marker').eq('key', key);

  static Future<void> snooze(String key, int tage) async {
    final bis = DateTime.now().add(Duration(days: tage));
    await SupabaseService.client.from('aufgaben').upsert({
      'user_id': _uid,
      'typ': 'snooze',
      'key': key,
      'snooze_bis': bis.toIso8601String().split('T').first,
    }, onConflict: 'user_id,typ,key');
  }

  static Future<void> eigeneAnlegen(String titel, DateTime? faelligAm) async =>
      SupabaseService.client.from('aufgaben').insert({
        'user_id': _uid,
        'typ': 'eigene',
        'titel': titel,
        'faellig_am': faelligAm?.toIso8601String().split('T').first,
      });

  static Future<void> eigeneErledigen(String id) async =>
      SupabaseService.client.from('aufgaben')
          .update({'erledigt_am': DateTime.now().toUtc().toIso8601String()})
          .eq('id', id);
}
```

Hinweis: `onConflict` mit dem partiellen Unique-Index funktioniert bei PostgREST über die Spaltenliste `user_id,typ,key` (Index deckt sie ab). Falls der Upsert wegen des partiellen Index einen Fehler wirft (PostgREST kann partielle Indizes nicht immer als Konfliktziel nutzen!): Fallback im Code — erst `delete().eq(...)` auf (typ,key), dann `insert`. Der Implementer testet den Upsert-Weg zuerst live per `execute_sql`-Gegenprobe im Verifikationsschritt AE-6 und baut bei Fehlern den Fallback ein (delete+insert ist bei einem Einzel-User völlig ausreichend).

- [ ] **Step 2: Provider** — `aufgaben_providers.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/util/aufgaben_regeln.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/aufgaben_repository.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';
import 'package:sbs_projer_app/services/rechnung/forderung_service.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Offene eigene Aufgabe (mit DB-id für Erledigen).
class EigeneAufgabe {
  final String id;
  final Aufgabe aufgabe;
  const EigeneAufgabe(this.id, this.aufgabe);
}

class AufgabenStand {
  final List<Aufgabe> offene;          // Detektoren, nach Snooze/Marker
  final List<EigeneAufgabe> eigene;    // offene eigene, sichtbar
  int get badge => offene.length + eigene.length;
  const AufgabenStand(this.offene, this.eigene);
  static const leer = AufgabenStand([], []);
}

final aufgabenProvider = FutureProvider<AufgabenStand>((ref) async {
  if (SupabaseService.currentUser == null) return AufgabenStand.leer;
  final heute = DateTime.now();
  final client = SupabaseService.client;

  // Tabelle: Marker, Snoozes, eigene.
  List<Map<String, dynamic>> zeilen = const [];
  try {
    zeilen = await AufgabenRepository.alleZeilen();
  } catch (e) {
    debugPrint('[Aufgaben] Tabelle nicht ladbar: $e');
    return AufgabenStand.leer;
  }
  final marker = zeilen
      .where((z) => z['typ'] == 'marker' && z['key'] != null)
      .map((z) => z['key'] as String)
      .toSet();
  final snoozes = <String, DateTime>{};
  for (final z in zeilen.where((z) => z['typ'] == 'snooze')) {
    final bis = DateTime.tryParse(z['snooze_bis'] ?? '');
    if (z['key'] != null && bis != null) snoozes[z['key'] as String] = bis;
  }

  final detektoren = <Aufgabe?>[];

  // a) Heineken — Rechnung des Vormonats gezielt abfragen.
  try {
    final vormonat = DateTime(heute.year, heute.month - 1, 1);
    final rows = await client
        .from('rechnungen')
        .select('zahlungsstatus')
        .eq('rechnungstyp', 'heineken_monat')
        .eq('heineken_monat', vormonat.toIso8601String().split('T').first)
        .limit(1);
    detektoren.add(heinekenAufgabe(
      heute: heute,
      rechnungExistiert: rows.isNotEmpty,
      rechnungOffen: rows.isNotEmpty && rows.first['zahlungsstatus'] == 'offen',
    ));
  } catch (e) {
    debugPrint('[Aufgaben] Heineken-Detektor: $e');
  }

  // b) MWST — nur Marker nötig.
  try {
    detektoren.add(mwstAufgabe(heute: heute, markerKeys: marker));
  } catch (e) {
    debugPrint('[Aufgaben] MWST-Detektor: $e');
  }

  // c) Mahnlauf — offene Kundenrechnungen über den bestehenden Schwellen.
  try {
    final rows = await client
        .from('rechnungen')
        .select()
        .inFilter('zahlungsstatus', ['offen', 'erinnert', 'mahnung_1', 'mahnung_2'])
        .neq('rechnungstyp', 'heineken_monat');
    final anzahl = rows
        .map((r) => Rechnung.fromJson(r))
        .where((r) => ForderungService.istMahnfaellig(r, heute: heute))
        .length;
    detektoren.add(mahnlaufAufgabe(anzahl));
  } catch (e) {
    debugPrint('[Aufgaben] Mahnlauf-Detektor: $e');
  }

  // d) Saisondaten — bestehender Tourenplan-Provider.
  try {
    detektoren.add(saisondatenAufgabe(ref.watch(saisonAnkerFehltProvider).length));
  } catch (e) {
    debugPrint('[Aufgaben] Saisondaten-Detektor: $e');
  }

  final offene = sortiereAufgaben(detektoren
      .whereType<Aufgabe>()
      .where((a) => !snoozeAktiv(snoozes[a.key], heute))
      .toList());

  final eigene = <EigeneAufgabe>[];
  for (final z in zeilen.where((z) => z['typ'] == 'eigene')) {
    if (z['erledigt_am'] != null) continue;
    final faellig = DateTime.tryParse(z['faellig_am'] ?? '');
    if (!eigeneSichtbar(faellig, heute)) continue;
    final key = 'eigene:${z['id']}';
    if (snoozeAktiv(snoozes[key], heute)) continue;
    final istDringend = faellig != null &&
        !faellig.isAfter(DateTime(heute.year, heute.month, heute.day));
    eigene.add(EigeneAufgabe(
      z['id'] as String,
      Aufgabe(
        key: key,
        titel: (z['titel'] ?? '?') as String,
        dringend: istDringend,
        manuellErledigbar: true,
      ),
    ));
  }
  eigene.sort((a, b) => (b.aufgabe.dringend ? 1 : 0) - (a.aufgabe.dringend ? 1 : 0));

  return AufgabenStand(offene, eigene);
});
```

Achtung Mahnlauf-Query: `rechnungen` hat mehr als 1000 Zeilen insgesamt, aber der `inFilter` auf offene Status begrenzt real auf wenige hundert (aktuell ~1600 offene laut Forderungen — DOCH über 1000!). Deshalb MUSS die Query paginiert werden: `.range(0, 1999)` reicht NICHT dauerhaft — Implementer: nutze `.limit(2000)` und logge, wenn 2000 erreicht werden (`debugPrint('[Aufgaben] Mahnlauf-Query am Limit')`). Alternativ Spalten reduzieren: `select('id, zahlungsstatus, rechnungstyp, faelligkeitsdatum, erinnerung_am, mahnung_1_am')` — prüfe die exakten Feldnamen in `lib/data/models/rechnung.dart` (fromJson) und übergib nur, was `ForderungService` liest; bei reduziertem select müssen die von `Rechnung.fromJson` verlangten Pflichtfelder dabei sein (prüfen!).

- [ ] **Step 3: Analyse + Tests + Commit**

```bash
flutter analyze && flutter test
git add -A && git commit -m "feat(aufgaben): Repository + aufgabenProvider (Detektoren kombiniert, AE-3)"
```

---

### Task AE-4: UI — Sheet, Dashboard-Karte, globale Glocke

**Files:**
- Create: `sbs_projer_app/lib/presentation/widgets/aufgaben_sheet.dart`
- Create: `sbs_projer_app/lib/presentation/widgets/aufgaben_glocke.dart`
- Modify: `sbs_projer_app/lib/app.dart:148-155` (builder)
- Modify: `sbs_projer_app/lib/presentation/screens/home_screen.dart:46-55` (Karte zuoberst)

- [ ] **Step 1: Sheet** — `aufgaben_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/config/router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/aufgaben_regeln.dart';
import 'package:sbs_projer_app/data/repositories/aufgaben_repository.dart';
import 'package:sbs_projer_app/presentation/providers/aufgaben_providers.dart';

/// Öffnet das Aufgaben-Sheet (von Dashboard-Karte und Glocke genutzt).
void zeigeAufgabenSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _AufgabenSheet(),
  );
}

class _AufgabenSheet extends ConsumerWidget {
  const _AufgabenSheet();

  Future<void> _aktion(WidgetRef ref, Future<void> Function() f,
      BuildContext context) async {
    try {
      await f();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    } finally {
      ref.invalidate(aufgabenProvider);
    }
  }

  Widget _zeile(BuildContext context, WidgetRef ref, Aufgabe a, {String? eigeneId}) {
    final farbe = a.dringend ? AppColors.error : AppColors.warning;
    return ListTile(
      dense: true,
      leading: Icon(Icons.circle, size: 12, color: farbe),
      title: Text(a.titel, style: const TextStyle(fontSize: 14)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (a.route != null)
            IconButton(
              icon: const Icon(Icons.arrow_forward, size: 18),
              tooltip: 'Dorthin',
              onPressed: () {
                Navigator.pop(context);
                router.push(a.route!);
              },
            ),
          PopupMenuButton<int>(
            icon: const Icon(Icons.snooze, size: 18),
            tooltip: 'Später erinnern',
            onSelected: (tage) => _aktion(
                ref, () => AufgabenRepository.snooze(a.key, tage), context),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 1, child: Text('1 Tag')),
              PopupMenuItem(value: 3, child: Text('3 Tage')),
              PopupMenuItem(value: 7, child: Text('7 Tage')),
            ],
          ),
          if (a.manuellErledigbar)
            IconButton(
              icon: const Icon(Icons.check_circle_outline, size: 20),
              tooltip: 'Erledigt',
              onPressed: () => _aktion(ref, () async {
                if (eigeneId != null) {
                  await AufgabenRepository.eigeneErledigen(eigeneId);
                } else {
                  await AufgabenRepository.markerSetzen(a.key);
                }
              }, context),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stand = ref.watch(aufgabenProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: stand.when(
          loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Padding(
              padding: const EdgeInsets.all(24), child: Text('Fehler: $e')),
          data: (s) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Text('Aufgaben',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Neue Aufgabe'),
                    onPressed: () => _neueAufgabeDialog(context, ref),
                  ),
                ],
              ),
              if (s.badge == 0)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Alles erledigt 🎉'),
                ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ...s.offene.map((a) => _zeile(context, ref, a)),
                    ...s.eigene.map(
                        (e) => _zeile(context, ref, e.aufgabe, eigeneId: e.id)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _neueAufgabeDialog(BuildContext context, WidgetRef ref) async {
    final titelCtrl = TextEditingController();
    DateTime? faellig;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Neue Aufgabe'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titelCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Titel *'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(faellig == null
                        ? 'Ohne Fälligkeitsdatum'
                        : 'Fällig: ${faellig!.day.toString().padLeft(2, '0')}.${faellig!.month.toString().padLeft(2, '0')}.${faellig!.year}'),
                  ),
                  TextButton(
                    child: const Text('Datum'),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 730)),
                        initialDate: DateTime.now(),
                      );
                      if (d != null) setDialogState(() => faellig = d);
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Abbrechen')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Speichern')),
          ],
        ),
      ),
    );
    if (ok == true && titelCtrl.text.trim().isNotEmpty) {
      await _aktion(
          ref,
          () => AufgabenRepository.eigeneAnlegen(titelCtrl.text.trim(), faellig),
          context);
    }
  }
}
```

Hinweis Implementer: `router` ist das globale GoRouter-Objekt aus `core/config/router.dart` (verifizieren: `grep -n "final router" lib/core/config/router.dart`); `AppColors.error/warning` existieren (app_theme).

- [ ] **Step 2: Glocke** — `aufgaben_glocke.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/presentation/providers/aufgaben_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/aufgaben_sheet.dart';

/// Globales Glocken-Overlay (MaterialApp.builder). Unten links —
/// einhändig erreichbar, kollidiert nicht mit FABs (unten rechts) oder
/// AppBar-Actions (oben). Unsichtbar bei 0 Aufgaben oder ohne Login.
class AufgabenGlocke extends ConsumerWidget {
  final Widget child;
  const AufgabenGlocke({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badge = ref.watch(aufgabenProvider).valueOrNull?.badge ?? 0;
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        child,
        if (badge > 0)
          Positioned(
            left: 12,
            bottom: 24,
            child: Directionality(
              textDirection: TextDirection.ltr,
              // CanvasKit-Muster: GestureDetector + Container.
              child: GestureDetector(
                onTap: () {
                  final ctx = rootNavigatorKey.currentContext;
                  if (ctx != null) zeigeAufgabenSheet(ctx);
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(blurRadius: 6, color: Colors.black26),
                    ],
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.notifications,
                          color: Colors.white, size: 22),
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('$badge',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
```

WICHTIG Implementer: `rootNavigatorKey` — prüfen, ob `core/config/router.dart` einen `navigatorKey` definiert (`grep -n "navigatorKey\|GlobalKey<NavigatorState>" lib/core/config/router.dart lib/app.dart`). Falls ja: importieren und verwenden. Falls NEIN: in router.dart `final rootNavigatorKey = GlobalKey<NavigatorState>();` anlegen und `GoRouter(navigatorKey: rootNavigatorKey, …)` ergänzen (eine Zeile), dann hier nutzen. Das Sheet braucht einen Kontext UNTER dem Navigator — der builder-Kontext selbst liegt darüber.

- [ ] **Step 3: builder einhängen** — `lib/app.dart:148-155`:

```dart
    return MaterialApp.router(
      title: 'SBS Projer',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      theme: AppTheme.light,
      routerConfig: router,
      builder: (context, child) =>
          AufgabenGlocke(child: child ?? const SizedBox.shrink()),
    );
```

(Import ergänzen. Falls `app.dart` kein ConsumerWidget ist: egal — AufgabenGlocke ist selbst ConsumerWidget, ProviderScope liegt in main.dart darüber; verifizieren mit `grep -n "ProviderScope" lib/main.dart`.)

- [ ] **Step 4: Dashboard-Karte** — in `home_screen.dart` als erstes ListView-Kind vor `_TagesUebersicht()`:

```dart
          const _AufgabenKarte(),
```

und am Dateiende:

```dart
class _AufgabenKarte extends ConsumerWidget {
  const _AufgabenKarte();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stand = ref.watch(aufgabenProvider).valueOrNull;
    if (stand == null || stand.badge == 0) return const SizedBox.shrink();
    final titel = [
      ...stand.offene.map((a) => a.titel),
      ...stand.eigene.map((e) => e.aufgabe.titel),
    ].take(3).toList();
    final dringend = stand.offene.any((a) => a.dringend) ||
        stand.eigene.any((e) => e.aufgabe.dringend);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: dringend
          ? AppColors.error.withValues(alpha: 0.08)
          : AppColors.warning.withValues(alpha: 0.08),
      child: InkWell(
        onTap: () => zeigeAufgabenSheet(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.notifications_active,
                      size: 18,
                      color: dringend ? AppColors.error : AppColors.warning),
                  const SizedBox(width: 8),
                  Text('${stand.badge} Aufgaben offen',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
              const SizedBox(height: 4),
              ...titel.map((t) => Padding(
                    padding: const EdgeInsets.only(left: 26, top: 2),
                    child: Text('· $t',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
```

(Imports ergänzen: aufgaben_providers, aufgaben_sheet. `withValues(alpha:)` ist das aktuelle Flutter-API — falls die Projektversion `withOpacity` nutzt (grep im Projekt), das Projekt-Muster übernehmen. Singular/Plural: bei badge == 1 «1 Aufgabe offen» — `final label = stand.badge == 1 ? '1 Aufgabe offen' : '${stand.badge} Aufgaben offen';`.)

- [ ] **Step 5: Analyse + Tests + Commit**

```bash
flutter analyze && flutter test
git add -A && git commit -m "feat(aufgaben): Sheet, Dashboard-Karte, globale Glocke (AE-4)"
```

---

### Task AE-5: MWST-Screen — «Als abgerechnet markieren»

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/buchhaltung/mwst_abrechnung_screen.dart`

- [ ] **Step 1: Button + Zustand** — im Screen (er kennt `_jahr` und `_quartal`) unter der Fristanzeige (~Zeile 58) einen Abschnitt ergänzen. Der Screen ist ein ConsumerStatefulWidget (verifizieren); Code:

```dart
              // Aufgaben-Marker: MWST-Erinnerung für dieses Quartal erledigen.
              Consumer(builder: (context, ref, _) {
                final key = 'mwst:$_jahr-Q$_quartal';
                final stand = ref.watch(aufgabenProvider).valueOrNull;
                final offen =
                    stand?.offene.any((a) => a.key == key) ?? false;
                return Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: Icon(
                        offen ? Icons.check_circle_outline : Icons.undo,
                        size: 18),
                    label: Text(offen
                        ? 'Als abgerechnet markieren'
                        : 'Markierung zurücknehmen'),
                    onPressed: () async {
                      try {
                        if (offen) {
                          await AufgabenRepository.markerSetzen(key);
                        } else {
                          await AufgabenRepository.markerLoeschen(key);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Fehler: $e')));
                        }
                      }
                      ref.invalidate(aufgabenProvider);
                    },
                  ),
                );
              }),
```

Hinweis: «Markierung zurücknehmen» nur sinnvoll anzeigen, wenn das gewählte Quartal ÜBERHAUPT das aktuelle Erinnerungs-Quartal ist ODER ein Marker existiert — einfachste korrekte Variante: Button immer zeigen; `offen == false` heisst entweder markiert oder (anderes Quartal) nie erinnert; beim Zurücknehmen eines nie gesetzten Markers ist `markerLoeschen` ein No-op. Das ist akzeptabel (Einzel-User). Imports ergänzen.

- [ ] **Step 2: Analyse + Tests + Commit**

```bash
flutter analyze && flutter test
git add -A && git commit -m "feat(mwst): Als-abgerechnet-Marker im MWST-Screen (AE-5)"
```

---

### Task AE-6: Verifikation, Deploy v0.53.0, Abnahme

**Files:**
- Modify: `sbs_projer_app/pubspec.yaml:4`, `sbs_projer_app/lib/core/app_version.dart`, `ToDo.md`

- [ ] **Step 1: Volle Suite + Analyse** — `flutter analyze` (Baseline 47) + `flutter test` (alle grün).

- [ ] **Step 2: Upsert-Gegenprobe (Controller)** — per MCP `execute_sql` als Service-Role einen Snooze-Upsert simulieren geht nicht 1:1 (auth.uid fehlt) — stattdessen prüft Daniel im Live-Test; der Implementer verifiziert nur, dass `AufgabenRepository.snooze` beim ersten Klick keine Exception wirft (SnackBar bliebe aus). Falls PostgREST den partiellen Index als onConflict ablehnt (Fehlermeldung «no unique or exclusion constraint»): Fallback delete+insert einbauen (AE-3-Hinweis) und erneut testen.

- [ ] **Step 3: Version** — `version: 0.53.0+592`, `kAppVersion = '0.53.0'`.

- [ ] **Step 4: Build + Cache-Bust + Deploy** (Controller, Standard-Ablauf):

```bash
export MSYS_NO_PATHCONV=1 && flutter build web --base-href "/sbs-projer-dev/" --pwa-strategy=none
cd .. && VER=$(grep -o '"version":"[^"]*"' sbs_projer_app/build/web/version.json | cut -d'"' -f4) \
  && sed -i "s/\"mainJsPath\":\"main.dart.js\"/\"mainJsPath\":\"main.dart.js?v=$VER\"/g" sbs_projer_app/build/web/flutter_bootstrap.js \
  && rm -f sbs_projer_app/build/web/flutter_service_worker.js
git add -A && git commit -m "chore: v0.53.0 — Aufgaben-Erinnerungen (Dashboard + Glocke)" && git push origin main
git checkout gh-pages && CUR=$(git branch --show-current) && if [ "$CUR" != "gh-pages" ]; then echo "ABBRUCH: $CUR"; exit 1; fi \
  && rm -rf assets canvaskit icons main.dart.js* flutter*.js index.html manifest.json favicon.png version.json docs \
  && cp -r sbs_projer_app/build/web/* . && touch .nojekyll \
  && git add index.html main.dart.js* flutter*.js manifest.json favicon.png version.json .nojekyll assets/ canvaskit/ icons/ \
  && git commit -m "deploy v0.53.0 — Aufgaben-Erinnerungen" && git push origin gh-pages && git checkout main
```

- [ ] **Step 5: Live-Check** — `version.json` bis `0.53.0` (Hintergrund-until-Loop).

- [ ] **Step 6: ToDo.md** — Abnahme-Checkliste für Daniel eintragen, committen, pushen:
  1. App laden (v0.53.0): Dashboard-Karte «X Aufgaben offen» sichtbar — erwartet aktuell: MWST Q2 2026 (Frist 31.08.), Mahnlauf (Anzahl > 0?), Saisondaten 15; Glocke unten links auf JEDER Seite mit Badge.
  2. Sheet öffnen: Dorthin-Links (MWST-Screen, Mahnwesen, Tourenplan) funktionieren.
  3. Snooze 1 Tag auf eine Aufgabe → verschwindet, Badge sinkt.
  4. Eigene Aufgabe anlegen (mit Datum in 3 Tagen) → erscheint; abhaken → weg.
  5. MWST-Screen: «Als abgerechnet markieren» → Aufgabe verschwindet; «Markierung zurücknehmen» → kommt wieder.
  6. Heineken-Test folgt natürlich am 01.08. (Juli-Rechnung).

---

## Self-Review (erledigt)

- **Spec-Abdeckung:** 4 Detektoren (AE-2/AE-3), Tabelle+RLS (AE-1), eigene Aufgaben + Snooze 1/3/7 (AE-3/AE-4), Dashboard-Karte + globale Glocke unten links (AE-4), MWST-Marker im Screen (AE-5), Fehlerbehandlung try/catch pro Regel + SnackBar (AE-3/AE-4), Tests (AE-2), Deploy/Abnahme (AE-6). Keine Lücken.
- **Platzhalter:** keine — wo Verifikation nötig ist (navigatorKey, withValues, Rechnung.fromJson-Pflichtfelder, onConflict-Partial-Index), steht der exakte Prüfbefehl und der Fallback.
- **Typ-Konsistenz:** `Aufgabe(key, titel, dringend, route, manuellErledigbar)` aus AE-2 wird in AE-3/AE-4/AE-5 exakt so verwendet; `AufgabenStand.offene/eigene/badge` konsistent; Repository-Methoden (markerSetzen/markerLoeschen/snooze/eigeneAnlegen/eigeneErledigen) stimmen zwischen AE-3 und AE-4/AE-5 überein.

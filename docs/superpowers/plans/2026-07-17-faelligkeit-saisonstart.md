# Fälligkeit ab Saisonstart — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Die Fälligkeits-Uhr eines Betriebs startet bei der Wiedereröffnung (Saisonstart/Ferien-Ende+1), wenn er nach der letzten Reinigung geschlossen war — die 17 unsichtbaren Saison-Kunden (Tgantieni-Fall) erscheinen mit korrekter Stufe im Standard-Filter.

**Architecture:** Neue reine Funktion `faelligkeitsAnker` in `touren_saison.dart` (TDD); `getFaelligkeit` nutzt sie statt des hart codierten „Endreinigung+28"-Blocks; das ewige `eroeffnungFaellig` (tage<0) entfällt; Warnleiste „Saisondaten fehlen" im Tourenplan (Muster der Rechnungs-Warnung); Filter-Default um Eröffnung/Endreinigung erweitert. Reine Client-Logik, keine DB-Änderung.

**Tech Stack:** Flutter Web, Riverpod. Bash: `export PATH="$PATH:/c/flutter/bin"`, App-Verzeichnis `sbs_projer_app`, Arbeit direkt auf `main`.

**Spec:** `docs/superpowers/specs/2026-07-17-faelligkeit-saisonstart-design.md`

---

### Task 1: `faelligkeitsAnker` (TDD)

**Files:**
- Modify: `sbs_projer_app/lib/core/util/touren_saison.dart`
- Test: `sbs_projer_app/test/faelligkeit_anker_test.dart` (neu)

- [ ] **Step 1: Failing Tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/touren_saison.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';

BetriebLocal _saisonBetrieb() => BetriebLocal()
  ..name = 'Test'
  ..status = 'aktiv'
  ..istSaisonbetrieb = true
  ..winterSaisonAktiv = true
  ..winterStartDatum = DateTime(2025, 12, 5)
  ..winterEndeDatum = DateTime(2026, 3, 29)
  ..sommerSaisonAktiv = true
  ..sommerStartDatum = DateTime(2026, 6, 6)
  ..sommerEndeDatum = DateTime(2026, 10, 21)
  ..ruhetage = ['Montag'];

BetriebLocal _ganzjahresBetrieb() => BetriebLocal()
  ..name = 'Test'
  ..status = 'aktiv'
  ..istSaisonbetrieb = false
  ..ferienStart = DateTime(2026, 5, 1)
  ..ferienEnde = DateTime(2026, 5, 28)
  ..ruhetage = [];

void main() {
  group('faelligkeitsAnker', () {
    test('Endreinigung am Tag nach Saisonschluss -> Anker = Saisonstart', () {
      // Tgantieni: Winterende 29.03., Endreinigung 30.03., Sommerstart 06.06.
      final anker =
          faelligkeitsAnker(_saisonBetrieb(), DateTime(2026, 3, 30));
      expect(anker, DateTime(2026, 6, 6));
    });
    test('Eröffnungsreinigung VOR Saisonstart -> Anker = Saisonstart', () {
      final anker =
          faelligkeitsAnker(_saisonBetrieb(), DateTime(2026, 6, 3));
      expect(anker, DateTime(2026, 6, 6));
    });
    test('Reinigung mitten in der Saison -> Anker = Reinigungsdatum', () {
      final anker =
          faelligkeitsAnker(_saisonBetrieb(), DateTime(2026, 7, 10));
      expect(anker, DateTime(2026, 7, 10));
    });
    test('Ruhetag nach der Reinigung verschiebt den Anker NICHT', () {
      // 12.07.2026 ist ein Sonntag -> 13.07. Montag = Ruhetag, aber in Saison.
      final anker =
          faelligkeitsAnker(_saisonBetrieb(), DateTime(2026, 7, 12));
      expect(anker, DateTime(2026, 7, 12));
    });
    test('Endreinigung, aber kein künftiger Saisonstart gepflegt -> null', () {
      final b = _saisonBetrieb()
        ..sommerSaisonAktiv = false
        ..sommerStartDatum = null
        ..sommerEndeDatum = null;
      // Endreinigung nach Winterende, nächster Winterstart (05.12.2025) liegt
      // davor -> keine Wiedereröffnung bestimmbar.
      expect(faelligkeitsAnker(b, DateTime(2026, 3, 30)), isNull);
    });
    test('Betriebsferien: Reinigung vor den Ferien -> Anker = Ferienende + 1', () {
      final anker =
          faelligkeitsAnker(_ganzjahresBetrieb(), DateTime(2026, 4, 30));
      expect(anker, DateTime(2026, 5, 29));
    });
    test('Ganzjahresbetrieb ohne Schliessung -> Anker = Reinigungsdatum', () {
      final b = _ganzjahresBetrieb()
        ..ferienStart = null
        ..ferienEnde = null;
      expect(faelligkeitsAnker(b, DateTime(2026, 4, 30)),
          DateTime(2026, 4, 30));
    });
  });
}
```

Hinweis Implementer: Feldnamen (`ferienStart`/`ferienEnde`, `ruhetage`) VOR dem Schreiben gegen `betrieb_local.dart`/`betrieb_ferien.dart` prüfen (`grep -n "ferienStart\|ruhetage" lib/data/local/betrieb_local.dart | head`) und Test-Setups anpassen, falls die Namen abweichen. `BetriebLocal()` ist in Tests instanziierbar (Muster: `test/anlage_pdf_util_test.dart`).

- [ ] **Step 2: Failen sehen** — `flutter test test/faelligkeit_anker_test.dart` → Compile-Fehler (Funktion fehlt).

- [ ] **Step 3: Implementation** — in `touren_saison.dart` ergänzen (nach `oeffnungNach`):

```dart
/// Anker für die Fälligkeits-Uhr (Regel Daniel 17.07.2026): War der Betrieb am
/// Tag nach der letzten Reinigung GESCHLOSSEN (Saisonpause oder Ferien —
/// Ruhetage zählen bewusst NICHT), startet die Zählung erst bei der
/// Wiedereröffnung. Deckt die Endreinigung am Saisonschluss UND die
/// Eröffnungsreinigung kurz vor Saisonstart ab. null = geschlossen, aber keine
/// Wiedereröffnung gepflegt -> Aufrufer zeigt die "Saisondaten fehlen"-Meldung.
DateTime? faelligkeitsAnker(BetriebLocal b, DateTime letzteReinigung) {
  final tagDanach = DateTime(letzteReinigung.year, letzteReinigung.month,
          letzteReinigung.day)
      .add(const Duration(days: 1));
  final geschlossen = !_inAktiverSaison(b, tagDanach) || istInFerien(b, tagDanach);
  if (!geschlossen) return letzteReinigung;
  return oeffnungNach(b, letzteReinigung);
}
```

- [ ] **Step 4: Tests grün**, dann `dart format` auf beide Dateien, `flutter analyze` auf beide (0 errors).

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/core/util/touren_saison.dart sbs_projer_app/test/faelligkeit_anker_test.dart
git commit -m "feat(touren): faelligkeitsAnker — Uhr startet bei Wiedereröffnung (TDD)"
```

---

### Task 2: `getFaelligkeit` auf den Anker umstellen + ewiges eroeffnungFaellig streichen (TDD)

**Files:**
- Modify: `sbs_projer_app/lib/presentation/providers/tour_providers.dart:127-196`
- Test: `sbs_projer_app/test/faelligkeit_anker_test.dart` (erweitern)

- [ ] **Step 1: Failing Szenario-Tests anhängen** (Import ergänzen: `package:sbs_projer_app/presentation/providers/tour_providers.dart` und `package:sbs_projer_app/data/local/anlage_local_export.dart`):

```dart
  group('getFaelligkeit mit Anker (Tgantieni-Szenario)', () {
    AnlageLocal anlage() => AnlageLocal()
      ..status = 'aktiv'
      ..typAnlage = 'Bier'
      ..reinigungRhythmus = '4-Wochen'
      ..letzteReinigung = DateTime(2026, 3, 30)
      ..naechsteReinigung = DateTime(2026, 4, 27); // alter, überholter Soll

    test('vor Saisonstart: nicht fällig (Pause)', () {
      expect(
          getFaelligkeit(anlage(), DateTime(2026, 5, 15),
              betrieb: _saisonBetrieb(), letzteServiceArt: 'endreinigung'),
          FaelligkeitsStatus.nichtFaellig);
    });
    test('7 Tage vor Start: Eröffnungs-Hinweis', () {
      expect(
          getFaelligkeit(anlage(), DateTime(2026, 6, 1),
              betrieb: _saisonBetrieb(), letzteServiceArt: 'endreinigung'),
          FaelligkeitsStatus.eroeffnungFaellig);
    });
    test('nach Start, vor Soll (03.07.): nicht fällig — KEIN ewiges eroeffnungFaellig', () {
      expect(
          getFaelligkeit(anlage(), DateTime(2026, 7, 3),
              betrieb: _saisonBetrieb(), letzteServiceArt: 'endreinigung'),
          FaelligkeitsStatus.nichtFaellig);
    });
    test('Soll erreicht (05.07.): bald fällig', () {
      expect(
          getFaelligkeit(anlage(), DateTime(2026, 7, 5),
              betrieb: _saisonBetrieb(), letzteServiceArt: 'endreinigung'),
          FaelligkeitsStatus.baldFaellig);
    });
    test('Soll +1 Woche (12.07.): fällig', () {
      expect(
          getFaelligkeit(anlage(), DateTime(2026, 7, 12),
              betrieb: _saisonBetrieb(), letzteServiceArt: 'endreinigung'),
          FaelligkeitsStatus.faellig);
    });
    test('Soll +2 Wochen (19.07.): überfällig', () {
      expect(
          getFaelligkeit(anlage(), DateTime(2026, 7, 19),
              betrieb: _saisonBetrieb(), letzteServiceArt: 'endreinigung'),
          FaelligkeitsStatus.ueberfaellig);
    });
    test('Eröffnungsreinigung in der Pause unterdrückt den Hinweis, Uhr ab Start', () {
      final a = anlage()
        ..letzteReinigung = DateTime(2026, 6, 3)
        ..naechsteReinigung = null;
      // 04.06.: kein eroeffnungFaellig mehr (Art ist eroeffnungsservice)
      expect(
          getFaelligkeit(a, DateTime(2026, 6, 4),
              betrieb: _saisonBetrieb(), letzteServiceArt: 'eroeffnungsservice'),
          FaelligkeitsStatus.nichtFaellig);
      // Uhr ab Saisonstart 06.06.: Soll 04.07. -> 12.07. fällig
      expect(
          getFaelligkeit(a, DateTime(2026, 7, 12),
              betrieb: _saisonBetrieb(), letzteServiceArt: 'eroeffnungsservice'),
          FaelligkeitsStatus.faellig);
    });
  });
```

Hinweis: `AnlageLocal`-Feldnamen (`typAnlage`, `reinigungRhythmus`, `letzteReinigung`, `naechsteReinigung`) vorher per grep verifizieren.

- [ ] **Step 2: Failen sehen** (der 03.07.-Test schlägt fehl: heute liefert er eroeffnungFaellig).

- [ ] **Step 3: Umbau in `tour_providers.dart`:**

a) `_getSaisonFaelligkeit` (Z. 127-141): den `tage < 0`-Zweig ERSATZLOS streichen:

```dart
  // --- Eröffnungsservice: Wiedereröffnung steht bevor (Fenster 7 Tage).
  // Nur solange in der Pause NICHT gereinigt wurde (jede Pausen-Reinigung
  // ändert letzteServiceArt -> Branch feuert nicht mehr). NACH dem Start
  // übernimmt die reguläre Uhr mit Anker = Wiedereröffnung (faelligkeitsAnker)
  // — das frühere ewige eroeffnungFaellig liess 17 offene Betriebe unsichtbar.
  if (letzteServiceArt == 'endreinigung' || letzteServiceArt == null) {
    final ab =
        anlage.letzteReinigung ?? datum.subtract(const Duration(days: 365));
    final oeffnung = oeffnungNach(betrieb, ab);
    if (oeffnung != null) {
      final tage = oeffnung.difference(datum).inDays;
      if (tage >= 0 && tage <= _saisonVorlaufTage) {
        return FaelligkeitsStatus.eroeffnungFaellig;
      }
    }
  }
```

b) In `getFaelligkeit` den Block Z. 173-185 („Endreinigung + Ferien/Saison → +4 Wochen") ersetzen durch:

```dart
  // Uhr-Anker (Regel Daniel 17.07.2026): War der Betrieb nach der letzten
  // Reinigung geschlossen, zählt der Rhythmus ab der Wiedereröffnung — für
  // JEDE Service-Art (Endreinigung am Schluss, Eröffnungsreinigung vor dem
  // Start). Nur nach hinten korrigierend: ein überholtes naechsteReinigung
  // aus der Zeit vor der Pause (z.B. 27.04. bei Wiedereröffnung 06.06.) wird
  // überstimmt. Anker == null (Saisondaten fehlen) meldet die Warnleiste im
  // Tourenplan (saisonAnkerFehltProvider).
  if (betrieb != null && anlage.letzteReinigung != null) {
    final anker = faelligkeitsAnker(betrieb, anlage.letzteReinigung!);
    if (anker != null) {
      final abAnker = anker.add(Duration(days: tage));
      if (abAnker.isAfter(naechste)) naechste = abAnker;
    }
  }
```

Die private Funktion `_wiederoeffnungNachEndreinigung` danach entfernen, falls sie sonst nirgends genutzt wird (`grep -n "_wiederoeffnungNachEndreinigung" lib/`); Import von `touren_saison.dart` besteht bereits.

- [ ] **Step 4: Alle Tests grün** (`flutter test test/faelligkeit_anker_test.dart`, dann volle Suite), `flutter analyze lib/ | grep -cE "error -"` → 0.

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/presentation/providers/tour_providers.dart sbs_projer_app/test/faelligkeit_anker_test.dart
git commit -m "feat(touren): Fälligkeits-Uhr ab Wiedereröffnung, Eröffnungs-Hinweis nur im Vorlauf-Fenster (TDD)"
```

---

### Task 3: Warnleiste „Saisondaten fehlen" im Tourenplan

**Files:**
- Modify: `sbs_projer_app/lib/presentation/providers/tour_providers.dart` (neuer Provider, ans Datei-Ende)
- Modify: `sbs_projer_app/lib/presentation/screens/touren/tourenplanung_screen.dart` (Leiste über der Fällig-Liste)

- [ ] **Step 1: Provider** (in `tour_providers.dart` ergänzen):

```dart
// ─── Saisondaten fehlen (Anker nicht bestimmbar) ───

/// Betriebe, deren letzte Reinigung eine Endreinigung ist, die aber keine
/// künftige Wiedereröffnung gepflegt haben — die Fälligkeits-Uhr kann nicht
/// starten. Ohne Meldung wären sie STILL nie fällig (Regel Daniel 17.07.2026:
/// "falls nicht festgelegt Meldung").
final saisonAnkerFehltProvider = Provider<List<BetriebLocal>>((ref) {
  final betriebe = ref.watch(betriebeProvider);
  final anlagen = ref.watch(anlagenProvider);
  final reinigungen = ref.watch(reinigungenProvider);
  final serviceArtMap = _buildLetzteServiceArtMap(reinigungen);
  final betriebMap = _buildBetriebMap(betriebe);

  final result = <String, BetriebLocal>{};
  for (final a in anlagen) {
    if (a.status != 'aktiv' || a.letzteReinigung == null) continue;
    final art = a.serverId != null ? serviceArtMap[a.serverId!] : null;
    if (art != 'endreinigung') continue;
    final b = betriebMap[a.betriebId];
    if (b == null || b.status != 'aktiv') continue;
    if (faelligkeitsAnker(b, a.letzteReinigung!) == null) {
      result[b.routeId] = b;
    }
  }
  return result.values.toList()
    ..sort((a, b) => a.name.compareTo(b.name));
});
```

- [ ] **Step 2: Leiste im Screen** — in `tourenplanung_screen.dart` eine Methode nach dem Muster von `_warnungOhneRechnung` (rechnungen_list_screen.dart) einbauen und direkt ÜBER der Fällig-Liste rendern (die Stelle, wo `angezeigtFaellig` in die Spalte kommt — per grep `angezeigtFaellig` finden):

```dart
  Widget _warnungSaisonAnker() {
    final fehlt = ref.watch(saisonAnkerFehltProvider);
    if (fehlt.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: InkWell(
        onTap: () => showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('${fehlt.length} Betriebe ohne Saisonstart'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Text(
                  '${fehlt.map((b) => b.ort != null && b.ort!.isNotEmpty ? '${b.name} ${b.ort}' : b.name).join('\n')}\n\n'
                  'Endreinigung erledigt, aber kein künftiger Saisonstart/\n'
                  'Ferien-Ende gepflegt — die Fälligkeits-Uhr kann nicht starten.\n'
                  'Bitte Saisondaten im Betrieb ergänzen.',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.warning.withAlpha(30),
            border: Border.all(color: AppColors.warning.withAlpha(100)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            const Icon(Icons.event_busy, color: AppColors.warning, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${fehlt.length} Betriebe: Endreinigung ohne Saisonstart — Uhr kann nicht starten',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.warning, size: 18),
          ]),
        ),
      ),
    );
  }
```

Import von `AppColors` besteht im Screen bereits (prüfen). Einbau-Punkt: unmittelbar vor dem Widget, das die Fällig-Liste (`angezeigtFaellig`) rendert.

- [ ] **Step 3: Analyze + volle Tests** (0 errors / grün).

- [ ] **Step 4: Commit**

```bash
git add sbs_projer_app/lib/presentation/providers/tour_providers.dart sbs_projer_app/lib/presentation/screens/touren/tourenplanung_screen.dart
git commit -m "feat(touren): Warnleiste Saisondaten fehlen (Anker nicht bestimmbar)"
```

---

### Task 4: Filter-Default, Verifikation, Deploy v0.51.0

**Files:**
- Modify: `sbs_projer_app/lib/presentation/providers/tour_providers.dart:378-382`
- Modify: `sbs_projer_app/pubspec.yaml:4`, `sbs_projer_app/lib/core/app_version.dart`, `ToDo.md`

- [ ] **Step 1: Filter-Default erweitern**

```dart
final selectedFaelligkeitProvider =
    StateProvider<Set<FaelligkeitsStatus>>((ref) => {
      FaelligkeitsStatus.ueberfaellig,
      FaelligkeitsStatus.faellig,
      // Saisonale Planungsfenster standardmässig sichtbar (17 unsichtbare
      // Betriebe am 17.07.2026 — der Eröffnungs-Chip war nie aktiv).
      FaelligkeitsStatus.endreinigungFaellig,
      FaelligkeitsStatus.eroeffnungFaellig,
    });
```

- [ ] **Step 2: Version bumpen** — `pubspec.yaml` Z. 4 → `version: 0.51.0+585`; `kAppVersion = '0.51.0'`.

- [ ] **Step 3: Gesamtverifikation** — `flutter analyze lib/ | grep -cE "error -"` → 0; `flutter test | tail -1` → passed.

- [ ] **Step 4: Commit + Build + Deploy** (Standard-Sequenz mit Branch-Guard):

```bash
cd .. && git add -A && git commit -m "feat(touren): Fälligkeit ab Saisonstart (v0.51.0) — 17 unsichtbare Saison-Kunden wieder im Plan"
cd sbs_projer_app && export MSYS_NO_PATHCONV=1 && flutter build web --base-href "/sbs-projer-dev/" --pwa-strategy=none
cd .. && VER=$(grep -o '"version":"[^"]*"' sbs_projer_app/build/web/version.json | cut -d'"' -f4) \
  && sed -i "s/\"mainJsPath\":\"main.dart.js\"/\"mainJsPath\":\"main.dart.js?v=$VER\"/g" sbs_projer_app/build/web/flutter_bootstrap.js \
  && rm -f sbs_projer_app/build/web/flutter_service_worker.js
git checkout gh-pages
CUR=$(git rev-parse --abbrev-ref HEAD); if [ "$CUR" != "gh-pages" ]; then echo ABBRUCH; exit 1; fi
rm -rf assets canvaskit icons main.dart.js* flutter*.js index.html manifest.json favicon.png version.json docs
cp -r sbs_projer_app/build/web/* . && touch .nojekyll
git add index.html main.dart.js* flutter*.js manifest.json favicon.png version.json .nojekyll assets/ canvaskit/ icons/
git commit -m "deploy v0.51.0 — Fälligkeit ab Saisonstart"
git push origin gh-pages && git checkout main && git push origin main
```

- [ ] **Step 5: Verifikation an den 17** — nach dem Deploy prüft der Koordinator per SQL-Nachbau, dass die 17 Betriebe der Kontroll-Liste jetzt eine Stufe ≥ baldFaellig hätten (Stichprobe Tgantieni = fällig, Chesa/Seehof = überfällig), und Daniel bestätigt im Tourenplan.

- [ ] **Step 6: ToDo.md** — 🟢-Abschnitt „Fälligkeit ab Saisonstart (v0.51.0)" + Verweis auf Spec; Live-Check durch Daniel als offenen Punkt.

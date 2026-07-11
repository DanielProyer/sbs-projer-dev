# Tourenplanung T2 (Fälligkeits-Logik & Auto-Termine) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Endreinigung/Eröffnung werden aus den Saison-/Ferien-Übergängen des Betriebs abgeleitet (robuster), und automatische Vorschläge erscheinen am berechneten Ziel-Tag im Tagesplan zum Übernehmen.

**Architecture:** Reine Saison-Funktionen in `core/util/touren_saison.dart` (TDD). `tour_providers.dart` nutzt sie für die Saison-Fälligkeit (statt reiner `letzteServiceArt`-Heuristik) und für einen neuen `autoTermineProvider`. Eine UI-Sektion im Tagesplan-Tab zeigt die Auto-Termine des Tages.

**Tech Stack:** Flutter, Riverpod, `flutter_test`. Keine DB-Migration.

**Wichtige Fakten (verifiziert):**
- `BetriebLocal`: `status` ('aktiv'), `istSaisonbetrieb`, `sommer/winterSaisonAktiv`,
  `sommer/winterStartDatum`, `sommer/winterEndeDatum`, `ruhetage` (List<String>, volle
  Wochentagsnamen), Ferien via `betrieb_ferien.dart` (`ferienSlots/ferienStarts/ferienEnden/
  istInFerien`). Test-Konstruktion: `BetriebLocal()..userId='t'..name='T'..<felder>` (siehe
  `test/core/util/betrieb_ferien_test.dart`).
- `AnlageLocal`: `routeId`, `serverId`, `status` ('aktiv'), `betriebId`, `typAnlage`,
  `letzteReinigung` (DateTime?), `naechsteReinigung`, `reinigungRhythmus`.
- `serviceArt`-Werte: `'standardservice'`, `'endreinigung'`, `'eroeffnungsservice'`.
- `tour_providers.dart` Ist: `_saisonVorlaufTage = 14`; `_getSaisonFaelligkeit` nutzt
  `_naechsteSchliessung`/`_naechsteOeffnUng`; `isBetriebOffen` (mit Ruhetag) und `_isBetriebAktiv`
  (ohne Ruhetag); `_buildBetriebMap`, `_buildLetzteServiceArtMap`, `_servicezeitAus`;
  `TourEintrag` trägt `ruhetage`/`servicezeit` (aus T1); `tagesplanProvider`.
- `_wiederoeffnungNachEndreinigung` bleibt (wird in `getFaelligkeit` genutzt).
- Konstanten T2: **`langeSchliessungTage = 21`**, **Vorlauf `_saisonVorlaufTage = 7`**.

**Umgebung/Befehle:**
```bash
export PATH="$PATH:/c/flutter/bin"
cd "D:/01_SBS_Projer_GmbH/00_Entwicklung/SBS Projer DEV/sbs_projer_app"
```
Tests: `flutter test test/core/util/touren_saison_test.dart`
Analyse: `flutter analyze`

---

## File Structure

- **Neu:** `sbs_projer_app/lib/core/util/touren_saison.dart` — reine Saison-Funktionen
  (`langeSchliessungTage`, `istOffenerTag`, `naechsterOffenerTag`, `qualifizierteSchliessung`,
  `oeffnungNach`).
- **Neu:** `sbs_projer_app/test/core/util/touren_saison_test.dart` — Unit-Tests.
- **Ändern:** `sbs_projer_app/lib/presentation/providers/tour_providers.dart` — Saison-Fälligkeit auf
  neue Funktionen umstellen, `_saisonVorlaufTage` 14→7, `isBetriebOffen` delegiert, alte
  `_naechsteSchliessung`/`_naechsteOeffnung` entfernen; `TourEintrag.istAutoTermin`/`zielDatum` +
  `alsPlanEintrag()`; `autoTermineProvider`.
- **Ändern:** `sbs_projer_app/lib/presentation/screens/touren/tourenplanung_screen.dart` — Sektion
  „Automatische Termine" im Tagesplan-Tab.
- **Ändern:** `sbs_projer_app/pubspec.yaml` — Version-Bump.

---

## Task 1: Saison-Funktionen `touren_saison.dart` (TDD)

**Files:**
- Create: `sbs_projer_app/lib/core/util/touren_saison.dart`
- Test: `sbs_projer_app/test/core/util/touren_saison_test.dart`

- [ ] **Step 1: Failing-Test schreiben**

Create `sbs_projer_app/test/core/util/touren_saison_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/touren_saison.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';

BetriebLocal _betrieb() => BetriebLocal()
  ..userId = 'test'
  ..name = 'Test'
  ..status = 'aktiv';

void main() {
  group('istOffenerTag', () {
    test('aktiv, kein Ruhetag, keine Ferien, kein Saisonbetrieb → true', () {
      // 2026-07-10 ist Freitag
      expect(istOffenerTag(_betrieb(), DateTime(2026, 7, 10)), isTrue);
    });
    test('Ruhetag → false', () {
      final b = _betrieb()..ruhetage = ['Samstag'];
      expect(istOffenerTag(b, DateTime(2026, 7, 11)), isFalse); // Sa
    });
    test('in Ferien → false', () {
      final b = _betrieb()
        ..ferienStart = DateTime(2026, 7, 6)
        ..ferienEnde = DateTime(2026, 7, 20);
      expect(istOffenerTag(b, DateTime(2026, 7, 10)), isFalse);
    });
    test('Saisonbetrieb ausserhalb Saison → false', () {
      final b = _betrieb()
        ..istSaisonbetrieb = true
        ..sommerSaisonAktiv = true
        ..sommerStartDatum = DateTime(2026, 5, 1)
        ..sommerEndeDatum = DateTime(2026, 9, 30);
      expect(istOffenerTag(b, DateTime(2026, 11, 1)), isFalse);
    });
    test('Saisonbetrieb innerhalb Saison → true', () {
      final b = _betrieb()
        ..istSaisonbetrieb = true
        ..sommerSaisonAktiv = true
        ..sommerStartDatum = DateTime(2026, 5, 1)
        ..sommerEndeDatum = DateTime(2026, 9, 30);
      expect(istOffenerTag(b, DateTime(2026, 7, 10)), isTrue);
    });
    test('status != aktiv → false', () {
      final b = _betrieb()..status = 'inaktiv';
      expect(istOffenerTag(b, DateTime(2026, 7, 10)), isFalse);
    });
  });

  group('naechsterOffenerTag', () {
    test('überspringt Ruhetage vorwärts', () {
      final b = _betrieb()..ruhetage = ['Samstag', 'Sonntag'];
      // 2026-07-11 = Sa → nächster offener = Mo 2026-07-13
      expect(naechsterOffenerTag(b, DateTime(2026, 7, 11)),
          DateTime(2026, 7, 13));
    });
    test('überspringt Ferien vorwärts', () {
      final b = _betrieb()
        ..ferienStart = DateTime(2026, 7, 13)
        ..ferienEnde = DateTime(2026, 7, 17);
      // ab 13.7 (Ferien) → erster offener = 18.7 (Sa, kein Ruhetag)
      expect(naechsterOffenerTag(b, DateTime(2026, 7, 13)),
          DateTime(2026, 7, 18));
    });
    test('rückwärts findet letzten offenen Tag', () {
      final b = _betrieb()..ruhetage = ['Samstag', 'Sonntag'];
      // ab Sa 2026-07-11 rückwärts → Fr 2026-07-10
      expect(naechsterOffenerTag(b, DateTime(2026, 7, 11), rueckwaerts: true),
          DateTime(2026, 7, 10));
    });
    test('nie offen → null nach 60 Tagen', () {
      final b = _betrieb()..status = 'inaktiv';
      expect(naechsterOffenerTag(b, DateTime(2026, 7, 10)), isNull);
    });
  });

  group('qualifizierteSchliessung', () {
    test('Saisonende → erster geschlossener Tag = Ende+1, istSaisonende', () {
      final b = _betrieb()
        ..istSaisonbetrieb = true
        ..sommerSaisonAktiv = true
        ..sommerStartDatum = DateTime(2026, 5, 1)
        ..sommerEndeDatum = DateTime(2026, 9, 30);
      final s = qualifizierteSchliessung(b, DateTime(2026, 9, 1));
      expect(s, isNotNull);
      expect(s!.datum, DateTime(2026, 10, 1));
      expect(s.istSaisonende, isTrue);
    });
    test('lange Ferien (≥21 Tage) → Start; kurze werden ignoriert', () {
      final lang = _betrieb()
        ..ferienStart = DateTime(2026, 7, 1)
        ..ferienEnde = DateTime(2026, 7, 21); // 21 Tage
      final s = qualifizierteSchliessung(lang, DateTime(2026, 6, 1));
      expect(s!.datum, DateTime(2026, 7, 1));
      expect(s.istSaisonende, isFalse);

      final kurz = _betrieb()
        ..ferienStart = DateTime(2026, 7, 1)
        ..ferienEnde = DateTime(2026, 7, 20); // 20 Tage
      expect(qualifizierteSchliessung(kurz, DateTime(2026, 6, 1)), isNull);
    });
    test('nächste Schliessung gewinnt (Ferien vor Saisonende)', () {
      final b = _betrieb()
        ..istSaisonbetrieb = true
        ..sommerSaisonAktiv = true
        ..sommerStartDatum = DateTime(2026, 5, 1)
        ..sommerEndeDatum = DateTime(2026, 9, 30)
        ..ferienStart = DateTime(2026, 7, 1)
        ..ferienEnde = DateTime(2026, 7, 21);
      final s = qualifizierteSchliessung(b, DateTime(2026, 6, 1));
      expect(s!.datum, DateTime(2026, 7, 1));
      expect(s.istSaisonende, isFalse);
    });
  });

  group('oeffnungNach', () {
    test('Saisonstart nach ab', () {
      final b = _betrieb()
        ..istSaisonbetrieb = true
        ..sommerSaisonAktiv = true
        ..sommerStartDatum = DateTime(2026, 5, 1)
        ..sommerEndeDatum = DateTime(2026, 9, 30);
      expect(oeffnungNach(b, DateTime(2026, 1, 1)), DateTime(2026, 5, 1));
    });
    test('Ferienende+1, nimmt die frühere Öffnung', () {
      final b = _betrieb()
        ..istSaisonbetrieb = true
        ..sommerSaisonAktiv = true
        ..sommerStartDatum = DateTime(2026, 5, 1)
        ..sommerEndeDatum = DateTime(2026, 9, 30)
        ..ferienStart = DateTime(2026, 2, 1)
        ..ferienEnde = DateTime(2026, 2, 10);
      expect(oeffnungNach(b, DateTime(2026, 1, 1)), DateTime(2026, 2, 11));
    });
  });
}
```

- [ ] **Step 2: Test ausführen (muss fehlschlagen)**

Run: `flutter test test/core/util/touren_saison_test.dart`
Expected: FAIL — `touren_saison.dart` nicht gefunden.

- [ ] **Step 3: Implementierung schreiben**

Create `sbs_projer_app/lib/core/util/touren_saison.dart`:

```dart
import 'package:sbs_projer_app/core/util/betrieb_ferien.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';

// Saison-/Übergangs-Logik für die Tourenplanung (reine Funktionen, testbar).

/// Ab dieser Schliessdauer (Tage) gilt eine Ferienperiode als "lange
/// Schliessung" und löst Endreinigung/Eröffnung aus.
const int langeSchliessungTage = 21;

const List<String> _wochentageVoll = [
  'Montag',
  'Dienstag',
  'Mittwoch',
  'Donnerstag',
  'Freitag',
  'Samstag',
  'Sonntag',
];

bool _istRuhetag(BetriebLocal b, DateTime tag) =>
    b.ruhetage.contains(_wochentageVoll[tag.weekday - 1]);

bool _inAktiverSaison(BetriebLocal b, DateTime datum) {
  if (!b.istSaisonbetrieb) return true;
  bool inSaison = false;
  if (b.winterSaisonAktiv &&
      b.winterStartDatum != null &&
      b.winterEndeDatum != null) {
    if (!datum.isBefore(b.winterStartDatum!) &&
        !datum.isAfter(b.winterEndeDatum!)) {
      inSaison = true;
    }
  }
  if (b.sommerSaisonAktiv &&
      b.sommerStartDatum != null &&
      b.sommerEndeDatum != null) {
    if (!datum.isBefore(b.sommerStartDatum!) &&
        !datum.isAfter(b.sommerEndeDatum!)) {
      inSaison = true;
    }
  }
  return inSaison;
}

/// Kanonischer „offen"-Begriff: aktiv, nicht in Ferien, in aktiver Saison,
/// kein Ruhetag.
bool istOffenerTag(BetriebLocal b, DateTime tag) {
  if (b.status != 'aktiv') return false;
  if (istInFerien(b, tag)) return false;
  if (!_inAktiverSaison(b, tag)) return false;
  if (_istRuhetag(b, tag)) return false;
  return true;
}

/// Erster offener Tag ab [ab] (vorwärts, oder [rueckwaerts]); max. 60 Tage
/// Suchfenster, sonst null.
DateTime? naechsterOffenerTag(BetriebLocal b, DateTime ab,
    {bool rueckwaerts = false}) {
  var tag = DateTime(ab.year, ab.month, ab.day);
  for (var i = 0; i < 60; i++) {
    if (istOffenerTag(b, tag)) return tag;
    tag = tag.add(Duration(days: rueckwaerts ? -1 : 1));
  }
  return null;
}

/// Nächste relevante Schliessung ab [ab]: der erste **geschlossene** Tag der
/// Schliessung (Saisonende+1 oder Ferienstart) plus Flag, ob Saisonende.
/// Nur Saisonende und Ferien ab [langeSchliessungTage].
({DateTime datum, bool istSaisonende})? qualifizierteSchliessung(
    BetriebLocal b, DateTime ab) {
  final kandidaten = <({DateTime datum, bool istSaisonende})>[];

  if (b.istSaisonbetrieb) {
    for (final ende in [
      if (b.sommerSaisonAktiv) b.sommerEndeDatum,
      if (b.winterSaisonAktiv) b.winterEndeDatum,
    ]) {
      if (ende != null) {
        final closed = ende.add(const Duration(days: 1));
        if (!closed.isBefore(ab)) {
          kandidaten.add((datum: closed, istSaisonende: true));
        }
      }
    }
  }

  for (final s in ferienSlots(b)) {
    if (s.start == null || s.ende == null) continue;
    final dauer = s.ende!.difference(s.start!).inDays + 1;
    if (dauer >= langeSchliessungTage && !s.start!.isBefore(ab)) {
      kandidaten.add((datum: s.start!, istSaisonende: false));
    }
  }

  if (kandidaten.isEmpty) return null;
  kandidaten.sort((x, y) => x.datum.compareTo(y.datum));
  return kandidaten.first;
}

/// Nächste Wiedereröffnung strikt nach [ab] (Saisonstart oder Ferienende+1).
DateTime? oeffnungNach(BetriebLocal b, DateTime ab) {
  DateTime? naechste;
  if (b.istSaisonbetrieb) {
    for (final start in [
      if (b.sommerSaisonAktiv) b.sommerStartDatum,
      if (b.winterSaisonAktiv) b.winterStartDatum,
    ]) {
      if (start != null && start.isAfter(ab)) {
        if (naechste == null || start.isBefore(naechste)) naechste = start;
      }
    }
  }
  for (final ende in ferienEnden(b)) {
    final reopen = ende.add(const Duration(days: 1));
    if (reopen.isAfter(ab)) {
      if (naechste == null || reopen.isBefore(naechste)) naechste = reopen;
    }
  }
  return naechste;
}
```

- [ ] **Step 4: Test ausführen (muss bestehen)**

Run: `flutter test test/core/util/touren_saison_test.dart`
Expected: PASS (alle Tests grün).

- [ ] **Step 5: Commit**

```bash
cd "D:/01_SBS_Projer_GmbH/00_Entwicklung/SBS Projer DEV"
git add sbs_projer_app/lib/core/util/touren_saison.dart sbs_projer_app/test/core/util/touren_saison_test.dart
git commit -m "feat(touren): Saison-Uebergangs-Funktionen touren_saison (TDD)"
```

---

## Task 2: Saison-Fälligkeit auf Übergangs-Modell umstellen

**Files:**
- Modify: `sbs_projer_app/lib/presentation/providers/tour_providers.dart`

- [ ] **Step 1: Import ergänzen**

Nach `import '...betrieb_ferien.dart';` einfügen:

```dart
import 'package:sbs_projer_app/core/util/touren_saison.dart';
```

- [ ] **Step 2: Vorlauf-Konstante 14 → 7**

Ersetze:

```dart
const _saisonVorlaufTage = 14; // 2 Wochen
```

durch:

```dart
const _saisonVorlaufTage = 7; // 1 Woche
```

- [ ] **Step 3: `_naechsteSchliessung` und `_naechsteOeffnung` entfernen**

Lösche die beiden kompletten Funktionen (Doc-Kommentar + Body):
- `DateTime? _naechsteSchliessung(BetriebLocal betrieb, DateTime datum) { ... }`
- `DateTime? _naechsteOeffnung(BetriebLocal betrieb, DateTime datum, DateTime? letzteReinigung) { ... }`

(`_wiederoeffnungNachEndreinigung` und `_saisonVorlaufTage` **bleiben**.)

- [ ] **Step 4: `_getSaisonFaelligkeit` neu schreiben**

Ersetze die gesamte Funktion `_getSaisonFaelligkeit(...)` durch:

```dart
/// Prüft ob eine saisonale Fälligkeit vorliegt (Endreinigung / Eröffnung),
/// abgeleitet aus den Saison-/Ferien-Übergängen des Betriebs.
FaelligkeitsStatus? _getSaisonFaelligkeit(
  AnlageLocal anlage,
  DateTime datum,
  BetriebLocal betrieb,
  String? letzteServiceArt,
) {
  // --- Endreinigung: qualifizierte Schliessung im Vorlauf, noch nicht erledigt ---
  if (letzteServiceArt != 'endreinigung') {
    final s = qualifizierteSchliessung(betrieb, datum);
    if (s != null) {
      final tage = s.datum.difference(datum).inDays;
      if (tage >= 0 && tage <= _saisonVorlaufTage) {
        return FaelligkeitsStatus.endreinigungFaellig;
      }
    }
  }

  // --- Eröffnungsservice: Wiedereröffnung bald oder gerade erst geöffnet ---
  if (letzteServiceArt == 'endreinigung' || letzteServiceArt == null) {
    final ab = anlage.letzteReinigung ??
        datum.subtract(const Duration(days: 365));
    final oeffnung = oeffnungNach(betrieb, ab);
    if (oeffnung != null) {
      final tage = oeffnung.difference(datum).inDays;
      if (tage >= 0 && tage <= _saisonVorlaufTage) {
        return FaelligkeitsStatus.eroeffnungFaellig;
      }
      if (tage < 0 && letzteServiceArt == 'endreinigung') {
        return FaelligkeitsStatus.eroeffnungFaellig;
      }
    }
  }

  return null;
}
```

- [ ] **Step 5: `isBetriebOffen` an `istOffenerTag` delegieren**

Ersetze die gesamte Funktion `bool isBetriebOffen(BetriebLocal b, DateTime datum) { ... }` durch:

```dart
/// Betrieb an diesem Tag betrieblich offen (aktiv, keine Ferien, in Saison,
/// kein Ruhetag). Delegiert an den kanonischen Helfer in touren_saison.
bool isBetriebOffen(BetriebLocal b, DateTime datum) => istOffenerTag(b, datum);
```

- [ ] **Step 6: Analyse**

Run: `flutter analyze lib/presentation/providers/tour_providers.dart`
Expected: `No issues found!` (keine ungenutzten Funktionen mehr; `_isBetriebAktiv` bleibt bewusst bestehen und ist weiterhin in `faelligeAnlagenProvider` genutzt).

- [ ] **Step 7: Commit**

```bash
git add sbs_projer_app/lib/presentation/providers/tour_providers.dart
git commit -m "feat(touren): Saison-Faelligkeit aus Betrieb-Uebergaengen, Vorlauf 7 Tage"
```

---

## Task 3: `TourEintrag`-Auto-Felder + `autoTermineProvider`

**Files:**
- Modify: `sbs_projer_app/lib/presentation/providers/tour_providers.dart`

- [ ] **Step 1: `TourEintrag` um Auto-Felder + `alsPlanEintrag()` erweitern**

Ersetze im `class TourEintrag` den Feld-/Konstruktor-Block:

```dart
  final List<String> ruhetage;
  final String? servicezeit;

  const TourEintrag({
    required this.typ,
    required this.id,
    this.betriebId,
    this.anlageId,
    required this.betriebName,
    this.betriebOrt,
    this.regionId,
    required this.beschreibung,
    this.faelligkeit,
    this.datum,
    this.ruhetage = const [],
    this.servicezeit,
  });
```

durch:

```dart
  final List<String> ruhetage;
  final String? servicezeit;
  final bool istAutoTermin;
  final DateTime? zielDatum;

  const TourEintrag({
    required this.typ,
    required this.id,
    this.betriebId,
    this.anlageId,
    required this.betriebName,
    this.betriebOrt,
    this.regionId,
    required this.beschreibung,
    this.faelligkeit,
    this.datum,
    this.ruhetage = const [],
    this.servicezeit,
    this.istAutoTermin = false,
    this.zielDatum,
  });

  /// Version für den gespeicherten Plan (kein Auto-Marker mehr).
  TourEintrag alsPlanEintrag() => TourEintrag(
        typ: typ,
        id: id,
        betriebId: betriebId,
        anlageId: anlageId,
        betriebName: betriebName,
        betriebOrt: betriebOrt,
        regionId: regionId,
        beschreibung: beschreibung,
        faelligkeit: faelligkeit,
        datum: datum,
        ruhetage: ruhetage,
        servicezeit: servicezeit,
      );
```

(Die JSON-Serialisierung bleibt unverändert — Auto-Felder werden nie persistiert.)

- [ ] **Step 2: `autoTermineProvider` hinzufügen**

Direkt nach dem `faelligeEintraegeProvider`-Block (vor `String _montageTypLabel(...)`) einfügen:

```dart
// ─── Automatische Saison-Termine (Endreinigung/Eröffnung am Ziel-Tag) ───

final autoTermineProvider =
    Provider.family<List<TourEintrag>, DateTime>((ref, datum) {
  final betriebe = ref.watch(betriebeProvider);
  final betriebMap = _buildBetriebMap(betriebe);
  final anlagen = ref.watch(anlagenProvider);
  final reinigungen = ref.watch(reinigungenProvider);
  final serviceArtMap = _buildLetzteServiceArtMap(reinigungen);
  final imPlan = ref.watch(tagesplanProvider).map((e) => e.id).toSet();
  final tag = DateTime(datum.year, datum.month, datum.day);
  final result = <TourEintrag>[];

  for (final a in anlagen) {
    if (a.status != 'aktiv') continue;
    final betrieb = betriebMap[a.betriebId];
    if (betrieb == null) continue;
    final hatUebergaenge =
        betrieb.istSaisonbetrieb || ferienStarts(betrieb).isNotEmpty;
    if (!hatUebergaenge) continue;

    final id = 'r_${a.routeId}';
    if (imPlan.contains(id)) continue;

    final letzteServiceArt =
        a.serverId != null ? serviceArtMap[a.serverId!] : null;

    // Endreinigung: letzter offener Tag vor der nächsten Schliessung
    if (letzteServiceArt != 'endreinigung') {
      final s = qualifizierteSchliessung(betrieb, tag);
      if (s != null) {
        final ziel =
            naechsterOffenerTag(betrieb, s.datum, rueckwaerts: true);
        if (ziel != null && ziel == tag) {
          result.add(TourEintrag(
            typ: TourEintragTyp.reinigung,
            id: id,
            betriebId: a.betriebId,
            anlageId: a.routeId,
            betriebName: betrieb.name,
            betriebOrt: betrieb.ort,
            regionId: betrieb.regionId,
            beschreibung: 'Endreinigung · ${a.typAnlage}',
            faelligkeit: FaelligkeitsStatus.endreinigungFaellig,
            ruhetage: betrieb.ruhetage,
            servicezeit: _servicezeitAus(betrieb),
            istAutoTermin: true,
            zielDatum: ziel,
          ));
          continue;
        }
      }
    }

    // Eröffnung: erster offener Tag ab Wiedereröffnung (Anlage ist geschlossen)
    if (letzteServiceArt == 'endreinigung') {
      final ab = a.letzteReinigung ??
          tag.subtract(const Duration(days: 365));
      final oeffnung = oeffnungNach(betrieb, ab);
      if (oeffnung != null) {
        final ziel =
            naechsterOffenerTag(betrieb, oeffnung, rueckwaerts: false);
        if (ziel != null && ziel == tag) {
          result.add(TourEintrag(
            typ: TourEintragTyp.reinigung,
            id: id,
            betriebId: a.betriebId,
            anlageId: a.routeId,
            betriebName: betrieb.name,
            betriebOrt: betrieb.ort,
            regionId: betrieb.regionId,
            beschreibung: 'Eröffnungsservice · ${a.typAnlage}',
            faelligkeit: FaelligkeitsStatus.eroeffnungFaellig,
            ruhetage: betrieb.ruhetage,
            servicezeit: _servicezeitAus(betrieb),
            istAutoTermin: true,
            zielDatum: ziel,
          ));
        }
      }
    }
  }

  return result;
});
```

- [ ] **Step 3: Analyse**

Run: `flutter analyze lib/presentation/providers/tour_providers.dart`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add sbs_projer_app/lib/presentation/providers/tour_providers.dart
git commit -m "feat(touren): autoTermineProvider + TourEintrag Auto-Felder"
```

---

## Task 4: UI-Sektion „Automatische Termine" im Tagesplan-Tab

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/touren/tourenplanung_screen.dart`

- [ ] **Step 1: Auto-Termine im build watchen**

Im `build` nach `final faelligeEintraege = ref.watch(faelligeEintraegeProvider(_selectedDate));`
einfügen:

```dart
    final autoTermine = ref.watch(autoTermineProvider(_selectedDate));
```

- [ ] **Step 2: Sektion oberhalb der Plan-Liste einbauen**

Im Tagesplan-Tab (der erste `Column`-Child im `TabBarView`) steht aktuell:

```dart
                Column(
                  children: [
                    _TagesplanHeader(
                      datum: _selectedDate,
                      onLeeren: () =>
                          ref.read(tagesplanProvider.notifier).leeren(),
                      onAusFaelligBefuellen: () {
                        ref
                            .read(tagesplanProvider.notifier)
                            .befuellenAusFaellig(angezeigtFaellig);
                      },
                    ),
                    Expanded(
```

Füge **zwischen** `_TagesplanHeader(...)` und `Expanded(` ein:

```dart
                    if (autoTermine.isNotEmpty)
                      _AutoTermineSektion(
                        eintraege: autoTermine,
                        onUebernehmen: (e) => ref
                            .read(tagesplanProvider.notifier)
                            .hinzufuegen(e.alsPlanEintrag()),
                        onAlleUebernehmen: () {
                          final notifier =
                              ref.read(tagesplanProvider.notifier);
                          for (final e in autoTermine) {
                            notifier.hinzufuegen(e.alsPlanEintrag());
                          }
                        },
                        onTap: _navigateToDetail,
                      ),
```

- [ ] **Step 3: `_AutoTermineSektion`-Widget anlegen**

Vor `// ─── Info-Zeile: ...` (also vor `class _TourInfoZeile`) einfügen:

```dart
// ─── Automatische Termine (Saison) ───

class _AutoTermineSektion extends StatelessWidget {
  final List<TourEintrag> eintraege;
  final void Function(TourEintrag) onUebernehmen;
  final VoidCallback onAlleUebernehmen;
  final void Function(TourEintrag) onTap;

  const _AutoTermineSektion({
    required this.eintraege,
    required this.onUebernehmen,
    required this.onAlleUebernehmen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      decoration: BoxDecoration(
        color: AppColors.info.withAlpha(12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.info.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 2),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome,
                    size: 16, color: AppColors.info),
                const SizedBox(width: 6),
                Text('Automatische Termine (${eintraege.length})',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.info)),
                const Spacer(),
                TextButton(
                  onPressed: onAlleUebernehmen,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('Alle übernehmen',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          ...eintraege.map((e) => _AutoTerminKarte(
                eintrag: e,
                onUebernehmen: () => onUebernehmen(e),
                onTap: () => onTap(e),
              )),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _AutoTerminKarte extends StatelessWidget {
  final TourEintrag eintrag;
  final VoidCallback onUebernehmen;
  final VoidCallback onTap;

  const _AutoTerminKarte({
    required this.eintrag,
    required this.onUebernehmen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = eintrag.faelligkeit != null
        ? faelligkeitFarbe(eintrag.faelligkeit!)
        : AppColors.info;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(eintrag.betriebName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                  Text(eintrag.beschreibung,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline,
                  color: AppColors.primary),
              onPressed: onUebernehmen,
              tooltip: 'Zum Tagesplan',
              iconSize: 22,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Analyse**

Run: `flutter analyze lib/presentation/screens/touren/tourenplanung_screen.dart`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/touren/tourenplanung_screen.dart
git commit -m "feat(touren): Sektion Automatische Termine im Tagesplan-Tab"
```

---

## Task 5: Gesamtverifikation + Deploy v0.30.0

**Files:**
- Modify: `sbs_projer_app/pubspec.yaml`

- [ ] **Step 1: Volle Analyse + Tests**

Run:
```bash
flutter analyze
flutter test test/core/util/touren_saison_test.dart test/touren_anzeige_test.dart
```
Expected: analyze ohne neue Fehler (nur vorbestehende Isar-`.g.dart`-Warnings); Tests grün.

- [ ] **Step 2: Version bumpen**

In `pubspec.yaml` Zeile 4 `version:` auf `0.30.0+509` setzen.

- [ ] **Step 3: Build + Cache-Bust**

```bash
cd sbs_projer_app && export MSYS_NO_PATHCONV=1 \
  && flutter build web --base-href "/sbs-projer-dev/" --pwa-strategy=none
cd .. && VER=$(grep -o '"version":"[^"]*"' sbs_projer_app/build/web/version.json | cut -d'"' -f4) \
  && sed -i "s/\"mainJsPath\":\"main.dart.js\"/\"mainJsPath\":\"main.dart.js?v=$VER\"/g" \
       sbs_projer_app/build/web/flutter_bootstrap.js \
  && rm -f sbs_projer_app/build/web/flutter_service_worker.js
```

- [ ] **Step 4: Visueller Live-Check nach Deploy** (Preview-Harness rendert canvaskit nicht; Login-Wall)

Wird vom User live geprüft (siehe Deploy-Handoff): Saisonbetrieb kurz vor Saisonende → Endreinigung-
Auto-Termin am letzten offenen Tag; nach Saisonstart → Eröffnung-Auto-Termin; „übernehmen" schiebt in
den Plan (Auto-Save); kurze Betriebsferien (<21 T) → keine Endreinigung; Ruhetag am Ziel-Tag
übersprungen.

- [ ] **Step 5: Deploy auf gh-pages + main**

```bash
git add sbs_projer_app/pubspec.yaml && git commit -m "chore: Version 0.30.0+509 (Tourenplanung T2)"
git checkout gh-pages
rm -rf assets canvaskit icons main.dart.js* flutter*.js index.html manifest.json favicon.png version.json docs
cp -r sbs_projer_app/build/web/* .
touch .nojekyll
git add index.html main.dart.js* flutter*.js manifest.json favicon.png version.json .nojekyll assets/ canvaskit/ icons/
git commit -m "deploy v0.30.0 — Tourenplanung T2 (Faelligkeit & Auto-Termine)"
git push origin gh-pages
git checkout main
git push origin main
```

- [ ] **Step 6: ToDo aktualisieren**

In `ToDo.md` „Tourenplanung T2" auf erledigt setzen.

```bash
git add ToDo.md && git commit -m "docs: ToDo — Tourenplanung T2 erledigt"
git push origin main
```

---

## Self-Review

**1. Spec coverage:**
- Baustein A (touren_saison, TDD) → Task 1. ✅
- Baustein B (Saison-Fälligkeit aus Übergängen, Vorlauf 7, isBetriebOffen unifiziert) → Task 2. ✅
- Baustein C (TourEintrag Auto-Felder + autoTermineProvider + Dedupe vs. Plan) → Task 3. ✅
- Baustein D (UI-Sektion, +übernehmen / alle übernehmen) → Task 4. ✅
- Keine Migration, Deploy v0.30.0 → Task 5. ✅

**2. Placeholder scan:** Keine TBD/TODO; alle Code-Schritte vollständig. ✅

**3. Type consistency:** `qualifizierteSchliessung` liefert `({DateTime datum, bool istSaisonende})`,
konsistent in Task 1/3 genutzt (`s.datum`). `naechsterOffenerTag(..., rueckwaerts:)`,
`oeffnungNach`, `istOffenerTag` einheitlich benannt zwischen touren_saison und Aufrufern.
`TourEintrag.istAutoTermin`/`zielDatum`/`alsPlanEintrag()` konsistent zwischen Task 3 (Definition) und
Task 4 (Nutzung). Auto-Termin-`id = 'r_<routeId>'` = gleiche id-Konvention wie fällige Reinigungen →
Dedupe via `imPlan` + `hinzufuegen`. Service-Art-Strings `'endreinigung'`/`'eroeffnungsservice'` wie im
Reinigungs-Formular. ✅

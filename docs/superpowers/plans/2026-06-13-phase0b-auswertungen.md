# Phase 0b – Auswertungen (Bilanz / Erfolgsrechnung / MWST) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Drei aus dem Journal berechnete Auswertungen bereitstellen — **Bilanz** (neu), **Erfolgsrechnung** in KMU-Stufengliederung (Umbau der bestehenden groben Variante) und **MWST-Vorschau** (Verifikation) — in der Gliederung **deckungsgleich mit den Excel-Sheets**, als Voraussetzung für den späteren Phase-1-Abgleich.

**Architecture:** Supabase-only (wie bestehende Buchhaltung). Die Berechnungslogik liegt in **reinen Dart-Services** (`BilanzService`, `ErfolgsrechnungService`), die über eine leichtgewichtige Eingabestruktur (`BuchungSaldo`) arbeiten und **ohne Supabase unit-testbar** sind. Provider laden die Buchungen/Konten und rufen die reinen Funktionen; Screens rendern. Keine redundante Saldo-Speicherung.

**Tech Stack:** Flutter/Dart, Riverpod (FutureProvider.family), Supabase (PostgreSQL), `flutter_test`, go_router. Spec: [Phase-0-Design §5](../specs/2026-06-09-phase0-fundament-buchhaltung-design.md). Ziel-Gliederung = Excel-Sheets „Bilanz" + „Erfolgsrechnung" (00_Buchhaltung/00_SBS_Projer_70.xlsm).

**Projekt-Konventionen:** Services in `lib/services/buchhaltung/`. Screens in `lib/presentation/screens/buchhaltung/`. Provider in `lib/presentation/providers/buchhaltung_providers.dart`. Routen in `lib/core/config/router.dart` (Block `/buchhaltung`). Theme über `AppColors` (`lib/core/theme/app_theme.dart`). Vorlage-Screen: `kontenplan_screen.dart`. Flutter via `export PATH="$PATH:/c/flutter/bin"`.

---

## Referenz: Kontonummer → Auswertungs-Zuordnung

**Bilanz (Saldo per Stichtag, Σ Soll − Σ Haben über nicht-stornierte Buchungen mit `datum ≤ Stichtag`; Vorzeichen-Konvention: Aktiven positiv bei Soll-Überhang, Passiven positiv bei Haben-Überhang):**

| Bilanz-Abschnitt | Seite | konto.kategorie |
|---|---|---|
| Umlaufvermögen | Aktiven | `Umlaufvermögen` |
| Anlagevermögen | Aktiven | `Anlagevermögen` |
| Kurzfristiges Fremdkapital | Passiven | `Kurzfristiges Fremdkapital`, `Sozialversicherungen` |
| Langfristiges Fremdkapital | Passiven | `Langfristiges Fremdkapital` |
| Eigenkapital | Passiven | `Eigenkapital` |

**Erfolgsrechnung (Stufengliederung, Periode von–bis; Ertrag = Σ Haben − Σ Soll, Aufwand = Σ Soll − Σ Haben):**

| Stufe | Formel (Kontonummer-Bereiche) |
|---|---|
| Nettoerlös | Σ Klasse 3 (3000–3999) als Ertrag |
| − Materialaufwand | Σ Klasse 4 (4000–4999) als Aufwand |
| = **Bruttoergebnis 1** | Nettoerlös − Material |
| − Personalaufwand | Σ Klasse 5 (5000–5999) |
| = **Bruttoergebnis 2** | BE1 − Personal |
| − übriger Betriebsaufwand | Σ 6000–6799 |
| = **EBITDA** | BE2 − übr. Aufwand |
| − Abschreibungen | Σ 6800–6899 |
| = **EBIT** | EBITDA − Abschreibungen |
| ± Finanzerfolg | Σ 6900–6999 (Aufwand mindert) |
| = **EBT** | EBIT − Finanzaufwand |
| ± betriebsfremd/a.o. | Σ Klasse 7 (Ertrag) − Σ 8000–8899 (Aufwand) |
| − Direkte Steuern | Σ 8900–8999 |
| = **Jahresergebnis** | EBT + Nebenerfolg − Steuern |

---

## Task 1: BilanzService – reine Saldo- & Gruppierungslogik (TDD)

**Files:**
- Create: `sbs_projer_app/lib/services/buchhaltung/bilanz_service.dart`
- Test: `sbs_projer_app/test/bilanz_service_test.dart`

- [ ] **Step 1: Failing Test schreiben**

```dart
// test/bilanz_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/buchhaltung/bilanz_service.dart';

BuchungSaldo _b(int soll, int haben, double betrag, String datum,
        {bool storniert = false}) =>
    BuchungSaldo(
      sollKonto: soll,
      habenKonto: haben,
      betrag: betrag,
      datum: DateTime.parse(datum),
      storniert: storniert,
    );

KontoInfo _k(int nr, String kat) =>
    KontoInfo(kontonummer: nr, bezeichnung: 'K$nr', kategorie: kat);

void main() {
  test('Saldo per Stichtag ignoriert spätere + stornierte Buchungen', () {
    final saldi = BilanzService.saldiPerStichtag(
      [
        _b(1020, 3400, 100, '2025-01-10'), // Bank +100
        _b(1020, 3400, 50, '2025-06-01'), // Bank +50 (nach Stichtag)
        _b(1020, 3400, 99, '2025-01-15', storniert: true), // ignoriert
      ],
      DateTime.parse('2025-03-31'),
    );
    expect(saldi[1020], 100); // nur die erste zählt
  });

  test('Aktiven positiv bei Soll-Überhang, Passiven positiv bei Haben-Überhang',
      () {
    final saldi = BilanzService.saldiPerStichtag(
      [
        _b(1020, 2000, 200, '2025-01-10'), // Bank Soll 200, Kreditor Haben 200
      ],
      DateTime.parse('2025-12-31'),
    );
    final bilanz = BilanzService.gruppiere(saldi, [
      _k(1020, 'Umlaufvermögen'),
      _k(2000, 'Kurzfristiges Fremdkapital'),
    ]);
    expect(bilanz.aktiven.single.summe, 200);
    expect(bilanz.passiven.single.summe, 200);
    expect(bilanz.totalAktiven, 200);
    expect(bilanz.totalPassiven, 200);
    expect(bilanz.differenz, 0);
  });

  test('Sozialversicherungen zählen zum kurzfristigen Fremdkapital', () {
    final saldi = BilanzService.saldiPerStichtag(
      [_b(5700, 2271, 80, '2025-02-01')], // Haben 2271 +80
      DateTime.parse('2025-12-31'),
    );
    final bilanz = BilanzService.gruppiere(saldi, [
      _k(2271, 'Sozialversicherungen'),
    ]);
    final kfk = bilanz.passiven
        .firstWhere((g) => g.titel == 'Kurzfristiges Fremdkapital');
    expect(kfk.summe, 80);
  });

  test('Konten mit Saldo 0 werden nicht gelistet', () {
    final saldi = BilanzService.saldiPerStichtag(
      [_b(1020, 1000, 0, '2025-01-01')],
      DateTime.parse('2025-12-31'),
    );
    final bilanz = BilanzService.gruppiere(
        saldi, [_k(1020, 'Umlaufvermögen'), _k(1000, 'Umlaufvermögen')]);
    expect(bilanz.aktiven, isEmpty);
  });
}
```

- [ ] **Step 2: Test laufen lassen → FAIL**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test test/bilanz_service_test.dart`
Expected: FAIL (Typen/Methoden fehlen).

- [ ] **Step 3: Service implementieren**

```dart
// lib/services/buchhaltung/bilanz_service.dart

/// Leichtgewichtige Buchungs-Eingabe für die reine Saldo-Berechnung.
class BuchungSaldo {
  final int sollKonto;
  final int habenKonto;
  final double betrag; // betragBrutto
  final DateTime datum;
  final bool storniert;
  const BuchungSaldo({
    required this.sollKonto,
    required this.habenKonto,
    required this.betrag,
    required this.datum,
    required this.storniert,
  });
}

/// Konto-Stammdaten für die Gruppierung.
class KontoInfo {
  final int kontonummer;
  final String bezeichnung;
  final String kategorie;
  const KontoInfo({
    required this.kontonummer,
    required this.bezeichnung,
    required this.kategorie,
  });
}

/// Eine Zeile (Konto + Saldo) in einer Bilanz-Gruppe.
class BilanzPosten {
  final int kontonummer;
  final String bezeichnung;
  final double summe;
  const BilanzPosten(this.kontonummer, this.bezeichnung, this.summe);
}

/// Eine Gruppe (z. B. „Umlaufvermögen") mit ihren Posten + Gruppensumme.
class BilanzGruppe {
  final String titel;
  final List<BilanzPosten> posten;
  const BilanzGruppe(this.titel, this.posten);
  double get summe => posten.fold(0.0, (s, p) => s + p.summe);
}

/// Eine fertige Bilanz: Aktiven/Passiven als Gruppen + Summen + Differenz.
class BilanzDaten {
  final List<BilanzGruppe> aktiven;
  final List<BilanzGruppe> passiven;
  const BilanzDaten(this.aktiven, this.passiven);
  double get totalAktiven => aktiven.fold(0.0, (s, g) => s + g.summe);
  double get totalPassiven => passiven.fold(0.0, (s, g) => s + g.summe);
  double get differenz => totalAktiven - totalPassiven;
}

class BilanzService {
  static const _aktivKategorien = {'Umlaufvermögen', 'Anlagevermögen'};
  // Reihenfolge der Passiv-Gruppen + welche Konto-Kategorien hineinfallen.
  static const _passivGruppen = <String, Set<String>>{
    'Kurzfristiges Fremdkapital': {
      'Kurzfristiges Fremdkapital',
      'Sozialversicherungen',
    },
    'Langfristiges Fremdkapital': {'Langfristiges Fremdkapital'},
    'Eigenkapital': {'Eigenkapital'},
  };

  /// Saldo je Konto per Stichtag: Σ Soll − Σ Haben (nur nicht-storniert,
  /// datum ≤ Stichtag). Vorzeichen wird erst in [gruppiere] seitenabhängig
  /// interpretiert.
  static Map<int, double> saldiPerStichtag(
      List<BuchungSaldo> buchungen, DateTime stichtag) {
    final saldi = <int, double>{};
    for (final b in buchungen) {
      if (b.storniert) continue;
      if (b.datum.isAfter(stichtag)) continue;
      saldi[b.sollKonto] = (saldi[b.sollKonto] ?? 0) + b.betrag;
      saldi[b.habenKonto] = (saldi[b.habenKonto] ?? 0) - b.betrag;
    }
    return saldi;
  }

  /// Gruppiert die Saldi nach Bilanz-Abschnitten. Aktiven nehmen den Saldo
  /// (Soll−Haben) direkt; Passiven invertieren ihn (Haben−Soll). Posten mit
  /// Saldo 0 entfallen.
  static BilanzDaten gruppiere(
      Map<int, double> saldi, List<KontoInfo> konten) {
    final byNr = {for (final k in konten) k.kontonummer: k};

    List<BilanzPosten> postenFuer(bool Function(String kat) match,
        {required bool invertieren}) {
      final result = <BilanzPosten>[];
      for (final entry in saldi.entries) {
        final k = byNr[entry.key];
        if (k == null || !match(k.kategorie)) continue;
        final summe = invertieren ? -entry.value : entry.value;
        if (summe == 0) continue;
        result.add(BilanzPosten(k.kontonummer, k.bezeichnung, summe));
      }
      result.sort((a, b) => a.kontonummer.compareTo(b.kontonummer));
      return result;
    }

    final aktiven = <BilanzGruppe>[];
    for (final kat in const ['Umlaufvermögen', 'Anlagevermögen']) {
      final posten =
          postenFuer((k) => k == kat, invertieren: false);
      if (posten.isNotEmpty) aktiven.add(BilanzGruppe(kat, posten));
    }

    final passiven = <BilanzGruppe>[];
    _passivGruppen.forEach((titel, kategorien) {
      final posten =
          postenFuer((k) => kategorien.contains(k), invertieren: true);
      if (posten.isNotEmpty) passiven.add(BilanzGruppe(titel, posten));
    });

    return BilanzDaten(aktiven, passiven);
  }
}
```

Hinweis: `_aktivKategorien` ist dokumentarisch (die Aktiv-Reihenfolge wird über die feste Liste in `gruppiere` erzeugt); falls ungenutzt-Warnung auftritt, das Feld entfernen.

- [ ] **Step 4: Test laufen lassen → PASS**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test test/bilanz_service_test.dart`
Expected: PASS (4 Tests).

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/services/buchhaltung/bilanz_service.dart sbs_projer_app/test/bilanz_service_test.dart
git commit -m "feat(buchhaltung): BilanzService (Saldo per Stichtag + Gruppierung) + Tests"
```

---

## Task 2: ErfolgsrechnungService – KMU-Stufengliederung (TDD)

**Files:**
- Create: `sbs_projer_app/lib/services/buchhaltung/erfolgsrechnung_service.dart`
- Test: `sbs_projer_app/test/erfolgsrechnung_service_test.dart`

- [ ] **Step 1: Failing Test schreiben**

```dart
// test/erfolgsrechnung_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/buchhaltung/bilanz_service.dart'
    show BuchungSaldo;
import 'package:sbs_projer_app/services/buchhaltung/erfolgsrechnung_service.dart';

BuchungSaldo _b(int soll, int haben, double betrag, String datum) =>
    BuchungSaldo(
        sollKonto: soll,
        habenKonto: haben,
        betrag: betrag,
        datum: DateTime.parse(datum),
        storniert: false);

void main() {
  // Erlös 1000 (Haben 3400), Material 100 (Soll 4004), Personal 300 (Soll 5000),
  // übr. Aufwand 50 (Soll 6200), Finanz 10 (Soll 6940), Steuern 20 (Soll 8900)
  final buchungen = [
    _b(1100, 3400, 1000, '2025-02-01'),
    _b(4004, 2000, 100, '2025-02-02'),
    _b(5000, 1020, 300, '2025-02-03'),
    _b(6200, 1020, 50, '2025-02-04'),
    _b(6940, 1020, 10, '2025-02-05'),
    _b(8900, 2208, 20, '2025-02-06'),
  ];

  test('Stufengliederung rechnet korrekt durch', () {
    final er = ErfolgsrechnungService.berechne(
      buchungen,
      von: DateTime.parse('2025-01-01'),
      bis: DateTime.parse('2025-12-31'),
    );
    expect(er.nettoerloes, 1000);
    expect(er.materialaufwand, 100);
    expect(er.bruttoergebnis1, 900);
    expect(er.personalaufwand, 300);
    expect(er.bruttoergebnis2, 600);
    expect(er.uebrigerAufwand, 50);
    expect(er.ebitda, 550);
    expect(er.abschreibungen, 0);
    expect(er.ebit, 550);
    expect(er.finanzerfolg, -10); // Finanzaufwand mindert
    expect(er.ebt, 540);
    expect(er.steuern, 20);
    expect(er.jahresergebnis, 520);
  });

  test('Periodenfilter: Buchung ausserhalb von–bis zählt nicht', () {
    final er = ErfolgsrechnungService.berechne(
      [_b(1100, 3400, 999, '2024-12-31')],
      von: DateTime.parse('2025-01-01'),
      bis: DateTime.parse('2025-12-31'),
    );
    expect(er.nettoerloes, 0);
  });
}
```

- [ ] **Step 2: Test laufen lassen → FAIL**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test test/erfolgsrechnung_service_test.dart`
Expected: FAIL.

- [ ] **Step 3: Service implementieren**

```dart
// lib/services/buchhaltung/erfolgsrechnung_service.dart
import 'bilanz_service.dart' show BuchungSaldo;

/// Ergebnis der KMU-Stufengliederung.
class ErfolgsrechnungDaten {
  final double nettoerloes;
  final double materialaufwand;
  final double personalaufwand;
  final double uebrigerAufwand; // 6000–6799
  final double abschreibungen; // 6800–6899
  final double finanzerfolg; // 6900–6999, negativ wenn Aufwand überwiegt
  final double nebenerfolg; // Klasse 7 (Ertrag) − 8000–8899 (Aufwand)
  final double steuern; // 8900–8999
  const ErfolgsrechnungDaten({
    required this.nettoerloes,
    required this.materialaufwand,
    required this.personalaufwand,
    required this.uebrigerAufwand,
    required this.abschreibungen,
    required this.finanzerfolg,
    required this.nebenerfolg,
    required this.steuern,
  });

  double get bruttoergebnis1 => nettoerloes - materialaufwand;
  double get bruttoergebnis2 => bruttoergebnis1 - personalaufwand;
  double get ebitda => bruttoergebnis2 - uebrigerAufwand;
  double get ebit => ebitda - abschreibungen;
  double get ebt => ebit + finanzerfolg;
  double get jahresergebnis => ebt + nebenerfolg - steuern;
}

class ErfolgsrechnungService {
  /// Aufwand-Saldo (Soll−Haben) über einen Kontonummer-Bereich [von,bis].
  static double _aufwand(Map<int, double> sollMinusHaben, int von, int bis) {
    double s = 0;
    sollMinusHaben.forEach((nr, v) {
      if (nr >= von && nr <= bis) s += v;
    });
    return s;
  }

  static ErfolgsrechnungDaten berechne(
    List<BuchungSaldo> buchungen, {
    required DateTime von,
    required DateTime bis,
  }) {
    // Soll−Haben je Konto über die Periode (nur nicht-storniert).
    final shm = <int, double>{};
    for (final b in buchungen) {
      if (b.storniert) continue;
      if (b.datum.isBefore(von) || b.datum.isAfter(bis)) continue;
      shm[b.sollKonto] = (shm[b.sollKonto] ?? 0) + b.betrag;
      shm[b.habenKonto] = (shm[b.habenKonto] ?? 0) - b.betrag;
    }

    // Ertrag = Haben−Soll (= −(Soll−Haben)); Aufwand = Soll−Haben.
    final nettoerloes = -_aufwand(shm, 3000, 3999);
    final material = _aufwand(shm, 4000, 4999);
    final personal = _aufwand(shm, 5000, 5999);
    final uebrig = _aufwand(shm, 6000, 6799);
    final abschreib = _aufwand(shm, 6800, 6899);
    final finanzAufwand = _aufwand(shm, 6900, 6999);
    final nebenErtrag = -_aufwand(shm, 7000, 7999);
    final nebenAufwand = _aufwand(shm, 8000, 8899);
    final steuern = _aufwand(shm, 8900, 8999);

    return ErfolgsrechnungDaten(
      nettoerloes: nettoerloes,
      materialaufwand: material,
      personalaufwand: personal,
      uebrigerAufwand: uebrig,
      abschreibungen: abschreib,
      finanzerfolg: -finanzAufwand,
      nebenerfolg: nebenErtrag - nebenAufwand,
      steuern: steuern,
    );
  }
}
```

- [ ] **Step 4: Test laufen lassen → PASS**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test test/erfolgsrechnung_service_test.dart`
Expected: PASS (2 Tests).

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/services/buchhaltung/erfolgsrechnung_service.dart sbs_projer_app/test/erfolgsrechnung_service_test.dart
git commit -m "feat(buchhaltung): ErfolgsrechnungService (KMU-Stufengliederung) + Tests"
```

---

## Task 3: Daten-Provider für Bilanz & Erfolgsrechnung

**Files:**
- Modify: `sbs_projer_app/lib/presentation/providers/buchhaltung_providers.dart`

**Kontext:** Beide Provider laden alle Buchungen (`BuchungRepository.getAll()`) + Konten (`KontoRepository.getAll()`), mappen `Buchung`→`BuchungSaldo` und rufen die reinen Services. `Buchung` hat `datum, sollKonto, habenKonto, betragBrutto, istStorniert`. `Konto` hat `kontonummer, bezeichnung, kategorie`.

- [ ] **Step 1: Provider ergänzen**

```dart
// am Kopf von buchhaltung_providers.dart ergänzen:
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/data/repositories/konto_repository.dart';
import 'package:sbs_projer_app/services/buchhaltung/bilanz_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/erfolgsrechnung_service.dart';

List<BuchungSaldo> _toSaldoInput(List buchungen) => buchungen
    .map((b) => BuchungSaldo(
          sollKonto: b.sollKonto,
          habenKonto: b.habenKonto,
          betrag: b.betragBrutto,
          datum: b.datum,
          storniert: b.istStorniert,
        ))
    .toList();

/// Bilanz per 31.12. des gewählten Geschäftsjahrs.
final bilanzProvider = FutureProvider.family<BilanzDaten, int>((ref, jahr) async {
  final buchungen = await BuchungRepository.getAll();
  final konten = await KontoRepository.getAll();
  final saldi = BilanzService.saldiPerStichtag(
    _toSaldoInput(buchungen),
    DateTime(jahr, 12, 31),
  );
  final kontoInfos = konten
      .map((k) => KontoInfo(
            kontonummer: k.kontonummer,
            bezeichnung: k.bezeichnung,
            kategorie: k.kategorie ?? '—',
          ))
      .toList();
  return BilanzService.gruppiere(saldi, kontoInfos);
});

/// Erfolgsrechnung (Stufengliederung) für ein Geschäftsjahr.
final erfolgsrechnungStufenProvider =
    FutureProvider.family<ErfolgsrechnungDaten, int>((ref, jahr) async {
  final buchungen = await BuchungRepository.getAll();
  return ErfolgsrechnungService.berechne(
    _toSaldoInput(buchungen),
    von: DateTime(jahr, 1, 1),
    bis: DateTime(jahr, 12, 31),
  );
});
```

- [ ] **Step 2: Analyse**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze lib/presentation/providers/buchhaltung_providers.dart`
Expected: No issues. (Falls `Konto.kategorie` nicht-nullable ist, das `?? '—'` entfernen — vorher mit `grep -n "kategorie" lib/data/models/konto.dart` prüfen.)

- [ ] **Step 3: Commit**

```bash
git add sbs_projer_app/lib/presentation/providers/buchhaltung_providers.dart
git commit -m "feat(buchhaltung): Provider für Bilanz + Erfolgsrechnung-Stufengliederung"
```

---

## Task 4: Bilanz-Screen + Route + Dashboard-Tile

**Files:**
- Create: `sbs_projer_app/lib/presentation/screens/buchhaltung/bilanz_screen.dart`
- Modify: `sbs_projer_app/lib/core/config/router.dart` (Block `/buchhaltung`)
- Modify: `sbs_projer_app/lib/presentation/screens/buchhaltung/buchhaltung_dashboard_screen.dart`

- [ ] **Step 1: Screen erstellen**

```dart
// lib/presentation/screens/buchhaltung/bilanz_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/presentation/providers/buchhaltung_providers.dart';
import 'package:sbs_projer_app/services/buchhaltung/bilanz_service.dart';

class BilanzScreen extends ConsumerStatefulWidget {
  const BilanzScreen({super.key});
  @override
  ConsumerState<BilanzScreen> createState() => _BilanzScreenState();
}

class _BilanzScreenState extends ConsumerState<BilanzScreen> {
  int _jahr = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(bilanzProvider(_jahr));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bilanz'),
        actions: [
          TextButton(
            onPressed: _pickJahr,
            child: Text('$_jahr',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (b) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Per 31.12.$_jahr',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _seite('Aktiven', b.aktiven, b.totalAktiven),
            const SizedBox(height: 16),
            _seite('Passiven', b.passiven, b.totalPassiven),
            const SizedBox(height: 16),
            _differenz(b.differenz),
          ],
        ),
      ),
    );
  }

  Widget _seite(String titel, List<BilanzGruppe> gruppen, double total) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titel,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16)),
            const Divider(),
            for (final g in gruppen) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(g.titel,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              for (final p in g.posten) _zeile(p.bezeichnung, p.summe),
              _zeile('Total ${g.titel}', g.summe, fett: true),
            ],
            const Divider(),
            _zeile('Total $titel', total, fett: true),
          ],
        ),
      ),
    );
  }

  Widget _zeile(String label, double betrag, {bool fett = false}) {
    final style = TextStyle(
        fontWeight: fett ? FontWeight.w700 : FontWeight.w400,
        color: betrag < 0 ? AppColors.error : AppColors.textPrimary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: style)),
          Text('${betrag.toStringAsFixed(2)} CHF', style: style),
        ],
      ),
    );
  }

  Widget _differenz(double diff) {
    final ok = diff.abs() < 0.005;
    return Card(
      color: ok ? AppColors.success.withAlpha(25) : AppColors.error.withAlpha(25),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(ok ? 'Aktiven = Passiven ✓' : 'Differenz (nicht ausgeglichen)',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: ok ? AppColors.success : AppColors.error)),
            Text('${diff.toStringAsFixed(2)} CHF',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: ok ? AppColors.success : AppColors.error)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickJahr() async {
    final jetzt = DateTime.now().year;
    final jahr = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Geschäftsjahr'),
        children: [
          for (int j = jetzt; j >= 2019; j--)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, j),
              child: Text('$j'),
            ),
        ],
      ),
    );
    if (jahr != null) setState(() => _jahr = jahr);
  }
}
```

- [ ] **Step 2: Route registrieren**

In `lib/core/config/router.dart` im `/buchhaltung`-Block (nach der `berichte`-Route) ergänzen — und Import oben hinzufügen:

```dart
// Import oben bei den anderen buchhaltung-Screens:
import 'package:sbs_projer_app/presentation/screens/buchhaltung/bilanz_screen.dart';

// Route:
GoRoute(
  path: '/buchhaltung/bilanz',
  builder: (context, state) => const BilanzScreen(),
),
```

- [ ] **Step 3: Dashboard-Tile ergänzen**

In `buchhaltung_dashboard_screen.dart` bei den Navigations-Tiles (gleiche Bauart wie das bestehende „Berichte"-Tile; vorher mit `grep -n "berichte" lib/presentation/screens/buchhaltung/buchhaltung_dashboard_screen.dart` die genaue Stelle/Widget-Form finden) einen Eintrag hinzufügen, der nach `/buchhaltung/bilanz` navigiert, z. B.:

```dart
// Muster (an die dort vorhandene Tile-Struktur anpassen):
ListTile(
  leading: const Icon(Icons.balance),
  title: const Text('Bilanz'),
  subtitle: const Text('Aktiven & Passiven per Stichtag'),
  onTap: () => context.push('/buchhaltung/bilanz'),
),
```

- [ ] **Step 4: Analyse + App startet**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze lib/presentation/screens/buchhaltung/bilanz_screen.dart lib/core/config/router.dart lib/presentation/screens/buchhaltung/buchhaltung_dashboard_screen.dart`
Expected: No issues (außer evtl. vorbestehende info-Hinweise).

- [ ] **Step 5: Manuelle Verifikation (Browser)**

App starten (`flutter run -d edge`), `/buchhaltung` → Tile „Bilanz" → Jahr 2025 wählen. Erwartung: Aktiven/Passiven gruppiert, Total-Zeilen, Differenz-Karte. (Bei aktuell unausgeglichenem Test-Datenbestand darf eine Differenz erscheinen — die Gliederung muss stimmen.)

- [ ] **Step 6: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/buchhaltung/bilanz_screen.dart sbs_projer_app/lib/core/config/router.dart sbs_projer_app/lib/presentation/screens/buchhaltung/buchhaltung_dashboard_screen.dart
git commit -m "feat(ui): Bilanz-Screen (Aktiven/Passiven per Stichtag) + Route + Dashboard-Tile"
```

---

## Task 5: Erfolgsrechnung-Tab auf Stufengliederung umstellen

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/buchhaltung/berichte_screen.dart`

**Kontext:** Der bestehende `_ErfolgsrechnungTab` liest `erfolgsrechnungProvider(jahr)` (grobe DB-View `view_erfolgsrechnung`). Er wird auf `erfolgsrechnungStufenProvider(jahr)` umgestellt und zeigt die KMU-Stufen (BE1, BE2, EBITDA, EBIT, EBT, Jahresergebnis). Die bestehende `_SummenZeile`-Hilfe wird wiederverwendet. Der alte Provider/View bleibt unangetastet (kann später entfernt werden).

- [ ] **Step 1: Tab umstellen**

Im `_ErfolgsrechnungTab.build` (in `berichte_screen.dart`) den Provider + Body ersetzen. Vorher mit `grep -n "_ErfolgsrechnungTab\|erfolgsrechnungProvider\|_SummenZeile" lib/presentation/screens/buchhaltung/berichte_screen.dart` die genaue Struktur/Signatur (Jahr-Parameter, `_SummenZeile`-API) bestätigen, dann sinngemäss:

```dart
// Import oben ergänzen:
import 'package:sbs_projer_app/presentation/providers/buchhaltung_providers.dart';
// (erfolgsrechnungStufenProvider ist dort definiert)

// im build des Tabs:
final async = ref.watch(erfolgsrechnungStufenProvider(jahr));
return async.when(
  loading: () => const Center(child: CircularProgressIndicator()),
  error: (e, _) => Center(child: Text('Fehler: $e')),
  data: (er) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _SummenZeile('Nettoerlös (3)', er.nettoerloes),
              _SummenZeile('− Materialaufwand (4)', -er.materialaufwand),
              const Divider(),
              _SummenZeile('Bruttoergebnis 1', er.bruttoergebnis1, fett: true),
              _SummenZeile('− Personalaufwand (5)', -er.personalaufwand),
              const Divider(),
              _SummenZeile('Bruttoergebnis 2', er.bruttoergebnis2, fett: true),
              _SummenZeile('− Übriger Aufwand (6000–6700)', -er.uebrigerAufwand),
              const Divider(),
              _SummenZeile('EBITDA', er.ebitda, fett: true),
              _SummenZeile('− Abschreibungen (6800)', -er.abschreibungen),
              const Divider(),
              _SummenZeile('EBIT', er.ebit, fett: true),
              _SummenZeile('± Finanzerfolg (6900)', er.finanzerfolg),
              const Divider(),
              _SummenZeile('EBT (vor Steuern)', er.ebt, fett: true),
              _SummenZeile('± Betriebsfremd/a.o. (7/8000–8800)', er.nebenerfolg),
              _SummenZeile('− Direkte Steuern (8900)', -er.steuern),
              const Divider(thickness: 2),
              _SummenZeile('Jahresergebnis', er.jahresergebnis, fett: true),
            ],
          ),
        ),
      ),
    ],
  ),
);
```

Falls die bestehende `_SummenZeile` keinen `fett`-Parameter hat: entweder den Parameter dort ergänzen (Default `false`) oder im obigen Code weglassen. Mit dem grep aus Step 1 abklären.

- [ ] **Step 2: Analyse**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze lib/presentation/screens/buchhaltung/berichte_screen.dart`
Expected: No issues (außer evtl. vorbestehende info-Hinweise). Falls `erfolgsrechnungProvider` dadurch ungenutzt wird und eine Warnung kommt: Import/Provider belassen (von `_MwstTab`/anderen genutzt) bzw. ungenutzten Import entfernen.

- [ ] **Step 3: Manuelle Verifikation (Browser)**

`/buchhaltung/berichte` → Tab „Erfolgsrechnung", Jahr 2025: Stufen erscheinen (BE1/BE2/EBITDA/EBIT/EBT/Jahresergebnis). Plausibilität gegen Excel-Erfolgsrechnung (Gliederung identisch).

- [ ] **Step 4: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/buchhaltung/berichte_screen.dart
git commit -m "feat(ui): Erfolgsrechnung-Tab auf KMU-Stufengliederung umgestellt"
```

---

## Task 6: MWST-Vorschau verifizieren

**Files:**
- Read/prüfen: `sbs_projer_app/lib/presentation/providers/buchhaltung_providers.dart` (`mwstQuartalDetailProvider`)
- Read/prüfen: `sbs_projer_app/lib/presentation/screens/buchhaltung/berichte_screen.dart` (`_MwstTab`)

**Kontext:** MWST-Tab existiert bereits (Quartalsberechnung: Umsatz Σ 3400, Umsatzsteuer 2200, Vorsteuer 1170+1171, Zahllast). Diese Task ist **Verifikation**, kein Neubau — Design §5 verlangt nur die Vorschau, die vorhanden ist.

- [ ] **Step 1: Logik gegen Spec prüfen**

`grep -n "1170\|1171\|2200\|3400\|quartal" lib/presentation/providers/buchhaltung_providers.dart` und die Berechnung lesen. Prüfen:
- Umsatz = Σ Haben 3400 (Erlös) der Periode
- Umsatzsteuer = Σ Haben 2200
- Vorsteuer = Σ Soll 1170 + 1171
- Zahllast = Umsatzsteuer − Vorsteuer

Falls korrekt → keine Code-Änderung. Falls eine Ziffer falsch zugeordnet ist (z. B. Vorsteuer nur 1170), hier minimal korrigieren und committen.

- [ ] **Step 2: Manuelle Verifikation (Browser)**

`/buchhaltung/berichte` → Tab „MwSt", Jahr 2025, Quartal wählen. Zahlen plausibel (Zahllast = USt − VSt). Stimmt die Gliederung mit der Excel „K - MWST" bzw. den ESTV-Ziffern überein.

- [ ] **Step 3 (nur falls Korrektur nötig): Commit**

```bash
git add sbs_projer_app/lib/presentation/providers/buchhaltung_providers.dart
git commit -m "fix(buchhaltung): MWST-Vorschau Vorsteuer/Umsatzsteuer-Zuordnung korrigiert"
```

---

## Task 7: Abschluss-Verifikation

- [ ] **Step 1: Alle Tests + Analyse**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test && flutter analyze`
Expected: Alle Tests PASS (inkl. der neuen Bilanz-/ER-Tests); analyze ohne neue Errors/Warnings.

- [ ] **Step 2: Erfolgskriterien prüfen (gegen Design §8)**
  - Bilanz aus dem Journal berechenbar, Aktiven/Passiven + Differenz sichtbar ✔
  - Erfolgsrechnung in KMU-Stufengliederung (deckungsgleich Excel) ✔
  - MWST-Vorschau vorhanden/verifiziert ✔
  - Gliederung deckungsgleich mit Excel-Sheets (Voraussetzung Phase-1-Abgleich) ✔
  - Keine Regression (bestehende Screens/Tests) ✔

---

## Hinweise für die Umsetzung

- **Kein Deploy** in diesem Plan — reine Logik/Provider/Screen-Änderungen.
- **Performance:** `BuchungRepository.getAll()` lädt alle Buchungen (paginiert). Bei ~15k Buchungen vertretbar für die Auswertung; falls träge, später auf eine date-gefilterte Query / DB-View optimieren (YAGNI — erst messen).
- **Offene-Posten-Sicht (Debitoren/Kreditoren)** ist Phase **0c** — eigener Plan, nicht hier.
- **Kategorie-Normalisierung:** Die DB-Kontokategorien weichen leicht von der Excel-Gliederung ab (siehe ToDo „0b-Vorbereitung"). Für die Bilanz-Gruppierung sind die aktuellen Kategorien ausreichend (Aktiven/Passiven-Zuordnung stimmt); eine feinere Angleichung an die Excel-Untergruppen ist optional und kann folgen.
- **Folge-Pläne:** 0c (Offene Posten), dann Phase 1 (Excel-Import + camt-Abgleich).
```

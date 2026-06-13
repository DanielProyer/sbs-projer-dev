# MWST-korrekte Saldo-Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Jede Buchung bei der Saldo-Berechnung MWST-korrekt verteilen (netto auf Aufwand/Ertrag, MWST aufs Steuerkonto, brutto auf Bank/Debitor) — über eine gemeinsame Helper-Funktion, genutzt von Bilanz, Erfolgsrechnung und der Live-Saldo-Berechnung (Kontenplan/Dashboard).

**Architecture:** Reiner Dart-Helper `SaldoExpansion.apply` (unit-testbar, ohne Supabase). `BuchungSaldo` (in bilanz_service.dart) wird um optionale MWST-Felder erweitert (rückwärtskompatibel). Vier Verbraucher rufen denselben Helper: `BilanzService`, `ErfolgsrechnungService`, `BuchungService.getAllSaldi`, `BuchungService.getKontoSaldo`. Die anschließende Vorzeichen-/Gruppierungslogik bleibt unverändert.

**Tech Stack:** Flutter/Dart, Riverpod, Supabase, `flutter_test`. Spec: [MWST-Saldo-Expansion](../specs/2026-06-13-mwst-saldo-expansion-design.md). Flutter via `export PATH="$PATH:/c/flutter/bin"`.

**Klassifikation (zentral):** `mwst_konto` in Klasse 1 (1000–1999) = Vorsteuer (Soll-seitig); sonst (≥2000) = Umsatzsteuer (Haben-seitig). Beiträge als Roh-Saldo `Σ Soll − Σ Haben`:
- keine MWST (`mwstBetrag == 0` oder `mwstKonto == null`): soll +brutto, haben −brutto
- Vorsteuer: soll +netto, mwstKonto +mwst, haben −brutto
- Umsatzsteuer: soll +brutto, mwstKonto −mwst, haben −netto

---

## Task 1: SaldoExpansion-Helper (TDD)

**Files:**
- Create: `sbs_projer_app/lib/services/buchhaltung/saldo_expansion.dart`
- Test: `sbs_projer_app/test/saldo_expansion_test.dart`

- [ ] **Step 1: Failing Test schreiben**

```dart
// test/saldo_expansion_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/buchhaltung/saldo_expansion.dart';

void main() {
  test('ohne MWST: brutto auf Soll und Haben', () {
    final s = <int, double>{};
    SaldoExpansion.apply(s,
        sollKonto: 6200,
        habenKonto: 1020,
        mwstKonto: null,
        betragNetto: 100,
        mwstBetrag: 0,
        betragBrutto: 100);
    expect(s[6200], 100);
    expect(s[1020], -100);
  });

  test('Vorsteuer (mwstKonto 1171): Aufwand=netto, Vorsteuer=+mwst, Bank=-brutto', () {
    final s = <int, double>{};
    SaldoExpansion.apply(s,
        sollKonto: 6200,
        habenKonto: 1020,
        mwstKonto: 1171,
        betragNetto: 100,
        mwstBetrag: 8.1,
        betragBrutto: 108.1);
    expect(s[6200], 100);
    expect(s[1171], 8.1);
    expect(s[1020], -108.1);
  });

  test('Umsatzsteuer (mwstKonto 2200): Debitor=+brutto, USt=-mwst, Erlös=-netto', () {
    final s = <int, double>{};
    SaldoExpansion.apply(s,
        sollKonto: 1100,
        habenKonto: 3400,
        mwstKonto: 2200,
        betragNetto: 87,
        mwstBetrag: 7.05,
        betragBrutto: 94.05);
    expect(s[1100], 94.05);
    expect(s[2200], -7.05);
    expect(s[3400], -87);
  });

  test('akkumuliert in vorhandene Map', () {
    final s = <int, double>{1020: -50};
    SaldoExpansion.apply(s,
        sollKonto: 6200,
        habenKonto: 1020,
        mwstKonto: null,
        betragNetto: 30,
        mwstBetrag: 0,
        betragBrutto: 30);
    expect(s[1020], -80);
  });
}
```

- [ ] **Step 2: Test laufen lassen → FAIL**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test test/saldo_expansion_test.dart`
Expected: FAIL (`SaldoExpansion` undefiniert).

- [ ] **Step 3: Helper implementieren**

```dart
// lib/services/buchhaltung/saldo_expansion.dart

/// Verteilt eine Buchung MWST-korrekt auf die beteiligten Konten und trägt die
/// Beiträge als Roh-Saldo (Σ Soll − Σ Haben) in [saldi] ein.
///
/// Klassifikation: mwstKonto Klasse 1 (1000–1999) = Vorsteuer (Soll-seitig);
/// sonst (≥2000) = Umsatzsteuer (Haben-seitig).
class SaldoExpansion {
  static void apply(
    Map<int, double> saldi, {
    required int sollKonto,
    required int habenKonto,
    int? mwstKonto,
    required double betragNetto,
    required double mwstBetrag,
    required double betragBrutto,
  }) {
    void add(int k, double v) => saldi[k] = (saldi[k] ?? 0) + v;

    if (mwstBetrag == 0 || mwstKonto == null) {
      add(sollKonto, betragBrutto);
      add(habenKonto, -betragBrutto);
      return;
    }

    final istVorsteuer = mwstKonto ~/ 1000 == 1;
    if (istVorsteuer) {
      add(sollKonto, betragNetto);
      add(mwstKonto, mwstBetrag);
      add(habenKonto, -betragBrutto);
    } else {
      add(sollKonto, betragBrutto);
      add(mwstKonto, -mwstBetrag);
      add(habenKonto, -betragNetto);
    }
  }
}
```

- [ ] **Step 4: Test laufen lassen → PASS**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test test/saldo_expansion_test.dart`
Expected: PASS (4 Tests).

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/services/buchhaltung/saldo_expansion.dart sbs_projer_app/test/saldo_expansion_test.dart
git commit -m "feat(buchhaltung): SaldoExpansion-Helper (MWST-korrekte Verteilung) + Tests"
```

---

## Task 2: BuchungSaldo erweitern + BilanzService nutzt SaldoExpansion

**Files:**
- Modify: `sbs_projer_app/lib/services/buchhaltung/bilanz_service.dart`
- Test: `sbs_projer_app/test/bilanz_service_test.dart`

**Kontext:** `BuchungSaldo` hat aktuell `sollKonto, habenKonto, betrag, datum, storniert` (alle required). `betrag` = brutto. `saldiPerStichtag` macht heute `saldi[soll]+=betrag; saldi[haben]-=betrag`.

- [ ] **Step 1: Failing Test ergänzen** (neuer Test in `test/bilanz_service_test.dart`, im bestehenden `main()`)

Der Helper `_b` in der Testdatei hat die Signatur
`_b(int soll, int haben, double betrag, String datum, {bool storniert = false})`.
Füge einen zweiten Helper + Test hinzu:

```dart
// innerhalb von main(), zusätzlich:
  test('Einnahme mit MWST: Debitor=brutto (Aktiv), Umsatzsteuer 2200=mwst (Passiv)', () {
    final saldi = BilanzService.saldiPerStichtag(
      [
        BuchungSaldo(
          sollKonto: 1100,
          habenKonto: 3400,
          betrag: 94.05,
          datum: DateTime.parse('2025-02-01'),
          storniert: false,
          mwstKonto: 2200,
          betragNetto: 87.0,
          mwstBetrag: 7.05,
        ),
      ],
      DateTime.parse('2025-12-31'),
    );
    expect(saldi[1100], 94.05); // Debitor brutto
    expect(saldi[2200], -7.05); // Roh-Saldo Umsatzsteuer (vor Invertierung)
    expect(saldi[3400], -87.0); // Erlös netto

    final bilanz = BilanzService.gruppiere(saldi, [
      KontoInfo(kontonummer: 1100, bezeichnung: 'Debitoren', kategorie: 'Umlaufvermögen'),
      KontoInfo(kontonummer: 2200, bezeichnung: 'Umsatzsteuer', kategorie: 'Kurzfristiges Fremdkapital'),
    ]);
    expect(bilanz.aktiven.single.summe, 94.05);
    expect(bilanz.passiven.single.summe, 7.05); // invertiert → positiv
  });
```

- [ ] **Step 2: Test laufen lassen → FAIL (Kompilierfehler: BuchungSaldo kennt mwstKonto nicht)**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test test/bilanz_service_test.dart`
Expected: FAIL (benannte Parameter `mwstKonto`/`betragNetto`/`mwstBetrag` existieren nicht).

- [ ] **Step 3: BuchungSaldo erweitern + Import + saldiPerStichtag umstellen**

In `bilanz_service.dart` oben den Import ergänzen:
```dart
import 'saldo_expansion.dart';
```

`BuchungSaldo` um optionale Felder erweitern (Klasse ersetzen):
```dart
class BuchungSaldo {
  final int sollKonto;
  final int habenKonto;
  final double betrag; // betragBrutto
  final DateTime datum;
  final bool storniert;
  final int? mwstKonto;
  final double? betragNetto; // null → = betrag (brutto)
  final double mwstBetrag;
  const BuchungSaldo({
    required this.sollKonto,
    required this.habenKonto,
    required this.betrag,
    required this.datum,
    required this.storniert,
    this.mwstKonto,
    this.betragNetto,
    this.mwstBetrag = 0,
  });
}
```

`saldiPerStichtag` so ändern, dass sie den Helper nutzt (Schleifenkörper ersetzen):
```dart
  static Map<int, double> saldiPerStichtag(
      List<BuchungSaldo> buchungen, DateTime stichtag) {
    final saldi = <int, double>{};
    for (final b in buchungen) {
      if (b.storniert) continue;
      if (b.datum.isAfter(stichtag)) continue;
      SaldoExpansion.apply(
        saldi,
        sollKonto: b.sollKonto,
        habenKonto: b.habenKonto,
        mwstKonto: b.mwstKonto,
        betragNetto: b.betragNetto ?? b.betrag,
        mwstBetrag: b.mwstBetrag,
        betragBrutto: b.betrag,
      );
    }
    return saldi;
  }
```

- [ ] **Step 4: Test laufen lassen → PASS (alle Bilanz-Tests)**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test test/bilanz_service_test.dart`
Expected: PASS (bestehende MWST-freie Tests unverändert grün + neuer MWST-Test).

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/services/buchhaltung/bilanz_service.dart sbs_projer_app/test/bilanz_service_test.dart
git commit -m "feat(buchhaltung): BuchungSaldo+BilanzService MWST-Expansion"
```

---

## Task 3: ErfolgsrechnungService nutzt SaldoExpansion

**Files:**
- Modify: `sbs_projer_app/lib/services/buchhaltung/erfolgsrechnung_service.dart`
- Test: `sbs_projer_app/test/erfolgsrechnung_service_test.dart`

**Kontext:** `berechne` baut heute `shm` per `shm[soll]+=betrag; shm[haben]-=betrag`. Der Helper `_b` in der Testdatei erzeugt `BuchungSaldo` ohne MWST.

- [ ] **Step 1: Failing Test ergänzen** (in `test/erfolgsrechnung_service_test.dart`, im bestehenden `main()`)

```dart
  test('Erlös mit MWST: Nettoerlös = netto (nicht brutto)', () {
    final er = ErfolgsrechnungService.berechne(
      [
        BuchungSaldo(
          sollKonto: 1100,
          habenKonto: 3400,
          betrag: 94.05,
          datum: DateTime.parse('2025-02-01'),
          storniert: false,
          mwstKonto: 2200,
          betragNetto: 87.0,
          mwstBetrag: 7.05,
        ),
      ],
      von: DateTime.parse('2025-01-01'),
      bis: DateTime.parse('2025-12-31'),
    );
    expect(er.nettoerloes, 87.0);
  });
```

Hinweis: Die Testdatei importiert `BuchungSaldo` bereits via
`import 'package:sbs_projer_app/services/buchhaltung/bilanz_service.dart' show BuchungSaldo;` — der Konstruktor-Aufruf mit den neuen optionalen Feldern kompiliert nach Task 2.

- [ ] **Step 2: Test laufen lassen → FAIL**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test test/erfolgsrechnung_service_test.dart`
Expected: FAIL (`nettoerloes` == 94.05 statt 87.0, weil noch brutto verteilt wird).

- [ ] **Step 3: berechne auf SaldoExpansion umstellen**

In `erfolgsrechnung_service.dart` Import ergänzen:
```dart
import 'saldo_expansion.dart';
```
(Der bestehende `import 'bilanz_service.dart' show BuchungSaldo;` bleibt.)

Den Schleifenkörper in `berechne` ersetzen:
```dart
    final shm = <int, double>{};
    for (final b in buchungen) {
      if (b.storniert) continue;
      if (b.datum.isBefore(von) || b.datum.isAfter(bis)) continue;
      SaldoExpansion.apply(
        shm,
        sollKonto: b.sollKonto,
        habenKonto: b.habenKonto,
        mwstKonto: b.mwstKonto,
        betragNetto: b.betragNetto ?? b.betrag,
        mwstBetrag: b.mwstBetrag,
        betragBrutto: b.betrag,
      );
    }
```
(Der Rest von `berechne` — die `_aufwand`-Bereichssummen — bleibt unverändert.)

- [ ] **Step 4: Test laufen lassen → PASS**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test test/erfolgsrechnung_service_test.dart`
Expected: PASS (bestehende Tests grün + neuer MWST-Test).

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/services/buchhaltung/erfolgsrechnung_service.dart sbs_projer_app/test/erfolgsrechnung_service_test.dart
git commit -m "feat(buchhaltung): ErfolgsrechnungService MWST-Expansion"
```

---

## Task 4: BuchungService.getAllSaldi + getKontoSaldo (Live) MWST-korrekt

**Files:**
- Modify: `sbs_projer_app/lib/services/rechnung/buchung_service.dart`

**Kontext:** `getAllSaldi` liest per Raw-SQL `soll_konto, haben_konto, betrag_brutto, ist_storniert` und verteilt brutto/brutto, danach Vorzeichen-Umkehr für Klassen 2/3/8/9. `getKontoSaldo` nutzt `BuchungRepository.getByKonto` (das **nur** Zeilen mit dem Konto als Soll ODER Haben findet — verfehlt Zeilen, wo das Konto `mwst_konto` ist!). Deshalb wird `getKontoSaldo` auf `getAllSaldi` umgestellt (korrekt + DRY).

- [ ] **Step 1: getAllSaldi auf SaldoExpansion umstellen**

In `buchung_service.dart` Import ergänzen:
```dart
import 'package:sbs_projer_app/services/buchhaltung/saldo_expansion.dart';
```

`getAllSaldi` ersetzen:
```dart
  static Future<Map<int, double>> getAllSaldi() async {
    final rows = await SupabaseService.client
        .from('buchungen')
        .select('soll_konto, haben_konto, mwst_konto, betrag_netto, mwst_betrag, betrag_brutto, ist_storniert')
        .eq('user_id', SupabaseService.dataUserId);

    final saldi = <int, double>{};
    for (final row in rows) {
      if (row['ist_storniert'] == true) continue;
      final brutto = double.tryParse(row['betrag_brutto'].toString()) ?? 0;
      final netto = row['betrag_netto'] != null
          ? (double.tryParse(row['betrag_netto'].toString()) ?? brutto)
          : brutto;
      final mwst = double.tryParse(row['mwst_betrag']?.toString() ?? '0') ?? 0;
      SaldoExpansion.apply(
        saldi,
        sollKonto: row['soll_konto'] as int,
        habenKonto: row['haben_konto'] as int,
        mwstKonto: row['mwst_konto'] as int?,
        betragNetto: netto,
        mwstBetrag: mwst,
        betragBrutto: brutto,
      );
    }

    // Passiv-/Ertragskonten: Saldo umkehren
    for (final konto in saldi.keys.toList()) {
      final klasse = konto ~/ 1000;
      if (klasse == 2 || klasse == 3 || klasse == 8 || klasse == 9) {
        saldi[konto] = -(saldi[konto] ?? 0);
      }
    }

    return saldi;
  }
```

- [ ] **Step 2: getKontoSaldo auf getAllSaldi umstellen**

`getKontoSaldo` ersetzen:
```dart
  /// Saldo eines Kontos (inkl. MWST-Anteil, falls das Konto ein Steuerkonto ist).
  static Future<double> getKontoSaldo(int kontonummer) async {
    final saldi = await getAllSaldi();
    return saldi[kontonummer] ?? 0;
  }
```

- [ ] **Step 3: Analyse**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze lib/services/rechnung/buchung_service.dart`
Expected: No issues.

- [ ] **Step 4: Aufrufer kurz prüfen**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && grep -rn "getKontoSaldo\|getByKonto" lib/`
Erwartung: `getKontoSaldo`-Aufrufer funktionieren unverändert (gleiche Signatur). `BuchungRepository.getByKonto` wird weiterhin von der Buchungsliste (Filter nach Konto) genutzt — **nicht** anfassen; nur `getKontoSaldo` nutzt es nicht mehr.

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/services/rechnung/buchung_service.dart
git commit -m "fix(buchhaltung): getAllSaldi/getKontoSaldo MWST-korrekt (Live-Bug Kontenplan/Dashboard)"
```

---

## Task 5: Provider `_toSaldoInput` um MWST-Felder ergänzen

**Files:**
- Modify: `sbs_projer_app/lib/presentation/providers/buchhaltung_providers.dart`

**Kontext:** `_toSaldoInput(List<Buchung>)` mappt aktuell nur `sollKonto/habenKonto/betrag(=betragBrutto)/datum/storniert`. Das `Buchung`-Modell hat zusätzlich `mwstKonto` (int?), `betragNetto` (double), `mwstBetrag` (double).

- [ ] **Step 1: Mapping ergänzen**

In `buchhaltung_providers.dart` die Helper-Funktion `_toSaldoInput` erweitern:
```dart
List<BuchungSaldo> _toSaldoInput(List<Buchung> buchungen) => buchungen
    .map((b) => BuchungSaldo(
          sollKonto: b.sollKonto,
          habenKonto: b.habenKonto,
          betrag: b.betragBrutto,
          datum: b.datum,
          storniert: b.istStorniert,
          mwstKonto: b.mwstKonto,
          betragNetto: b.betragNetto,
          mwstBetrag: b.mwstBetrag,
        ))
    .toList();
```

- [ ] **Step 2: Analyse**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze lib/presentation/providers/buchhaltung_providers.dart`
Expected: No issues. (Falls `Buchung.betragNetto`/`mwstBetrag` nicht-nullable sind, passt das direkt; falls nullable, `?? 0` bzw. weglassen — vorher mit `grep -n "betragNetto\|mwstBetrag\|mwstKonto" lib/data/models/buchung.dart` prüfen.)

- [ ] **Step 3: Commit**

```bash
git add sbs_projer_app/lib/presentation/providers/buchhaltung_providers.dart
git commit -m "feat(buchhaltung): Bilanz/ER-Provider geben MWST-Felder an Saldo-Expansion"
```

---

## Task 6: Abschluss-Verifikation

- [ ] **Step 1: Alle Tests + Analyse**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test && flutter analyze`
Expected: Alle Tests PASS (inkl. neuem `saldo_expansion_test` + MWST-Tests in Bilanz/ER); analyze ohne neue Errors/Warnings.

- [ ] **Step 2: Erfolgskriterien prüfen (gegen Spec §6)**
  - Eine Helper-Quelle (`SaldoExpansion.apply`) wird von Bilanz, ER, getAllSaldi, getKontoSaldo genutzt ✔
  - Vorsteuer 1170/1171 (Soll-seitig) und Umsatzsteuer 2200 (Haben-seitig) akkumulieren korrekt ✔
  - Aufwand/Ertrag mit netto, Bank/Debitor mit brutto ✔
  - Bestehende MWST-freie Tests/Pfade unverändert ✔

---

## Hinweise für die Umsetzung
- **Kein DB-Schema-Change, kein Deploy.** Reine Logik-/Service-Änderung.
- **Reihenfolge wichtig:** Task 1 (Helper) zuerst, dann Task 2 (BuchungSaldo-Felder — davon hängen Task 3 & 5 ab).
- **Folge-Teil:** Teil 2 (Excel-Import 2019–Nov 2025 + Jahr-für-Jahr-Abgleich) baut auf der jetzt MWST-korrekten Saldo-/Bilanz-/ER-Berechnung auf — eigene Spec/Plan.

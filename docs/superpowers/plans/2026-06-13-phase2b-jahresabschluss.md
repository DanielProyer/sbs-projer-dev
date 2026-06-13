# Phase 2b – Jahresabschluss-Reconciliation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Die App-Bilanz zum Aufgehen bringen, indem das kumulierte Ergebnis (Klasse 3–8) berechnet und im Eigenkapital als Gewinnvortrag + Jahresergebnis gezeigt wird; die verschränkten historischen Abschlussbuchungen (2970/2980/9000/9100) werden zurückgenommen.

**Architecture:** `BilanzService` bekommt einen reinen Helper `kumuliertesErgebnis` + `gruppiere` nimmt den Ergebnis-Split (Vortrag/laufend) entgegen und hängt ihn ans Eigenkapital. `bilanzProvider` rechnet den Split über zwei Stichtage (31.12.jahr und 31.12.(jahr−1)). Eine Migration storniert die Abschlussbuchungen. ER bleibt unberührt (Storno-Buchungen liegen außerhalb der ER-Bereiche). Kein Deploy.

**Tech Stack:** Flutter/Dart, Riverpod, Supabase MCP (project_id `pltbaqqwpnmdajwgnhpd`), `flutter_test`. Spec: [Phase-2b](../specs/2026-06-13-phase2b-jahresabschluss-design.md). Flutter via `export PATH="$PATH:/c/flutter/bin"`. Daniel `user_id=1e1ec2dd-7836-4d8e-8256-c5649d994ee2`.

---

## Task 1: BilanzService – kumuliertesErgebnis + gruppiere-Split (TDD)

**Files:**
- Modify: `sbs_projer_app/lib/services/buchhaltung/bilanz_service.dart`
- Test: `sbs_projer_app/test/bilanz_service_test.dart`

**Kontext:** `gruppiere(Map<int,double> saldi, List<KontoInfo> konten)` baut Aktiven (Kategorie Umlauf-/Anlagevermögen) und Passiven (Kurzfristiges/Langfristiges FK, Eigenkapital) via `postenFuer`; die `Eigenkapital`-Gruppe entsteht in der `_passivGruppen.forEach`-Schleife.

- [ ] **Step 1: Failing Tests ergänzen** (in `test/bilanz_service_test.dart`, im bestehenden `main()`)

```dart
  test('kumuliertesErgebnis: Ertrag (Kl.3) minus Aufwand (Kl.4-8) = Gewinn', () {
    // Roh-Saldo Soll-Haben: Ertrag 3400 credit (-1000), Aufwand 5000 debit (+300), 8900 debit (+20)
    final saldi = {3400: -1000.0, 5000: 300.0, 8900: 20.0, 1020: 680.0};
    expect(BilanzService.kumuliertesErgebnis(saldi), 680.0); // -(-1000+300+20)
  });

  test('kumuliertesErgebnis ignoriert Klasse 1/2/9', () {
    final saldi = {1020: 500.0, 2000: -200.0, 9000: 999.0};
    expect(BilanzService.kumuliertesErgebnis(saldi), 0.0);
  });

  test('gruppiere mit Vortrag+Jahresergebnis hängt EK-Posten an und balanciert', () {
    // Aktiv 1020 = 83118 (debit); EK-Konto 2800 = 20000 (credit, raw -20000)
    final saldi = {1020: 83118.0, 2800: -20000.0};
    final bilanz = BilanzService.gruppiere(
      saldi,
      [
        KontoInfo(kontonummer: 1020, bezeichnung: 'Bank', kategorie: 'Umlaufvermögen'),
        KontoInfo(kontonummer: 2800, bezeichnung: 'Eigenkapital', kategorie: 'Eigenkapital'),
      ],
      gewinnvortrag: 35319.11,
      jahresergebnis: 27798.89,
    );
    final ek = bilanz.passiven.firstWhere((g) => g.titel == 'Eigenkapital');
    expect(ek.posten.any((p) => p.bezeichnung == 'Gewinn-/Verlustvortrag' && p.summe == 35319.11), isTrue);
    expect(ek.posten.any((p) => p.bezeichnung == 'Jahresergebnis' && p.summe == 27798.89), isTrue);
    expect(bilanz.totalAktiven, 83118.0);
    expect(bilanz.totalPassiven, 83118.0); // 20000 + 35319.11 + 27798.89
    expect(bilanz.differenz.abs() < 0.005, isTrue);
  });

  test('gruppiere ohne Split (Default 0) erzeugt keine Ergebnis-Posten', () {
    final saldi = {1020: 100.0, 2800: -100.0};
    final bilanz = BilanzService.gruppiere(saldi, [
      KontoInfo(kontonummer: 1020, bezeichnung: 'Bank', kategorie: 'Umlaufvermögen'),
      KontoInfo(kontonummer: 2800, bezeichnung: 'EK', kategorie: 'Eigenkapital'),
    ]);
    final ek = bilanz.passiven.firstWhere((g) => g.titel == 'Eigenkapital');
    expect(ek.posten.length, 1); // nur 2800
  });
```

- [ ] **Step 2: Tests → FAIL**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test test/bilanz_service_test.dart`
Expected: FAIL (`kumuliertesErgebnis` fehlt; `gruppiere` kennt `gewinnvortrag`/`jahresergebnis` nicht).

- [ ] **Step 3: Implementieren**

In `bilanz_service.dart` der Klasse `BilanzService` hinzufügen:
```dart
  /// Kumuliertes Ergebnis = −Σ Roh-Saldo der Erfolgskonten (Klasse 3–8). Gewinn positiv.
  static double kumuliertesErgebnis(Map<int, double> saldi) {
    double s = 0;
    saldi.forEach((konto, v) {
      final kl = konto ~/ 1000;
      if (kl >= 3 && kl <= 8) s += v;
    });
    return -s;
  }
```

`gruppiere`-Signatur + Eigenkapital-Anhang ändern:
```dart
  static BilanzDaten gruppiere(
    Map<int, double> saldi,
    List<KontoInfo> konten, {
    double gewinnvortrag = 0,
    double jahresergebnis = 0,
  }) {
    // ... (byNr, postenFuer, aktiven unverändert) ...

    final passiven = <BilanzGruppe>[];
    _passivGruppen.forEach((titel, kategorien) {
      final posten = postenFuer((k) => kategorien.contains(k), invertieren: true);
      if (titel == 'Eigenkapital') {
        if (gewinnvortrag != 0) {
          posten.add(BilanzPosten(2970, 'Gewinn-/Verlustvortrag', gewinnvortrag));
        }
        if (jahresergebnis != 0) {
          posten.add(BilanzPosten(2980, 'Jahresergebnis', jahresergebnis));
        }
      }
      if (posten.isNotEmpty) passiven.add(BilanzGruppe(titel, posten));
    });

    return BilanzDaten(aktiven, passiven);
  }
```
(Nur die Passiven-Schleife + Signatur ändern; `aktiven`/`postenFuer`/Value-Klassen bleiben.)

- [ ] **Step 4: Tests → PASS**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test test/bilanz_service_test.dart`
Expected: PASS (alle bestehenden + 4 neue). Der bestehende „Einnahme mit MWST"-Test bleibt grün (er ruft `gruppiere` ohne Split → keine Ergebnis-Posten).

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/services/buchhaltung/bilanz_service.dart sbs_projer_app/test/bilanz_service_test.dart
git commit -m "feat(buchhaltung): BilanzService kumuliertesErgebnis + Eigenkapital-Split"
```

---

## Task 2: bilanzProvider – Zwei-Stichtag-Split

**Files:**
- Modify: `sbs_projer_app/lib/presentation/providers/buchhaltung_providers.dart`

**Kontext:** `bilanzProvider` lädt heute Buchungen+Konten, ruft `saldiPerStichtag(_toSaldoInput(buchungen), DateTime(jahr,12,31))` und `gruppiere(saldi, kontoInfos)`.

- [ ] **Step 1: Provider erweitern**

`bilanzProvider` so anpassen:
```dart
final bilanzProvider = FutureProvider.family<BilanzDaten, int>((ref, jahr) async {
  final buchungen = await BuchungRepository.getAll();
  final konten = await KontoRepository.getAll();
  final input = _toSaldoInput(buchungen);

  final saldiBis = BilanzService.saldiPerStichtag(input, DateTime(jahr, 12, 31));
  final saldiVor = BilanzService.saldiPerStichtag(input, DateTime(jahr - 1, 12, 31));
  final resBis = BilanzService.kumuliertesErgebnis(saldiBis);
  final resVor = BilanzService.kumuliertesErgebnis(saldiVor);

  final kontoInfos = konten
      .map((k) => KontoInfo(
            kontonummer: k.kontonummer,
            bezeichnung: k.bezeichnung,
            kategorie: k.kategorie ?? '—',
          ))
      .toList();
  return BilanzService.gruppiere(
    saldiBis,
    kontoInfos,
    gewinnvortrag: resVor,
    jahresergebnis: resBis - resVor,
  );
});
```

- [ ] **Step 2: Analyse**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze lib/presentation/providers/buchhaltung_providers.dart`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add sbs_projer_app/lib/presentation/providers/buchhaltung_providers.dart
git commit -m "feat(buchhaltung): bilanzProvider rechnet Ergebnis-Split (Vortrag/laufend)"
```

---

## Task 3: Migration 094 – Abschlussbuchungen stornieren

**Files:**
- Create: `Datenbank/migrations/094_abschlussbuchungen_storno.sql`

- [ ] **Step 1: Ist-Stand erfassen (Referenz)**

Via `mcp__supabase__execute_sql`:
```sql
SELECT count(*) AS abschluss_buchungen,
       count(*) FILTER (WHERE soll_konto=2800 OR haben_konto=2800) AS stammkapital_betroffen
FROM buchungen
WHERE user_id='1e1ec2dd-7836-4d8e-8256-c5649d994ee2' AND datum<'2025-12-01' AND NOT ist_storniert
  AND (soll_konto IN (2970,2980,9000,9100) OR haben_konto IN (2970,2980,9000,9100));
```
Erwartung: `abschluss_buchungen` ≈ 14; `stammkapital_betroffen = 0` (Storno fasst 2800 NICHT an).

- [ ] **Step 2: Migration schreiben**

```sql
-- 094_abschlussbuchungen_storno.sql
-- Phase 2b (Modell 2): historische Abschluss-/Vortrags-Buchungen zurücknehmen.
-- Das Ergebnis wird künftig vom BilanzService berechnet (Klasse 3–8) und im EK gezeigt.
-- 2800 Stammkapital bleibt unberührt (nicht in der WHERE-Menge).
UPDATE buchungen
   SET ist_storniert = true,
       notizen = trim(both ' |' from coalesce(notizen,'') || ' | Phase2b: Re-Close (Ergebnis wird berechnet)')
 WHERE user_id='1e1ec2dd-7836-4d8e-8256-c5649d994ee2'
   AND datum < '2025-12-01'
   AND (soll_konto IN (2970,2980,9000,9100) OR haben_konto IN (2970,2980,9000,9100));
```

- [ ] **Step 3: Anwenden + verifizieren**

Anwenden via `mcp__supabase__apply_migration` (name `094_abschlussbuchungen_storno`), dann Saldo-Check (Roh-Saldo Soll−Haben, MWST-frei auf diesen Konten):
```sql
SELECT konto, round(sum(v)::numeric,2) AS roh_saldo FROM (
  SELECT soll_konto AS konto, betrag_brutto AS v FROM buchungen
    WHERE user_id='1e1ec2dd-7836-4d8e-8256-c5649d994ee2' AND NOT ist_storniert AND soll_konto IN (2970,2980,9000,9100)
  UNION ALL
  SELECT haben_konto, -betrag_brutto FROM buchungen
    WHERE user_id='1e1ec2dd-7836-4d8e-8256-c5649d994ee2' AND NOT ist_storniert AND haben_konto IN (2970,2980,9000,9100)
) t GROUP BY konto ORDER BY konto;
```
Expected: leeres Resultat oder alle Salden 0.00 (2970/2980/9000/9100 genullt). 2800-Saldo separat prüfen (muss 20'000 bleiben):
```sql
SELECT round(sum(CASE WHEN haben_konto=2800 THEN betrag_brutto WHEN soll_konto=2800 THEN -betrag_brutto END)::numeric,2) AS stammkapital
FROM buchungen WHERE (soll_konto=2800 OR haben_konto=2800) AND NOT ist_storniert;
```
Expected: `20000.00`.

- [ ] **Step 4: Commit**

```bash
git add Datenbank/migrations/094_abschlussbuchungen_storno.sql
git commit -m "fix(db): Phase 2b Abschlussbuchungen storniert (2970/2980/9000/9100 → 0)"
```

---

## Task 4: Abschluss-Verifikation (Bilanz geht auf, ER unverändert)

- [ ] **Step 1: Tests + Analyse**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test && flutter analyze`
Expected: Alle Tests PASS; analyze ohne neue Errors/Warnings.

- [ ] **Step 2: Bilanz-Differenz per Jahresende prüfen (SQL-Nachbau)**

Für 2024-12-31 (und stichprobenartig 2021/2022): Aktiven (Klasse 1, Anzeige) vs. FK (Klasse 2 ohne EK) + EK (2800 + kumuliertes Ergebnis bis Stichtag). Via `mcp__supabase__execute_sql` die MWST-expandierte Saldenrechnung (wie in `Datenbank/import/validate_import.py` / der Audit-Query) nutzen:
```sql
-- Vorlage: Roh-Saldo je Konto bis Stichtag (MWST-Expansion), dann
-- aktiv1 = Σ Klasse1; fk = -Σ(Klasse2 ohne 2800/2970/2980); ek = -Σ 2800 + ergebnis;
-- ergebnis = -Σ(Klasse3..8). differenz = aktiv1 - (fk + ek)  ->  muss ≈ 0 sein.
```
(Die konkrete Query analog zur bestehenden Audit-/Validate-Query bauen; Stichtag anpassen.)
Expected: |differenz| ≤ 0.05 für jedes geprüfte Jahresende.

- [ ] **Step 3: ER-Unverändertheit stichprobenartig** — Nettoerlös 3400 pro Jahr vor/nach Migration identisch (die Storno-Buchungen liegen außerhalb 3000–8999). Kurzer Vergleich gegen `Datenbank/import/diff_report.md`-Werte oder eine erneute Jahres-Summe.

- [ ] **Step 4: Audit-Screen** — „Abschluss-Rest"-Kategorie ist leer (9000/9100/2980 = 0). 1100/8900 bleiben (→ 2c).

- [ ] **Step 5: Erfolgskriterien (gegen Spec §6)**
  - Bilanz-Differenz ≈ 0 ✔
  - EK = Stammkapital + Vortrag + Jahresergebnis ✔
  - 2970/2980/9000/9100 = 0 ✔
  - ER pro Jahr unverändert ✔

---

## Hinweise für die Umsetzung
- **Prod-Schreibzugriff** (Storno-UPDATE) ist eng begrenzt + über `notizen`/`ist_storniert` markiert → reversibel (`ist_storniert=false` wo der Vermerk steht).
- **Reihenfolge:** Task 1 (Service) → 2 (Provider) → 3 (Daten) → 4 (Verifikation).
- **Folge:** 2c Debitoren-Abschreibung (Treuhänder) + negative Salden 2202/2273/8900.

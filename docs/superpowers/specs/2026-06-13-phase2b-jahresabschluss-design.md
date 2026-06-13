# Phase 2b – Jahresabschluss-Reconciliation (Modell 2) – Design

**Datum:** 2026-06-13 · **Status:** Spec zur Freigabe durch Daniel
**Übergeordnet:** Phase 2 (Aufräumen), Sub-Projekt 2b. Vorher: 2a (Audit + mechanische Korrekturen). Folge: 2c (Debitoren-Abschreibung, mit Treuhänder).

---

## 1. Problem (aus der Analyse)

Die App-Bilanz geht **nicht auf** (Differenz ≈ 27'799 per 30.11.2025). Ursache: die ER-Konten (Klasse 3–8) **laufen durch** (2019–2025) und werden nie ins Eigenkapital geschlossen (die App-ER filtert nach Datum statt über Abschlussbuchungen). Die Excel hat die Jahresergebnisse separat über **2980/9100** (2019–2020) bzw. **9000/2980** (2021–2024) gebucht — inkonsistent, mit dem Tippfehler-Konto 9100 — sodass **9000 (−76'289)** und **9100 (+40'970)** „hängen" und das kumulierte Ergebnis nur teilweise (35'319 von 63'118) im Eigenkapital steht.

**Rechnerisch (Roh-Salden Soll−Haben, per 30.11.2025):** Aktiven Klasse 1 = 133'163.75; FK = −50'045.75; Eigenkapital (2800/2970/2980) = −55'319.11; ER (3–8) = −63'118.00; Abschluss (9000/9100) = +35'319.11; Summe = 0 ✓. **Kumuliertes Ergebnis 2019–Nov 2025 = 63'118.00 Gewinn.**

## 2. Lösung (Modell 2: laufende ER + berechnetes Ergebnis im Eigenkapital)

Passend zur datumsgefilterten ER der App: die ER-Konten bleiben laufend; die Bilanz **berechnet** das Ergebnis und zeigt es im Eigenkapital — aufgeteilt in **Gewinn-/Verlustvortrag** (Vorjahre) + **Jahresergebnis** (laufendes Jahr). Die historischen Abschlussbuchungen werden zurückgenommen, damit nichts doppelt zählt.

### Teil A — `BilanzService`: Ergebnis ins Eigenkapital (Code)
- Neuer reiner Helper `BilanzService.kumuliertesErgebnis(Map<int,double> saldi)` = `−Σ(saldi[k] für Konto-Klasse 3..8)` (Roh-Saldo → Ergebnis; Gewinn positiv).
- `gruppiere(saldi, konten, {double gewinnvortrag = 0, double jahresergebnis = 0})`: hängt in die **Eigenkapital**-Gruppe zwei berechnete Posten an, wenn ≠ 0 — `BilanzPosten(2970, 'Gewinn-/Verlustvortrag', gewinnvortrag)` und `BilanzPosten(2980, 'Jahresergebnis', jahresergebnis)`. (Existiert keine Eigenkapital-Gruppe, wird sie erzeugt.)
- **Provider** `bilanzProvider(jahr)` berechnet den Split über zwei Stichtage:
  - `saldiBis = saldiPerStichtag(buchungen, 31.12.jahr)`, `resBis = kumuliertesErgebnis(saldiBis)`
  - `saldiVor = saldiPerStichtag(buchungen, 31.12.(jahr−1))`, `resVor = kumuliertesErgebnis(saldiVor)`
  - `gruppiere(saldiBis, konten, gewinnvortrag: resVor, jahresergebnis: resBis − resVor)`

Damit: Eigenkapital = Stammkapital 20'000 + Vortrag + Jahresergebnis = 20'000 + 63'118 = 83'118 → **Aktiven 133'164 = FK 50'046 + EK 83'118** → Bilanz geht auf.

### Teil B — Abschlussbuchungen zurücknehmen (Daten, Migration 094)
Alle Buchungen, die **2970/2980/9000/9100** berühren (die ~14 Abschluss-/Vortrags-Buchungen; **2800 Stammkapital bleibt unberührt**), werden auf `ist_storniert = true` gesetzt + `notizen`-Vermerk „Phase2b: Re-Close (Ergebnis wird berechnet)". Dadurch gehen 2970/2980/9000/9100 auf **0**; das Ergebnis lebt sauber in den laufenden ER-Konten. (9100→9010 entfällt — 9100 wird ohnehin genullt.)

## 3. Warum die ER unberührt bleibt
Die stornierten Buchungen liegen auf Klasse 2 (2970/2980) und Klasse 9 (9000/9100) — **außerhalb** der ER-Bereiche (3000–8999), die `ErfolgsrechnungService` summiert. Die Erfolgsrechnung pro Jahr ändert sich also nicht.

## 4. Komponenten / Architektur-Einheiten
- `BilanzService` (lib/services/buchhaltung/bilanz_service.dart): + `kumuliertesErgebnis`, `gruppiere` um `gewinnvortrag`/`jahresergebnis` erweitert (rückwärtskompatibel mit Default 0).
- `bilanzProvider` (buchhaltung_providers.dart): Zwei-Stichtag-Berechnung + Übergabe des Splits.
- Migration `Datenbank/migrations/094_abschlussbuchungen_storno.sql`.
- Tests: `test/bilanz_service_test.dart` (neuer Split-Test; bestehender MWST-Bilanz-Test wird angepasst, da nun eine Eigenkapital-Ergebniszeile dazukommt).

## 5. Tests (TDD)
- `kumuliertesErgebnis`: Ertrag (Klasse 3) − Aufwand (Klasse 4–8) → Gewinn positiv; nur Klasse 3–8 zählt (1/2/9 ignoriert).
- `gruppiere` mit `gewinnvortrag`/`jahresergebnis`: beide erscheinen als Eigenkapital-Posten; Bilanz balanciert im konstruierten Fall (Aktiven = Passiven inkl. EK-Ergebnis); bei 0 kein Zusatz-Posten.
- Bestehende Bilanz-/ER-Tests grün (MWST-Bilanz-Test angepasst).
- Verifikation (SQL, kein Unit-Test): nach Migration 094 Saldo 2970/2980/9000/9100 = 0; ER-Werte pro Jahr unverändert; Bilanz-Differenz ≈ 0.

## 6. Erfolgskriterien
- App-Bilanz-Differenz ≈ 0 (|≤0.05|) zu jedem Jahresende 2019–2025.
- Eigenkapital zeigt Stammkapital + Gewinnvortrag + Jahresergebnis; Summe = 20'000 + kumuliertes Ergebnis.
- 2970/2980/9000/9100 = 0; Audit listet keine „Abschluss-Reste" mehr.
- Erfolgsrechnung pro Jahr unverändert; alle Tests grün; kein Deploy.

## 7. Nicht im Scope
- Debitoren-Abschreibung (2c, Treuhänder).
- Negative Salden 2202/2273/8900 (separat in 2c prüfen).
- Echte Abschluss-Buchungen pro Jahr (Modell 1) — bewusst verworfen zugunsten der datumsgefilterten ER + berechnetem Ergebnis.

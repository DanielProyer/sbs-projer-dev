# Berichtswesen-Umbau Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bilanz & Erfolgsrechnung in einen 2-Tab-Screen mit frei wählbarem Stichtag/Zeitraum, professioneller Darstellung, aufklappbaren Konten-Übersichten und PDF-/Mail-Export bringen; MwSt-Abrechnung als eigenen Screen herauslösen.

**Architecture:** Reine, getestete Services (`BilanzService`/`ErfolgsrechnungService` + CHF-Format) liefern die Daten; neue Riverpod-Family-Provider mit `DateTime`/`Zeitraum`-Key; schlanke View-Widgets pro Tab; PDF via `pdf`/`printing`; Mail via neue Edge Function `send-pdf-mail` (Inline-PDF). Inkrementell: neue Provider werden additiv eingeführt, alte am Ende entfernt, damit jeder Commit kompiliert.

**Tech Stack:** Flutter, Riverpod, GoRouter, `pdf`/`printing`, `intl`, Supabase Edge Functions (Deno/Gmail API).

**Spec:** `docs/superpowers/specs/2026-06-18-berichtswesen-umbau-design.md`

**Arbeitsverzeichnis:** alle `flutter`-Befehle in `sbs_projer_app/` (vorher `export PATH="$PATH:/c/flutter/bin"`).

---

## Datei-Übersicht

**Neu:**
- `sbs_projer_app/lib/core/util/chf_format.dart` — Schweizer Betragsformat `1'234.55`
- `sbs_projer_app/lib/presentation/screens/buchhaltung/mwst_abrechnung_screen.dart` — MwSt-Quartalsansicht
- `sbs_projer_app/lib/presentation/screens/buchhaltung/widgets/bilanz_view.dart` — Bilanz-Darstellung (Tab)
- `sbs_projer_app/lib/presentation/screens/buchhaltung/widgets/erfolgsrechnung_view.dart` — ER-Scroll-Seite (Tab)
- `sbs_projer_app/lib/presentation/screens/buchhaltung/widgets/bericht_datum_picker.dart` — Stichtag-/Zeitraum-Picker
- `sbs_projer_app/lib/services/pdf/bericht_pdf_common.dart` — Firmenkopf/Helfer
- `sbs_projer_app/lib/services/pdf/bilanz_pdf_service.dart`
- `sbs_projer_app/lib/services/pdf/erfolgsrechnung_pdf_service.dart`
- `sbs_projer_app/lib/services/mail/bericht_mail_service.dart`
- `supabase/functions/send-pdf-mail/index.ts`
- Tests: `test/core/util/chf_format_test.dart`, `test/services/buchhaltung/er_kontenaufstellung_test.dart`, `test/services/buchhaltung/bilanz_erstelle_test.dart`

**Geändert:**
- `sbs_projer_app/lib/services/buchhaltung/erfolgsrechnung_service.dart` — `kontenAufstellung()` + Typen
- `sbs_projer_app/lib/services/buchhaltung/bilanz_service.dart` — `erstelle()`
- `sbs_projer_app/lib/presentation/providers/buchhaltung_providers.dart` — neue Provider + `Zeitraum`
- `sbs_projer_app/lib/presentation/screens/buchhaltung/berichte_screen.dart` — Umbau auf Tabs Bilanz|ER
- `sbs_projer_app/lib/core/config/router.dart` — Route `/buchhaltung/mwst`, `/buchhaltung/bilanz`→Redirect
- `sbs_projer_app/lib/presentation/screens/buchhaltung/buchhaltung_dashboard_screen.dart` — Kacheln

**Entfernt:**
- `sbs_projer_app/lib/presentation/screens/buchhaltung/bilanz_screen.dart`
- alte Provider `bilanzProvider(int)` / `erfolgsrechnungStufenProvider(int)`

---

## Task 1: CHF-Format-Helper

**Files:**
- Create: `sbs_projer_app/lib/core/util/chf_format.dart`
- Test: `sbs_projer_app/test/core/util/chf_format_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/core/util/chf_format_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/chf_format.dart';

void main() {
  test('formatiert mit Tausender-Apostroph und 2 Dezimalstellen', () {
    expect(chf(1234.5), "1'234.50");
    expect(chf(-1234.55), "-1'234.55");
    expect(chf(0), "0.00");
    expect(chf(1000000), "1'000'000.00");
    expect(chf(12.1), "12.10");
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd sbs_projer_app && flutter test test/core/util/chf_format_test.dart`
Expected: FAIL (Target of URI doesn't exist / `chf` undefined).

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/util/chf_format.dart
import 'package:intl/intl.dart';

final NumberFormat _fmt = NumberFormat('#,##0.00', 'en_US');

/// Schweizer Betragsformat: Tausender-Apostroph, 2 Dezimalstellen.
/// Beispiele: 1234.5 -> "1'234.50", -1234.55 -> "-1'234.55", 0 -> "0.00".
String chf(double v) => _fmt.format(v).replaceAll(',', "'");
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd sbs_projer_app && flutter test test/core/util/chf_format_test.dart`
Expected: PASS (5 expects).

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/core/util/chf_format.dart sbs_projer_app/test/core/util/chf_format_test.dart
git commit -m "feat(util): CHF-Betragsformat mit Tausender-Apostroph"
```

---

## Task 2: ErfolgsrechnungService.kontenAufstellung

**Files:**
- Modify: `sbs_projer_app/lib/services/buchhaltung/erfolgsrechnung_service.dart`
- Test: `sbs_projer_app/test/services/buchhaltung/er_kontenaufstellung_test.dart`

**Vorzeichen-Konvention:** Pro Konto `net = Soll−Haben` über den Zeitraum. Für Ertragsklassen (3, 7) wird `−net` als Summe gespeichert (Ertrag positiv), für Aufwandsklassen (4, 5, 6, 8) `net` (Aufwand positiv). Konten mit Summe 0 entfallen. Klassen nur 3–8, aufsteigend; Konten aufsteigend.

- [ ] **Step 1: Write the failing test**

```dart
// test/services/buchhaltung/er_kontenaufstellung_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/buchhaltung/bilanz_service.dart' show BuchungSaldo;
import 'package:sbs_projer_app/services/buchhaltung/erfolgsrechnung_service.dart';

BuchungSaldo b(int soll, int haben, double betrag, DateTime d) =>
    BuchungSaldo(sollKonto: soll, habenKonto: haben, betrag: betrag, datum: d, storniert: false);

void main() {
  final von = DateTime(2026, 1, 1);
  final bis = DateTime(2026, 12, 31);

  test('Ertragskonto 3400 erscheint positiv in Klasse 3', () {
    // Erlös: Soll Bank 1020 / Haben 3400 -> 3400 hat net = -1000 -> Anzeige +1000
    final a = ErfolgsrechnungService.kontenAufstellung(
        [b(1020, 3400, 1000, DateTime(2026, 3, 1))], von: von, bis: bis);
    final k3 = a.klassen.firstWhere((k) => k.klasse == 3);
    expect(k3.konten.single.nr, 3400);
    expect(k3.konten.single.summe, 1000);
    expect(k3.summe, 1000);
    expect(a.nettoerloes, 1000);
  });

  test('Aufwandkonto 4000 erscheint positiv in Klasse 4', () {
    // Aufwand: Soll 4000 / Haben Bank 1020 -> 4000 net = +500 -> Anzeige +500
    final a = ErfolgsrechnungService.kontenAufstellung(
        [b(4000, 1020, 500, DateTime(2026, 4, 1))], von: von, bis: bis);
    final k4 = a.klassen.firstWhere((k) => k.klasse == 4);
    expect(k4.konten.single.nr, 4000);
    expect(k4.konten.single.summe, 500);
  });

  test('Konten mit Summe 0 und Buchungen ausserhalb des Zeitraums fehlen', () {
    final a = ErfolgsrechnungService.kontenAufstellung([
      b(4000, 1020, 500, DateTime(2025, 12, 31)), // ausserhalb
    ], von: von, bis: bis);
    expect(a.klassen, isEmpty);
  });

  test('Klassen und Konten aufsteigend sortiert', () {
    final a = ErfolgsrechnungService.kontenAufstellung([
      b(5000, 1020, 100, DateTime(2026, 2, 1)),
      b(4000, 1020, 100, DateTime(2026, 2, 1)),
      b(4200, 1020, 100, DateTime(2026, 2, 1)),
    ], von: von, bis: bis);
    expect(a.klassen.map((k) => k.klasse).toList(), [4, 5]);
    expect(a.klassen.first.konten.map((k) => k.nr).toList(), [4000, 4200]);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd sbs_projer_app && flutter test test/services/buchhaltung/er_kontenaufstellung_test.dart`
Expected: FAIL (`kontenAufstellung`/`ErKlasse` undefined).

- [ ] **Step 3: Write minimal implementation** — am Ende von `erfolgsrechnung_service.dart` die Typen + Methode ergänzen (innerhalb der Datei, Klasse `ErfolgsrechnungService` erweitern):

```dart
// --- am Dateiende, NACH der bestehenden Klasse ErfolgsrechnungService die Typen ---
class ErKonto {
  final int nr;
  final String? bezeichnung; // im Service null, Provider füllt
  final double summe;
  const ErKonto(this.nr, this.summe, {this.bezeichnung});
  ErKonto withBezeichnung(String b) => ErKonto(nr, summe, bezeichnung: b);
}

class ErKlasse {
  final int klasse;
  final List<ErKonto> konten;
  const ErKlasse(this.klasse, this.konten);
  double get summe => konten.fold(0.0, (s, k) => s + k.summe);
}

class ErKontenAufstellung {
  final List<ErKlasse> klassen;
  const ErKontenAufstellung(this.klassen);
  double get nettoerloes {
    for (final k in klassen) {
      if (k.klasse == 3) return k.summe;
    }
    return 0;
  }
}
```

Und innerhalb der Klasse `ErfolgsrechnungService` (vor der schliessenden `}`) die Methode hinzufügen:

```dart
  /// Konten-Aufstellung je Klasse 3–8 über [von,bis]. Vorzeichen: Ertragsklassen
  /// (3,7) positiv = Ertrag (−Saldo), Aufwandsklassen (4,5,6,8) positiv = Aufwand.
  static ErKontenAufstellung kontenAufstellung(
    List<BuchungSaldo> buchungen, {
    required DateTime von,
    required DateTime bis,
  }) {
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

    final byKlasse = <int, List<ErKonto>>{};
    shm.forEach((nr, net) {
      final kl = nr ~/ 1000;
      if (kl < 3 || kl > 8) return;
      final ertragsklasse = kl == 3 || kl == 7;
      final summe = ertragsklasse ? -net : net;
      if (summe == 0) return;
      (byKlasse[kl] ??= []).add(ErKonto(nr, summe));
    });

    final klassen = <ErKlasse>[];
    for (final kl in [3, 4, 5, 6, 7, 8]) {
      final konten = byKlasse[kl];
      if (konten == null || konten.isEmpty) continue;
      konten.sort((a, b) => a.nr.compareTo(b.nr));
      klassen.add(ErKlasse(kl, konten));
    }
    return ErKontenAufstellung(klassen);
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd sbs_projer_app && flutter test test/services/buchhaltung/er_kontenaufstellung_test.dart`
Expected: PASS (4 Tests).

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/services/buchhaltung/erfolgsrechnung_service.dart sbs_projer_app/test/services/buchhaltung/er_kontenaufstellung_test.dart
git commit -m "feat(buchhaltung): ErfolgsrechnungService.kontenAufstellung (Klassen+Konten)"
```

---

## Task 3: BilanzService.erstelle (Stichtag-basiert, testbar)

**Files:**
- Modify: `sbs_projer_app/lib/services/buchhaltung/bilanz_service.dart`
- Test: `sbs_projer_app/test/services/buchhaltung/bilanz_erstelle_test.dart`

Kapselt die bisher im Provider liegende Logik (Saldi bis Stichtag + Vorjahr-Stichtag, kumuliertes Ergebnis, EK-Split) in einer reinen Methode.

- [ ] **Step 1: Write the failing test**

```dart
// test/services/buchhaltung/bilanz_erstelle_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/buchhaltung/bilanz_service.dart';

BuchungSaldo b(int soll, int haben, double betrag, DateTime d) =>
    BuchungSaldo(sollKonto: soll, habenKonto: haben, betrag: betrag, datum: d, storniert: false);

void main() {
  final konten = [
    const KontoInfo(kontonummer: 1020, bezeichnung: 'Bank', kategorie: 'Umlaufvermögen'),
    const KontoInfo(kontonummer: 2800, bezeichnung: 'Eigenkapital', kategorie: 'Eigenkapital'),
  ];

  test('Mitte-Jahr-Stichtag: EK-Split Vortrag + laufendes Ergebnis, Bilanz ausgeglichen', () {
    final buchungen = [
      // 2025: Ertrag 1000 (Bank/3400) -> Gewinnvortrag 1000 per 31.12.2025
      b(1020, 3400, 1000, DateTime(2025, 6, 1)),
      // 2026 bis 30.06: Ertrag 400 -> Jahresergebnis 400
      b(1020, 3400, 400, DateTime(2026, 3, 1)),
      // 2026 nach Stichtag: darf NICHT zählen
      b(1020, 3400, 999, DateTime(2026, 9, 1)),
    ];
    final daten = BilanzService.erstelle(buchungen, konten, DateTime(2026, 6, 30));

    // Aktiven = Bank 1400 (1000 + 400), Passiven = Vortrag 1000 + Jahresergebnis 400
    expect(daten.totalAktiven, closeTo(1400, 0.001));
    expect(daten.differenz.abs() < 0.005, isTrue);
    final ek = daten.passiven.firstWhere((g) => g.titel == 'Eigenkapital');
    final vortrag = ek.posten.firstWhere((p) => p.kontonummer == 2970).summe;
    final jahr = ek.posten.firstWhere((p) => p.kontonummer == 2980).summe;
    expect(vortrag, closeTo(1000, 0.001));
    expect(jahr, closeTo(400, 0.001));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd sbs_projer_app && flutter test test/services/buchhaltung/bilanz_erstelle_test.dart`
Expected: FAIL (`BilanzService.erstelle` undefined).

- [ ] **Step 3: Write minimal implementation** — innerhalb `class BilanzService` (z. B. nach `kumuliertesErgebnis`) ergänzen:

```dart
  /// Komplette Bilanz per [stichtag]: Saldi bis Stichtag + EK-Split aus
  /// kumuliertem Ergebnis (Gewinnvortrag bis 31.12. Vorjahr, Jahresergebnis
  /// Jahresbeginn–Stichtag). Reine Funktion (testbar).
  static BilanzDaten erstelle(
    List<BuchungSaldo> buchungen,
    List<KontoInfo> konten,
    DateTime stichtag,
  ) {
    final saldiBis = saldiPerStichtag(buchungen, stichtag);
    final saldiVor = saldiPerStichtag(buchungen, DateTime(stichtag.year - 1, 12, 31));
    final resBis = kumuliertesErgebnis(saldiBis);
    final resVor = kumuliertesErgebnis(saldiVor);
    return gruppiere(
      saldiBis,
      konten,
      gewinnvortrag: resVor,
      jahresergebnis: resBis - resVor,
    );
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd sbs_projer_app && flutter test test/services/buchhaltung/bilanz_erstelle_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/services/buchhaltung/bilanz_service.dart sbs_projer_app/test/services/buchhaltung/bilanz_erstelle_test.dart
git commit -m "feat(buchhaltung): BilanzService.erstelle (Stichtag + EK-Split)"
```

---

## Task 4: Neue Provider + Zeitraum-Typ (additiv)

**Files:**
- Modify: `sbs_projer_app/lib/presentation/providers/buchhaltung_providers.dart`

Neue Provider neben den bestehenden hinzufügen (alte bleiben bis Task 10). Imports `ErKlasse/ErKonto/ErKontenAufstellung` kommen aus `erfolgsrechnung_service.dart` (bereits importiert).

- [ ] **Step 1: Implementierung hinzufügen** — am Dateiende von `buchhaltung_providers.dart` ergänzen:

```dart
/// Zeitraum-Key für Erfolgsrechnungs-Provider (Wert-Gleichheit via Record).
typedef Zeitraum = ({DateTime von, DateTime bis});

/// Bilanz per beliebigem Stichtag (Datum-normalisiert vom Aufrufer).
final bilanzStichtagProvider =
    FutureProvider.family<BilanzDaten, DateTime>((ref, stichtag) async {
  final buchungen = await BuchungRepository.getAll();
  final konten = await KontoRepository.getAll();
  final infos = konten
      .map((k) => KontoInfo(
            kontonummer: k.kontonummer,
            bezeichnung: k.bezeichnung,
            kategorie: k.kategorie ?? '—',
          ))
      .toList();
  return BilanzService.erstelle(_toSaldoInput(buchungen), infos, stichtag);
});

/// Erfolgsrechnung (Stufengliederung) über einen Zeitraum.
final erfolgsrechnungZeitraumProvider =
    FutureProvider.family<ErfolgsrechnungDaten, Zeitraum>((ref, z) async {
  final buchungen = await BuchungRepository.getAll();
  return ErfolgsrechnungService.berechne(
    _toSaldoInput(buchungen),
    von: z.von,
    bis: z.bis,
  );
});

/// Konten-Aufstellung (Klassen + Konten) über einen Zeitraum, mit Bezeichnung.
final erKontenAufstellungProvider =
    FutureProvider.family<ErKontenAufstellung, Zeitraum>((ref, z) async {
  final buchungen = await BuchungRepository.getAll();
  final konten = await KontoRepository.getAll();
  final namen = {for (final k in konten) k.kontonummer: k.bezeichnung};
  final roh = ErfolgsrechnungService.kontenAufstellung(
      _toSaldoInput(buchungen), von: z.von, bis: z.bis);
  final klassen = roh.klassen
      .map((kl) => ErKlasse(
            kl.klasse,
            kl.konten
                .map((kt) => kt.withBezeichnung(namen[kt.nr] ?? '—'))
                .toList(),
          ))
      .toList();
  return ErKontenAufstellung(klassen);
});
```

- [ ] **Step 2: Verify analyze passes**

Run: `cd sbs_projer_app && flutter analyze lib/presentation/providers/buchhaltung_providers.dart`
Expected: "No issues found!" (ggf. nur Infos; keine Errors).

- [ ] **Step 3: Commit**

```bash
git add sbs_projer_app/lib/presentation/providers/buchhaltung_providers.dart
git commit -m "feat(buchhaltung): Provider bilanzStichtag/erfolgsrechnungZeitraum/erKontenAufstellung"
```

---

## Task 5: Datum-Picker-Widget

**Files:**
- Create: `sbs_projer_app/lib/presentation/screens/buchhaltung/widgets/bericht_datum_picker.dart`

Zwei zustandslose Steuerleisten: `StichtagPicker` (Bilanz) und `ZeitraumPicker` (ER), jeweils mit `onChanged`-Callback.

- [ ] **Step 1: Implementierung**

```dart
// lib/presentation/screens/buchhaltung/widgets/bericht_datum_picker.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/presentation/providers/buchhaltung_providers.dart';

final _df = DateFormat('dd.MM.yyyy');
DateTime _d(DateTime x) => DateTime(x.year, x.month, x.day);
const _monatNamen = ['', 'Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'];

/// Stichtag-Auswahl für die Bilanz: Presets + freie Datumswahl.
class StichtagPicker extends StatelessWidget {
  final DateTime stichtag;
  final ValueChanged<DateTime> onChanged;
  const StichtagPicker({super.key, required this.stichtag, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final jetzt = DateTime.now();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ActionChip(
            label: Text('Per 31.12.${jetzt.year - 1}'),
            onPressed: () => onChanged(DateTime(jetzt.year - 1, 12, 31)),
          ),
          ActionChip(
            label: const Text('Heute'),
            onPressed: () => onChanged(_d(jetzt)),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text(_df.format(stichtag)),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: stichtag,
                firstDate: DateTime(2019, 1, 1),
                lastDate: jetzt,
              );
              if (picked != null) onChanged(_d(picked));
            },
          ),
        ],
      ),
    );
  }
}

/// Zeitraum-Auswahl für die Erfolgsrechnung: Presets + freie von/bis-Wahl.
class ZeitraumPicker extends StatelessWidget {
  final Zeitraum zeitraum;
  final ValueChanged<Zeitraum> onChanged;
  const ZeitraumPicker({super.key, required this.zeitraum, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final jetzt = DateTime.now();
    final j = zeitraum.von.year;
    final q = ((zeitraum.von.month - 1) ~/ 3) + 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ActionChip(
            label: Text('Geschäftsjahr $j'),
            onPressed: () => onChanged((von: DateTime(j, 1, 1), bis: DateTime(j, 12, 31))),
          ),
          ActionChip(
            label: Text('Q$q $j'),
            onPressed: () {
              final start = DateTime(j, (q - 1) * 3 + 1, 1);
              final end = DateTime(j, q * 3 + 1, 0); // letzter Tag des Quartals
              onChanged((von: start, bis: end));
            },
          ),
          ActionChip(
            label: Text('${_monatNamen[zeitraum.von.month]} $j'),
            onPressed: () {
              final start = DateTime(j, zeitraum.von.month, 1);
              final end = DateTime(j, zeitraum.von.month + 1, 0);
              onChanged((von: start, bis: end));
            },
          ),
          ActionChip(
            label: const Text('YTD'),
            onPressed: () => onChanged((von: DateTime(jetzt.year, 1, 1), bis: _d(jetzt))),
          ),
          OutlinedButton(
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                initialDateRange: DateTimeRange(start: zeitraum.von, end: zeitraum.bis),
                firstDate: DateTime(2019, 1, 1),
                lastDate: jetzt,
              );
              if (picked != null) {
                onChanged((von: _d(picked.start), bis: _d(picked.end)));
              }
            },
            child: Text('${_df.format(zeitraum.von)} – ${_df.format(zeitraum.bis)}'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify analyze passes**

Run: `cd sbs_projer_app && flutter analyze lib/presentation/screens/buchhaltung/widgets/bericht_datum_picker.dart`
Expected: keine Errors.

- [ ] **Step 3: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/buchhaltung/widgets/bericht_datum_picker.dart
git commit -m "feat(buchhaltung): Stichtag-/Zeitraum-Picker-Widgets"
```

---

## Task 6: Bilanz-View-Widget

**Files:**
- Create: `sbs_projer_app/lib/presentation/screens/buchhaltung/widgets/bilanz_view.dart`

- [ ] **Step 1: Implementierung**

```dart
// lib/presentation/screens/buchhaltung/widgets/bilanz_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/chf_format.dart';
import 'package:sbs_projer_app/presentation/providers/buchhaltung_providers.dart';
import 'package:sbs_projer_app/services/buchhaltung/bilanz_service.dart';

class BilanzView extends ConsumerWidget {
  final DateTime stichtag;
  const BilanzView({super.key, required this.stichtag});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bilanzStichtagProvider(stichtag));
    final df = DateFormat('dd.MM.yyyy');
    final provisorisch = !stichtag.isBefore(DateTime(DateTime.now().year, 1, 1));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Fehler: $e')),
      data: (b) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Text('Bilanz per ${df.format(stichtag)}',
                  style: Theme.of(context).textTheme.titleMedium),
              if (provisorisch) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('provisorisch',
                      style: TextStyle(fontSize: 11, color: AppColors.warning)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _seite('Aktiven', b.aktiven, b.totalAktiven),
          const SizedBox(height: 16),
          _seite('Passiven', b.passiven, b.totalPassiven),
          const SizedBox(height: 16),
          _differenz(b.differenz),
        ],
      ),
    );
  }

  Widget _seite(String titel, List<BilanzGruppe> gruppen, double total) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const Divider(),
              for (final g in gruppen) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Text(g.titel, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                for (final p in g.posten)
                  _zeile('${p.kontonummer}  ${p.bezeichnung}', p.summe),
                _zeile('Total ${g.titel}', g.summe, fett: true),
              ],
              const Divider(thickness: 2),
              _zeile('Total $titel', total, fett: true),
            ],
          ),
        ),
      );

  Widget _zeile(String label, double betrag, {bool fett = false}) {
    final style = TextStyle(
        fontWeight: fett ? FontWeight.w700 : FontWeight.w400,
        color: betrag < 0 ? AppColors.error : AppColors.textPrimary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text('${chf(betrag)} CHF',
              style: style.copyWith(fontFeatures: const [], fontFamily: 'monospace')),
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
            Text('${chf(diff)} CHF',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: ok ? AppColors.success : AppColors.error)),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify analyze passes**

Run: `cd sbs_projer_app && flutter analyze lib/presentation/screens/buchhaltung/widgets/bilanz_view.dart`
Expected: keine Errors.

- [ ] **Step 3: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/buchhaltung/widgets/bilanz_view.dart
git commit -m "feat(buchhaltung): BilanzView-Widget (Stichtag, professionell, CHF-Format)"
```

---

## Task 7: Erfolgsrechnung-View-Widget (Scroll + aufklappbar)

**Files:**
- Create: `sbs_projer_app/lib/presentation/screens/buchhaltung/widgets/erfolgsrechnung_view.dart`

- [ ] **Step 1: Implementierung**

```dart
// lib/presentation/screens/buchhaltung/widgets/erfolgsrechnung_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/chf_format.dart';
import 'package:sbs_projer_app/presentation/providers/buchhaltung_providers.dart';
import 'package:sbs_projer_app/services/buchhaltung/erfolgsrechnung_service.dart';

class ErfolgsrechnungView extends ConsumerWidget {
  final Zeitraum zeitraum;
  const ErfolgsrechnungView({super.key, required this.zeitraum});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stufenAsync = ref.watch(erfolgsrechnungZeitraumProvider(zeitraum));
    final kontenAsync = ref.watch(erKontenAufstellungProvider(zeitraum));
    final df = DateFormat('dd.MM.yyyy');
    final titel = 'Erfolgsrechnung ${df.format(zeitraum.von)} – ${df.format(zeitraum.bis)}';

    return stufenAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Fehler: $e')),
      data: (er) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _stufenCard(context, titel, er),
          const SizedBox(height: 12),
          kontenAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => Text('Konten-Fehler: $e'),
            data: (auf) => Column(
              children: [
                _klassenCard(auf),
                const SizedBox(height: 12),
                _kontenCard(auf),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stufenCard(BuildContext context, String titel, ErfolgsrechnungDaten er) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titel, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              _z('Nettoerlös (3)', er.nettoerloes, AppColors.success),
              _z('− Materialaufwand (4)', -er.materialaufwand, AppColors.error),
              const Divider(),
              _z('Bruttoergebnis 1', er.bruttoergebnis1, _c(er.bruttoergebnis1), bold: true),
              _z('− Personalaufwand (5)', -er.personalaufwand, AppColors.error),
              const Divider(),
              _z('Bruttoergebnis 2', er.bruttoergebnis2, _c(er.bruttoergebnis2), bold: true),
              _z('− Übriger Aufwand (6000–6799)', -er.uebrigerAufwand, AppColors.error),
              const Divider(),
              _z('EBITDA', er.ebitda, _c(er.ebitda), bold: true),
              _z('− Abschreibungen (6800)', -er.abschreibungen, AppColors.error),
              const Divider(),
              _z('EBIT', er.ebit, _c(er.ebit), bold: true),
              _z('± Finanzerfolg (6900)', er.finanzerfolg, _c(er.finanzerfolg)),
              const Divider(),
              _z('EBT (vor Steuern)', er.ebt, _c(er.ebt), bold: true),
              _z('± Betriebsfremd/a.o. (7/8000–8800)', er.nebenerfolg, _c(er.nebenerfolg)),
              _z('− Direkte Steuern (8900)', -er.steuern, AppColors.error),
              const Divider(thickness: 2),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: BoxDecoration(
                  color: _c(er.jahresergebnis).withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: _z('Jahresergebnis', er.jahresergebnis, _c(er.jahresergebnis), bold: true),
              ),
            ],
          ),
        ),
      );

  Widget _klassenCard(ErKontenAufstellung auf) {
    final basis = auf.nettoerloes.abs();
    String pct(double v) => basis == 0 ? '' : '  (${(v / basis * 100).toStringAsFixed(0)}%)';
    return Card(
      child: ExpansionTile(
        title: const Text('Kontenklassen', style: TextStyle(fontWeight: FontWeight.w600)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          for (final kl in auf.klassen)
            _z('Klasse ${kl.klasse}${pct(kl.summe)}', kl.summe, AppColors.textPrimary),
        ],
      ),
    );
  }

  Widget _kontenCard(ErKontenAufstellung auf) => Card(
        child: ExpansionTile(
          title: const Text('Alle Konten', style: TextStyle(fontWeight: FontWeight.w600)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: [
            for (final kl in auf.klassen) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 2),
                child: Text('Klasse ${kl.klasse}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              for (final kt in kl.konten)
                _z('${kt.nr}  ${kt.bezeichnung ?? ''}', kt.summe, AppColors.textPrimary),
            ],
          ],
        ),
      );

  Color _c(double v) => v >= 0 ? AppColors.success : AppColors.error;

  Widget _z(String label, double betrag, Color color, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w400, fontSize: 14)),
            ),
            Text('${chf(betrag)} CHF',
                style: TextStyle(
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w600, fontSize: 14, color: color)),
          ],
        ),
      );
}
```

- [ ] **Step 2: Verify analyze passes**

Run: `cd sbs_projer_app && flutter analyze lib/presentation/screens/buchhaltung/widgets/erfolgsrechnung_view.dart`
Expected: keine Errors.

- [ ] **Step 3: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/buchhaltung/widgets/erfolgsrechnung_view.dart
git commit -m "feat(buchhaltung): ErfolgsrechnungView (Stufen + Klassen + Konten)"
```

---

## Task 8: MwSt-Abrechnung als eigener Screen

**Files:**
- Create: `sbs_projer_app/lib/presentation/screens/buchhaltung/mwst_abrechnung_screen.dart`

Inhalt = der heutige `_MwstTab` + Jahr-Picker, als eigenständiger Screen. CHF-Format übernehmen.

- [ ] **Step 1: Implementierung**

```dart
// lib/presentation/screens/buchhaltung/mwst_abrechnung_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/chf_format.dart';
import 'package:sbs_projer_app/presentation/providers/buchhaltung_providers.dart';

class MwstAbrechnungScreen extends ConsumerStatefulWidget {
  const MwstAbrechnungScreen({super.key});
  @override
  ConsumerState<MwstAbrechnungScreen> createState() => _MwstAbrechnungScreenState();
}

class _MwstAbrechnungScreenState extends ConsumerState<MwstAbrechnungScreen> {
  int _jahr = DateTime.now().year;
  late int _quartal = ((DateTime.now().month - 1) ~/ 3) + 1;

  static const _abgabefristen = {1: '31.05.', 2: '31.08.', 3: '30.11.', 4: '28.02.'};

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(mwstQuartalDetailProvider(_jahr));
    return Scaffold(
      appBar: AppBar(
        title: const Text('MwSt-Abrechnung'),
        actions: [
          TextButton(
            onPressed: _pickJahr,
            child: Text('$_jahr',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ],
      ),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (rows) {
          final sel = rows.firstWhere((r) => r['quartal'] == _quartal,
              orElse: () => <String, dynamic>{});
          final umsatz = _d(sel['umsatz']);
          final umsatzsteuer = _d(sel['umsatzsteuer']);
          final vstMaterial = _d(sel['vorsteuer_material']);
          final vstBetrieb = _d(sel['vorsteuer_betrieb']);
          final netto = _d(sel['netto_mwst_schuld']);
          final fristJahr = _quartal == 4 ? _jahr + 1 : _jahr;
          final frist = '${_abgabefristen[_quartal]}$fristJahr';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('Q1')),
                  ButtonSegment(value: 2, label: Text('Q2')),
                  ButtonSegment(value: 3, label: Text('Q3')),
                  ButtonSegment(value: 4, label: Text('Q4')),
                ],
                selected: {_quartal},
                onSelectionChanged: (s) => setState(() => _quartal = s.first),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Q$_quartal $_jahr',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      _z('Umsatz (Ziff. 200)', umsatz, AppColors.success),
                      _z('Umsatzsteuer (Ziff. 382)', umsatzsteuer, AppColors.error),
                      const SizedBox(height: 4),
                      _z('Vorsteuer Material (Ziff. 400)', vstMaterial, AppColors.success),
                      _z('Vorsteuer Betrieb (Ziff. 405)', vstBetrieb, AppColors.success),
                      const Divider(),
                      _z('Zu bezahlen (Ziff. 500)', netto,
                          netto > 0 ? AppColors.error : AppColors.success, bold: true),
                      const SizedBox(height: 8),
                      Text('Abgabefrist: $frist',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _pickJahr() {
    final jetzt = DateTime.now().year;
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Jahr wählen'),
        children: [
          for (int y = jetzt; y >= 2019; y--)
            SimpleDialogOption(
              onPressed: () {
                setState(() => _jahr = y);
                Navigator.pop(ctx);
              },
              child: Text('$y', style: TextStyle(fontWeight: y == _jahr ? FontWeight.w700 : null)),
            ),
        ],
      ),
    );
  }

  static double _d(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;

  Widget _z(String label, double betrag, Color color, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w400, fontSize: 14)),
            Text('${chf(betrag)} CHF',
                style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w600, fontSize: 14, color: color)),
          ],
        ),
      );
}
```

- [ ] **Step 2: Verify analyze passes**

Run: `cd sbs_projer_app && flutter analyze lib/presentation/screens/buchhaltung/mwst_abrechnung_screen.dart`
Expected: keine Errors.

- [ ] **Step 3: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/buchhaltung/mwst_abrechnung_screen.dart
git commit -m "feat(buchhaltung): MwSt-Abrechnung als eigener Screen"
```

---

## Task 9: BerichteScreen → Tabs Bilanz | Erfolgsrechnung

**Files:**
- Modify (komplett ersetzen): `sbs_projer_app/lib/presentation/screens/buchhaltung/berichte_screen.dart`

Ersetzt den kompletten Inhalt: 2 Tabs (Bilanz | ER), Datum-State, eingebettete Views + Picker. PDF/Mail-Actions kommen in Task 12/13 dazu (hier Platzhalter-freie Grundstruktur ohne diese Buttons).

- [ ] **Step 1: Datei komplett ersetzen**

```dart
// lib/presentation/screens/buchhaltung/berichte_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/presentation/providers/buchhaltung_providers.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/widgets/bericht_datum_picker.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/widgets/bilanz_view.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/widgets/erfolgsrechnung_view.dart';

class BerichteScreen extends ConsumerStatefulWidget {
  const BerichteScreen({super.key});
  @override
  ConsumerState<BerichteScreen> createState() => _BerichteScreenState();
}

class _BerichteScreenState extends ConsumerState<BerichteScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  DateTime _stichtag = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  Zeitraum _zeitraum = (von: DateTime(DateTime.now().year, 1, 1), bis: DateTime(DateTime.now().year, 12, 31));

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bilanz & Erfolgsrechnung'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [Tab(text: 'Bilanz'), Tab(text: 'Erfolgsrechnung')],
        ),
      ),
      body: Column(
        children: [
          AnimatedBuilder(
            animation: _tab,
            builder: (context, _) => _tab.index == 0
                ? StichtagPicker(
                    stichtag: _stichtag,
                    onChanged: (d) => setState(() => _stichtag = d),
                  )
                : ZeitraumPicker(
                    zeitraum: _zeitraum,
                    onChanged: (z) => setState(() => _zeitraum = z),
                  ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                BilanzView(stichtag: _stichtag),
                ErfolgsrechnungView(zeitraum: _zeitraum),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify analyze passes**

Run: `cd sbs_projer_app && flutter analyze lib/presentation/screens/buchhaltung/berichte_screen.dart`
Expected: keine Errors.

- [ ] **Step 3: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/buchhaltung/berichte_screen.dart
git commit -m "feat(buchhaltung): BerichteScreen = Tabs Bilanz | Erfolgsrechnung mit Datumswahl"
```

---

## Task 10: Router + Dashboard + Bilanz-Screen entfernen + alte Provider weg

**Files:**
- Modify: `sbs_projer_app/lib/core/config/router.dart`
- Modify: `sbs_projer_app/lib/presentation/screens/buchhaltung/buchhaltung_dashboard_screen.dart`
- Modify: `sbs_projer_app/lib/presentation/providers/buchhaltung_providers.dart`
- Delete: `sbs_projer_app/lib/presentation/screens/buchhaltung/bilanz_screen.dart`

- [ ] **Step 1: Router anpassen** — in `router.dart`:
  1. Import `bilanz_screen.dart` **entfernen** (Zeile 52) und Import für den neuen MwSt-Screen ergänzen:

```dart
import 'package:sbs_projer_app/presentation/screens/buchhaltung/mwst_abrechnung_screen.dart';
```

  2. Den Block für `/buchhaltung/bilanz` (Zeilen 438–441) ersetzen durch Redirect + neue MwSt-Route:

```dart
    GoRoute(
      path: '/buchhaltung/bilanz',
      redirect: (context, state) => '/buchhaltung/berichte',
    ),
    GoRoute(
      path: '/buchhaltung/mwst',
      builder: (context, state) => const MwstAbrechnungScreen(),
    ),
```

- [ ] **Step 2: Dashboard-Kacheln anpassen** — in `buchhaltung_dashboard_screen.dart` die „Berichte"- und „Bilanz"-Tiles (Zeilen ~126–137) ersetzen durch:

```dart
          _NavTile(
            icon: Icons.assessment,
            title: 'Bilanz & Erfolgsrechnung',
            subtitle: 'Bilanz & Erfolgsrechnung per Datum',
            onTap: () => context.push('/buchhaltung/berichte'),
          ),
          _NavTile(
            icon: Icons.account_balance,
            title: 'MwSt-Abrechnung',
            subtitle: 'Quartals-Abrechnung ESTV',
            onTap: () => context.push('/buchhaltung/mwst'),
          ),
```

- [ ] **Step 3: Alte Provider entfernen** — in `buchhaltung_providers.dart` die jetzt ungenutzten Provider `bilanzProvider` (family<BilanzDaten,int>, ~Zeilen 95–122) und `erfolgsrechnungStufenProvider` (family<ErfolgsrechnungDaten,int>, ~Zeilen 124–133) **löschen**. (`erfolgsrechnungProvider` aus der DB-View und `mwstAbrechnungProvider`/`mwstQuartalDetailProvider` bleiben.)

- [ ] **Step 4: Bilanz-Screen löschen**

```bash
git rm sbs_projer_app/lib/presentation/screens/buchhaltung/bilanz_screen.dart
```

- [ ] **Step 5: Voll-Analyse + alle Tests**

Run: `cd sbs_projer_app && flutter analyze && flutter test`
Expected: „No issues found!" (keine Errors); alle Tests grün. Falls `flutter analyze` einen verbliebenen Verweis auf `BilanzScreen` oder die alten Provider meldet, die Stelle entsprechend auf die neue Route/Provider umstellen.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(buchhaltung): Routen/Dashboard auf neue Screens, alten Bilanz-Screen + Provider entfernt"
```

---

## Task 11: PDF-Services (Bilanz + Erfolgsrechnung)

**Files:**
- Create: `sbs_projer_app/lib/services/pdf/bericht_pdf_common.dart`
- Create: `sbs_projer_app/lib/services/pdf/bilanz_pdf_service.dart`
- Create: `sbs_projer_app/lib/services/pdf/erfolgsrechnung_pdf_service.dart`

- [ ] **Step 1: Gemeinsamer Kopf/Helfer**

```dart
// lib/services/pdf/bericht_pdf_common.dart
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sbs_projer_app/core/util/chf_format.dart';

class BerichtPdfCommon {
  static const firma = 'SBS Projer GmbH';
  static const strasse = 'Via Rezia 8';
  static const ort = '7013 Domat/Ems';
  static const dunkel = PdfColor.fromInt(0xFF1A3A5C);

  static pw.Widget kopf(String titel, String periode) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(firma, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: dunkel)),
                pw.Text(strasse, style: const pw.TextStyle(fontSize: 9)),
                pw.Text(ort, style: const pw.TextStyle(fontSize: 9)),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text(titel, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.Text(periode, style: const pw.TextStyle(fontSize: 10)),
              ]),
            ],
          ),
          pw.Divider(color: dunkel, thickness: 1.5),
        ],
      );

  /// Betrags-Zeile (Label links, CHF rechts), optional fett / Linie oben.
  static pw.Widget zeile(String label, double betrag,
          {bool bold = false, bool linieOben = false, double indent = 0}) =>
      pw.Container(
        decoration: linieOben
            ? const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.5)))
            : null,
        padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Padding(
              padding: pw.EdgeInsets.only(left: indent),
              child: pw.Text(label,
                  style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
            ),
            pw.Text(chf(betrag),
                style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          ],
        ),
      );
}
```

- [ ] **Step 2: Bilanz-PDF (zweispaltig)**

```dart
// lib/services/pdf/bilanz_pdf_service.dart
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sbs_projer_app/services/buchhaltung/bilanz_service.dart';
import 'package:sbs_projer_app/services/pdf/bericht_pdf_common.dart';

class BilanzPdfService {
  static Future<Uint8List> generate(BilanzDaten b, DateTime stichtag) async {
    final pdf = pw.Document();
    final df = DateFormat('dd.MM.yyyy');

    pw.Widget seite(String titel, List<BilanzGruppe> gruppen, double total) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(titel, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            for (final g in gruppen) ...[
              pw.Text(g.titel, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              for (final p in g.posten)
                BerichtPdfCommon.zeile('${p.kontonummer}  ${p.bezeichnung}', p.summe, indent: 6),
              BerichtPdfCommon.zeile('Total ${g.titel}', g.summe, bold: true, linieOben: true),
              pw.SizedBox(height: 4),
            ],
            BerichtPdfCommon.zeile('Total $titel', total, bold: true, linieOben: true),
          ],
        );

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          BerichtPdfCommon.kopf('Bilanz', 'per ${df.format(stichtag)}'),
          pw.SizedBox(height: 16),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: seite('Aktiven', b.aktiven, b.totalAktiven)),
              pw.SizedBox(width: 24),
              pw.Expanded(child: seite('Passiven', b.passiven, b.totalPassiven)),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Divider(),
          BerichtPdfCommon.zeile(
            b.differenz.abs() < 0.005 ? 'Aktiven = Passiven' : 'Differenz',
            b.differenz,
            bold: true,
          ),
        ],
      ),
    ));
    return pdf.save();
  }
}
```

- [ ] **Step 3: Erfolgsrechnung-PDF (3 Ebenen, MultiPage)**

```dart
// lib/services/pdf/erfolgsrechnung_pdf_service.dart
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sbs_projer_app/presentation/providers/buchhaltung_providers.dart' show Zeitraum;
import 'package:sbs_projer_app/services/buchhaltung/erfolgsrechnung_service.dart';
import 'package:sbs_projer_app/services/pdf/bericht_pdf_common.dart';

class ErfolgsrechnungPdfService {
  static Future<Uint8List> generate(
    ErfolgsrechnungDaten er,
    ErKontenAufstellung konten,
    Zeitraum z,
  ) async {
    final pdf = pw.Document();
    final df = DateFormat('dd.MM.yyyy');
    final periode = '${df.format(z.von)} – ${df.format(z.bis)}';

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      header: (context) => context.pageNumber == 1
          ? BerichtPdfCommon.kopf('Erfolgsrechnung', periode)
          : pw.SizedBox(),
      build: (context) => [
        pw.SizedBox(height: 12),
        pw.Text('Stufengliederung', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        BerichtPdfCommon.zeile('Nettoerlös (3)', er.nettoerloes),
        BerichtPdfCommon.zeile('− Materialaufwand (4)', -er.materialaufwand),
        BerichtPdfCommon.zeile('Bruttoergebnis 1', er.bruttoergebnis1, bold: true, linieOben: true),
        BerichtPdfCommon.zeile('− Personalaufwand (5)', -er.personalaufwand),
        BerichtPdfCommon.zeile('Bruttoergebnis 2', er.bruttoergebnis2, bold: true, linieOben: true),
        BerichtPdfCommon.zeile('− Übriger Aufwand (6000–6799)', -er.uebrigerAufwand),
        BerichtPdfCommon.zeile('EBITDA', er.ebitda, bold: true, linieOben: true),
        BerichtPdfCommon.zeile('− Abschreibungen (6800)', -er.abschreibungen),
        BerichtPdfCommon.zeile('EBIT', er.ebit, bold: true, linieOben: true),
        BerichtPdfCommon.zeile('± Finanzerfolg (6900)', er.finanzerfolg),
        BerichtPdfCommon.zeile('EBT (vor Steuern)', er.ebt, bold: true, linieOben: true),
        BerichtPdfCommon.zeile('± Betriebsfremd/a.o.', er.nebenerfolg),
        BerichtPdfCommon.zeile('− Direkte Steuern (8900)', -er.steuern),
        BerichtPdfCommon.zeile('Jahresergebnis', er.jahresergebnis, bold: true, linieOben: true),
        pw.SizedBox(height: 16),
        pw.Text('Kontenklassen', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        for (final kl in konten.klassen)
          BerichtPdfCommon.zeile('Klasse ${kl.klasse}', kl.summe, bold: true),
        pw.SizedBox(height: 16),
        pw.Text('Konten', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        for (final kl in konten.klassen) ...[
          pw.SizedBox(height: 4),
          pw.Text('Klasse ${kl.klasse}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          for (final kt in kl.konten)
            BerichtPdfCommon.zeile('${kt.nr}  ${kt.bezeichnung ?? ''}', kt.summe, indent: 6),
        ],
      ],
    ));
    return pdf.save();
  }
}
```

- [ ] **Step 4: Verify analyze passes**

Run: `cd sbs_projer_app && flutter analyze lib/services/pdf/bericht_pdf_common.dart lib/services/pdf/bilanz_pdf_service.dart lib/services/pdf/erfolgsrechnung_pdf_service.dart`
Expected: keine Errors.

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/services/pdf/bericht_pdf_common.dart sbs_projer_app/lib/services/pdf/bilanz_pdf_service.dart sbs_projer_app/lib/services/pdf/erfolgsrechnung_pdf_service.dart
git commit -m "feat(pdf): Bilanz- und Erfolgsrechnungs-PDF-Services"
```

---

## Task 12: PDF-Button in BerichteScreen verdrahten

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/buchhaltung/berichte_screen.dart`

PDF des aktiven Tabs erzeugen und via `Printing.layoutPdf` anzeigen/teilen. Daten werden über `ref.read(...future)` geladen.

- [ ] **Step 1: Importe ergänzen** (oben in `berichte_screen.dart`):

```dart
import 'package:printing/printing.dart';
import 'package:sbs_projer_app/services/pdf/bilanz_pdf_service.dart';
import 'package:sbs_projer_app/services/pdf/erfolgsrechnung_pdf_service.dart';
```

- [ ] **Step 2: AppBar-Action + Methode** — in `AppBar(...)` `actions:` ergänzen und Methode in der State-Klasse hinzufügen:

```dart
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'PDF',
            onPressed: _pdf,
          ),
        ],
```

```dart
  Future<void> _pdf() async {
    try {
      if (_tab.index == 0) {
        final b = await ref.read(bilanzStichtagProvider(_stichtag).future);
        final bytes = await BilanzPdfService.generate(b, _stichtag);
        await Printing.layoutPdf(onLayout: (_) => bytes);
      } else {
        final er = await ref.read(erfolgsrechnungZeitraumProvider(_zeitraum).future);
        final konten = await ref.read(erKontenAufstellungProvider(_zeitraum).future);
        final bytes = await ErfolgsrechnungPdfService.generate(er, konten, _zeitraum);
        await Printing.layoutPdf(onLayout: (_) => bytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF-Fehler: $e')));
      }
    }
  }
```

- [ ] **Step 3: Verify analyze + run app smoke**

Run: `cd sbs_projer_app && flutter analyze lib/presentation/screens/buchhaltung/berichte_screen.dart`
Expected: keine Errors.

- [ ] **Step 4: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/buchhaltung/berichte_screen.dart
git commit -m "feat(buchhaltung): PDF-Export (Bilanz/ER) im Berichte-Screen"
```

---

## Task 13: Edge Function send-pdf-mail + Mail-Service + Mail-Button

**Files:**
- Create: `supabase/functions/send-pdf-mail/index.ts`
- Create: `sbs_projer_app/lib/services/mail/bericht_mail_service.dart`
- Modify: `sbs_projer_app/lib/presentation/screens/buchhaltung/berichte_screen.dart`

- [ ] **Step 1: Edge Function** (Gmail-Helfer aus `send-rechnung-mail` übernommen, Inline-PDF):

```ts
// supabase/functions/send-pdf-mail/index.ts
// Sendet eine E-Mail mit einem inline übergebenen PDF (base64) via Gmail API.
// Deploy: supabase functions deploy send-pdf-mail --no-verify-jwt
// Secrets: GMAIL_CLIENT_ID, GMAIL_CLIENT_SECRET, GMAIL_REFRESH_TOKEN

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const GMAIL_SENDER = "sbs.projer@gmail.com";

function bytesToBinary(bytes: Uint8Array): string {
  const chunks: string[] = [];
  for (let i = 0; i < bytes.length; i += 8192) {
    chunks.push(String.fromCharCode(...bytes.subarray(i, Math.min(i + 8192, bytes.length))));
  }
  return chunks.join("");
}
function base64url(input: string): string {
  return btoa(bytesToBinary(new TextEncoder().encode(input)))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
function b64ToBytes(b64: string): Uint8Array {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}
async function getGmailAccessToken(): Promise<string> {
  const clientId = Deno.env.get("GMAIL_CLIENT_ID");
  const clientSecret = Deno.env.get("GMAIL_CLIENT_SECRET");
  const refreshToken = Deno.env.get("GMAIL_REFRESH_TOKEN");
  if (!clientId || !clientSecret || !refreshToken) throw new Error("Gmail OAuth2 credentials not configured");
  const r = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ client_id: clientId, client_secret: clientSecret, refresh_token: refreshToken, grant_type: "refresh_token" }),
  });
  if (!r.ok) throw new Error(`OAuth2 token refresh failed (${r.status}): ${await r.text()}`);
  return (await r.json()).access_token;
}
function buildMime(to: string, subject: string, bodyText: string, filename: string, pdf: Uint8Array): string {
  const boundary = `b_${crypto.randomUUID().replace(/-/g, "")}`;
  const subjEnc = `=?UTF-8?B?${btoa(bytesToBinary(new TextEncoder().encode(subject)))}?=`;
  let mime = `From: ${GMAIL_SENDER}\r\nTo: ${to}\r\nSubject: ${subjEnc}\r\nMIME-Version: 1.0\r\n`;
  mime += `Content-Type: multipart/mixed; boundary="${boundary}"\r\n\r\n`;
  mime += `--${boundary}\r\nContent-Type: text/plain; charset=UTF-8\r\nContent-Transfer-Encoding: base64\r\n\r\n`;
  mime += btoa(bytesToBinary(new TextEncoder().encode(bodyText))) + `\r\n`;
  mime += `--${boundary}\r\nContent-Type: application/pdf; name="${filename}"\r\n`;
  mime += `Content-Disposition: attachment; filename="${filename}"\r\nContent-Transfer-Encoding: base64\r\n\r\n`;
  const b64 = btoa(bytesToBinary(pdf));
  for (let i = 0; i < b64.length; i += 76) mime += b64.slice(i, i + 76) + "\r\n";
  mime += `--${boundary}--\r\n`;
  return mime;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  try {
    const { to, subject, bodyText, filename, pdfBase64 } = await req.json();
    if (!to || !subject || !pdfBase64) {
      return new Response(JSON.stringify({ error: "to, subject, pdfBase64 required" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } });
    }
    const mime = buildMime(to, subject, bodyText ?? "Bericht im Anhang.", filename ?? "Bericht.pdf", b64ToBytes(pdfBase64));
    const token = await getGmailAccessToken();
    const resp = await fetch("https://gmail.googleapis.com/gmail/v1/users/me/messages/send", {
      method: "POST",
      headers: { "Authorization": `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify({ raw: base64url(mime) }),
    });
    if (!resp.ok) {
      return new Response(JSON.stringify({ error: `Gmail API error: ${resp.status}`, details: await resp.text() }),
        { status: 502, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } });
    }
    return new Response(JSON.stringify({ success: true, messageId: (await resp.json()).id }),
      { headers: { ...CORS_HEADERS, "Content-Type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: `Fehler: ${(e as Error).message}` }),
      { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } });
  }
});
```

- [ ] **Step 2: Deploy der Edge Function**

Run: `cd "D:/01_SBS_Projer_GmbH/00_Entwicklung/SBS Projer DEV" && npx supabase functions deploy send-pdf-mail --no-verify-jwt --project-ref pltbaqqwpnmdajwgnhpd`
Expected: „Deployed Function send-pdf-mail". (Secrets sind bereits vom bestehenden Mailversand gesetzt.)

- [ ] **Step 3: Mail-Service (Dart)**

```dart
// lib/services/mail/bericht_mail_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class BerichtMailService {
  /// Fixer Empfänger der Bericht-Mails.
  /// TODO(settings): später E-Mail des Geschäftsführers aus den Einstellungen.
  static const empfaenger = 'dani.proyer@gmail.com';

  static Future<void> send({
    required String subject,
    required String bodyText,
    required String filename,
    required Uint8List pdf,
  }) async {
    await SupabaseService.client.functions.invoke('send-pdf-mail', body: {
      'to': empfaenger,
      'subject': subject,
      'bodyText': bodyText,
      'filename': filename,
      'pdfBase64': base64Encode(pdf),
    });
  }
}
```

- [ ] **Step 4: Mail-Button im BerichteScreen** — Import ergänzen und zweite AppBar-Action + Methode hinzufügen:

```dart
import 'package:sbs_projer_app/services/mail/bericht_mail_service.dart';
```

In `actions:` vor dem PDF-IconButton ergänzen:

```dart
          IconButton(
            icon: const Icon(Icons.mail_outline),
            tooltip: 'Per Mail senden',
            onPressed: _mail,
          ),
```

Methode in der State-Klasse:

```dart
  Future<void> _mail() async {
    final istBilanz = _tab.index == 0;
    final was = istBilanz ? 'Bilanz' : 'Erfolgsrechnung';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$was senden'),
        content: Text('$was als PDF an ${BerichtMailService.empfaenger} senden?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Senden')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final Uint8List bytes;
      final String filename;
      if (istBilanz) {
        final b = await ref.read(bilanzStichtagProvider(_stichtag).future);
        bytes = await BilanzPdfService.generate(b, _stichtag);
        filename = 'Bilanz.pdf';
      } else {
        final er = await ref.read(erfolgsrechnungZeitraumProvider(_zeitraum).future);
        final konten = await ref.read(erKontenAufstellungProvider(_zeitraum).future);
        bytes = await ErfolgsrechnungPdfService.generate(er, konten, _zeitraum);
        filename = 'Erfolgsrechnung.pdf';
      }
      await BerichtMailService.send(
        subject: '$was SBS Projer GmbH',
        bodyText: 'Im Anhang die $was.\n\nSBS Projer GmbH',
        filename: filename,
        pdf: bytes,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$was gesendet an ${BerichtMailService.empfaenger}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Mail-Fehler: $e')));
      }
    }
  }
```

Dazu am Anfang von `berichte_screen.dart` `import 'dart:typed_data';` ergänzen.

- [ ] **Step 5: Verify analyze + alle Tests**

Run: `cd sbs_projer_app && flutter analyze && flutter test`
Expected: keine Errors; alle Tests grün.

- [ ] **Step 6: Commit**

```bash
git add supabase/functions/send-pdf-mail/index.ts sbs_projer_app/lib/services/mail/bericht_mail_service.dart sbs_projer_app/lib/presentation/screens/buchhaltung/berichte_screen.dart
git commit -m "feat(buchhaltung): Bericht-PDF per Mail (Edge Function send-pdf-mail)"
```

---

## Task 14: Gesamt-Verifikation + Deploy

**Files:** keine Code-Änderung (nur Build/Deploy).

- [ ] **Step 1: Voll-Analyse + Tests**

Run: `cd sbs_projer_app && flutter analyze && flutter test`
Expected: „No issues found!"; alle Tests grün.

- [ ] **Step 2: Manueller Klicktest (Web)**

Run: `cd sbs_projer_app && flutter run -d edge`
Prüfen: Dashboard → „Bilanz & Erfolgsrechnung" (2 Tabs, Datum-Presets + frei, Zahlen mit Apostroph, Bilanz-Check; ER aufklappbar Klassen/Konten; PDF-Button zeigt PDF; Mail-Button sendet an dani.proyer@gmail.com). Dashboard → „MwSt-Abrechnung" (Quartalsansicht). Alte URL `/buchhaltung/bilanz` leitet auf den kombinierten Screen um.

- [ ] **Step 3: Version bump + Deploy** (gemäss `CLAUDE.md` Deployment-Abschnitt)

`pubspec.yaml` Zeile 4 Version erhöhen, dann der dort dokumentierte gh-pages-Deploy-Ablauf. (Deploy erst nach Freigabe durch Daniel — separat bestätigen lassen.)

---

## Self-Review (vom Plan-Autor)

- **Spec-Abdeckung:** MwSt eigener Screen (T8/T10) ✓; Bilanz+ER in 2 Tabs (T9) ✓; Stichtag/Periode wählbar (T5/T9) ✓; professionelle Darstellung + CHF-Format (T1/T6/T7) ✓; ER Klassen+Konten aufklappbar (T2/T7) ✓; PDF Bilanz+ER alle 3 Ebenen (T11/T12) ✓; Mail an feste Adresse + Edge Function (T13) ✓; TODO-Marker für Settings (T13) ✓; Tests reine Services (T1/T2/T3) ✓.
- **Typ-Konsistenz:** `Zeitraum` = `({DateTime von, DateTime bis})` einheitlich (T4/T5/T7/T11/T12/T13); `ErKonto/ErKlasse/ErKontenAufstellung` (T2) konsistent genutzt (T4/T7/T11); `chf()` (T1) überall; `BilanzService.erstelle` (T3) im Provider (T4); `bilanzStichtagProvider`/`erfolgsrechnungZeitraumProvider`/`erKontenAufstellungProvider` einheitlich.
- **Reihenfolge/Kompilierbarkeit:** Provider additiv (T4), Screens danach (T6–T9), alte Provider/Screen erst nach Migration entfernt (T10) — jeder Commit kompiliert.

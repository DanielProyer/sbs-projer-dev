# Phase 2c – Abschreibungs-Werkzeug Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Debitoren jederzeit korrekt abschreiben (3805 netto + 2200 MWST-Rückholung / 1100, rückdatiert), historische Sammel-Abschreibung + Delkredere, MWST-Vorschau berücksichtigt die Rückholung, alles über einen Debitoren-Hub-Screen.

**Architecture:** Reiner Split-Helper + Buchungs-Service (`AbschreibungService`); `MahnwesenService.abschreiben` nutzt ihn; `mwstQuartalDetailProvider` rechnet über `SaldoExpansion`; neuer `DebitorenScreen` + Sammel-Abschreibung-Dialog. Kein DB-Schema-Change, kein Deploy.

**Tech Stack:** Flutter/Dart, Riverpod, Supabase MCP (project_id `pltbaqqwpnmdajwgnhpd`), `flutter_test`, go_router. Spec: [Phase-2c](../specs/2026-06-13-phase2c-abschreibungen-design.md). Flutter via `export PATH="$PATH:/c/flutter/bin"`. Daniel `user_id=1e1ec2dd-7836-4d8e-8256-c5649d994ee2`.

---

## Task 1: AbschreibungService.split (TDD)

**Files:**
- Create: `sbs_projer_app/lib/services/buchhaltung/abschreibung_service.dart`
- Test: `sbs_projer_app/test/abschreibung_service_test.dart`

- [ ] **Step 1: Failing Test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/buchhaltung/abschreibung_service.dart';

void main() {
  test('Split 8.1%: netto+mwst = brutto', () {
    final s = AbschreibungService.split(108.10, 8.1);
    expect(s.netto, 100.00);
    expect(s.mwst, 8.10);
  });
  test('Split 7.7%', () {
    final s = AbschreibungService.split(107.70, 7.7);
    expect(s.netto, 100.00);
    expect(s.mwst, 7.70);
  });
  test('Split ohne MWST (Satz 0)', () {
    final s = AbschreibungService.split(50.0, 0);
    expect(s.netto, 50.0);
    expect(s.mwst, 0.0);
  });
  test('mwst = brutto - netto (Residuum)', () {
    final s = AbschreibungService.split(94.05, 8.1);
    expect((s.netto + s.mwst - 94.05).abs() < 0.005, isTrue);
  });
}
```

- [ ] **Step 2: Test → FAIL**
Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test test/abschreibung_service_test.dart`

- [ ] **Step 3: Implementieren** (nur Split-Teil; Buchungsmethoden + deren Imports folgen in Task 2)

```dart
// lib/services/buchhaltung/abschreibung_service.dart
class AbschreibungSplit {
  final double netto;
  final double mwst;
  const AbschreibungSplit(this.netto, this.mwst);
}

class AbschreibungService {
  /// Netto/MWST aus Brutto + Satz (mwst = Residuum, keine Drift).
  static AbschreibungSplit split(double brutto, double satz) {
    if (satz <= 0) return AbschreibungSplit(brutto, 0);
    final netto = (brutto / (1 + satz / 100) * 100).roundToDouble() / 100;
    final mwst = ((brutto - netto) * 100).roundToDouble() / 100;
    return AbschreibungSplit(netto, mwst);
  }
}
```
(Keine Imports in Task 1 — `split` ist rein. Die Imports `buchung_service.dart`, `buchung_repository.dart`, `mwst_satz_service.dart` werden in Task 2 oben ergänzt.)

- [ ] **Step 4: Test → PASS (4)**
- [ ] **Step 5: Commit**
```bash
git add sbs_projer_app/lib/services/buchhaltung/abschreibung_service.dart sbs_projer_app/test/abschreibung_service_test.dart
git commit -m "feat(buchhaltung): AbschreibungService.split (Netto/MWST) + Tests"
```

---

## Task 2: AbschreibungService.abschreiben + delkredereSetzen (Buchung)

**Files:**
- Modify: `sbs_projer_app/lib/services/buchhaltung/abschreibung_service.dart`

**Kontext:** `BuchungRepository.create(Map)` setzt user_id selbst und gibt `Buchung` zurück (siehe bestehende Nutzer wie `BuchungService.createFromVorlage`). `MwstSatzService.satzFuerDatum(DateTime)` liefert 7.7/8.1. `BuchungService.getAllSaldi()` liefert Anzeige-Saldi (Map).

- [ ] **Step 1: Methoden ergänzen** (Imports oben ergänzen falls nötig)

```dart
  /// Schreibt einen Debitor-Brutto-Betrag ab: Soll 3805/Haben 1100 (netto)
  /// + Soll 2200/Haben 1100 (MWST-Rückholung), rückdatiert auf [datum].
  static Future<void> abschreiben({
    required double brutto,
    required DateTime datum,
    required String beschreibung,
    String? belegnummer,
    String? belegId,
  }) async {
    final satz = await MwstSatzService.satzFuerDatum(datum);
    final s = split(brutto, satz);
    final d = datum.toIso8601String().split('T').first;

    await BuchungRepository.create({
      'datum': d,
      'belegnummer': belegnummer,
      'soll_konto': 3805,
      'haben_konto': 1100,
      'betrag_netto': s.netto,
      'mwst_satz': 0,
      'mwst_betrag': 0,
      'betrag_brutto': s.netto,
      'beschreibung': beschreibung,
      'zahlungsweg': 'intern',
      'beleg_typ': 'abschreibung',
      'beleg_id': belegId,
      'geschaeftsjahr': datum.year,
      'notizen': 'Phase2c Abschreibung (netto)',
    });

    if (s.mwst > 0) {
      await BuchungRepository.create({
        'datum': d,
        'belegnummer': belegnummer,
        'soll_konto': 2200,
        'haben_konto': 1100,
        'betrag_netto': s.mwst,
        'mwst_satz': 0,
        'mwst_betrag': 0,
        'betrag_brutto': s.mwst,
        'beschreibung': '$beschreibung — MWST-Rückholung',
        'zahlungsweg': 'intern',
        'beleg_typ': 'abschreibung',
        'beleg_id': belegId,
        'geschaeftsjahr': datum.year,
        'notizen': 'Phase2c Abschreibung (MWST-Rückholung)',
      });
    }
  }

  /// Setzt das Delkredere (Konto 1109, Aktiv-Minus) auf [zielWertberichtigung]
  /// (positiv = gewünschte Wertberichtigung) durch Buchung der Differenz.
  static Future<void> delkredereSetzen({
    required double zielWertberichtigung,
    required DateTime datum,
  }) async {
    final saldi = await BuchungService.getAllSaldi();
    // 1109 ist Klasse 1 → Anzeige-Saldo = Roh (Soll−Haben). Wertberichtigung
    // (Haben-Überhang) erscheint als negativer Anzeige-Saldo.
    final aktuelleWb = -(saldi[1109] ?? 0);
    final diff = (zielWertberichtigung - aktuelleWb);
    final betrag = (diff.abs() * 100).roundToDouble() / 100;
    if (betrag < 0.01) return;
    final d = datum.toIso8601String().split('T').first;
    // diff > 0 → mehr Wertberichtigung bilden: Soll 3805 / Haben 1109
    // diff < 0 → auflösen: Soll 1109 / Haben 3805
    await BuchungRepository.create({
      'datum': d,
      'soll_konto': diff > 0 ? 3805 : 1109,
      'haben_konto': diff > 0 ? 1109 : 3805,
      'betrag_netto': betrag,
      'mwst_satz': 0,
      'mwst_betrag': 0,
      'betrag_brutto': betrag,
      'beschreibung': 'Delkredere-Anpassung (Ziel ${zielWertberichtigung.toStringAsFixed(2)})',
      'zahlungsweg': 'intern',
      'beleg_typ': 'abschreibung',
      'geschaeftsjahr': datum.year,
      'notizen': 'Phase2c Delkredere',
    });
  }
```

- [ ] **Step 2: Analyse**
Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze lib/services/buchhaltung/abschreibung_service.dart`
Expected: No issues. (Prüfen, dass `BuchungRepository.create` einen Map akzeptiert + `notizen`/`beleg_typ` gültige Spalten sind — vgl. bestehende Aufrufe in `buchung_service.dart`/`mahnwesen_service.dart`.)

- [ ] **Step 3: Commit**
```bash
git add sbs_projer_app/lib/services/buchhaltung/abschreibung_service.dart
git commit -m "feat(buchhaltung): AbschreibungService.abschreiben + delkredereSetzen (2-Buchungs-Logik)"
```

---

## Task 3: MahnwesenService.abschreiben auf AbschreibungService umstellen

**Files:**
- Modify: `sbs_projer_app/lib/services/rechnung/mahnwesen_service.dart`

**Kontext:** Aktuell (Zeilen ~123–149) bucht `abschreiben` Soll 3805/Haben 1100 für die ganze Brutto-Summe (falsch). `Rechnung` hat `betragBrutto`, `rechnungsdatum` (DateTime), `rechnungsnummer`, `id`.

- [ ] **Step 1: Methode ersetzen**

```dart
  /// Rechnung abschreiben + Debitorenverlust korrekt buchen (netto + MWST-Rückholung).
  static Future<void> abschreiben(Rechnung rechnung) async {
    await RechnungRepository.update(rechnung.id, {'zahlungsstatus': 'abgeschrieben'});
    await AbschreibungService.abschreiben(
      brutto: (rechnung.betragBrutto * 20).roundToDouble() / 20,
      datum: rechnung.rechnungsdatum,
      beschreibung:
          'Debitorenverlust ${rechnung.rechnungsnummer ?? rechnung.id.substring(0, 8)} (abgeschrieben)',
      belegnummer: rechnung.rechnungsnummer,
      belegId: rechnung.id,
    );
    debugPrint('[Mahnwesen] Rechnung ${rechnung.rechnungsnummer} abgeschrieben (mit MWST-Rückholung)');
  }
```
Import oben ergänzen: `import 'package:sbs_projer_app/services/buchhaltung/abschreibung_service.dart';`. Den nun ungenutzten `BuchungRepository`-Import nur entfernen, falls er sonst nirgends in der Datei verwendet wird (vorher prüfen).

- [ ] **Step 2: Analyse**
Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze lib/services/rechnung/mahnwesen_service.dart`
Expected: No issues.

- [ ] **Step 3: Commit**
```bash
git add sbs_projer_app/lib/services/rechnung/mahnwesen_service.dart
git commit -m "fix(rechnung): Mahnwesen-Abschreibung mit korrekter MWST-Rückholung"
```

---

## Task 4: mwstQuartalDetailProvider auf SaldoExpansion umstellen

**Files:**
- Modify: `sbs_projer_app/lib/presentation/providers/buchhaltung_providers.dart`

**Kontext:** Aktuell rechnet der Provider Umsatzsteuer aus `haben_konto=3400`/`mwst_betrag` und Vorsteuer fehlerhaft aus `betrag_brutto` (Konto 1170/1171 als soll/haben). Er erfasst Abschreibungs-Rückholungen (2200-Soll) nicht. Neu: pro Quartal über `SaldoExpansion` die Konto-Bewegungen rechnen.

- [ ] **Step 1: Provider neu schreiben** (Import `SaldoExpansion` ergänzen)

```dart
import 'package:sbs_projer_app/services/buchhaltung/saldo_expansion.dart';

final mwstQuartalDetailProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((ref, jahr) async {
  final rows = await SupabaseService.client
      .from('buchungen')
      .select('quartal, soll_konto, haben_konto, mwst_konto, betrag_netto, mwst_betrag, betrag_brutto, ist_storniert')
      .eq('user_id', SupabaseService.dataUserId)
      .eq('geschaeftsjahr', jahr);

  final buchungen = List<Map<String, dynamic>>.from(rows);
  final result = <Map<String, dynamic>>[];

  for (int q = 1; q <= 4; q++) {
    final saldi = <int, double>{};
    for (final b in buchungen) {
      if (b['quartal'] != q || b['ist_storniert'] == true) continue;
      final brutto = _toDouble(b['betrag_brutto']);
      final netto = b['betrag_netto'] != null ? _toDouble(b['betrag_netto']) : brutto;
      final mwst = _toDouble(b['mwst_betrag']);
      SaldoExpansion.apply(
        saldi,
        sollKonto: b['soll_konto'] as int,
        habenKonto: b['haben_konto'] as int,
        mwstKonto: b['mwst_konto'] as int?,
        betragNetto: netto,
        mwstBetrag: mwst,
        betragBrutto: brutto,
      );
    }
    final umsatz = -(saldi[3400] ?? 0); // Erlös netto (Roh negativ → positiv)
    final umsatzsteuer = -(saldi[2200] ?? 0); // inkl. Abschreibungs-Rückholung (2200-Soll)
    final vorsteuerMaterial = (saldi[1170] ?? 0);
    final vorsteuerBetrieb = (saldi[1171] ?? 0);
    final nettoSchuld = umsatzsteuer - vorsteuerMaterial - vorsteuerBetrieb;
    result.add({
      'quartal': q,
      'umsatz': (umsatz * 100).roundToDouble() / 100,
      'umsatzsteuer': (umsatzsteuer * 100).roundToDouble() / 100,
      'vorsteuer_material': (vorsteuerMaterial * 100).roundToDouble() / 100,
      'vorsteuer_betrieb': (vorsteuerBetrieb * 100).roundToDouble() / 100,
      'netto_mwst_schuld': (nettoSchuld * 100).roundToDouble() / 100,
    });
  }
  return result;
});
```
(Die Keys der Ergebnis-Maps unverändert lassen, damit `_MwstTab` in `berichte_screen.dart` weiterläuft — vorher `grep -n "umsatzsteuer\|vorsteuer\|netto_mwst_schuld\|umsatz" lib/presentation/screens/buchhaltung/berichte_screen.dart` prüfen.)

- [ ] **Step 2: Analyse + Tab-Kompatibilität**
Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze lib/presentation/providers/buchhaltung_providers.dart`
Expected: No issues; `_MwstTab` nutzt dieselben Map-Keys.

- [ ] **Step 3: Commit**
```bash
git add sbs_projer_app/lib/presentation/providers/buchhaltung_providers.dart
git commit -m "fix(buchhaltung): MWST-Vorschau über SaldoExpansion (erfasst Abschreibungs-Rückholung + Vorsteuer-Fix)"
```

---

## Task 5: Debitoren-Hub-Screen + Sammel-Abschreibung-Dialog + Route + Tile

**Files:**
- Create: `sbs_projer_app/lib/presentation/screens/buchhaltung/debitoren_screen.dart`
- Modify: `sbs_projer_app/lib/presentation/providers/buchhaltung_providers.dart` (Provider)
- Modify: `sbs_projer_app/lib/core/config/router.dart`
- Modify: `sbs_projer_app/lib/presentation/screens/buchhaltung/buchhaltung_dashboard_screen.dart`

- [ ] **Step 1: Provider** in `buchhaltung_providers.dart` ergänzen — Debitoren-Übersicht (1100-Saldo, native offene Summe, 1109 Delkredere):

```dart
final debitorenUebersichtProvider = FutureProvider<Map<String, double>>((ref) async {
  final saldi = await BuchungService.getAllSaldi();
  final offeneRg = await SupabaseService.client
      .from('rechnungen')
      .select('betrag_brutto')
      .not('zahlungsstatus', 'in', '("bezahlt","abgeschrieben")');
  final nativeOffen = (offeneRg as List)
      .fold<double>(0, (s, r) => s + _toDouble(r['betrag_brutto']));
  final debitoren = saldi[1100] ?? 0;
  final delkredere = -(saldi[1109] ?? 0);
  return {
    'debitoren_total': (debitoren * 100).roundToDouble() / 100,
    'native_offen': (nativeOffen * 100).roundToDouble() / 100,
    'historisch_aggregat': ((debitoren - nativeOffen) * 100).roundToDouble() / 100,
    'delkredere': (delkredere * 100).roundToDouble() / 100,
  };
});
```

- [ ] **Step 2: Screen** `debitoren_screen.dart` (Muster wie `BilanzScreen`/`AuditScreen`): zeigt die Übersichtszahlen in Cards; ein Button „Historische Sammel-Abschreibung" öffnet einen Dialog (Felder: Betrag CHF, Datum via `showDatePicker`, Bezeichnung) → ruft `AbschreibungService.abschreiben(brutto:…, datum:…, beschreibung:…, belegnummer: 'ABSCHR-HIST')`, danach `ref.invalidate(debitorenUebersichtProvider)` + `ref.invalidate(bilanzProvider)`; ein Button „Delkredere auf 5 % setzen" → `AbschreibungService.delkredereSetzen(zielWertberichtigung: 0.05*debitorenTotal, datum: DateTime.now())` + invalidate. Vollständige `AppColors`-/Card-Konventionen wie in `bilanz_screen.dart` (Theme-Import von dort kopieren). Bei Fehlern `ScaffoldMessenger`-SnackBar.

```dart
// Grundgerüst:
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/presentation/providers/buchhaltung_providers.dart';
import 'package:sbs_projer_app/services/buchhaltung/abschreibung_service.dart';

class DebitorenScreen extends ConsumerStatefulWidget {
  const DebitorenScreen({super.key});
  @override
  ConsumerState<DebitorenScreen> createState() => _DebitorenScreenState();
}

class _DebitorenScreenState extends ConsumerState<DebitorenScreen> {
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(debitorenUebersichtProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Debitoren / Abschreibungen')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (d) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _zeileCard('Debitoren gesamt (1100)', d['debitoren_total']!),
            _zeileCard('davon native offene Rechnungen', d['native_offen']!),
            _zeileCard('davon historischer Aggregat', d['historisch_aggregat']!),
            _zeileCard('Delkredere (1109)', d['delkredere']!),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.remove_circle_outline),
              label: const Text('Historische Sammel-Abschreibung'),
              onPressed: () => _sammelDialog(context, d['historisch_aggregat']!),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.percent),
              label: const Text('Delkredere auf 5 % setzen'),
              onPressed: () => _delkredere(d['debitoren_total']!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _zeileCard(String label, double v) => Card(
        child: ListTile(
          title: Text(label),
          trailing: Text('${v.toStringAsFixed(2)} CHF',
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      );

  Future<void> _delkredere(double debitorenTotal) async {
    try {
      await AbschreibungService.delkredereSetzen(
          zielWertberichtigung: (debitorenTotal * 0.05 * 100).roundToDouble() / 100,
          datum: DateTime.now());
      ref.invalidate(debitorenUebersichtProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Delkredere gesetzt')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  Future<void> _sammelDialog(BuildContext context, double maxBetrag) async {
    final betragC = TextEditingController();
    final bezC = TextEditingController(text: 'Sammel-Abschreibung alte Debitoren');
    DateTime datum = DateTime(2024, 12, 31);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Historische Sammel-Abschreibung'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: betragC,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Betrag brutto (CHF)'),
              ),
              TextField(
                  controller: bezC,
                  decoration: const InputDecoration(labelText: 'Bezeichnung')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: Text('Datum: ${datum.toIso8601String().split('T').first}')),
                TextButton(
                  onPressed: () async {
                    final p = await showDatePicker(
                        context: ctx,
                        initialDate: datum,
                        firstDate: DateTime(2019),
                        lastDate: DateTime.now());
                    if (p != null) setS(() => datum = p);
                  },
                  child: const Text('wählen'),
                ),
              ]),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Abschreiben')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final brutto = double.tryParse(betragC.text.replaceAll(',', '.'));
    if (brutto == null || brutto <= 0) return;
    try {
      await AbschreibungService.abschreiben(
          brutto: brutto, datum: datum, beschreibung: bezC.text, belegnummer: 'ABSCHR-HIST');
      ref.invalidate(debitorenUebersichtProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${brutto.toStringAsFixed(2)} CHF abgeschrieben')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }
}
```

- [ ] **Step 3: Route + Tile**
In `router.dart`: Import `debitoren_screen.dart` + `GoRoute(path: '/buchhaltung/debitoren', builder: (c,s) => const DebitorenScreen())`. In `buchhaltung_dashboard_screen.dart` ein `_NavTile` (Icon `Icons.request_quote`, Titel 'Debitoren', Subtitle 'Offene Forderungen & Abschreibungen', → `/buchhaltung/debitoren`) analog zum Bilanz-/Audit-Tile.

- [ ] **Step 4: Analyse**
Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze lib/presentation/screens/buchhaltung/debitoren_screen.dart lib/presentation/providers/buchhaltung_providers.dart lib/core/config/router.dart lib/presentation/screens/buchhaltung/buchhaltung_dashboard_screen.dart`
Expected: No issues (außer vorbestehende info-Hinweise).

- [ ] **Step 5: Commit**
```bash
git add sbs_projer_app/lib/presentation/screens/buchhaltung/debitoren_screen.dart sbs_projer_app/lib/presentation/providers/buchhaltung_providers.dart sbs_projer_app/lib/core/config/router.dart sbs_projer_app/lib/presentation/screens/buchhaltung/buchhaltung_dashboard_screen.dart
git commit -m "feat(ui): Debitoren-Hub-Screen (Sammel-Abschreibung + Delkredere) + Route + Tile"
```

---

## Task 6: Abschluss-Verifikation

- [ ] **Step 1: Tests + Analyse**
Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test && flutter analyze`
Expected: Alle Tests PASS (inkl. `abschreibung_service_test`); analyze ohne neue Errors/Warnings.

- [ ] **Step 2: Test-Abschreibung end-to-end (manuell, dann zurücknehmen)**
Über die App (`flutter run -d edge`) oder direkt: eine kleine historische Sammel-Abschreibung (z. B. 1'077.00, Datum 2022-06-30) auslösen, dann via `mcp__supabase__execute_sql` prüfen:
```sql
SELECT soll_konto, haben_konto, betrag_brutto, geschaeftsjahr, beschreibung
FROM buchungen WHERE belegnummer='ABSCHR-HIST' ORDER BY soll_konto;
```
Expected: 2 Zeilen — 3805/1100 (netto) + 2200/1100 (mwst), zusammen brutto, geschaeftsjahr 2022. Danach die MWST-Vorschau Q2/2022 prüfen (Umsatzsteuer um die Rückholung gesunken). **Test-Buchungen wieder löschen** (`DELETE FROM buchungen WHERE belegnummer='ABSCHR-HIST'`), falls nur zur Verifikation.

- [ ] **Step 3: Erfolgskriterien (Spec §7)**
  - Abschreibung bucht netto 3805 + MWST 2200 / 1100, rückdatiert ✔
  - MWST-Vorschau erfasst die Rückholung im Ursprungs-Quartal ✔
  - Debitoren-Hub: native Einzel-Abschreibung (Mahnwesen) + Sammel-Abschreibung + Delkredere ✔
  - Bilanz bleibt ausgeglichen (Verlust mindert Ergebnis) ✔

---

## Hinweise für die Umsetzung
- **Prod-Schreibzugriff:** Abschreibungs-Buchungen sind reversibel (per `belegnummer`/`notizen` markiert, löschbar).
- **Reihenfolge:** Task 1 → 2 (Service) → 3 (Mahnwesen) → 4 (MWST) → 5 (UI) → 6.
- **Daniel entscheidet selbst** ([[buchhaltung-ohne-treuhaender]]) — keine Treuhänder-Gates.

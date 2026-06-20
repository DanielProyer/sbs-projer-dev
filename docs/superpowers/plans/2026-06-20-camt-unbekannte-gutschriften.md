# camt unbekannte Gutschriften — Bucket + manuelle Zuordnung Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Gutschriften mit erkennbarem Zahler, die keiner offenen Forderung zugeordnet wurden, in einem vierten Bucket „Nicht zugeordnet" sichtbar machen und von dort manuell einer beliebigen offenen Forderung zuordnen + verbuchen.

**Architecture:** Additives viertes Feld `unbekannteGutschriften` in `AbgleichErgebnis` (reine Engine, TDD). Im Abgleich-Screen eine vierte Ergebnis-Gruppe + Zuordnungs-Dialog (Suche + Mehrfachauswahl + 5-Rappen-Differenz wie der bestehende 🟡-Dialog), der über die bestehende `ForderungsAbgleichService.verbuche` bucht.

**Tech Stack:** Flutter + Riverpod + GoRouter + Supabase. Tests via `flutter test` (Flutter-PATH: `export PATH="$PATH:/c/flutter/bin"`).

**Spec:** `docs/superpowers/specs/2026-06-20-camt-unbekannte-gutschriften-design.md`

**Verifizierte Signaturen (aus dem bestehenden Code):**
- `AbgleichErgebnis(List<AutoTreffer> auto, List<ManuellFall> manuell, List<Rechnung> keineZahlung)` — bekommt 4. Feld.
- `AutoTreffer{gutschrift: CamtTransaction, forderungen: List<Rechnung>}`, `ManuellFall{betriebId, betriebName, gutschriften: List<CamtTransaction>, forderungen: List<Rechnung>}`.
- `effektiverZahlername({required String? partyName, required String? additionalInfo}) → String?`.
- `CamtTransaction{amount: double, isCredit: bool, bookingDate: DateTime, partyName: String?, additionalInfo: String?}`.
- `Rechnung{id, rechnungsnummer: String?, betriebId: String?, betragBrutto: double}`.
- `ForderungsAbgleichService.verbuche({required double zahlbetrag, required DateTime datum, required List<Rechnung> forderungen}) → Future<void>`.
- Screen nutzt bereits `_dateFormat = DateFormat('dd.MM.yyyy')`, invalidiert `rechnungenStreamProvider` + `buchungenStreamProvider`.

---

## Task 1: Engine — viertes Feld `unbekannteGutschriften` (TDD)

**Files:**
- Modify: `sbs_projer_app/lib/services/camt/forderungs_abgleich_service.dart`
- Test: `sbs_projer_app/test/forderungs_abgleich_service_test.dart` (ergänzen, bestehende 9 behalten)

- [ ] **Step 1: Failing Tests schreiben** — am Ende von `void main(){...}` in `test/forderungs_abgleich_service_test.dart` ergänzen (Helper `_rg`/`_gut` und `betriebe` existieren bereits in der Datei):

```dart
  test('benannte Gutschrift ohne Betrieb-Match → unbekannt', () {
    final r = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(99.0, 'Unbekannt AG')],
      offeneForderungen: [_rg('r1', 'b1', 67.85)],
      betriebe: betriebe,
    );
    expect(r.unbekannteGutschriften.single.amount, 99.0);
    expect(r.auto, isEmpty);
    expect(r.keineZahlung.single.id, 'r1');
  });

  test('Betrieb ohne offene Forderung, Gutschrift vorhanden → unbekannt', () {
    final r = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(50.0, 'Gastro Latina GmbH')],
      offeneForderungen: [_rg('r1', 'b1', 67.85)], // nur b1 hat Forderung, Gutschrift geht an b2
      betriebe: betriebe,
    );
    expect(r.unbekannteGutschriften.single.amount, 50.0);
  });

  test('Rest-Gutschrift nach Auto-Match (Forderungen leer) → unbekannt', () {
    final r = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(67.85, 'Hotel Alpina'), _gut(200.0, 'Hotel Alpina')],
      offeneForderungen: [_rg('r1', 'b1', 67.85)],
      betriebe: betriebe,
    );
    expect(r.auto.single.forderungen.single.id, 'r1');
    expect(r.unbekannteGutschriften.single.amount, 200.0);
  });

  test('namenlose Gutschrift (Saldovortrag) → NICHT unbekannt', () {
    final r = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(10.0, '', 'Saldovortrag')],
      offeneForderungen: [_rg('r1', 'b1', 67.85)],
      betriebe: betriebe,
    );
    expect(r.unbekannteGutschriften, isEmpty);
  });

  test('zugeordnete (auto) Gutschrift nicht doppelt in unbekannt', () {
    final r = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(67.85, 'Hotel Alpina')],
      offeneForderungen: [_rg('r1', 'b1', 67.85)],
      betriebe: betriebe,
    );
    expect(r.auto.single.gutschrift.amount, 67.85);
    expect(r.unbekannteGutschriften, isEmpty);
  });
```

- [ ] **Step 2: Tests laufen → FAIL** (`unbekannteGutschriften` existiert nicht)

Run: `cd sbs_projer_app && flutter test test/forderungs_abgleich_service_test.dart`
Expected: Compile-Fehler / FAIL.

- [ ] **Step 3: `AbgleichErgebnis` um Feld erweitern**

In `forderungs_abgleich_service.dart` die Klasse ersetzen:
```dart
class AbgleichErgebnis {
  final List<AutoTreffer> auto;
  final List<ManuellFall> manuell;
  final List<Rechnung> keineZahlung; // offene Forderungen ohne passende Gutschrift
  final List<CamtTransaction> unbekannteGutschriften; // benannte Zahlungseingänge ohne Zuordnung
  AbgleichErgebnis(this.auto, this.manuell, this.keineZahlung, this.unbekannteGutschriften);
}
```

- [ ] **Step 4: Befüllung in `abgleich` ergänzen**

In `abgleich(...)` direkt vor `return AbgleichErgebnis(...)` einfügen und das return anpassen:
```dart
    // 4. Benannte Gutschriften, die weder auto noch manuell zugeordnet wurden → unbekannt.
    final zugeordnet = <CamtTransaction>{
      ...auto.map((a) => a.gutschrift),
      ...manuell.expand((m) => m.gutschriften),
    };
    final unbekannt = <CamtTransaction>[];
    for (final g in gutschriften.where((g) => g.isCredit)) {
      final name = effektiverZahlername(partyName: g.partyName, additionalInfo: g.additionalInfo);
      if (name == null) continue;
      if (zugeordnet.contains(g)) continue;
      unbekannt.add(g);
    }

    return AbgleichErgebnis(auto, manuell, keineZahlung, unbekannt);
```
(Das alte `return AbgleichErgebnis(auto, manuell, keineZahlung);` wird dadurch ersetzt.)

- [ ] **Step 5: Tests → PASS** (alle 14: 9 alt + 5 neu)

Run: `flutter test test/forderungs_abgleich_service_test.dart`
Expected: PASS.

- [ ] **Step 6: `flutter analyze lib/services/camt/forderungs_abgleich_service.dart`** → No issues found.

- [ ] **Step 7: Commit**

```bash
git add sbs_projer_app/lib/services/camt/forderungs_abgleich_service.dart sbs_projer_app/test/forderungs_abgleich_service_test.dart
git commit -m "feat(camt): unbekannteGutschriften-Bucket in AbgleichErgebnis"
```

---

## Task 2: Screen — 4. Gruppe „Nicht zugeordnet" + Zuordnungs-Dialog

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/buchhaltung/camt_abgleich_screen.dart`

Hinweis: Der Screen lädt in `_waehleDatei` bereits `offen` (alle offenen Kundenrechnungen) und baut `betriebe` (`List<Map<String,String>>`). Diese Werte sind bisher lokal — sie müssen in State gehoben werden.

- [ ] **Step 1: State-Felder ergänzen**

Bei den bestehenden State-Feldern (`AbgleichErgebnis? _ergebnis; bool _loading = false; String? _dateiname;`) ergänzen:
```dart
  List<Rechnung> _alleOffenen = [];
  Map<String, String> _betriebName = {};
```

- [ ] **Step 2: In `_waehleDatei` die geladenen Werte in State speichern**

Direkt nachdem `offen` und `betriebe` berechnet sind und VOR/IN dem `setState(() { _ergebnis = erg; _loading = false; })` ergänzen (im selben setState):
```dart
        _alleOffenen = offen;
        _betriebName = {for (final b in betriebe) b['id']!: b['name']!};
```
(`offen` ist `List<Rechnung>`, `betriebe` ist `List<Map<String,String>>` mit Keys `id`/`name` — beide bereits im Handler vorhanden.)

- [ ] **Step 3: 4. Ergebnis-Gruppe rendern**

In der ListView/Column der drei bestehenden `_Gruppe`-Blöcke (🟢/🟡/🔴) nach der 🔴-Gruppe ergänzen:
```dart
  _Gruppe(
    titel: '⚪ Nicht zugeordnet (${_ergebnis!.unbekannteGutschriften.length})',
    child: Column(children: [
      for (final g in _ergebnis!.unbekannteGutschriften)
        ListTile(
          title: Text('${g.amount.toStringAsFixed(2)} CHF — '
              '${effektiverZahlername(partyName: g.partyName, additionalInfo: g.additionalInfo) ?? '?'}'),
          subtitle: Text(_dateFormat.format(g.bookingDate)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _ordneZu(g),
        ),
    ]),
  ),
```
Falls noch nicht importiert, oben ergänzen: `import 'package:sbs_projer_app/services/camt/zahlername.dart';`

- [ ] **Step 4: Zuordnungs-Dialog `_ordneZu` implementieren**

Neue Methode in der State-Klasse (Muster aus `_oeffneManuell`, aber Auswahlpool = `_alleOffenen` + Such-Feld):
```dart
  Future<void> _ordneZu(CamtTransaction g) async {
    final gewaehlt = <Rechnung>{};
    var suche = '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final gefiltert = _alleOffenen.where((r) {
            if (suche.isEmpty) return true;
            final q = suche.toLowerCase();
            final nr = (r.rechnungsnummer ?? '').toLowerCase();
            final betrieb = (_betriebName[r.betriebId] ?? '').toLowerCase();
            return nr.contains(q) || betrieb.contains(q);
          }).toList();
          final zahlSumme = g.amount;
          final fordSumme =
              gewaehlt.fold<double>(0, (s, r) => s + r.betragBrutto);
          final diff = ((zahlSumme - fordSumme) * 20).roundToDouble() / 20;
          return AlertDialog(
            title: Text('Zahlung zuordnen — ${g.amount.toStringAsFixed(2)} CHF'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Suche (Rechnungsnr. oder Betrieb)',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setDialogState(() => suche = v),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final r in gefiltert)
                          CheckboxListTile(
                            dense: true,
                            value: gewaehlt.contains(r),
                            title: Text('${r.rechnungsnummer ?? '?'} · '
                                '${_betriebName[r.betriebId] ?? '?'}'),
                            subtitle:
                                Text('${r.betragBrutto.toStringAsFixed(2)} CHF'),
                            onChanged: (sel) => setDialogState(() {
                              if (sel == true) {
                                gewaehlt.add(r);
                              } else {
                                gewaehlt.remove(r);
                              }
                            }),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (gewaehlt.isNotEmpty && diff.abs() >= 0.01)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (diff < 0 ? AppColors.warning : AppColors.success)
                            .withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        Icon(diff < 0 ? Icons.trending_down : Icons.trending_up,
                            color:
                                diff < 0 ? AppColors.warning : AppColors.success),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(diff < 0
                              ? 'Unterzahlung ${diff.abs().toStringAsFixed(2)} CHF — wird als Debitorenverlust (3805) gebucht'
                              : 'Mehrzahlung ${diff.toStringAsFixed(2)} CHF — wird als a.o. Ertrag (8000) gebucht'),
                        ),
                      ]),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Abbrechen')),
              FilledButton(
                onPressed: gewaehlt.isEmpty
                    ? null
                    : () async {
                        try {
                          await ForderungsAbgleichService.verbuche(
                            zahlbetrag: g.amount,
                            datum: g.bookingDate,
                            forderungen: gewaehlt.toList(),
                          );
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('Verbuchungs-Fehler: $e')));
                          }
                        }
                      },
                child: const Text('Verbuchen'),
              ),
            ],
          );
        },
      ),
    );
    if (ok == true) {
      ref.invalidate(rechnungenStreamProvider);
      ref.invalidate(buchungenStreamProvider);
      if (!mounted) return;
      setState(() {
        _ergebnis!.unbekannteGutschriften.remove(g);
        final gebuchteIds = gewaehlt.map((r) => r.id).toSet();
        _alleOffenen.removeWhere((r) => gebuchteIds.contains(r.id));
        _ergebnis!.keineZahlung.removeWhere((r) => gebuchteIds.contains(r.id));
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Zahlung verbucht.')));
      }
    }
  }
```

- [ ] **Step 5: Konsistenz-Bonus im 🟡-Dialog `_oeffneManuell`**

Im Post-Booking-`setState` von `_oeffneManuell`, an der Stelle wo der Fall bei leeren Forderungen entfernt wird (`if (f.forderungen.isEmpty) { _ergebnis!.manuell.remove(f); }`), die übrigen Gutschriften retten:
```dart
        if (f.forderungen.isEmpty) {
          // Übrige (nicht zugeordnete) Gutschriften des Falls sichtbar halten.
          _ergebnis!.unbekannteGutschriften.addAll(f.gutschriften);
          _ergebnis!.manuell.remove(f);
        }
```
(Der bestehende dreizeilige Scoping-Kommentar darüber kann entfallen oder bleiben — die Gutschrift verschwindet nun nicht mehr.)

- [ ] **Step 6: `flutter analyze lib/presentation/screens/buchhaltung/camt_abgleich_screen.dart`** → No issues found.

- [ ] **Step 7: Gesamt-Tests** `cd sbs_projer_app && flutter test` → alle grün.

- [ ] **Step 8: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/buchhaltung/camt_abgleich_screen.dart
git commit -m "feat(camt): Bucket 'Nicht zugeordnet' + manuelle Zuordnung im Abgleich-Screen"
```

---

## Self-Review (Plan-Autor)
- **Spec-Abdeckung:** 4. Feld `unbekannteGutschriften` (T1) ✓; Befüllung benannt-und-nicht-zugeordnet, namenlos ausgeschlossen (T1 Step 4 + Tests) ✓; 4. Gruppe im Screen (T2 Step 3) ✓; Zuordnungs-Dialog mit Suche + Mehrfachauswahl + 5-Rappen-Differenz 3805/8000 (T2 Step 4) ✓; State `_alleOffenen`/`_betriebName` (T2 Step 1/2) ✓; Provider-Invalidierung + lokale Pool-Bereinigung (T2 Step 4) ✓; Konsistenz-Bonus 🟡-Dialog (T2 Step 5) ✓; `verbuche` unverändert ✓.
- **Typ-Konsistenz:** `unbekannteGutschriften: List<CamtTransaction>` durchgängig (T1 Klasse, T1 Befüllung, T2 Gruppe/Dialog/Bonus); `verbuche(zahlbetrag,datum,forderungen)` wie bestehend; `effektiverZahlername` Import in T2 sichergestellt.
- **Platzhalter:** keine — vollständiger Dialog-Code in T2 Step 4.
- **Risiken:** Dialog-Liste bei ~1000 offenen Forderungen → Such-Feld filtert; `ListView`/`shrinkWrap` in `Flexible` performant genug für gefilterte Teilmenge. `AppColors.success`/`.warning` existieren (im 🟡-Dialog verwendet).

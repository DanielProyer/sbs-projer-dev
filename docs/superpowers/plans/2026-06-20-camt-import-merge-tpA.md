# TP-A: Bankauszug-Import + Forderungs-Abgleich zusammenführen (Kern) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Der Bankauszug-Import teilt eine camt-Datei (ab Stichtag 11.03.2026) in **Bereich 1 = Kundenzahlungen** (eingebetteter Forderungs-Abgleich mit Vorschau+Bestätigen) und **Bereich 2 = Übriges** (bestehende regelbasierte Auto-Buchung → Prüfliste), archiviert die Datei und nutzt für beide denselben Code wie der Standalone-Abgleich (DRY).

**Architecture:** Eine reine Routing-Funktion trennt Kundenzahlungs-Gutschriften vom Rest. Die Gruppen-Vorschau + Zuordnen-Dialoge des Abgleich-Screens werden in ein wiederverwendbares `AbgleichVorschau`-Widget extrahiert; Standalone-Abgleich und Import betten es ein. Bereich 2 läuft unverändert über `CamtAutoBooker` (jetzt ohne Kundenzahlungen).

**Tech Stack:** Flutter + Riverpod + GoRouter + Supabase. Tests via `flutter test` (Flutter-PATH: `export PATH="$PATH:/c/flutter/bin"`).

**Spec:** `docs/superpowers/specs/2026-06-20-camt-import-forderungsabgleich-merge-design.md`

**Verifizierte Fakten (aus dem Code):**
- `CamtStichtag.stichtag` (camt_stichtag.dart:4), genutzt nur in `camt_auto_booker.dart:39` (Gate) + Import-Confirm-Text.
- `CamtKlassifizierer.kategorie(tx, {required bool betriebErkannt})` → `TxKategorie {kundenzahlung, heinekenEingang, bargeldEinzahlung, ausgabe, saldovortrag, unbekannt}`. Negativ-Kriterien für Bargeld: `additionalInfo+partyName` enthält `geldautomaten`/`posteinzahlung`/`six token`; Heineken: partyName enthält `heineken`; Saldo: enthält `saldovortrag`.
- `CamtAutoBooker.run({transactions, betriebe, offeneRechnungen, heinekenRechnungen, bereitsVerarbeitet, regeln, vorlagenById}) → AutoBookerResult{gebucht,pruefliste,uebersprungen,fehler}`.
- `ForderungsAbgleichService.abgleich({gutschriften, offeneForderungen, betriebe}) → AbgleichErgebnis{auto,manuell,keineZahlung,unbekannteGutschriften}` und `.verbuche({zahlbetrag,datum,forderungen})`.
- `CamtDateiRepository.existsZeitraum(iban,von,bis)`, `.speichern(CamtDatei, Uint8List)`.
- Import-Screen `camt_import_screen.dart`: 3-Schritt-Wizard (0 pick, 1 confirm, 2 result), `_doImport()` lädt betriebe/offeneRechnungen/heinekenRechnungen/bereitsVerarbeitet/regeln/vorlagenById und ruft `CamtAutoBooker.run` über ALLE Transaktionen.
- Abgleich-Screen `camt_abgleich_screen.dart` enthält: `_buildErgebnis`, `_uebersicht`, `_autoZeile`, `_verbuche`, `_verbucheAlle`, `_oeffneManuell`, `_ordneZu`, `_zahlungInfo`, `_zahlungInfoText`, Widgets `_GruppeCard`, `_Kpi`; nutzt `AutoMatchTile` (eigenes Widget).

**Hinweis Daten:** 4 Kundenrechnungen sind `offen`/`gesendet`, haben aber `zahlung_eingegangen_am=2026-05-17` (CHF 337.28). Vor Echtlauf von Daniel sichten lassen (evtl. auf `bezahlt`). Kein Code-Blocker.

---

## Task 1: Stichtag auf 11.03.2026 senken (TDD)

**Files:**
- Modify: `sbs_projer_app/lib/services/camt/camt_stichtag.dart`
- Modify: `sbs_projer_app/test/camt_stichtag_test.dart`
- Modify: `sbs_projer_app/test/camt_parser_test.dart`

- [ ] **Step 1: Tests anpassen**

In `test/camt_stichtag_test.dart` den bestehenden Test ersetzen:
```dart
  test('Stichtag ist 11.03.2026, davor nicht automatisierbar', () {
    expect(CamtStichtag.stichtag, DateTime(2026, 3, 11));
    expect(CamtStichtag.istAutomatisierbar(DateTime(2026, 3, 10)), isFalse);
    expect(CamtStichtag.istAutomatisierbar(DateTime(2026, 3, 11)), isTrue);
  });
```
In `test/camt_parser_test.dart` den Stichtag-Test ersetzen:
```dart
  test('Stichtag: vor 11.03.2026 nicht automatisiert', () {
    expect(CamtStichtag.istAutomatisierbar(DateTime(2026, 3, 10)), false);
    expect(CamtStichtag.istAutomatisierbar(DateTime(2026, 3, 11)), true);
  });
```

- [ ] **Step 2: Tests laufen → FAIL**

Run: `cd sbs_projer_app && flutter test test/camt_stichtag_test.dart test/camt_parser_test.dart`
Expected: FAIL (Stichtag noch 2026-06-20).

- [ ] **Step 3: Konstante ändern**

In `camt_stichtag.dart` die `stichtag`-Zeile:
```dart
  static final DateTime stichtag = DateTime(2026, 3, 11);
```

- [ ] **Step 4: Tests → PASS**

Run: `flutter test test/camt_stichtag_test.dart test/camt_parser_test.dart` → PASS.

- [ ] **Step 5: Commit**
```bash
git add sbs_projer_app/lib/services/camt/camt_stichtag.dart sbs_projer_app/test/camt_stichtag_test.dart sbs_projer_app/test/camt_parser_test.dart
git commit -m "feat(camt): Stichtag auf 11.03.2026 gesenkt"
```

---

## Task 2: Routing-Funktion `istKundenzahlungsKandidat` (rein, TDD)

Trennt Bereich 1 (Kundenzahlungen) von Bereich 2. Kundenzahlungs-Kandidat = Gutschrift, die **nicht** Saldovortrag, **nicht** Heineken und **nicht** Bargeld (Geldautomaten/Post/SIX) ist. Bewusst unabhängig von `betriebErkannt`, weil der Abgleich in Bereich 1 selbst (besser, via `effektiverZahlername`) den Betrieb sucht.

**Files:**
- Create: `sbs_projer_app/lib/services/camt/camt_bereich_router.dart`
- Test: `sbs_projer_app/test/camt_bereich_router_test.dart`

- [ ] **Step 1: Test schreiben**
```dart
// test/camt_bereich_router_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/camt_transaction.dart';
import 'package:sbs_projer_app/services/camt/camt_bereich_router.dart';

CamtTransaction _tx({required bool credit, String? party, String? addtl}) =>
    CamtTransaction(
      amount: 50, currency: 'CHF', isCredit: credit,
      bookingDate: DateTime(2026, 4, 1), partyName: party,
      additionalInfo: addtl, txKey: '$party-$addtl-$credit');

void main() {
  test('benannte Gutschrift → Kandidat', () {
    expect(istKundenzahlungsKandidat(_tx(credit: true, party: 'Hotel Alpina')), isTrue);
  });
  test('Gutschrift ohne Name (Abgleich findet via additionalInfo) → Kandidat', () {
    expect(istKundenzahlungsKandidat(
        _tx(credit: true, party: null, addtl: 'Gutschrift Bar Müller')), isTrue);
  });
  test('Belastung → kein Kandidat', () {
    expect(istKundenzahlungsKandidat(_tx(credit: false, party: 'Swisscom')), isFalse);
  });
  test('Geldautomaten-Einzahlung → kein Kandidat (Bargeld → Bereich 2)', () {
    expect(istKundenzahlungsKandidat(
        _tx(credit: true, addtl: 'Geldautomaten Einzahlung GKB')), isFalse);
  });
  test('Posteinzahlung → kein Kandidat', () {
    expect(istKundenzahlungsKandidat(_tx(credit: true, addtl: 'Posteinzahlung')), isFalse);
  });
  test('Heineken-Gutschrift → kein Kandidat', () {
    expect(istKundenzahlungsKandidat(_tx(credit: true, party: 'Heineken AG')), isFalse);
  });
  test('Saldovortrag → kein Kandidat', () {
    expect(istKundenzahlungsKandidat(_tx(credit: true, addtl: 'Saldovortrag')), isFalse);
  });
}
```

- [ ] **Step 2: Test → FAIL** (`flutter test test/camt_bereich_router_test.dart`)

- [ ] **Step 3: Implementieren**
```dart
// lib/services/camt/camt_bereich_router.dart
import 'package:sbs_projer_app/data/models/camt_transaction.dart';

/// True, wenn die Transaktion in Bereich 1 (Kundenzahlungs-Abgleich) gehört.
/// Bereich 1 = Gutschrift, die weder Saldovortrag, Heineken noch Bargeld
/// (Geldautomaten-/Post-/SIX-Einzahlung) ist. Alles andere → Bereich 2.
bool istKundenzahlungsKandidat(CamtTransaction tx) {
  if (!tx.isCredit) return false;
  final info = '${tx.additionalInfo ?? ''} ${tx.partyName ?? ''}'.toLowerCase();
  if (info.contains('saldovortrag')) return false;
  if ((tx.partyName ?? '').toLowerCase().contains('heineken')) return false;
  if (info.contains('geldautomaten') ||
      info.contains('posteinzahlung') ||
      info.contains('six token')) {
    return false;
  }
  return true;
}
```

- [ ] **Step 4: Test → PASS** (alle 7)

- [ ] **Step 5: Commit**
```bash
git add sbs_projer_app/lib/services/camt/camt_bereich_router.dart sbs_projer_app/test/camt_bereich_router_test.dart
git commit -m "feat(camt): Bereich-Router (Kundenzahlung vs Übriges)"
```

---

## Task 3: `AbgleichVorschau` wiederverwendbares Widget extrahieren

Die Gruppen-Vorschau + Zuordnen-Dialoge aus `camt_abgleich_screen.dart` in ein eigenes Widget auslagern, das Standalone-Abgleich UND Import einbetten. Reiner Refactor (Verhalten unverändert).

**Files:**
- Create: `sbs_projer_app/lib/presentation/screens/buchhaltung/widgets/abgleich_vorschau.dart`
- Modify: `sbs_projer_app/lib/presentation/screens/buchhaltung/camt_abgleich_screen.dart`

- [ ] **Step 1: Widget anlegen**

Neues `AbgleichVorschau extends ConsumerStatefulWidget` mit dieser öffentlichen API:
```dart
class AbgleichVorschau extends ConsumerStatefulWidget {
  final AbgleichErgebnis ergebnis;          // wird in-place mutiert beim Verbuchen
  final List<Rechnung> alleOffenen;         // Pool für ⚪-Zuordnung
  final Map<String, String> betriebName;    // id → Name
  final EdgeInsets padding;                  // Default: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
  const AbgleichVorschau({
    super.key,
    required this.ergebnis,
    required this.alleOffenen,
    required this.betriebName,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  });
  ...
}
```

Aus `camt_abgleich_screen.dart` **vollständig in dieses Widget verschieben** (Code 1:1, nur `_ergebnis!`→`widget.ergebnis`, `_alleOffenen`→`widget.alleOffenen`, `_betriebName`→`widget.betriebName`, und lokale Mutationen über `setState`):
- die Render-Logik aus `_buildErgebnis` **ohne** das äußere `Align`+`ConstrainedBox` (das bleibt im jeweiligen Host) — also nur die `ListView`/Gruppen; nimm `padding` aus dem Widget-Feld. (Die `_uebersicht`-KPI-Karte bleibt Teil der Vorschau.)
- `_autoZeile`, `_verbuche`, `_verbucheAlle`, `_oeffneManuell`, `_ordneZu`, `_zahlungInfo`, `_zahlungInfoText`
- die privaten Widgets `_GruppeCard`, `_Kpi` (in diese Datei mitnehmen)
- die Konstante `_maxZeilen`
- benötigte Imports (`AutoMatchTile`, `chf`, `effektiverZahlername`, `ForderungsAbgleichService`, Provider `rechnungenStreamProvider`/`buchungenStreamProvider`, Modelle).

Build des Widgets:
```dart
  @override
  Widget build(BuildContext context) {
    final erg = widget.ergebnis;
    final autoSumme = erg.auto.fold<double>(0, (s, t) => s + t.gutschrift.amount);
    final offenSumme = erg.keineZahlung.fold<double>(0, (s, r) => s + r.betragBrutto);
    final unbekanntSumme =
        erg.unbekannteGutschriften.fold<double>(0, (s, g) => s + g.amount);
    return ListView(
      padding: widget.padding,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [ /* _uebersicht(...) + die vier _GruppeCard wie bisher */ ],
    );
  }
```
> `shrinkWrap: true` + `NeverScrollableScrollPhysics`, damit die Vorschau auch eingebettet in eine andere Scroll-Ansicht (Import-Result) funktioniert. Der Host stellt das Scrollen.

- [ ] **Step 2: `CamtAbgleichScreen` auf das Widget umstellen**

In `camt_abgleich_screen.dart`:
- Die verschobenen Methoden/Widgets entfernen.
- State `_alleOffenen`, `_betriebName` bleiben (werden in `_waehleDatei` befüllt).
- `_buildErgebnis` wird:
```dart
  Widget _buildErgebnis(AbgleichErgebnis erg) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxBreite),
        child: AbgleichVorschau(
          ergebnis: erg,
          alleOffenen: _alleOffenen,
          betriebName: _betriebName,
        ),
      ),
    );
  }
```
- `_maxBreite` bleibt im Screen; `_maxZeilen` zog ins Widget.

- [ ] **Step 3: Verifikation**

Run: `cd sbs_projer_app && flutter analyze lib/presentation/screens/buchhaltung/camt_abgleich_screen.dart lib/presentation/screens/buchhaltung/widgets/abgleich_vorschau.dart` → No issues found.
Run: `flutter test` → alle bisherigen Tests (inkl. `auto_match_tile_test.dart`) grün.
Manueller Klicktest entfällt (reiner Refactor; Verhalten unverändert).

- [ ] **Step 4: Commit**
```bash
git add sbs_projer_app/lib/presentation/screens/buchhaltung/widgets/abgleich_vorschau.dart sbs_projer_app/lib/presentation/screens/buchhaltung/camt_abgleich_screen.dart
git commit -m "refactor(camt): AbgleichVorschau als wiederverwendbares Widget"
```

---

## Task 4: Archivierung + Doppel-Upload-Schutz in den Import

Den camt-Datei-Archiv-Schritt (wie im Abgleich) in den Import übernehmen.

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/buchhaltung/camt_import_screen.dart`

- [ ] **Step 1: Imports + Archivierung in `_doImport`**

Oben ergänzen:
```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:sbs_projer_app/data/models/camt_datei.dart';
import 'package:sbs_projer_app/data/repositories/camt_datei_repository.dart';
```
In `_doImport`, als ERSTE Aktion im `try` (vor dem Laden der Stammdaten), die Datei archivieren. Da der Import den rohen XML-String nicht mehr im State hält, wird in `_pickFile` der bereits geparste `_statement` genutzt + der XML-Text in einem neuen State-Feld `String? _xmlRoh` gehalten:

In State ergänzen: `String? _xmlRoh;` und in `_pickFile` nach erfolgreichem Parse `_xmlRoh = xmlString;` setzen (im `setState`).

In `_doImport` vor dem Stammdaten-Laden:
```dart
      final stmt = _statement!;
      // Doppel-Upload-Schutz (wie Abgleich).
      final bereitsErfasst = await CamtDateiRepository.existsZeitraum(
          stmt.iban, stmt.fromDate, stmt.toDate);
      if (bereitsErfasst) {
        if (!mounted) { setState(() => _loading = false); return; }
        final weiter = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Zeitraum bereits erfasst'),
            content: Text('Für diese IBAN ist der Zeitraum '
                '${_dateFormat.format(stmt.fromDate)} – '
                '${_dateFormat.format(stmt.toDate)} bereits archiviert.\n\nTrotzdem importieren?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Trotzdem')),
            ],
          ),
        );
        if (weiter != true) { setState(() => _loading = false); return; }
      }
      final gut = stmt.transactions.where((t) => t.isCredit).length;
      await CamtDateiRepository.speichern(
        CamtDatei(id: '', userId: '', dateiname: 'camt.xml',
          zeitraumVon: stmt.fromDate, zeitraumBis: stmt.toDate, iban: stmt.iban,
          anzahlEintraege: stmt.transactions.length, anzahlGutschriften: gut, storagePfad: ''),
        Uint8List.fromList(utf8.encode(_xmlRoh ?? '')));
```

- [ ] **Step 2: `flutter analyze` des Screens** → No issues found.

- [ ] **Step 3: Commit**
```bash
git add sbs_projer_app/lib/presentation/screens/buchhaltung/camt_import_screen.dart
git commit -m "feat(camt): Import archiviert camt-Datei + Doppel-Upload-Schutz"
```

---

## Task 5: Import-Verarbeitung aufteilen (Bereich 1 berechnen, Bereich 2 buchen)

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/buchhaltung/camt_import_screen.dart`

- [ ] **Step 1: State + Split in `_doImport`**

In State ergänzen:
```dart
  AbgleichErgebnis? _abgleich;          // Bereich 1
  List<Rechnung> _alleOffenen = [];
  Map<String, String> _betriebName = {};
```
Imports ergänzen:
```dart
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/services/camt/camt_bereich_router.dart';
import 'package:sbs_projer_app/services/camt/forderungs_abgleich_service.dart';
```
In `_doImport`, nach dem Laden von `betriebe`/`offeneRechnungen`/… und VOR dem Auto-Booker-Aufruf, aufteilen:
```dart
      final post = stmt.transactions
          .where((t) => CamtStichtag.istAutomatisierbar(t.bookingDate))
          .where((t) => !bereitsVerarbeitet.contains(t.txKey))
          .toList();
      final bereich1 = post.where(istKundenzahlungsKandidat).toList();
      final bereich2 = post.where((t) => !istKundenzahlungsKandidat(t)).toList();
```
Auto-Booker NUR über Bereich 2 (plus die übersprungenen Pre-Stichtag/bereits-verarbeitet zählt der Booker selbst, daher hier `stmt.transactions` MINUS bereich1 übergeben):
```dart
      final result = await CamtAutoBooker.run(
        transactions: [...bereich2,
          ...stmt.transactions.where((t) =>
              !CamtStichtag.istAutomatisierbar(t.bookingDate) ||
              bereitsVerarbeitet.contains(t.txKey))],
        betriebe: betriebe,
        offeneRechnungen: offeneRechnungen,
        heinekenRechnungen: heinekenRechnungen,
        bereitsVerarbeitet: bereitsVerarbeitet,
        regeln: regeln,
        vorlagenById: vorlagenById,
      );
```
> So zählt der Booker die übersprungenen korrekt mit und verarbeitet nur Bereich 2 inhaltlich (Bereich-1-Txs sind nicht in seiner Liste).

Bereich 1 berechnen:
```dart
      final abgleich = ForderungsAbgleichService.abgleich(
        gutschriften: bereich1,
        offeneForderungen: offeneRechnungen,
        betriebe: betriebe,
      );
```
setState am Ende:
```dart
      setState(() {
        _result = result;
        _abgleich = abgleich;
        _alleOffenen = offeneRechnungen;
        _betriebName = {for (final b in betriebe) b['id']!: b['name']!};
        _step = 2;
        _loading = false;
      });
```

- [ ] **Step 2: `flutter analyze`** → No issues found.

- [ ] **Step 3: Commit**
```bash
git add sbs_projer_app/lib/presentation/screens/buchhaltung/camt_import_screen.dart
git commit -m "feat(camt): Import teilt in Bereich 1 (Kundenzahlungen) + Bereich 2"
```

---

## Task 6: Kombinierter Ergebnis-Screen (Bereich 1 Vorschau + Bereich 2 Zähler)

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/buchhaltung/camt_import_screen.dart`

- [ ] **Step 1: `_buildResultStep` umbauen**

Statt nur der Zähler: oben **Bereich 1** als `AbgleichVorschau`, darunter **Bereich 2** (bisherige Zähler + Prüfliste-Button). Import des Widgets:
```dart
import 'package:sbs_projer_app/presentation/screens/buchhaltung/widgets/abgleich_vorschau.dart';
```
Neuer Aufbau:
```dart
  Widget _buildResultStep() {
    final r = _result!;
    final ab = _abgleich!;
    final hatKundenzahlungen = ab.auto.isNotEmpty || ab.manuell.isNotEmpty ||
        ab.unbekannteGutschriften.isNotEmpty || ab.keineZahlung.isNotEmpty;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // Bereich 1
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text('Kundenzahlungen',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            if (hatKundenzahlungen)
              AbgleichVorschau(
                ergebnis: ab,
                alleOffenen: _alleOffenen,
                betriebName: _betriebName,
                padding: const EdgeInsets.symmetric(vertical: 8),
              )
            else
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Keine Kundenzahlungen in diesem Auszug.',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            const Divider(height: 32),
            // Bereich 2
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text('Übriges (automatisch verbucht)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            _ResultRow(Icons.check, '${r.gebucht} verbucht', AppColors.success),
            if (r.pruefliste > 0)
              _ResultRow(Icons.info_outline, '${r.pruefliste} in Prüfliste', AppColors.warning),
            if (r.uebersprungen > 0)
              _ResultRow(Icons.skip_next,
                  '${r.uebersprungen} übersprungen (vor Stichtag / bereits verarbeitet)',
                  AppColors.textSecondary),
            if (r.fehler.isNotEmpty)
              _ResultRow(Icons.error_outline, '${r.fehler.length} Fehler', AppColors.error),
            if (r.fehler.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...r.fehler.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(e, style: const TextStyle(fontSize: 12, color: AppColors.error)),
                  )),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push('/buchhaltung/camt-pruefliste'),
              icon: const Icon(Icons.fact_check),
              label: const Text('Zur Prüfliste'),
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => setState(() {
                    _step = 0; _statement = null; _result = null;
                    _abgleich = null; _automatisierbarCount = 0; _xmlRoh = null;
                  }),
                  child: const Text('Weiteren Auszug importieren'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Fertig'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 2: `flutter analyze` + Gesamt-Tests**

Run: `cd sbs_projer_app && flutter analyze 2>&1 | grep -E "error •" || echo "0 errors"` → 0 errors.
Run: `flutter test` → alle grün.

- [ ] **Step 3: Commit**
```bash
git add sbs_projer_app/lib/presentation/screens/buchhaltung/camt_import_screen.dart
git commit -m "feat(camt): Import-Ergebnis = Bereich-1-Vorschau + Bereich-2-Zähler"
```

---

## Task 7: Manueller Klicktest (Web) + Deploy

**Files:** keine (Verifikation/Deploy).

- [ ] **Step 1: Klicktest** — `cd sbs_projer_app && flutter run -d edge`: camt 12.03→heute im **Bankauszug Import** hochladen → Ergebnis zeigt oben Kundenzahlungen (🟢/🟡/🔴/⚪, verbuchbar) und unten „Übriges" (gebucht/Prüfliste). Einen 🟢-Treffer verbuchen → verschwindet; Prüfliste-Button öffnet die Prüfliste. Standalone-Abgleich weiterhin funktionsfähig (Fallback).
- [ ] **Step 2: Version bumpen** `sbs_projer_app/pubspec.yaml` Zeile 4 (beide Teile +1).
- [ ] **Step 3: Build** `cd sbs_projer_app && export MSYS_NO_PATHCONV=1 && flutter build web --base-href "/sbs-projer-dev/" --pwa-strategy=none`
- [ ] **Step 4: Cache-Bust** mainJsPath in `flutter_bootstrap.js` + `rm flutter_service_worker.js` (CLAUDE.md-Prozedur).
- [ ] **Step 5: Deploy** gh-pages + main (Branch `feature/camt-import-merge` → mergen nach main, dann deployen — nach Rückfrage beim User).

---

## Self-Review (Plan-Autor)
- **Spec-Abdeckung:** Stichtag 11.03 (T1) ✓; Bereich-1/2-Split nur Kundenzahlungen, Bargeld→Bereich 2 (T2/T5) ✓; Bereich 2 = Regeln/Auto-Booker unverändert (T5) ✓; UI-Bausteine als gemeinsames Widget (T3) ✓; Vorschau+Bestätigen statt Auto-Buchen für Kundenzahlungen (T5/T6 — Bereich-1-Txs gehen nicht in den Booker) ✓; Archivierung (T4) ✓; kombinierter Ergebnis-Screen (T6) ✓; Abgleich-Screen bleibt Fallback (T3 refactor, Screen bleibt) ✓; Daten-Auffälligkeit dokumentiert ✓.
- **Matching-Kette (Stufen 1/2 für TP-B/C):** In TP-A bleibt Matching = `ForderungsAbgleichService.abgleich` (Stufe 3). Der Service ist der Andockpunkt für Referenz-/Alias-Stufen in TP-B/C — kein zusätzlicher Bau in TP-A nötig (Spec: „als erweiterbare Kette angelegt" wird in TP-B umgesetzt, wenn Stufe 2 dazukommt).
- **Typ-Konsistenz:** `AbgleichVorschau(ergebnis, alleOffenen, betriebName, padding)` in T3/T6; `istKundenzahlungsKandidat(CamtTransaction)→bool` in T2/T5; `AbgleichErgebnis`/`AutoBookerResult` wie bestehend.
- **Platzhalter:** keine.
- **Risiken:** T3 ist der größte Brocken (Code-Move); Verhalten muss identisch bleiben — bestehende Widget-/Service-Tests + analyze sichern ab. Booker-`uebersprungen`-Zählung durch die zusammengesetzte transactions-Liste (Bereich 2 + pre-Stichtag/bereits-verarbeitet) verifizieren.

# TP-C — QR-Referenz (SCOR) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Kundenrechnungen bekommen eine eindeutige Schweizer **SCOR**-Referenz (ISO 11649, `RF…`), gespeichert in `rechnungen.qr_referenz` und eingebettet in QR-Code + Zahlteil der Rechnungs-/Mahnungs-PDFs; der camt-Abgleich nutzt sie als **deterministische Matching-Stufe 1** vor Alias/Unscharf.

**Architecture:** SCOR (nicht QRR), weil die hinterlegte IBAN `CH6600774010376550601` eine **normale** Postfinance-IBAN ist (keine QR-IBAN). Eine reine, getestete Util (`scor_referenz.dart`) erzeugt/normalisiert Referenzen. Die Vergabe sitzt **zentral in `RechnungRepository.create`** (Kundentypen, heineken_monat ausgeschlossen) → deckt alle Erstellungs-Services ab. Matching-Stufe 1 (`strukturierteReferenz` → `qr_referenz`, exakt/normalisiert) läuft vor der bestehenden Betriebs-Gruppierung; verbrauchte Gutschriften/Rechnungen werden aus Stufe 2/3 ausgeschlossen.

**Tech Stack:** Flutter (Dart), Supabase (PostgREST) + Isar (offline). Swiss QR-bill via `barcode`-Package (bereits vorhanden). Tests: `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-06-20-camt-import-forderungsabgleich-merge-design.md` (Abschnitt „QR-Referenz (deterministisch …)").

---

## Hinweise für alle Tasks

- Setup einmal je Bash-Session:
  ```bash
  export PATH="$PATH:/c/flutter/bin"
  cd "D:/01_SBS_Projer_GmbH/00_Entwicklung/SBS Projer DEV/sbs_projer_app"
  ```
- Branch: **nicht** auf `main` implementieren — der Controller legt vor Task 1 den Branch `feature/camt-qr-referenz` an. Subagenten wechseln den Branch NICHT.
- `strukturierteReferenz` (camt) wird bereits geparst (`camt053_parser.dart` → `CamtTransaction.strukturierteReferenz`) — **keine** Parser-Änderung nötig.
- SCOR betrifft nur **Kundenrechnungen** (und Jahresrechnungen), nicht `heineken_monat`.

---

## Task 1: DB-Migration — Spalte `rechnungen.qr_referenz`

**Files:**
- Create: `Datenbank/migrations/104_rechnungen_qr_referenz.sql`

- [ ] **Step 1: Migrations-Datei schreiben**

Create `Datenbank/migrations/104_rechnungen_qr_referenz.sql`:
```sql
-- Migration 104: SCOR-Referenz (ISO 11649) für Kundenrechnungen (TP-C).
-- Wird bei der Rechnungserstellung vergeben, in den QR-Code/Zahlteil eingebettet
-- und beim camt-Abgleich als deterministische Matching-Stufe 1 genutzt.
-- Altbestand bleibt NULL; UNIQUE erlaubt mehrere NULL in Postgres.
ALTER TABLE rechnungen ADD COLUMN IF NOT EXISTS qr_referenz text;
CREATE UNIQUE INDEX IF NOT EXISTS rechnungen_qr_referenz_key
  ON rechnungen (qr_referenz) WHERE qr_referenz IS NOT NULL;
```

- [ ] **Step 2: Migration anwenden**

Über Supabase-MCP `apply_migration` (Projekt-ID `pltbaqqwpnmdajwgnhpd`), name `rechnungen_qr_referenz`, query = beide Statements aus Step 1.

- [ ] **Step 3: Verifizieren**

`execute_sql`:
```sql
select column_name, data_type from information_schema.columns
where table_name='rechnungen' and column_name='qr_referenz';
```
Erwartung: eine Zeile, `data_type = text`.

- [ ] **Step 4: Jahresrechnungs-Typ prüfen (für Task 4)**

Lies `sbs_projer_app/lib/services/rechnung/jahresrechnung_service.dart` um Zeile 172 und notiere den Wert von `'rechnungstyp'` im `create({...})`-Aufruf. Schreib ihn in den Commit-Body (z.B. „jahresrechnung nutzt rechnungstyp='kundenrechnung'"). Das bestimmt die Kundentypen-Menge in Task 4.

- [ ] **Step 5: Commit**
```bash
git add Datenbank/migrations/104_rechnungen_qr_referenz.sql
git commit -m "feat(db): Migration 104 — rechnungen.qr_referenz (TP-C)"
```

---

## Task 2: SCOR-Util (`scor_referenz.dart`) + Tests

**Files:**
- Create: `sbs_projer_app/lib/core/util/scor_referenz.dart`
- Test: `sbs_projer_app/test/scor_referenz_test.dart`

- [ ] **Step 1: Failing-Test schreiben**

Create `sbs_projer_app/test/scor_referenz_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/scor_referenz.dart';

void main() {
  test('kanonischer ISO-11649-Vektor', () {
    expect(scorReferenz('539007547034'), 'RF18539007547034');
  });

  test('erzeugte Referenz ist mod-97-gültig (RF…00-Regel)', () {
    final ref = scorReferenz('202606250001');
    expect(ref.startsWith('RF'), isTrue);
    // Verschiebe "RF"+Prüfziffern ans Ende, mod 97 muss 1 ergeben.
    expect(istGueltigeScor(ref), isTrue);
  });

  test('scorRefNorm: Leerzeichen weg, Uppercase', () {
    expect(scorRefNorm('rf18 5390 0754 7034'), 'RF18539007547034');
    expect(scorRefNorm(' RF18539007547034 '), 'RF18539007547034');
  });

  test('qrReferenzAusNummer: nur Kundentypen, Ziffern aus Nummer', () {
    expect(qrReferenzAusNummer('kundenrechnung', '2026-06-25-0001'),
        scorReferenz('202606250001'));
    expect(qrReferenzAusNummer('heineken_monat', '2026-06-25-0001'), isNull);
    expect(qrReferenzAusNummer('kundenrechnung', null), isNull);
  });
}
```

- [ ] **Step 2: Test ausführen → FAIL**
```bash
flutter test test/scor_referenz_test.dart
```
Erwartung: FAIL (Funktionen nicht definiert).

- [ ] **Step 3: Util implementieren**

Create `sbs_projer_app/lib/core/util/scor_referenz.dart`:
```dart
/// SCOR / ISO 11649 Creditor Reference (`RF` + 2 Prüfziffern + Body).
/// Body wird auf A–Z/0–9 reduziert und uppercased. Prüfziffer nach ISO 7064
/// MOD 97-10: 98 - (Body + "RF00", Buchstaben→Zahlen A=10..Z=35) mod 97.
String scorReferenz(String body) {
  final b = body.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
  final pruef = 98 - _mod97('${b}RF00');
  return 'RF${pruef.toString().padLeft(2, '0')}$b';
}

/// Prüft, ob [referenz] eine gültige SCOR-Referenz ist (Mod-97 == 1, wenn die
/// ersten 4 Zeichen ans Ende verschoben werden).
bool istGueltigeScor(String referenz) {
  final r = scorRefNorm(referenz);
  if (r.length < 5 || !r.startsWith('RF')) return false;
  return _mod97('${r.substring(4)}${r.substring(0, 4)}') == 1;
}

/// Normalisiert eine Referenz für den Vergleich: nur A–Z/0–9, Uppercase.
String scorRefNorm(String s) =>
    s.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');

/// Leitet die SCOR-Referenz aus der Rechnungsnummer ab — nur für Kundentypen
/// (heineken_monat ausgeschlossen). Body = Ziffern der Rechnungsnummer.
/// Liefert null, wenn kein Kundentyp, keine Nummer oder keine Ziffern.
String? qrReferenzAusNummer(String? rechnungstyp, String? rechnungsnummer) {
  const kundentypen = {'kundenrechnung', 'jahresrechnung'};
  if (!kundentypen.contains(rechnungstyp)) return null;
  if (rechnungsnummer == null) return null;
  final digits = rechnungsnummer.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;
  return scorReferenz(digits);
}

/// MOD 97 über einen alphanumerischen String: jede Ziffer 0–9 bleibt, jeder
/// Buchstabe A–Z wird zu 10–35 (zweistellig), iterativ gerechnet (kein BigInt).
int _mod97(String s) {
  var rem = 0;
  for (final ch in s.split('')) {
    final code = int.parse(ch, radix: 36); // '0'..'9'→0..9, 'A'..'Z'→10..35
    for (final d in code.toString().split('')) {
      rem = (rem * 10 + int.parse(d)) % 97;
    }
  }
  return rem;
}
```

> **Falls `kundentypen` laut Task-1-Step-4 abweicht** (z.B. Jahresrechnung nutzt einen anderen `rechnungstyp`), passe die Menge entsprechend an, damit genau die kundengezahlten Rechnungstypen eine Referenz bekommen.

- [ ] **Step 4: Test ausführen → PASS (4 Tests)**
```bash
flutter test test/scor_referenz_test.dart
```

- [ ] **Step 5: Commit**
```bash
git add lib/core/util/scor_referenz.dart test/scor_referenz_test.dart
git commit -m "feat(util): SCOR/ISO-11649 Referenz-Generator + Normalisierung (TP-C)"
```

---

## Task 3: Feld `qrReferenz` im Rechnungs-Modell

**Files:**
- Modify: `sbs_projer_app/lib/data/models/rechnung.dart`
- Modify: `sbs_projer_app/lib/data/local/rechnung_local.dart`
- Modify: `sbs_projer_app/lib/data/local/web/rechnung_local_web.dart`
- Modify: `sbs_projer_app/lib/data/mappers/rechnung_mapper.dart`
- Test: `sbs_projer_app/test/rechnung_qr_referenz_test.dart`

> Mirror the existing **nullable String** field `pdfUrl` exactly (declaration, constructor, fromJson `json['pdf_url']`, toJson `'pdf_url'`, copyWith, Isar field, web stub, mapper both directions). Field name: `qrReferenz`, JSON key: `qr_referenz`.

- [ ] **Step 1: Failing-Test schreiben**

Create `sbs_projer_app/test/rechnung_qr_referenz_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';

void main() {
  test('qrReferenz round-trips durch fromJson/toJson', () {
    final r = Rechnung.fromJson({
      'id': 'r1', 'user_id': 'u', 'rechnungstyp': 'kundenrechnung',
      'rechnungsdatum': '2026-06-25', 'faelligkeitsdatum': '2026-07-25',
      'qr_referenz': 'RF18539007547034',
    });
    expect(r.qrReferenz, 'RF18539007547034');
    expect(r.toJson()['qr_referenz'], 'RF18539007547034');
  });

  test('copyWith behält qrReferenz', () {
    final r = Rechnung(
      id: 'r1', userId: 'u', rechnungstyp: 'kundenrechnung',
      rechnungsdatum: DateTime(2026, 6, 25),
      faelligkeitsdatum: DateTime(2026, 7, 25),
      qrReferenz: 'RF18539007547034',
    );
    expect(r.copyWith().qrReferenz, 'RF18539007547034');
  });
}
```

- [ ] **Step 2: Test ausführen → FAIL**
```bash
flutter test test/rechnung_qr_referenz_test.dart
```

- [ ] **Step 3: DTO `rechnung.dart` erweitern**
- Feld nach `final String? pdfUrl;` (Zeile 24): `final String? qrReferenz;`
- Konstruktor nach `this.pdfUrl,` (Zeile 52): `this.qrReferenz,`
- `fromJson` nach `pdfUrl: json['pdf_url'],` (Zeile 96): `qrReferenz: json['qr_referenz'],`
- `toJson` nach `'pdf_url': pdfUrl,` (Zeile 127): `'qr_referenz': qrReferenz,`
- `copyWith`: im Konstruktoraufruf nach `pdfUrl: pdfUrl,` (Zeile 162): `qrReferenz: qrReferenz,`

- [ ] **Step 4: Isar-Local `rechnung_local.dart`** — `String? qrReferenz;` analog zum vorhandenen `String? pdfUrl;` ergänzen.

- [ ] **Step 5: Web-Stub `web/rechnung_local_web.dart`** — `String? qrReferenz;` analog `pdfUrl` ergänzen.

- [ ] **Step 6: Mapper `rechnung_mapper.dart`** — in `fromDto` `local.qrReferenz = dto.qrReferenz;` (analog `pdfUrl`) und in `toJson` `'qr_referenz': local.qrReferenz,` (analog `'pdf_url'`) ergänzen.

- [ ] **Step 7: Isar-Code generieren**
```bash
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 8: Test ausführen → PASS (2 Tests)**
```bash
flutter test test/rechnung_qr_referenz_test.dart
```

- [ ] **Step 9: Commit**
```bash
git add lib/data/models/rechnung.dart lib/data/local/rechnung_local.dart lib/data/local/web/rechnung_local_web.dart lib/data/mappers/rechnung_mapper.dart lib/data/local/rechnung_local.g.dart test/rechnung_qr_referenz_test.dart
git commit -m "feat(model): rechnung.qrReferenz (DTO/Isar/Web/Mapper) (TP-C)"
```
(`.g.dart` ist evtl. gitignored — wenn `git add` es überspringt, ist das ok.)

---

## Task 4: SCOR-Vergabe zentral in `RechnungRepository.create`

**Files:**
- Modify: `sbs_projer_app/lib/data/repositories/rechnung_repository.dart` (um Zeile 84)

> Die reine Ableitlogik (`qrReferenzAusNummer`) ist bereits in Task 2 getestet. Hier nur die Verdrahtung.

- [ ] **Step 1: Lies** `rechnung_repository.dart` Zeilen 80–100 (die `create`-Methode), um die exakte Form des Insert/Returns zu sehen.

- [ ] **Step 2: Import ergänzen**
```dart
import 'package:sbs_projer_app/core/util/scor_referenz.dart';
```

- [ ] **Step 3: In `create(Map<String, dynamic> json)`** ganz am Anfang des Methodenrumpfs (vor dem Supabase-Insert) einfügen:
```dart
    // SCOR-Referenz für Kundenrechnungen vergeben (einmalig, idempotent).
    if (json['qr_referenz'] == null) {
      final ref = qrReferenzAusNummer(
        json['rechnungstyp'] as String?,
        json['rechnungsnummer'] as String?,
      );
      if (ref != null) {
        json = {...json, 'qr_referenz': ref};
      }
    }
```
(Der zurückgegebene `Rechnung.fromJson(row)` trägt `qrReferenz` dann automatisch, da die Spalte mitgeschrieben wird.)

- [ ] **Step 4: Analyze**
```bash
flutter analyze lib/data/repositories/rechnung_repository.dart
```
Erwartung: keine Fehler.

- [ ] **Step 5: Commit**
```bash
git add lib/data/repositories/rechnung_repository.dart
git commit -m "feat(rechnung): SCOR-Referenz zentral bei create() vergeben (TP-C)"
```

---

## Task 5: SCOR in Rechnungs- und Mahnungs-PDF einbetten

**Files:**
- Modify: `sbs_projer_app/lib/services/pdf/rechnung_pdf_service.dart`
- Modify: `sbs_projer_app/lib/services/pdf/mahnung_pdf_service.dart`

> **Lies beide Dateien sorgfältig.** Eine fehlerhafte QR-Rechnung geht an Kunden — sorgfältig arbeiten. In beiden Dateien gibt es `_buildQrData(double betrag, _KundeAdresse kunde, {String? mitteilung})` mit den Zeilen `'NON', // Reference Type` und `'', // Reference`, sowie den gedruckten Zahlteil.

### rechnung_pdf_service.dart

- [ ] **Step 1:** `_buildQrData` um einen Referenz-Parameter erweitern. Signatur ändern zu:
```dart
  static String _buildQrData(double betrag, _KundeAdresse kunde,
      {String? mitteilung, String? referenz}) {
```
und die beiden Referenz-Zeilen ersetzen:
```dart
      'NON', // Reference Type
      '', // Reference
```
durch:
```dart
      (referenz != null && referenz.isNotEmpty) ? 'SCOR' : 'NON', // Reference Type
      referenz ?? '', // Reference
```

- [ ] **Step 2:** An der Aufrufstelle (`final qrData = _buildQrData(betrag, kunde, mitteilung: mitteilung);`, ~Zeile 367) die Referenz aus der Rechnung durchreichen. Finde im Scope das `rechnung`-Objekt (Parameter von `generate`) und ergänze:
```dart
    final qrData = _buildQrData(betrag, kunde,
        mitteilung: mitteilung, referenz: rechnung.qrReferenz);
```
Falls `rechnung` an dieser Stelle nicht direkt im Scope ist, reiche `rechnung.qrReferenz` als lokale Variable (z.B. `final referenz = rechnung.qrReferenz;`) von `generate` bis hierher durch.

- [ ] **Step 3:** Im gedruckten Zahlteil einen **Referenz**-Abschnitt ergänzen. Finde den Block (≈ Zeile 500–505):
```dart
                  _qrSectionTitle('Konto / Zahlbar an'),
                  _qrText(_ibanFormatted),
                  _qrText(_firmaName),
                  _qrText('$_firmaStrasse $_firmaNr'),
                  _qrText('$_firmaPlz $_firmaOrt'),
                  pw.SizedBox(height: 6),
```
und füge **direkt danach** ein:
```dart
                  if (referenz != null && referenz.isNotEmpty) ...[
                    _qrSectionTitle('Referenz'),
                    _qrText(_scorAnzeige(referenz)),
                    pw.SizedBox(height: 6),
                  ],
```
Dafür muss `referenz` in der Zahlteil-bauenden Methode im Scope sein — reiche sie als Parameter dieser Methode durch (dieselbe Methode, die `qrData`/`betragStr`/`kunde` erhält). Ergänze außerdem den Anzeige-Helfer (Gruppen zu 4 ab links) bei den anderen `_qr*`-Helfern:
```dart
  /// SCOR-Referenz in 4er-Gruppen für die Anzeige: RF18 5390 0754 7034.
  static String _scorAnzeige(String ref) {
    final r = ref.replaceAll(' ', '');
    final sb = StringBuffer();
    for (var i = 0; i < r.length; i += 4) {
      if (i > 0) sb.write(' ');
      sb.write(r.substring(i, i + 4 > r.length ? r.length : i + 4));
    }
    return sb.toString();
  }
```

### mahnung_pdf_service.dart

- [ ] **Step 4:** Dieselben Änderungen wie Step 1–3 in `mahnung_pdf_service.dart` (Aufruf ~Zeile 301, `_buildQrData` ~Zeile 445). Die Mahnung betrifft eine bestehende Rechnung — verwende deren `qrReferenz` (gleicher Wert wie auf der Originalrechnung), damit eine Mahnungszahlung dieselbe Referenz trägt. Falls die Mahnungs-`generate` die `Rechnung` bereits erhält, `rechnung.qrReferenz` durchreichen; den `_scorAnzeige`-Helfer ebenfalls ergänzen.

- [ ] **Step 5: Analyze + Web-Build (QR-Pfad kompiliert)**
```bash
flutter analyze lib/services/pdf/rechnung_pdf_service.dart lib/services/pdf/mahnung_pdf_service.dart
```
Erwartung: keine neuen Fehler.

- [ ] **Step 6: Commit**
```bash
git add lib/services/pdf/rechnung_pdf_service.dart lib/services/pdf/mahnung_pdf_service.dart
git commit -m "feat(pdf): SCOR-Referenz in QR-Code + Zahlteil (Rechnung+Mahnung) (TP-C)"
```

---

## Task 6: Matching-Stufe 1 (QR-Referenz) im Abgleich

**Files:**
- Modify: `sbs_projer_app/lib/services/camt/forderungs_abgleich_service.dart`
- Test: `sbs_projer_app/test/forderungs_abgleich_service_test.dart`

- [ ] **Step 1: Failing-Test schreiben**

Lies zuerst die vorhandenen Hilfs-Konstruktoren `_gut(...)`/`_rg(...)` im Test-File. Erweitere sie bei Bedarf um optionale Parameter (`strukturierteReferenz` bei `_gut`, `qrReferenz` bei `_rg`) — analog zu deren bestehenden Feldern. Füge dann in `main()` ein:
```dart
  test('QR-Referenz-Treffer (Stufe 1) ordnet exakt zu, vor Betrieb-Logik', () {
    final betriebe = [
      {'id': 'b1', 'name': 'Hotel Alpina', 'aliase': ''},
    ];
    // Zahlername passt NICHT auf den Betrieb — nur die Referenz verbindet.
    final gut = _gutMitRef(100.00, 'Wildfremd AG', 'RF18539007547034');
    final rg = _rgMitRef('r1', 'b1', 100.00, 'RF18539007547034');
    final erg = ForderungsAbgleichService.abgleich(
      gutschriften: [gut], offeneForderungen: [rg], betriebe: betriebe,
    );
    expect(erg.auto.length, 1);
    expect(erg.auto.first.forderungen.first.id, 'r1');
    expect(erg.auto.first.forderungen.length, 1);
  });
```
Lege dazu zwei lokale Helfer an (oder erweitere `_gut`/`_rg`), z.B.:
```dart
  CamtTransaction _gutMitRef(double amt, String party, String ref) =>
      CamtTransaction(
        amount: amt, currency: 'CHF', isCredit: true,
        bookingDate: DateTime(2026, 4, 1),
        partyName: party, strukturierteReferenz: ref, txKey: '$party-$amt',
      );
```
(Pflichtfelder an die bestehenden Helfer im File angleichen.) Für `_rgMitRef` analog eine `Rechnung` mit `qrReferenz: ref` bauen.

- [ ] **Step 2: Test ausführen → FAIL** (Referenz wird ignoriert → `erg.auto` leer)
```bash
flutter test test/forderungs_abgleich_service_test.dart
```

- [ ] **Step 3: Stufe 1 implementieren**

In `forderungs_abgleich_service.dart`:
- Import ergänzen:
```dart
import 'package:sbs_projer_app/core/util/scor_referenz.dart';
```
- Direkt nach der Methoden-Signatur von `abgleich(...)` (vor `// 1. Gutschriften pro Betrieb gruppieren`) einfügen:
```dart
    // STUFE 1: deterministischer QR-/SCOR-Referenz-Match (vor der Gruppierung).
    final refTreffer = <AutoTreffer>[];
    final verbrauchteGuts = <CamtTransaction>{};
    final verbrauchteFordIds = <String>{};
    final refIndex = <String, Rechnung>{};
    for (final r in offeneForderungen) {
      final ref = r.qrReferenz;
      if (ref != null && ref.trim().isNotEmpty) {
        refIndex[scorRefNorm(ref)] = r;
      }
    }
    for (final g in gutschriften.where((g) => g.isCredit)) {
      final sref = g.strukturierteReferenz;
      if (sref == null || sref.trim().isEmpty) continue;
      final r = refIndex[scorRefNorm(sref)];
      if (r == null || verbrauchteFordIds.contains(r.id)) continue;
      refTreffer.add(AutoTreffer(g, [r]));
      verbrauchteGuts.add(g);
      verbrauchteFordIds.add(r.id);
    }
    final gutschriftenAktiv =
        gutschriften.where((g) => !verbrauchteGuts.contains(g)).toList();
    final offeneAktiv = offeneForderungen
        .where((r) => !verbrauchteFordIds.contains(r.id))
        .toList();
```
- Danach die bestehenden Stufen auf die gefilterten Listen umstellen:
  - `for (final g in gutschriften.where((g) => g.isCredit))` (Gruppierung, ~Zeile 43) → `for (final g in gutschriftenAktiv.where((g) => g.isCredit))`
  - `for (final r in offeneForderungen)` (~Zeile 53) → `for (final r in offeneAktiv)`
  - In der „unbekannt"-Schleife `for (final g in gutschriften.where((g) => g.isCredit))` (~Zeile 100) → `for (final g in gutschriftenAktiv.where((g) => g.isCredit))`
- Das `return` am Ende ändern, sodass die Referenz-Treffer den Auto-Treffern vorangestellt werden:
```dart
    return AbgleichErgebnis([...refTreffer, ...auto], manuell, keineZahlung, unbekannt);
```

- [ ] **Step 4: Test ausführen → PASS** (neuer + alle bestehenden Tests)
```bash
flutter test test/forderungs_abgleich_service_test.dart
```

- [ ] **Step 5: Analyze**
```bash
flutter analyze lib/services/camt/forderungs_abgleich_service.dart
```

- [ ] **Step 6: Commit**
```bash
git add lib/services/camt/forderungs_abgleich_service.dart test/forderungs_abgleich_service_test.dart
git commit -m "feat(camt): QR-Referenz als Matching-Stufe 1 im Abgleich (TP-C)"
```

---

## Task 7: Gesamtverifikation + Deploy

**Files:** keine (Build/Deploy)

- [ ] **Step 1: Volle Analyse** — `flutter analyze` → keine neuen Errors (vorbestehende info-Lints ok).
- [ ] **Step 2: Komplette Testsuite** — `flutter test` → alle grün (neu: scor_referenz, rechnung_qr_referenz, forderungs_abgleich Stufe-1).
- [ ] **Step 3: Web-Build** — `export MSYS_NO_PATHCONV=1 && flutter build web --base-href "/sbs-projer-dev/" --pwa-strategy=none` → „Built build/web".
- [ ] **Step 4: Manueller Test (Pflicht, Daniel)** — Browser:
  1. Neue Kundenrechnung erzeugen (Reinigung abschließen) → PDF öffnen → Zahlteil zeigt **Referenz `RF…`**, QR-Code enthält SCOR. Mit einer Banking-App / einem QR-Reader gegenprüfen, dass der QR scanbar ist und die Referenz trägt.
  2. camt-Import mit einer Gutschrift, deren `<Strd><Ref>` = die `qr_referenz` der Rechnung → erscheint als 🟢 exakter Treffer (Stufe 1), unabhängig vom Zahlernamen.
- [ ] **Step 5: Version bumpen** — `pubspec.yaml` Zeile 4 (z.B. `0.13.0+442`).
- [ ] **Step 6: Deploy** — gemäß `CLAUDE.md` (Build `--pwa-strategy=none`, `main.dart.js` cache-busten, `flutter_service_worker.js` löschen, auf `gh-pages` kopieren, committen, pushen, zurück auf `main`, beide pushen). Vorher alle `main`-Änderungen committen (kein `git stash`).

---

## Selbst-Review (Spec-Abdeckung)

- **`rechnungen.qr_referenz` (UNIQUE, NULL-fähig)** → Task 1.
- **SCOR-Generator + Normalisierung (rein, getestet, kanonischer Vektor)** → Task 2.
- **Modell-Feld `qrReferenz` (inkl. copyWith — sonst geht die Referenz bei PDF-Generierung via copyWith verloren)** → Task 3.
- **Zentrale Vergabe (Kundentypen, heineken_monat aus), deckt alle create-Pfade** → Task 4 (+ Typ-Verifikation Task 1 Step 4).
- **PDF-Einbettung SCOR + gedruckte Referenz, Rechnung UND Mahnung (gleiche Referenz)** → Task 5.
- **Matching-Stufe 1 vor Alias/Unscharf, verbrauchte ausgeschlossen, Einzel-Rechnung** → Task 6.
- **Keine Parser-Änderung** (strukturierteReferenz existiert) — bewusst.
- Nicht im Scope: QRR/QR-IBAN (verworfen, normale IBAN); IBAN aus `geschaeft_einstellungen` statt hardcodiert (separate Aufgabe).

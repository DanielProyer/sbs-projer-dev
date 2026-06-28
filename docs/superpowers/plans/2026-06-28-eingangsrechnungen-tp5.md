# TP-5 camt-Kreditor-Abschluss (Stufe 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development oder inline TDD. Steps mit Checkbox.

**Goal:** Eine camt-Belastung (DBIT) wird einer offenen, Stufe-1-gebuchten Eingangsrechnung zugeordnet und Stufe 2 gebucht (Kreditorkonto → Bank 1020), Status `bezahlt`, im Bestätigungs-Modus.

**Architecture:** Reine Matching-Funktion (`KreditorenAbgleichService`) + Booker (`CamtKreditorBooker`), eingehängt in `CamtAutoBooker.plan()`/`bucheVorschlag()` über einen neuen `CamtVorschlagTyp.kreditor`. Keine Migration (Spalten/Index aus Migration 106 vorhanden, `status` ist frei). Idempotenz dreifach (Screen-`getAlleCamtTxKeys`, Kandidaten-Filter, Booker-`getByBeleg`). `camt_tx_key` auf Buchung UND Eingangsrechnung → Reversibilität (TP-6).

**Tech Stack:** Flutter, Supabase, bestehende camt-Pipeline.

**Verifizierte Fakten:** kein CHECK auf `eingangsrechnung.status`; Konten 1020 Bankguthaben / 2000 Kreditoren existieren; DBIT läuft über `camt_import_screen.dart:347-353` → `CamtAutoBooker.plan()`. Stufe-1-Buchung: Aufwand brutto (soll) AN Kreditorkonto (haben, Default 2000); `buchung_stufe1_id` = erste Zeile → deren `haben_konto` = das zu entlastende Kreditorkonto.

---

### Task 1: KreditorenAbgleichService (reines Matching)

**Files:**
- Create: `sbs_projer_app/lib/services/eingangsrechnung/kreditoren_abgleich_service.dart`
- Test: `sbs_projer_app/test/kreditoren_abgleich_service_test.dart`

- [ ] **Step 1: Test schreiben** (`kreditoren_abgleich_service_test.dart`):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/camt_transaction.dart';
import 'package:sbs_projer_app/data/models/eingangsrechnung.dart';
import 'package:sbs_projer_app/services/eingangsrechnung/kreditoren_abgleich_service.dart';

CamtTransaction _tx({
  bool isCredit = false,
  double amount = 100.0,
  String? ref,
  String? iban,
  String? name,
}) =>
    CamtTransaction(
      amount: amount,
      currency: 'CHF',
      isCredit: isCredit,
      bookingDate: DateTime(2026, 6, 20),
      txKey: 'K1',
      strukturierteReferenz: ref,
      partyIban: iban,
      partyName: name,
    );

Eingangsrechnung _er({
  String id = 'e1',
  String? ref,
  String? iban,
  String? name,
  double betrag = 100.0,
}) =>
    Eingangsrechnung(
      id: id,
      userId: 'u',
      qrReferenz: ref,
      lieferantIban: iban,
      ausstellerName: name,
      betragBrutto: betrag,
      status: 'exportiert',
      buchungStufe1Id: 'b1',
    );

void main() {
  test('Referenz + Betrag -> Treffer', () {
    final tx = _tx(ref: '00 00000 00410 ...', amount: 100);
    final e = _er(ref: '000000000410...', betrag: 100);
    expect(KreditorenAbgleichService.match(tx, [e])?.id, 'e1');
  });

  test('Gutschrift (CRDT) -> kein Treffer', () {
    final tx = _tx(isCredit: true, iban: 'CH93...', amount: 100);
    final e = _er(iban: 'CH93...', betrag: 100);
    expect(KreditorenAbgleichService.match(tx, [e]), isNull);
  });

  test('IBAN + Betrag -> Treffer (ohne Referenz)', () {
    final tx = _tx(iban: 'CH9300762011623852957', amount: 250);
    final e = _er(iban: 'CH93 0076 2011 6238 5295 7', betrag: 250);
    expect(KreditorenAbgleichService.match(tx, [e])?.id, 'e1');
  });

  test('IBAN passt, Betrag weicht ab -> kein Treffer', () {
    final tx = _tx(iban: 'CH93...', amount: 250);
    final e = _er(iban: 'CH93...', betrag: 999);
    expect(KreditorenAbgleichService.match(tx, [e]), isNull);
  });

  test('mehrdeutig (2 gleiche IBAN+Betrag) -> kein Auto-Treffer', () {
    final tx = _tx(iban: 'CH93...', amount: 100);
    final a = _er(id: 'a', iban: 'CH93...', betrag: 100);
    final b = _er(id: 'b', iban: 'CH93...', betrag: 100);
    expect(KreditorenAbgleichService.match(tx, [a, b]), isNull);
  });

  test('Name + Betrag -> Treffer (kein Ref/IBAN)', () {
    final tx = _tx(name: 'Heineken Switzerland AG', amount: 50);
    final e = _er(name: 'Heineken', betrag: 50);
    expect(KreditorenAbgleichService.match(tx, [e])?.id, 'e1');
  });
}
```

- [ ] **Step 2: Lauf (FAIL)** `flutter test test/kreditoren_abgleich_service_test.dart`
- [ ] **Step 3: Implementierung** (`kreditoren_abgleich_service.dart`):

```dart
import 'package:sbs_projer_app/core/util/scor_referenz.dart';
import 'package:sbs_projer_app/data/models/camt_transaction.dart';
import 'package:sbs_projer_app/data/models/eingangsrechnung.dart';

/// Ordnet eine camt-Belastung (DBIT/Ausgang) einer offenen Eingangsrechnung zu.
///
/// Reine Funktion (kein IO) — Kandidaten werden übergeben. Reihenfolge:
/// 1. strukturierte Referenz (QRR/SCOR, normalisiert) + Betrag
/// 2. Lieferant-IBAN + Betrag
/// 3. Name (Substring) + Betrag
/// Mehrdeutig (>1 Treffer) oder kein Treffer -> null (Prüfliste/manuell).
class KreditorenAbgleichService {
  static double _round2(double v) => (v * 100).roundToDouble() / 100;
  static bool _betragGleich(double a, double b) => _round2(a) == _round2(b);
  static String _ibanNorm(String? s) =>
      (s ?? '').replaceAll(' ', '').toUpperCase();

  /// [kandidaten]: offene Eingangsrechnungen (Stufe-1 gebucht, noch nicht bezahlt).
  static Eingangsrechnung? match(
      CamtTransaction tx, List<Eingangsrechnung> kandidaten) {
    if (tx.isCredit) return null; // nur Belastungen
    final betrag = tx.amount;

    // 1) strukturierte Referenz (QRR/SCOR) exakt + Betrag
    final ref = scorRefNorm(tx.strukturierteReferenz ?? '');
    if (ref.isNotEmpty) {
      final t = kandidaten
          .where((e) =>
              scorRefNorm(e.qrReferenz ?? '') == ref &&
              _betragGleich(e.betragBrutto, betrag))
          .toList();
      if (t.length == 1) return t.first;
      if (t.length > 1) return null;
    }

    // 2) Lieferant-IBAN + Betrag
    final iban = _ibanNorm(tx.partyIban);
    if (iban.isNotEmpty) {
      final t = kandidaten
          .where((e) =>
              _ibanNorm(e.lieferantIban) == iban &&
              _betragGleich(e.betragBrutto, betrag))
          .toList();
      if (t.length == 1) return t.first;
      if (t.length > 1) return null;
    }

    // 3) Name (Substring, beidseitig) + Betrag
    final name = (tx.partyName ?? '').toLowerCase().trim();
    if (name.isNotEmpty) {
      final t = kandidaten.where((e) {
        final an = (e.ausstellerName ?? '').toLowerCase().trim();
        if (an.isEmpty) return false;
        return (name.contains(an) || an.contains(name)) &&
            _betragGleich(e.betragBrutto, betrag);
      }).toList();
      if (t.length == 1) return t.first;
    }
    return null;
  }
}
```

- [ ] **Step 4: Lauf (PASS)**, **Step 5: Commit**

---

### Task 2: CamtVorschlag um Typ `kreditor` erweitern

**Files:** Modify `sbs_projer_app/lib/services/camt/camt_vorschlag.dart`

- [ ] **Step 1:** Import ergänzen: `import 'package:sbs_projer_app/data/models/eingangsrechnung.dart';`
- [ ] **Step 2:** `enum CamtVorschlagTyp { ausgabe, heineken }` → `{ ausgabe, heineken, kreditor }`
- [ ] **Step 3:** In `class CamtVorschlag` Feld + Konstruktor-Param ergänzen:
  - Feld nach `heinekenRechnung`: `final Eingangsrechnung? eingangsrechnung; // bei typ == kreditor`
  - Konstruktor: `this.eingangsrechnung,` (named, optional)
- [ ] **Step 4:** `flutter analyze lib/services/camt/camt_vorschlag.dart` → clean. Commit.

---

### Task 3: CamtKreditorBooker (bucht Stufe 2)

**Files:** Create `sbs_projer_app/lib/services/camt/camt_kreditor_booker.dart`

- [ ] **Step 1: Implementierung:**

```dart
import 'package:sbs_projer_app/data/models/camt_transaction.dart';
import 'package:sbs_projer_app/data/models/eingangsrechnung.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/data/repositories/eingangsrechnung_repository.dart';

/// Stufe 2 des Kreditorenmodells: bucht die Bank-Belastung einer Lieferanten-
/// zahlung (Kreditorkonto → Bank 1020) und setzt die Eingangsrechnung auf
/// 'bezahlt'. Idempotent: existiert bereits eine Zahlungs-Buchung zum Beleg,
/// passiert nichts.
class CamtKreditorBooker {
  static const int bankKonto = 1020;
  static const int kreditorKontoDefault = 2000;

  static double _round2(double v) => (v * 100).roundToDouble() / 100;

  static Future<void> book(CamtTransaction tx, Eingangsrechnung e) async {
    // Idempotenz: bereits Stufe-2 gebucht?
    final existing = await BuchungRepository.getByBeleg(e.id);
    if (existing.any((b) => b.belegTyp == 'zahlung' && !b.istStorniert)) {
      return;
    }

    // Kreditorkonto, das Stufe 1 bebucht hat, rekonstruieren (Sonderkonten!).
    int kreditorKonto = kreditorKontoDefault;
    if (e.buchungStufe1Id != null) {
      final stufe1 = await BuchungRepository.getById(e.buchungStufe1Id!);
      if (stufe1 != null) kreditorKonto = stufe1.habenKonto;
    }

    final brutto = _round2(e.betragBrutto);
    final datumStr = tx.bookingDate.toIso8601String().split('T').first;

    final buchung = await BuchungRepository.create({
      'datum': datumStr,
      'belegnummer': e.rechnungsnummer,
      'soll_konto': kreditorKonto,
      'haben_konto': bankKonto,
      'betrag_netto': brutto,
      'mwst_satz': 0,
      'mwst_betrag': 0,
      'betrag_brutto': brutto,
      'beschreibung': 'Zahlung Kreditor ${e.ausstellerName ?? ''}'.trim(),
      'zahlungsweg': 'bank',
      'beleg_typ': 'zahlung',
      'beleg_id': e.id,
      'geschaeftsjahr': tx.bookingDate.year,
      'camt_tx_key': tx.txKey,
    });

    await EingangsrechnungRepository.update(e.id, {
      'status': 'bezahlt',
      'bezahlt_am': datumStr,
      'buchung_stufe2_id': buchung.id,
      'camt_tx_key': tx.txKey,
    });
  }
}
```

- [ ] **Step 2:** `flutter analyze` der Datei → clean. Commit.

---

### Task 4: Integration in CamtAutoBooker.plan() + bucheVorschlag()

**Files:** Modify `sbs_projer_app/lib/services/camt/camt_auto_booker.dart`; Test `sbs_projer_app/test/camt_kreditor_plan_test.dart`

- [ ] **Step 1: Test** (`camt_kreditor_plan_test.dart`): plan() mit einer DBIT-Tx + passender offener Eingangsrechnung liefert genau einen Vorschlag mit `typ == CamtVorschlagTyp.kreditor` und `eingangsrechnung.id` korrekt; ohne Kandidat → Prüfliste.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/camt_transaction.dart';
import 'package:sbs_projer_app/data/models/eingangsrechnung.dart';
import 'package:sbs_projer_app/services/camt/camt_auto_booker.dart';
import 'package:sbs_projer_app/services/camt/camt_vorschlag.dart';

void main() {
  final tx = CamtTransaction(
    amount: 100, currency: 'CHF', isCredit: false,
    bookingDate: DateTime(2026, 6, 20), txKey: 'K1',
    partyIban: 'CH9300762011623852957', partyName: 'Lieferant X',
    additionalInfo: 'Lieferant X',
  );
  final e = Eingangsrechnung(
    id: 'e1', userId: 'u', lieferantIban: 'CH9300762011623852957',
    betragBrutto: 100, status: 'exportiert', buchungStufe1Id: 'b1',
  );

  test('DBIT + offene Eingangsrechnung -> Kreditor-Vorschlag', () {
    final r = CamtAutoBooker.plan(
      transactions: [tx], heinekenRechnungen: [], regeln: [],
      vorlagenById: {}, offeneKreditoren: [e]);
    expect(r.vorschlaege.length, 1);
    expect(r.vorschlaege.first.typ, CamtVorschlagTyp.kreditor);
    expect(r.vorschlaege.first.eingangsrechnung?.id, 'e1');
  });

  test('DBIT ohne Kandidat -> Prüfliste (kein Kreditor-Vorschlag)', () {
    final r = CamtAutoBooker.plan(
      transactions: [tx], heinekenRechnungen: [], regeln: [],
      vorlagenById: {}, offeneKreditoren: []);
    expect(r.vorschlaege.where((v) => v.typ == CamtVorschlagTyp.kreditor),
        isEmpty);
    expect(r.pruefliste.length, 1);
  });
}
```

- [ ] **Step 2: Lauf (FAIL).**
- [ ] **Step 3: Implementierung:**
  - Import ergänzen: `import 'package:sbs_projer_app/data/models/eingangsrechnung.dart';` und `import 'package:sbs_projer_app/services/camt/camt_kreditor_booker.dart';` und `import 'package:sbs_projer_app/services/eingangsrechnung/kreditoren_abgleich_service.dart';`
  - `plan()`-Signatur: neuen optionalen Param ergänzen: `List<Eingangsrechnung> offeneKreditoren = const [],`
  - Im `case TxKategorie.bargeldEinzahlung: case TxKategorie.ausgabe:` GANZ AM ANFANG (vor `RegelMatcher`):

```dart
          // TP-5: Kreditor-Abschluss VOR dem Ausgaben-Regelwerk (nur Belastungen).
          if (!tx.isCredit) {
            final e = KreditorenAbgleichService.match(tx, offeneKreditoren);
            if (e != null) {
              vorschlaege.add(CamtVorschlag(
                tx: tx,
                typ: CamtVorschlagTyp.kreditor,
                eingangsrechnung: e,
                label:
                    'Kreditor-Zahlung ${e.ausstellerName ?? ''} → bezahlt (${e.betragBrutto.toStringAsFixed(2)})',
              ));
              break;
            }
          }
```

  - `bucheVorschlag()` auf `switch (v.typ)` umstellen, mit Kreditor-Zweig zuerst:

```dart
  static Future<void> bucheVorschlag(CamtVorschlag v) async {
    switch (v.typ) {
      case CamtVorschlagTyp.kreditor:
        await CamtKreditorBooker.book(v.tx, v.eingangsrechnung!);
        break;
      case CamtVorschlagTyp.ausgabe:
        await CamtAusgabeBooker.book(v.tx, v.vorlage!);
        break;
      case CamtVorschlagTyp.heineken:
        final b = await HeinekenBuchungService.createZahlungseingang(
            v.heinekenRechnung!, datum: v.tx.bookingDate);
        if (b != null) {
          await BuchungRepository.setCamtTxKey(b.id, v.tx.txKey);
          final datumStr = v.tx.bookingDate.toIso8601String().split('T').first;
          await RechnungRepository.update(v.heinekenRechnung!.id, {
            'zahlungsstatus': 'bezahlt',
            'zahlung_eingegangen_am': datumStr,
            'zahlung_betrag': v.heinekenRechnung!.betragBrutto,
          });
        }
        break;
    }
  }
```

- [ ] **Step 4: Lauf (PASS)** + `flutter analyze camt_auto_booker.dart`. **Step 5: Commit.**

---

### Task 5: Screen-Verdrahtung (offene Kreditoren laden + an plan() geben)

**Files:** Modify `sbs_projer_app/lib/presentation/screens/buchhaltung/camt_import_screen.dart`

- [ ] **Step 1:** Import `eingangsrechnung_repository.dart` ergänzen.
- [ ] **Step 2:** Vor dem `CamtAutoBooker.plan(...)`-Aufruf (≈ Zeile 350) offene Kreditoren laden:

```dart
      final offeneKreditoren = (await EingangsrechnungRepository
              .getByStatus(['gebucht', 'exportiert']))
          .where((e) =>
              e.camtTxKey == null &&
              e.bezahltAm == null &&
              e.buchungStufe1Id != null)
          .toList();
```

- [ ] **Step 3:** Im `CamtAutoBooker.plan(...)`-Aufruf `offeneKreditoren: offeneKreditoren,` ergänzen.
- [ ] **Step 4:** `flutter analyze` der Datei. Commit.

---

### Task 6: Gesamtverifikation

- [ ] `flutter analyze` (ganzes Projekt) — 0 Errors.
- [ ] `flutter test` — alle grün.
- [ ] `flutter build web` — erfolgreich.
- [ ] Adversariale Review (Doppelbuchung/Idempotenz, Kontorekonstruktion, Vorzeichen, Reversibilitäts-Stempel, Spec-Treue) → bestätigte Findings fixen.
- [ ] Version-Bump + Deploy + Memory/ToDo.

## Self-Review
- Spec-Abdeckung: Matching-Kette (Ref/IBAN/Name) ✓, CamtKreditorBooker (2000/Sonderkonto → 1020) ✓, Integration in CamtAutoBooker VOR Regel-Match ✓, camt_tx_key-Stempel (Buchung+Rechnung) ✓, Bestätigungs-Modus ✓.
- Typkonsistenz: `KreditorenAbgleichService.match`, `CamtKreditorBooker.book`, `CamtVorschlagTyp.kreditor`, `CamtVorschlag.eingangsrechnung` durchgängig.
- Offen/empirisch: GKB-Referenz-Rückspielung im camt (Fallback IBAN+Betrag deckt ab); Reversibilität = TP-6.

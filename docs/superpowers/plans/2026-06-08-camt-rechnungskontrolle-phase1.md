# camt-Rechnungskontrolle Phase 1 — Implementierungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** camt.053-Upload übernimmt ab Stichtag 01.07.2026 Zahlungen automatisch in die Buchhaltung und führt die Rechnungskontrolle (Kundenzahlung + Heineken) durch; Unklares landet in einer persistenten Prüfliste.

**Architecture:** Pipeline `Parser → Stichtag-Filter → Dedup → Klassifizierer → (Auto-Booker | Prüfliste)`. Reine Logik (Parser/Klassifizierer/Matcher) ist als statische, seiteneffektfreie Funktionen unit-testbar; Persistenz über bestehende Repositories + neue Supabase-Tabelle `camt_pruefliste`. Wiederverwendung von `ZahlungsdifferenzService`, `HeinekenBuchungService`, `CamtBetriebMatcher`, `BankbelegPdfService`.

**Tech Stack:** Flutter/Dart, Riverpod, Supabase (online-only für Buchhaltung), `package:xml`, `flutter_test`.

**Scope:** Nur Phase 1. Phase 2 (Ausgaben-Regelwerk `camt_regel` + 4 neue Buchungsvorlagen 5700/5720/5730/8900 + „Regel anlegen"-UI) bekommt einen eigenen Plan. Referenz-Specs: `docs/superpowers/specs/2026-06-08-camt-rechnungskontrolle-design.md`, `…-buchungsvorlagen-vorschlag.md`.

---

## Dateistruktur

**Neu:**
- `lib/services/camt/camt_stichtag.dart` — Stichtag-Konstante + Filterhilfe.
- `lib/services/camt/camt_klassifizierer.dart` — Tx → `TxKategorie`.
- `lib/services/camt/rechnung_matcher.dart` — Kundenzahlung → offene Rechnung(en), reine Logik.
- `lib/services/camt/heineken_matcher.dart` — Heineken-Eingang → heineken_monat-Rechnung.
- `lib/services/camt/camt_auto_booker.dart` — Orchestrierung Auto-Buchung + Dedup.
- `lib/data/models/camt_pruefliste_eintrag.dart` — DTO.
- `lib/data/repositories/camt_pruefliste_repository.dart` — CRUD (Supabase).
- `lib/presentation/providers/camt_pruefliste_providers.dart` — Riverpod.
- `lib/presentation/screens/buchhaltung/camt_pruefliste_screen.dart` — UI.
- `Datenbank/migrations/0XX_camt_pruefliste.sql` — Migration.
- `test/camt_parser_test.dart`, `test/camt_klassifizierer_test.dart`, `test/rechnung_matcher_test.dart`.

**Geändert:**
- `lib/data/models/camt_transaction.dart` — Felder `txKey`, `strukturierteReferenz`, `isBatchChild`, `kategorie`.
- `lib/services/camt/camt053_parser.dart` — Batch-Split, Strd-Ref, txKey.
- `lib/services/buchhaltung/zahlungsdifferenz_service.dart` — optionaler `datum`-Parameter.
- `lib/presentation/screens/buchhaltung/camt_import_screen.dart` — automatischer Lauf + Report.
- `lib/core/config/router.dart` — Route Prüfliste.

---

## Task 1: CamtTransaction um Felder erweitern

**Files:**
- Modify: `lib/data/models/camt_transaction.dart`

- [ ] **Step 1: Felder ergänzen**

In `class CamtTransaction` zu den bestehenden mutierbaren Import-Feldern (`selected`, `matchedBetriebId`, …) hinzufügen:

```dart
  // camt-Pipeline (Phase 1)
  final String txKey;                 // eindeutiger Dedup-Schlüssel
  final String? strukturierteReferenz; // ESR/QR/ISR aus Strd/CdtrRefInf/Ref
  final bool isBatchChild;            // Teil eines Sammelauftrags
  String? kategorie;                  // gesetzt vom Klassifizierer
```

Im Konstruktor `txKey` als `required this.txKey`, `this.strukturierteReferenz`, `this.isBatchChild = false`, `this.kategorie` ergänzen.

- [ ] **Step 2: Analyze**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze lib/data/models/camt_transaction.dart`
Expected: Fehler in `camt053_parser.dart` (txKey fehlt) — wird in Task 2 behoben. Modell selbst fehlerfrei.

- [ ] **Step 3: Commit**

```bash
git add sbs_projer_app/lib/data/models/camt_transaction.dart
git commit -m "feat(camt): CamtTransaction um txKey/strukturierteReferenz/isBatchChild/kategorie"
```

---

## Task 2: Parser — Batch-Split, Strd-Referenz, txKey (TDD)

**Files:**
- Test: `test/camt_parser_test.dart`
- Modify: `lib/services/camt/camt053_parser.dart`

- [ ] **Step 1: Failing-Test schreiben**

`test/camt_parser_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/camt/camt053_parser.dart';

const _batchXml = '''<?xml version="1.0"?>
<Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.04"><BkToCstmrStmt><Stmt>
<Id>T</Id><Acct><Id><IBAN>CH6600774010376550601</IBAN></Id><Ccy>CHF</Ccy>
<Ownr><Nm>SBS Projer GmbH</Nm></Ownr></Acct>
<FrToDt><FrDtTm>2026-07-01T00:00:00</FrDtTm><ToDtTm>2026-07-31T23:59:59</ToDtTm></FrToDt>
<Ntry><Amt Ccy="CHF">200.00</Amt><CdtDbtInd>DBIT</CdtDbtInd><Sts>BOOK</Sts>
<BookgDt><Dt>2026-07-10</Dt></BookgDt><ValDt><Dt>2026-07-10</Dt></ValDt>
<AcctSvcrRef>ZV20260710/111</AcctSvcrRef>
<NtryDtls>
<TxDtls><Refs><AcctSvcrRef>ZV20260710/111/1</AcctSvcrRef></Refs><Amt Ccy="CHF">120.00</Amt>
<CdtDbtInd>DBIT</CdtDbtInd><RltdPties><Cdtr><Nm>Swisscom AG</Nm></Cdtr></RltdPties>
<RmtInf><Strd><CdtrRefInf><Ref>001329672833009201211220224</Ref></CdtrRefInf></Strd></RmtInf></TxDtls>
<TxDtls><Refs><AcctSvcrRef>ZV20260710/111/2</AcctSvcrRef></Refs><Amt Ccy="CHF">80.00</Amt>
<CdtDbtInd>DBIT</CdtDbtInd><RltdPties><Cdtr><Nm>Suva</Nm></Cdtr></RltdPties></TxDtls>
</NtryDtls></Ntry>
</Stmt></BkToCstmrStmt></Document>''';

void main() {
  test('Sammelauftrag wird in zwei Transaktionen gesplittet', () {
    final stmt = Camt053Parser.parse(_batchXml);
    expect(stmt.transactions.length, 2);
    final swisscom = stmt.transactions.firstWhere((t) => t.partyName == 'Swisscom AG');
    expect(swisscom.amount, 120.00);
    expect(swisscom.isBatchChild, true);
    expect(swisscom.strukturierteReferenz, '001329672833009201211220224');
    expect(swisscom.txKey, 'ZV20260710/111/1');
  });

  test('txKey ist pro Teiltransaktion eindeutig', () {
    final stmt = Camt053Parser.parse(_batchXml);
    final keys = stmt.transactions.map((t) => t.txKey).toSet();
    expect(keys.length, 2);
  });
}
```

- [ ] **Step 2: Test laufen — muss fehlschlagen**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test test/camt_parser_test.dart`
Expected: FAIL (Parser liefert 1 statt 2 Transaktionen).

- [ ] **Step 3: Parser umbauen**

In `camt053_parser.dart`: `_parseEntry` ersetzen durch `_parseEntries` (gibt Liste zurück). Schleife in `parse` anpassen:

```dart
    for (final ntry in _findElements(stmt, 'Ntry')) {
      transactions.addAll(_parseEntries(ntry, ccy));
    }
```

Neue Methode `_parseEntries`:

```dart
  static List<CamtTransaction> _parseEntries(XmlElement ntry, String defaultCcy) {
    final isCredit = _text(_findElement(ntry, 'CdtDbtInd')) == 'CRDT';
    final bookingDtStr = _text(_findElement(_findElement(ntry, 'BookgDt'), 'Dt'));
    if (bookingDtStr == null) return [];
    final bookingDate = DateTime.parse(bookingDtStr);
    final valueDtStr = _text(_findElement(_findElement(ntry, 'ValDt'), 'Dt'));
    final valueDate = valueDtStr != null ? DateTime.parse(valueDtStr) : null;
    final ntryRef = _text(_findElement(ntry, 'AcctSvcrRef'));
    final ntryAddtlInfo = _text(_findElement(ntry, 'AddtlNtryInf'));

    final ntryDtls = _findElement(ntry, 'NtryDtls');
    final txDtlsList = ntryDtls == null
        ? const <XmlElement>[]
        : _findElements(ntryDtls, 'TxDtls').toList();
    final isBatch = txDtlsList.length > 1;

    // Kein TxDtls: Ntry-Ebene als eine Transaktion (z.B. Saldovortrag, Bargeld)
    if (txDtlsList.isEmpty) {
      final amount = double.tryParse(_attr(_findElement(ntry, 'Amt')) ?? '0') ?? 0;
      final ccy = _findElement(ntry, 'Amt')?.getAttribute('Ccy') ?? defaultCcy;
      return [CamtTransaction(
        amount: amount, currency: ccy, isCredit: isCredit,
        bookingDate: bookingDate, valueDate: valueDate,
        accountServiceRef: ntryRef, partyAddressLines: const [],
        additionalInfo: ntryAddtlInfo,
        txKey: _buildTxKey(ntryRef, null, bookingDate, amount, isCredit, null, null),
      )];
    }

    final result = <CamtTransaction>[];
    for (final txDtls in txDtlsList) {
      final amount = double.tryParse(_attr(_findElement(txDtls, 'Amt')) ?? '0') ?? 0;
      final ccy = _findElement(txDtls, 'Amt')?.getAttribute('Ccy') ?? defaultCcy;
      final refs = _findElement(txDtls, 'Refs');
      var endToEndId = _text(_findElement(refs, 'EndToEndId'));
      if (endToEndId == 'NOTPROVIDED') endToEndId = null;
      final txSvcrRef = _text(_findElement(refs, 'AcctSvcrRef')) ?? ntryRef;
      final txId = _text(_findElement(refs, 'TxId'));

      String? partyName, partyIban, partyStreet, partyBuildingNr,
          partyPostCode, partyCity, partyCountry;
      List<String> partyAddressLines = [];
      final rltdPties = _findElement(txDtls, 'RltdPties');
      if (rltdPties != null) {
        final party = isCredit ? _findElement(rltdPties, 'Dbtr') : _findElement(rltdPties, 'Cdtr');
        final partyAcct = isCredit ? _findElement(rltdPties, 'DbtrAcct') : _findElement(rltdPties, 'CdtrAcct');
        if (party != null) {
          partyName = _text(_findElement(party, 'Nm'));
          final addr = _findElement(party, 'PstlAdr');
          if (addr != null) {
            partyStreet = _text(_findElement(addr, 'StrtNm'));
            partyBuildingNr = _text(_findElement(addr, 'BldgNb'));
            partyPostCode = _text(_findElement(addr, 'PstCd'));
            partyCity = _text(_findElement(addr, 'TwnNm'));
            partyCountry = _text(_findElement(addr, 'Ctry'));
            partyAddressLines = _findElements(addr, 'AdrLine')
                .map((e) => e.innerText.trim()).where((s) => s.isNotEmpty).toList();
          }
        }
        if (partyAcct != null) {
          partyIban = _text(_findElement(_findElement(partyAcct, 'Id'), 'IBAN'));
        }
      }
      final rmtInf = _findElement(txDtls, 'RmtInf');
      final remittanceInfo = _text(_findElement(rmtInf, 'Ustrd'));
      final strdRef = _text(_findElement(
          _findElement(_findElement(_findElement(rmtInf, 'Strd'), 'CdtrRefInf'), 'Ref') == null
              ? null
              : _findElement(_findElement(rmtInf, 'Strd'), 'CdtrRefInf'),
          'Ref'));
      final additionalInfo = _text(_findElement(txDtls, 'AddtlTxInf')) ?? ntryAddtlInfo;

      result.add(CamtTransaction(
        amount: amount, currency: ccy, isCredit: isCredit,
        bookingDate: bookingDate, valueDate: valueDate,
        accountServiceRef: txSvcrRef, endToEndId: endToEndId, transactionId: txId,
        partyName: partyName, partyIban: partyIban, partyStreet: partyStreet,
        partyBuildingNr: partyBuildingNr, partyPostCode: partyPostCode,
        partyCity: partyCity, partyCountry: partyCountry,
        partyAddressLines: partyAddressLines, remittanceInfo: remittanceInfo,
        additionalInfo: additionalInfo, strukturierteReferenz: strdRef,
        isBatchChild: isBatch,
        txKey: _buildTxKey(txSvcrRef, txId, bookingDate, amount, isCredit, partyName, endToEndId),
      ));
    }
    return result;
  }

  static String _buildTxKey(String? svcrRef, String? txId, DateTime date,
      double amount, bool isCredit, String? party, String? e2e) {
    if (svcrRef != null && svcrRef.isNotEmpty) return svcrRef;
    if (txId != null && txId.isNotEmpty) return txId;
    final d = date.toIso8601String().split('T').first;
    return '$d|${amount.toStringAsFixed(2)}|${isCredit ? 'C' : 'D'}'
        '|${party ?? ''}|${e2e ?? ''}';
  }
```

> Hinweis: `_findElement(null, …)` muss `null` zurückgeben — ist bereits so implementiert. Den verschachtelten Strd-Ausdruck ggf. durch zwei Zeilen ersetzen, falls lesbarer:
> ```dart
> final strd = _findElement(rmtInf, 'Strd');
> final strdRef = _text(_findElement(_findElement(strd, 'CdtrRefInf'), 'Ref'));
> ```

- [ ] **Step 4: Test laufen — muss bestehen**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test test/camt_parser_test.dart`
Expected: PASS (2 Tests).

- [ ] **Step 5: Analyze + Commit**

Run: `flutter analyze lib/services/camt/camt053_parser.dart`
```bash
git add sbs_projer_app/lib/services/camt/camt053_parser.dart sbs_projer_app/test/camt_parser_test.dart
git commit -m "feat(camt): Parser splittet Sammelaufträge, liest Strd-Referenz, baut txKey"
```

---

## Task 3: Stichtag-Konstante + Filter (TDD)

**Files:**
- Create: `lib/services/camt/camt_stichtag.dart`
- Test: `test/camt_parser_test.dart` (Test anhängen)

- [ ] **Step 1: Failing-Test anhängen**

In `test/camt_parser_test.dart` ergänzen:

```dart
  test('Stichtag: vor 01.07.2026 nicht automatisiert', () {
    expect(CamtStichtag.istAutomatisierbar(DateTime(2026, 6, 30)), false);
    expect(CamtStichtag.istAutomatisierbar(DateTime(2026, 7, 1)), true);
  });
```
Import oben ergänzen: `import 'package:sbs_projer_app/services/camt/camt_stichtag.dart';`

- [ ] **Step 2: Test laufen — FAIL** (Klasse fehlt)

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test test/camt_parser_test.dart`

- [ ] **Step 3: Implementieren**

`lib/services/camt/camt_stichtag.dart`:

```dart
/// Ab diesem Buchungsdatum greift die automatische Rechnungskontrolle/Buchung.
/// Alles davor bleibt im bestehenden System.
class CamtStichtag {
  static final DateTime stichtag = DateTime(2026, 7, 1);
  static bool istAutomatisierbar(DateTime bookingDate) =>
      !bookingDate.isBefore(stichtag);
}
```

- [ ] **Step 4: Test laufen — PASS**

Run: `flutter test test/camt_parser_test.dart`

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/services/camt/camt_stichtag.dart sbs_projer_app/test/camt_parser_test.dart
git commit -m "feat(camt): Stichtag 01.07.2026 für Automatik"
```

---

## Task 4: DB-Migration — camt_tx_key + camt_pruefliste

**Files:**
- Create: `Datenbank/migrations/0XX_camt_pruefliste.sql` (nächste freie Nummer ermitteln)

- [ ] **Step 1: Nächste Migrationsnummer ermitteln**

Run: `ls Datenbank/migrations/ | sort | tail -3`
Dateinamen mit der nächsten freien Nummer wählen (z.B. `095_camt_pruefliste.sql`).

- [ ] **Step 2: Migration schreiben**

```sql
-- camt-Auto-Buchung Phase 1: Dedup-Schlüssel + Prüfliste
ALTER TABLE buchungen ADD COLUMN IF NOT EXISTS camt_tx_key TEXT;
CREATE INDEX IF NOT EXISTS idx_buchungen_camt_tx_key ON buchungen(camt_tx_key);

CREATE TABLE IF NOT EXISTS camt_pruefliste (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  tx_key TEXT NOT NULL,
  booking_datum DATE NOT NULL,
  betrag NUMERIC(12,2) NOT NULL,
  ist_gutschrift BOOLEAN NOT NULL,
  partei_name TEXT,
  referenz TEXT,
  kategorie TEXT NOT NULL,
  vorschlag_json JSONB,
  status TEXT NOT NULL DEFAULT 'offen'
    CHECK (status IN ('offen','erledigt','ignoriert')),
  fehlertext TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id, tx_key)
);
ALTER TABLE camt_pruefliste ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own rows" ON camt_pruefliste
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
```

- [ ] **Step 3: Migration anwenden** (via Supabase MCP `apply_migration`, Project-ID `pltbaqqwpnmdajwgnhpd`).

Verify: `SELECT column_name FROM information_schema.columns WHERE table_name='camt_pruefliste';`
Expected: alle Spalten vorhanden.

- [ ] **Step 4: Commit**

```bash
git add Datenbank/migrations/0XX_camt_pruefliste.sql
git commit -m "feat(db): camt_tx_key + camt_pruefliste (Migration)"
```

---

## Task 5: Prüflisten-DTO + Repository

**Files:**
- Create: `lib/data/models/camt_pruefliste_eintrag.dart`
- Create: `lib/data/repositories/camt_pruefliste_repository.dart`

- [ ] **Step 1: DTO**

```dart
class CamtPrueflisteEintrag {
  final String? id;
  final String txKey;
  final DateTime bookingDatum;
  final double betrag;
  final bool istGutschrift;
  final String? parteiName;
  final String? referenz;
  final String kategorie;
  final Map<String, dynamic>? vorschlag;
  final String status;
  final String? fehlertext;

  CamtPrueflisteEintrag({
    this.id, required this.txKey, required this.bookingDatum,
    required this.betrag, required this.istGutschrift, this.parteiName,
    this.referenz, required this.kategorie, this.vorschlag,
    this.status = 'offen', this.fehlertext,
  });

  factory CamtPrueflisteEintrag.fromJson(Map<String, dynamic> j) => CamtPrueflisteEintrag(
    id: j['id'], txKey: j['tx_key'],
    bookingDatum: DateTime.parse(j['booking_datum']),
    betrag: (j['betrag'] as num).toDouble(),
    istGutschrift: j['ist_gutschrift'],
    parteiName: j['partei_name'], referenz: j['referenz'],
    kategorie: j['kategorie'], vorschlag: j['vorschlag_json'],
    status: j['status'], fehlertext: j['fehlertext'],
  );

  Map<String, dynamic> toInsert(String userId) => {
    'user_id': userId, 'tx_key': txKey,
    'booking_datum': bookingDatum.toIso8601String().split('T').first,
    'betrag': betrag, 'ist_gutschrift': istGutschrift,
    'partei_name': parteiName, 'referenz': referenz, 'kategorie': kategorie,
    'vorschlag_json': vorschlag, 'status': status, 'fehlertext': fehlertext,
  };
}
```

- [ ] **Step 2: Repository** (Muster aus bestehenden Repos, online-only)

```dart
import 'package:sbs_projer_app/data/models/camt_pruefliste_eintrag.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class CamtPrueflisteRepository {
  static Future<List<CamtPrueflisteEintrag>> getOffen() async {
    final rows = await SupabaseService.client
        .from('camt_pruefliste').select().eq('status', 'offen')
        .order('booking_datum');
    return (rows as List).map((r) => CamtPrueflisteEintrag.fromJson(r)).toList();
  }

  static Future<Set<String>> getAlleTxKeys() async {
    final rows = await SupabaseService.client.from('camt_pruefliste').select('tx_key');
    return (rows as List).map((r) => r['tx_key'] as String).toSet();
  }

  static Future<void> insert(CamtPrueflisteEintrag e) async {
    final uid = SupabaseService.client.auth.currentUser!.id;
    await SupabaseService.client.from('camt_pruefliste').insert(e.toInsert(uid));
  }

  static Future<void> setStatus(String id, String status) async {
    await SupabaseService.client.from('camt_pruefliste')
        .update({'status': status, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', id);
  }
}
```

- [ ] **Step 3: Analyze + Commit**

Run: `flutter analyze lib/data/models/camt_pruefliste_eintrag.dart lib/data/repositories/camt_pruefliste_repository.dart`
```bash
git add sbs_projer_app/lib/data/models/camt_pruefliste_eintrag.dart sbs_projer_app/lib/data/repositories/camt_pruefliste_repository.dart
git commit -m "feat(camt): Prüflisten-DTO + Repository"
```

---

## Task 6: Klassifizierer (TDD)

**Files:**
- Create: `lib/services/camt/camt_klassifizierer.dart`
- Test: `test/camt_klassifizierer_test.dart`

- [ ] **Step 1: Failing-Test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/camt_transaction.dart';
import 'package:sbs_projer_app/services/camt/camt_klassifizierer.dart';

CamtTransaction _tx({required bool credit, String? name, String? addtl, double amt = 100}) =>
    CamtTransaction(amount: amt, currency: 'CHF', isCredit: credit,
      bookingDate: DateTime(2026, 7, 10), partyAddressLines: const [],
      partyName: name, additionalInfo: addtl, txKey: 'k');

void main() {
  test('Heineken-Eingang → heinekenEingang', () {
    expect(CamtKlassifizierer.kategorie(_tx(credit: true, name: 'HEINEKEN SWITZERLAND AG'),
        betriebErkannt: false), TxKategorie.heinekenEingang);
  });
  test('Bargeld → bargeldEinzahlung', () {
    expect(CamtKlassifizierer.kategorie(
        _tx(credit: true, addtl: 'Geldautomaten Einzahlung GKB'), betriebErkannt: false),
        TxKategorie.bargeldEinzahlung);
  });
  test('Saldovortrag → saldovortrag', () {
    expect(CamtKlassifizierer.kategorie(_tx(credit: true, addtl: 'Saldovortrag'),
        betriebErkannt: false), TxKategorie.saldovortrag);
  });
  test('Eingang mit Betrieb → kundenzahlung', () {
    expect(CamtKlassifizierer.kategorie(_tx(credit: true, name: 'Hotel Rovanada AG'),
        betriebErkannt: true), TxKategorie.kundenzahlung);
  });
  test('Eingang ohne Betrieb → unbekannt', () {
    expect(CamtKlassifizierer.kategorie(_tx(credit: true, name: 'Irgendwer'),
        betriebErkannt: false), TxKategorie.unbekannt);
  });
  test('Ausgang → ausgabe', () {
    expect(CamtKlassifizierer.kategorie(_tx(credit: false, name: 'Swisscom AG'),
        betriebErkannt: false), TxKategorie.ausgabe);
  });
}
```

- [ ] **Step 2: Test laufen — FAIL**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test test/camt_klassifizierer_test.dart`

- [ ] **Step 3: Implementieren**

```dart
import 'package:sbs_projer_app/data/models/camt_transaction.dart';

enum TxKategorie {
  kundenzahlung, heinekenEingang, bargeldEinzahlung, ausgabe,
  saldovortrag, unbekannt,
}

class CamtKlassifizierer {
  static TxKategorie kategorie(CamtTransaction tx, {required bool betriebErkannt}) {
    final info = '${tx.additionalInfo ?? ''} ${tx.partyName ?? ''}'.toLowerCase();
    if (info.contains('saldovortrag')) return TxKategorie.saldovortrag;
    if (tx.isCredit) {
      if ((tx.partyName ?? '').toLowerCase().contains('heineken')) {
        return TxKategorie.heinekenEingang;
      }
      if (info.contains('geldautomaten') || info.contains('posteinzahlung') ||
          info.contains('six token')) {
        return TxKategorie.bargeldEinzahlung;
      }
      if (betriebErkannt) return TxKategorie.kundenzahlung;
      return TxKategorie.unbekannt;
    }
    return TxKategorie.ausgabe; // Ausgaben-Regelwerk in Phase 2; vorerst Prüfliste
  }
}
```

- [ ] **Step 4: Test laufen — PASS**

Run: `flutter test test/camt_klassifizierer_test.dart`

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/services/camt/camt_klassifizierer.dart sbs_projer_app/test/camt_klassifizierer_test.dart
git commit -m "feat(camt): Klassifizierer für Tx-Kategorien"
```

---

## Task 7: Rechnungs-Matcher Kundenzahlung (TDD, reine Logik)

**Files:**
- Create: `lib/services/camt/rechnung_matcher.dart`
- Test: `test/rechnung_matcher_test.dart`

- [ ] **Step 1: Failing-Test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/services/camt/rechnung_matcher.dart';

Rechnung _rg(String id, double brutto) => Rechnung(
  id: id, userId: 'u', rechnungstyp: 'kundenrechnung', betriebId: 'b1',
  rechnungsdatum: DateTime(2026, 7, 1), faelligkeitsdatum: DateTime(2026, 7, 31),
  betragBrutto: brutto, zahlungsstatus: 'offen');

void main() {
  test('Genau 1 Rechnung, Betrag exakt → eindeutig', () {
    final r = RechnungMatcher.match(zahlbetrag: 130.30, offeneRechnungen: [_rg('a', 130.30), _rg('b', 99.00)]);
    expect(r.eindeutig, true);
    expect(r.rechnungen.map((e) => e.id), ['a']);
  });
  test('Summe zweier Rechnungen = Betrag, eindeutige Kombination → Sammel', () {
    final r = RechnungMatcher.match(zahlbetrag: 229.30, offeneRechnungen: [_rg('a', 130.30), _rg('b', 99.00)]);
    expect(r.eindeutig, true);
    expect(r.rechnungen.map((e) => e.id).toSet(), {'a', 'b'});
  });
  test('Mehrdeutige Kombination → nicht eindeutig', () {
    final r = RechnungMatcher.match(zahlbetrag: 100.00,
        offeneRechnungen: [_rg('a', 100.00), _rg('b', 100.00)]);
    expect(r.eindeutig, false);
  });
  test('Kein passender Betrag → nicht eindeutig', () {
    final r = RechnungMatcher.match(zahlbetrag: 55.00, offeneRechnungen: [_rg('a', 130.30)]);
    expect(r.eindeutig, false);
  });
}
```

- [ ] **Step 2: Test laufen — FAIL**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test test/rechnung_matcher_test.dart`

- [ ] **Step 3: Implementieren** (5-Rappen-genau, Teilmengensuche bis 4 Rechnungen)

```dart
import 'package:sbs_projer_app/data/models/rechnung.dart';

class MatchErgebnis {
  final bool eindeutig;
  final List<Rechnung> rechnungen;
  MatchErgebnis(this.eindeutig, this.rechnungen);
}

class RechnungMatcher {
  static int _rappen(double v) => (v * 20).round(); // 5-Rappen-Einheiten

  /// Findet die eindeutige Teilmenge offener Rechnungen, deren Summe dem
  /// Zahlbetrag entspricht. Eindeutig = genau eine Kombination passt.
  static MatchErgebnis match({
    required double zahlbetrag,
    required List<Rechnung> offeneRechnungen,
  }) {
    final ziel = _rappen(zahlbetrag);
    final items = offeneRechnungen.take(20).toList(); // Schutz gegen Kombinatorik
    final treffer = <List<Rechnung>>[];

    // Subset-Suche bis Größe 4 (typische Sammelzahlung)
    void suche(int start, List<Rechnung> akku, int summe) {
      if (summe == ziel && akku.isNotEmpty) { treffer.add(List.of(akku)); return; }
      if (summe > ziel || akku.length >= 4) return;
      for (var i = start; i < items.length; i++) {
        akku.add(items[i]);
        suche(i + 1, akku, summe + _rappen(items[i].betragBrutto));
        akku.removeLast();
      }
    }
    suche(0, [], 0);

    if (treffer.length == 1) return MatchErgebnis(true, treffer.first);
    return MatchErgebnis(false, const []);
  }
}
```

- [ ] **Step 4: Test laufen — PASS**

Run: `flutter test test/rechnung_matcher_test.dart`

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/services/camt/rechnung_matcher.dart sbs_projer_app/test/rechnung_matcher_test.dart
git commit -m "feat(camt): Rechnungs-Matcher (exakt + eindeutige Sammelzahlung)"
```

---

## Task 8: ZahlungsdifferenzService — Datum-Parameter

**Files:**
- Modify: `lib/services/buchhaltung/zahlungsdifferenz_service.dart`

- [ ] **Step 1: Optionalen Parameter ergänzen**

In `verbuchen` und `verbuchenSammel` Signatur erweitern: `{… , DateTime? datum}` und `final datumStr = (datum ?? DateTime.now()).toIso8601String().split('T').first;` verwenden statt `DateTime.now()`. Ebenso `'geschaeftsjahr': (datum ?? DateTime.now()).year`.

- [ ] **Step 2: Analyze**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze lib/services/buchhaltung/zahlungsdifferenz_service.dart`
Expected: keine neuen Fehler (Parameter ist optional, bestehende Aufrufer unverändert).

- [ ] **Step 3: Commit**

```bash
git add sbs_projer_app/lib/services/buchhaltung/zahlungsdifferenz_service.dart
git commit -m "feat(buchhaltung): ZahlungsdifferenzService akzeptiert echtes Buchungsdatum"
```

---

## Task 9: Heineken-Matcher

**Files:**
- Create: `lib/services/camt/heineken_matcher.dart`

- [ ] **Step 1: Implementieren** (Betrag-Match gegen heineken_monat-Rechnungen mit Status offen/gesendet/freigegeben)

```dart
import 'package:sbs_projer_app/data/models/rechnung.dart';

class HeinekenMatcher {
  /// Liefert die eindeutige Heineken-Monatsrechnung mit passendem Bruttobetrag,
  /// sonst null (→ Prüfliste).
  static Rechnung? match({
    required double zahlbetrag,
    required List<Rechnung> heinekenRechnungen,
  }) {
    int rappen(double v) => (v * 20).round();
    final ziel = rappen(zahlbetrag);
    final passende = heinekenRechnungen
        .where((r) => r.rechnungstyp == 'heineken_monat')
        .where((r) => r.zahlungsstatus != 'bezahlt')
        .where((r) => rappen(r.betragBrutto) == ziel)
        .toList();
    return passende.length == 1 ? passende.first : null;
  }
}
```

- [ ] **Step 2: Analyze + Commit**

Run: `flutter analyze lib/services/camt/heineken_matcher.dart`
```bash
git add sbs_projer_app/lib/services/camt/heineken_matcher.dart
git commit -m "feat(camt): Heineken-Matcher (Betrag → heineken_monat-Rechnung)"
```

---

## Task 10: Auto-Booker (Orchestrierung + Dedup)

**Files:**
- Create: `lib/services/camt/camt_auto_booker.dart`

Diese Komponente fügt die reinen Logik-Bausteine zusammen und schreibt in die DB. Sie wird über den Import-Screen aufgerufen.

- [ ] **Step 1: Implementieren**

```dart
import 'package:sbs_projer_app/data/models/camt_transaction.dart';
import 'package:sbs_projer_app/data/models/camt_pruefliste_eintrag.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/data/repositories/camt_pruefliste_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/services/buchhaltung/heineken_buchung_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/zahlungsdifferenz_service.dart';
import 'package:sbs_projer_app/services/camt/camt_betrieb_matcher.dart';
import 'package:sbs_projer_app/services/camt/camt_klassifizierer.dart';
import 'package:sbs_projer_app/services/camt/camt_stichtag.dart';
import 'package:sbs_projer_app/services/camt/heineken_matcher.dart';
import 'package:sbs_projer_app/services/camt/rechnung_matcher.dart';

class AutoBookerResult {
  int gebucht = 0, pruefliste = 0, uebersprungen = 0;
  final List<String> fehler = [];
}

class CamtAutoBooker {
  /// Verarbeitet alle Transaktionen ab Stichtag. Eindeutige → Buchung,
  /// Unklare → Prüfliste. Idempotent über txKey.
  static Future<AutoBookerResult> run({
    required List<CamtTransaction> transactions,
    required List<Map<String, String>> betriebe,           // {id,name}
    required List<Rechnung> offeneRechnungen,               // status offen/gesendet
    required List<Rechnung> heinekenRechnungen,
    required Set<String> bereitsVerarbeitet,                // txKeys aus buchungen + pruefliste
  }) async {
    final res = AutoBookerResult();

    for (final tx in transactions) {
      if (!CamtStichtag.istAutomatisierbar(tx.bookingDate)) { res.uebersprungen++; continue; }
      if (bereitsVerarbeitet.contains(tx.txKey)) { res.uebersprungen++; continue; }

      final match = CamtBetriebMatcher.findBestMatch(tx.partyName, betriebe);
      final betriebId = match?['id'];
      final kat = CamtKlassifizierer.kategorie(tx, betriebErkannt: betriebId != null);
      tx.kategorie = kat.name;

      try {
        switch (kat) {
          case TxKategorie.saldovortrag:
            res.uebersprungen++;
            break;

          case TxKategorie.kundenzahlung:
            final offen = offeneRechnungen.where((r) => r.betriebId == betriebId).toList();
            final m = RechnungMatcher.match(zahlbetrag: tx.amount, offeneRechnungen: offen);
            if (m.eindeutig) {
              await ZahlungsdifferenzService.verbuchenSammel(
                rechnungen: m.rechnungen, zahlungBetrag: tx.amount, datum: tx.bookingDate);
              for (final r in m.rechnungen) {
                await RechnungRepository.setBezahlt(r.id, tx.bookingDate, tx.amount);
              }
              await _markBuchungTxKey(tx);
              res.gebucht++;
            } else {
              await _zurPruefliste(tx, kat, vorschlagBetrieb: match?['name']);
              res.pruefliste++;
            }
            break;

          case TxKategorie.heinekenEingang:
            final hr = HeinekenMatcher.match(
                zahlbetrag: tx.amount, heinekenRechnungen: heinekenRechnungen);
            if (hr != null) {
              await HeinekenBuchungService.createZahlungseingang(hr);
              await RechnungRepository.setBezahlt(hr.id, tx.bookingDate, tx.amount);
              await _markBuchungTxKey(tx);
              res.gebucht++;
            } else {
              await _zurPruefliste(tx, kat);
              res.pruefliste++;
            }
            break;

          case TxKategorie.bargeldEinzahlung:
          case TxKategorie.ausgabe:
          case TxKategorie.unbekannt:
            // Phase 1: keine Auto-Regel → Prüfliste (Ausgaben-Regelwerk = Phase 2)
            await _zurPruefliste(tx, kat, vorschlagBetrieb: match?['name']);
            res.pruefliste++;
            break;
        }
      } catch (e) {
        await _zurPrueflisteMitFehler(tx, kat, e.toString());
        res.pruefliste++;
        res.fehler.add('${tx.partyName ?? tx.txKey}: $e');
      }
    }
    return res;
  }

  static Future<void> _markBuchungTxKey(CamtTransaction tx) async {
    // Die zuletzt für diese Zahlung erzeugte(n) Buchung(en) tragen den txKey,
    // damit ein erneuter Upload sie als verarbeitet erkennt.
    await BuchungRepository.setCamtTxKeyForBeleg(tx.accountServiceRef, tx.txKey);
  }

  static Future<void> _zurPruefliste(CamtTransaction tx, TxKategorie kat,
      {String? vorschlagBetrieb}) async {
    await CamtPrueflisteRepository.insert(CamtPrueflisteEintrag(
      txKey: tx.txKey, bookingDatum: tx.bookingDate, betrag: tx.amount,
      istGutschrift: tx.isCredit, parteiName: tx.partyName,
      referenz: tx.strukturierteReferenz ?? tx.remittanceInfo,
      kategorie: kat.name,
      vorschlag: vorschlagBetrieb != null ? {'betrieb': vorschlagBetrieb} : null,
    ));
  }

  static Future<void> _zurPrueflisteMitFehler(
      CamtTransaction tx, TxKategorie kat, String fehler) async {
    await CamtPrueflisteRepository.insert(CamtPrueflisteEintrag(
      txKey: tx.txKey, bookingDatum: tx.bookingDate, betrag: tx.amount,
      istGutschrift: tx.isCredit, parteiName: tx.partyName,
      referenz: tx.strukturierteReferenz ?? tx.remittanceInfo,
      kategorie: kat.name, fehlertext: fehler,
    ));
  }
}
```

- [ ] **Step 2: Fehlende Repository-Methoden ergänzen**

In `RechnungRepository` (falls nicht vorhanden) hinzufügen:
```dart
  static Future<void> setBezahlt(String id, DateTime am, double betrag) async {
    await SupabaseService.client.from('rechnungen').update({
      'zahlungsstatus': 'bezahlt',
      'zahlung_eingegangen_am': am.toIso8601String().split('T').first,
      'zahlung_betrag': betrag,
    }).eq('id', id);
  }
```
In `BuchungRepository` hinzufügen:
```dart
  static Future<void> setCamtTxKeyForBeleg(String? belegnummer, String txKey) async {
    if (belegnummer == null) return;
    await SupabaseService.client.from('buchungen')
        .update({'camt_tx_key': txKey}).eq('belegnummer', belegnummer);
  }
  static Future<Set<String>> getAlleCamtTxKeys() async {
    final rows = await SupabaseService.client
        .from('buchungen').select('camt_tx_key').not('camt_tx_key', 'is', null);
    return (rows as List).map((r) => r['camt_tx_key'] as String).toSet();
  }
```
> Vorher prüfen, ob ähnliche Methoden bereits existieren (DRY) — ggf. wiederverwenden statt duplizieren.

- [ ] **Step 3: Analyze + Commit**

Run: `flutter analyze lib/services/camt/camt_auto_booker.dart lib/data/repositories/rechnung_repository.dart lib/data/repositories/buchung_repository.dart`
```bash
git add sbs_projer_app/lib/services/camt/camt_auto_booker.dart sbs_projer_app/lib/data/repositories/rechnung_repository.dart sbs_projer_app/lib/data/repositories/buchung_repository.dart
git commit -m "feat(camt): Auto-Booker orchestriert Buchung/Prüfliste mit Dedup"
```

---

## Task 11: Prüflisten-UI + Provider + Route

**Files:**
- Create: `lib/presentation/providers/camt_pruefliste_providers.dart`
- Create: `lib/presentation/screens/buchhaltung/camt_pruefliste_screen.dart`
- Modify: `lib/core/config/router.dart`

- [ ] **Step 1: Provider**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/models/camt_pruefliste_eintrag.dart';
import 'package:sbs_projer_app/data/repositories/camt_pruefliste_repository.dart';

final camtPrueflisteProvider =
    FutureProvider.autoDispose<List<CamtPrueflisteEintrag>>((ref) async {
  return CamtPrueflisteRepository.getOffen();
});
```

- [ ] **Step 2: Screen** (Liste offener Einträge; je Eintrag Datum/Betrag/Partei/Kategorie + Aktionen „Betrieb/Rechnung wählen → verbuchen" und „Ignorieren"). Für die manuelle Auflösung denselben `ZahlungsdifferenzService` nutzen wie der Auto-Booker; nach Verbuchen `setStatus(id,'erledigt')` und Provider invalidieren. UI-Muster aus `camt_import_screen.dart` (Cards, AppColors) übernehmen.

> Konkrete Felder/Buttons: `ListView` über `camtPrueflisteProvider`; pro Eintrag `Card` mit Betrag (grün/rot je `istGutschrift`), `parteiName`, `kategorie`, `fehlertext` (falls vorhanden, rot). Button „Erledigt" → `CamtPrueflisteRepository.setStatus(e.id!, 'erledigt')`; Button „Ignorieren" → `setStatus(..., 'ignoriert')`. Die geführte Zuordnung (Betrieb/Rechnung wählen) kann zunächst auf einen einfachen Dialog reduziert werden, der eine Rechnung per Dropdown wählt und `ZahlungsdifferenzService.verbuchen(rechnung:…, zahlung: e.betrag, datum: e.bookingDatum)` aufruft.

- [ ] **Step 3: Route ergänzen** in `router.dart` analog zu `camt_import_screen` (Pfad `/buchhaltung/camt-pruefliste`).

- [ ] **Step 4: Analyze + Commit**

Run: `flutter analyze lib/presentation/screens/buchhaltung/camt_pruefliste_screen.dart lib/presentation/providers/camt_pruefliste_providers.dart lib/core/config/router.dart`
```bash
git add sbs_projer_app/lib/presentation/screens/buchhaltung/camt_pruefliste_screen.dart sbs_projer_app/lib/presentation/providers/camt_pruefliste_providers.dart sbs_projer_app/lib/core/config/router.dart
git commit -m "feat(camt): Prüflisten-Screen + Provider + Route"
```

---

## Task 12: Import-Screen auf Auto-Lauf umstellen

**Files:**
- Modify: `lib/presentation/screens/buchhaltung/camt_import_screen.dart`

- [ ] **Step 1: Ablauf umbauen**

Statt Vorlagen-Dropdown pro Zeile: Datei wählen → parsen → Auto-Booker laufen lassen → Ergebnis-Report (gebucht / Prüfliste / übersprungen / Fehler). `_doImport` ersetzen durch Aufruf von `CamtAutoBooker.run(...)` mit:
- `transactions` aus `statement.transactions`,
- `betriebe` wie bisher (`betriebeProvider`, serverId+name),
- `offeneRechnungen` (RechnungRepository: status in offen/gesendet),
- `heinekenRechnungen` (rechnungstyp heineken_monat, status != bezahlt),
- `bereitsVerarbeitet = await BuchungRepository.getAlleCamtTxKeys() ∪ await CamtPrueflisteRepository.getAlleTxKeys()`.

Ergebnis-Step zeigt die vier Zahlen + Button „Zur Prüfliste" (Navigation zur Route aus Task 11). `buchungenStreamProvider` und `camtPrueflisteProvider` invalidieren.

- [ ] **Step 2: Analyze**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze`
Expected: keine Fehler.

- [ ] **Step 3: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/buchhaltung/camt_import_screen.dart
git commit -m "feat(camt): Import-Screen führt Auto-Buchung + Rechnungskontrolle aus"
```

---

## Task 13: Gesamt-Verifikation

- [ ] **Step 1: Alle Unit-Tests**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test`
Expected: alle Tests grün (Parser, Stichtag, Klassifizierer, Matcher).

- [ ] **Step 2: Analyze gesamt**

Run: `flutter analyze`
Expected: keine Fehler.

- [ ] **Step 3: Manuelle Verifikation (echte Datei, Testkonto)**

Mit der vorhandenen camt-Datei im App-UI: Import starten. Da alle Buchungen < 01.07.2026 liegen, erwartet: **0 gebucht, 0 Prüfliste, alle übersprungen** (Stichtag greift). Damit ist der Stichtag-Schutz in der Praxis bestätigt, ohne Echtdaten zu verändern. Für einen Positiv-Test eine Test-Transaktion mit Datum ≥ 01.07.2026 (manipulierte XML-Kopie) verwenden.

- [ ] **Step 4: Abschluss-Commit / Branch-Status**

```bash
git status
```

---

## Self-Review-Notiz (Spec-Abdeckung)
- Parser-Split/Ref/txKey → Task 2. Stichtag → Task 3. Dedup → Task 2+10+12. Klassifizierer → Task 6. Rechnungs-Matcher (exakt/Sammel/unklar) → Task 7+10. Heineken → Task 9+10. Prüfliste (Tabelle/Repo/UI) → Task 4/5/11. Auto-Booker/Fehlerisolation → Task 10. Import-Report → Task 12.
- **Phase 2 (separat):** Ausgaben-Regelwerk `camt_regel`, 4 neue Buchungsvorlagen (5700/5720/5730/8900), „Regel anlegen"-UI, Bargeld-/Bank-Abschluss-Regeln. In Phase 1 landen Ausgaben/Bargeld bewusst in der Prüfliste.

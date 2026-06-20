# camt-Forderungsabgleich + Datei-Archiv Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Offene Forderungen forderungs-getrieben gegen eine Voll-camt-Datei abgleichen (eindeutig → auto-verbuchen, Rest manuell), alle camt-Dateien archivieren mit Zeitraum-Übersicht, und wöchentlich an den Upload erinnern.

**Architecture:** Neue `ForderungsAbgleichService` (Pull-Logik) nutzt bestehende `Camt053Parser`, `CamtBetriebMatcher`, `RechnungMatcher`, `ZahlungsdifferenzService`. Neue Tabelle `camt_dateien` + Storage-Bucket für das Archiv. Zwei neue Screens (Abgleich, Datei-Übersicht) + Dashboard-Erinnerung. Stichtag des bestehenden Auto-Bookers wird auf heute gesenkt.

**Tech Stack:** Flutter + Riverpod + GoRouter + Supabase. Tests via `flutter test`.

**Spec:** `docs/superpowers/specs/2026-06-20-camt-forderungsabgleich-design.md`

**Verifizierte Signaturen:**
- `Camt053Parser.parse(String xml) → CamtStatement` (`.transactions: List<CamtTransaction>`).
- `CamtTransaction`: `amount, isCredit, bookingDate, partyName, additionalInfo, txKey`.
- `CamtBetriebMatcher.findBestMatch(String? partyName, List<Map<String,String>> betriebe) → Map<String,String>?`.
- `RechnungMatcher.match({required double zahlbetrag, required List<Rechnung> offeneRechnungen}) → MatchErgebnis(eindeutig, rechnungen)`.
- `ZahlungsdifferenzService.verbuchenSammel({required List<Rechnung> rechnungen, required double zahlungBetrag, DateTime? datum}) → Future<List<Buchung>>`.
- `RechnungRepository.getAll()` (paginiert), `.update(String id, Map fields)`.
- `Rechnung`: `id, betriebId, rechnungsnummer, betragBrutto, zahlungsstatus, rechnungstyp`.

---

## Task 1: Stichtag auf heute senken

**Files:**
- Modify: `sbs_projer_app/lib/services/camt/camt_stichtag.dart`
- Test: `sbs_projer_app/test/camt_stichtag_test.dart`

- [ ] **Step 1: Test schreiben**

```dart
// test/camt_stichtag_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/camt/camt_stichtag.dart';

void main() {
  test('Stichtag ist 20.06.2026, davor nicht automatisierbar', () {
    expect(CamtStichtag.stichtag, DateTime(2026, 6, 20));
    expect(CamtStichtag.istAutomatisierbar(DateTime(2026, 6, 19)), isFalse);
    expect(CamtStichtag.istAutomatisierbar(DateTime(2026, 6, 20)), isTrue);
  });
}
```

- [ ] **Step 2: Test laufen lassen → FAIL**

Run: `cd sbs_projer_app && flutter test test/camt_stichtag_test.dart`
Expected: FAIL (stichtag ist noch 2026-07-01)

- [ ] **Step 3: Konstante ändern**

In `camt_stichtag.dart` Zeile 4:
```dart
  static final DateTime stichtag = DateTime(2026, 6, 20);
```

- [ ] **Step 4: Test → PASS**

Run: `flutter test test/camt_stichtag_test.dart` → PASS

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/services/camt/camt_stichtag.dart sbs_projer_app/test/camt_stichtag_test.dart
git commit -m "feat(camt): Stichtag auf heute (20.06.2026) gesenkt"
```

---

## Task 2: Migration 101 — `camt_dateien` Tabelle + Storage-Bucket

**Files:**
- Create: `Datenbank/migrations/101_camt_dateien.sql`

- [ ] **Step 1: Migration schreiben**

```sql
-- 101_camt_dateien.sql — Archiv hochgeladener camt-Dateien + erfasste Zeiträume
CREATE TABLE IF NOT EXISTS camt_dateien (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  dateiname text NOT NULL,
  hochgeladen_am timestamptz NOT NULL DEFAULT now(),
  zeitraum_von date,
  zeitraum_bis date,
  iban text,
  anzahl_eintraege int DEFAULT 0,
  anzahl_gutschriften int DEFAULT 0,
  storage_pfad text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE camt_dateien ENABLE ROW LEVEL SECURITY;
CREATE POLICY camt_dateien_owner ON camt_dateien
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE INDEX IF NOT EXISTS idx_camt_dateien_zeitraum ON camt_dateien(user_id, zeitraum_von);
```

- [ ] **Step 2: Migration anwenden (MCP `apply_migration`)** — name `camt_dateien`, project_id `pltbaqqwpnmdajwgnhpd`, query = obiger Inhalt. Expected `{"success":true}`.

- [ ] **Step 3: Storage-Bucket anlegen** — im Supabase-Dashboard Bucket `camt-dateien` (privat) erstellen. Verifizieren via `execute_sql`: `SELECT id FROM storage.buckets WHERE id='camt-dateien';` → 1 Zeile.

- [ ] **Step 4: Commit**

```bash
git add Datenbank/migrations/101_camt_dateien.sql
git commit -m "feat(db): camt_dateien Archiv-Tabelle (Migration 101)"
```

---

## Task 3: `CamtDatei` Model + Repository

**Files:**
- Create: `sbs_projer_app/lib/data/models/camt_datei.dart`
- Create: `sbs_projer_app/lib/data/repositories/camt_datei_repository.dart`
- Test: `sbs_projer_app/test/camt_datei_model_test.dart`

- [ ] **Step 1: Model-Test schreiben**

```dart
// test/camt_datei_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/camt_datei.dart';

void main() {
  test('fromJson/toJson roundtrip', () {
    final j = {
      'id': 'a', 'user_id': 'u', 'dateiname': 'x.xml',
      'zeitraum_von': '2026-01-01', 'zeitraum_bis': '2026-06-19',
      'iban': 'CH66', 'anzahl_eintraege': 10, 'anzahl_gutschriften': 8,
      'storage_pfad': 'u/x.xml',
    };
    final d = CamtDatei.fromJson(j);
    expect(d.dateiname, 'x.xml');
    expect(d.zeitraumBis, DateTime(2026, 6, 19));
    expect(d.anzahlGutschriften, 8);
  });
}
```

- [ ] **Step 2: Test → FAIL** (`flutter test test/camt_datei_model_test.dart`)

- [ ] **Step 3: Model implementieren**

```dart
// lib/data/models/camt_datei.dart
class CamtDatei {
  final String id;
  final String userId;
  final String dateiname;
  final DateTime? hochgeladenAm;
  final DateTime? zeitraumVon;
  final DateTime? zeitraumBis;
  final String? iban;
  final int anzahlEintraege;
  final int anzahlGutschriften;
  final String storagePfad;

  CamtDatei({
    required this.id,
    required this.userId,
    required this.dateiname,
    this.hochgeladenAm,
    this.zeitraumVon,
    this.zeitraumBis,
    this.iban,
    this.anzahlEintraege = 0,
    this.anzahlGutschriften = 0,
    required this.storagePfad,
  });

  static DateTime? _d(dynamic v) => v == null ? null : DateTime.parse(v.toString());

  factory CamtDatei.fromJson(Map<String, dynamic> j) => CamtDatei(
        id: j['id'].toString(),
        userId: j['user_id'].toString(),
        dateiname: j['dateiname'] as String,
        hochgeladenAm: _d(j['hochgeladen_am']),
        zeitraumVon: _d(j['zeitraum_von']),
        zeitraumBis: _d(j['zeitraum_bis']),
        iban: j['iban'] as String?,
        anzahlEintraege: (j['anzahl_eintraege'] ?? 0) as int,
        anzahlGutschriften: (j['anzahl_gutschriften'] ?? 0) as int,
        storagePfad: j['storage_pfad'] as String,
      );

  Map<String, dynamic> toInsert() => {
        'dateiname': dateiname,
        'zeitraum_von': zeitraumVon?.toIso8601String().split('T').first,
        'zeitraum_bis': zeitraumBis?.toIso8601String().split('T').first,
        'iban': iban,
        'anzahl_eintraege': anzahlEintraege,
        'anzahl_gutschriften': anzahlGutschriften,
        'storage_pfad': storagePfad,
      };
}
```

- [ ] **Step 4: Test → PASS**

- [ ] **Step 5: Repository implementieren** (Muster wie `rechnung_repository.dart`, Bucket-Upload wie `protokoll_foto_storage.dart`)

```dart
// lib/data/repositories/camt_datei_repository.dart
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import 'package:sbs_projer_app/data/models/camt_datei.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class CamtDateiRepository {
  static const _bucket = 'camt-dateien';
  static String get _userId => SupabaseService.dataUserId;

  static Future<List<CamtDatei>> getAll() async {
    final all = <Map<String, dynamic>>[];
    const pageSize = 1000;
    int from = 0;
    while (true) {
      final rows = await SupabaseService.client
          .from('camt_dateien').select().eq('user_id', _userId)
          .order('zeitraum_von', ascending: true)
          .range(from, from + pageSize - 1);
      all.addAll(rows);
      if (rows.length < pageSize) break;
      from += pageSize;
    }
    return all.map((r) => CamtDatei.fromJson(r)).toList();
  }

  /// True wenn schon eine Datei mit gleicher IBAN + Zeitraum existiert.
  static Future<bool> existsZeitraum(String? iban, DateTime? von, DateTime? bis) async {
    if (von == null || bis == null) return false;
    final rows = await SupabaseService.client
        .from('camt_dateien').select('id')
        .eq('user_id', _userId)
        .eq('zeitraum_von', von.toIso8601String().split('T').first)
        .eq('zeitraum_bis', bis.toIso8601String().split('T').first);
    return (rows as List).isNotEmpty;
  }

  /// Lädt das XML in den Bucket + erstellt den Metadaten-Record.
  static Future<CamtDatei> speichern(CamtDatei meta, Uint8List xmlBytes) async {
    final pfad = '$_userId/${meta.dateiname}';
    await SupabaseService.client.storage.from(_bucket).uploadBinary(
          pfad, xmlBytes,
          fileOptions: const FileOptions(contentType: 'application/xml', upsert: true),
        );
    final json = meta.toInsert()..['user_id'] = _userId..['storage_pfad'] = pfad;
    final rows = await SupabaseService.client.from('camt_dateien').insert(json).select();
    return CamtDatei.fromJson(rows.first);
  }

  static Future<String> signedUrl(String storagePfad) =>
      SupabaseService.client.storage.from(_bucket).createSignedUrl(storagePfad, 3600);
}
```

- [ ] **Step 6: Commit**

```bash
git add sbs_projer_app/lib/data/models/camt_datei.dart sbs_projer_app/lib/data/repositories/camt_datei_repository.dart sbs_projer_app/test/camt_datei_model_test.dart
git commit -m "feat(camt): CamtDatei Model + Repository (Archiv)"
```

---

## Task 4: Effektiver Zahlername (aus „Gutschrift X")

Bei dieser Bank (GKB) steht der Zahler oft nicht in `partyName` (`Nm`), sondern im `additionalInfo` als „Gutschrift <Name>". Der Abgleich braucht einen kombinierten Namen.

**Files:**
- Create: `sbs_projer_app/lib/services/camt/zahlername.dart`
- Test: `sbs_projer_app/test/zahlername_test.dart`

- [ ] **Step 1: Test schreiben**

```dart
// test/zahlername_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/camt/zahlername.dart';

void main() {
  test('nutzt partyName wenn vorhanden', () {
    expect(effektiverZahlername(partyName: 'Hotel X', additionalInfo: 'Gutschrift Y'), 'Hotel X');
  });
  test('extrahiert aus "Gutschrift <Name>"', () {
    expect(effektiverZahlername(partyName: null, additionalInfo: 'Gutschrift Gastro Latina GmbH'),
        'Gastro Latina GmbH');
  });
  test('null wenn nichts brauchbar', () {
    expect(effektiverZahlername(partyName: null, additionalInfo: 'Saldovortrag'), isNull);
  });
}
```

- [ ] **Step 2: Test → FAIL**

- [ ] **Step 3: Implementieren**

```dart
// lib/services/camt/zahlername.dart
/// Liefert den besten verfügbaren Zahlernamen: partyName, sonst aus
/// "Gutschrift <Name>" im AddtlNtryInf. Null wenn nichts Brauchbares.
String? effektiverZahlername({required String? partyName, required String? additionalInfo}) {
  final pn = partyName?.trim();
  if (pn != null && pn.isNotEmpty) return pn;
  final info = additionalInfo?.trim() ?? '';
  final m = RegExp(r'^Gutschrift\s+(.+)$', caseSensitive: false).firstMatch(info);
  if (m != null) {
    final name = m.group(1)!.trim();
    if (name.isNotEmpty) return name;
  }
  return null;
}
```

- [ ] **Step 4: Test → PASS**

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/services/camt/zahlername.dart sbs_projer_app/test/zahlername_test.dart
git commit -m "feat(camt): effektiver Zahlername aus AddtlNtryInf"
```

---

## Task 5: `ForderungsAbgleichService` — Kern-Matching (TDD)

Pull-Logik: pro Betrieb mit offenen Forderungen die passende Gutschrift(en) finden.

**Files:**
- Create: `sbs_projer_app/lib/services/camt/forderungs_abgleich_service.dart`
- Test: `sbs_projer_app/test/forderungs_abgleich_service_test.dart`

- [ ] **Step 1: Test schreiben**

```dart
// test/forderungs_abgleich_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/camt_transaction.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/services/camt/forderungs_abgleich_service.dart';

Rechnung _rg(String id, String betriebId, double betrag) => Rechnung(
      id: id, userId: 'u', rechnungsnummer: id, rechnungstyp: 'kundenrechnung',
      betriebId: betriebId, rechnungsdatum: DateTime(2025, 1, 1),
      faelligkeitsdatum: DateTime(2025, 2, 1), betragNetto: betrag, mwstBetrag: 0,
      betragBrutto: betrag, zahlungsstatus: 'offen');

CamtTransaction _gut(double amt, String party, [String? info]) => CamtTransaction(
      amount: amt, currency: 'CHF', isCredit: true, bookingDate: DateTime(2026, 1, 5),
      partyName: party, additionalInfo: info, txKey: '$party-$amt');

void main() {
  final betriebe = [
    {'id': 'b1', 'name': 'Hotel Alpina'},
    {'id': 'b2', 'name': 'Gastro Latina GmbH'},
  ];

  test('eindeutige Einzelzahlung → auto', () {
    final r = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(67.85, 'Hotel Alpina')],
      offeneForderungen: [_rg('r1', 'b1', 67.85)],
      betriebe: betriebe,
    );
    expect(r.auto.length, 1);
    expect(r.auto.first.forderungen.single.id, 'r1');
    expect(r.auto.first.gutschrift.amount, 67.85);
    expect(r.manuell, isEmpty);
    expect(r.keineZahlung, isEmpty);
  });

  test('Sammelzahlung über zwei Forderungen → auto', () {
    final r = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(135.70, 'Hotel Alpina')],
      offeneForderungen: [_rg('r1', 'b1', 67.85), _rg('r2', 'b1', 67.85)],
      betriebe: betriebe,
    );
    expect(r.auto.length, 1);
    expect(r.auto.first.forderungen.map((f) => f.id).toSet(), {'r1', 'r2'});
  });

  test('Zahlername aus AddtlNtryInf wird genutzt', () {
    final r = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(50.0, '', 'Gutschrift Gastro Latina GmbH')],
      offeneForderungen: [_rg('r3', 'b2', 50.0)],
      betriebe: betriebe,
    );
    expect(r.auto.single.forderungen.single.id, 'r3');
  });

  test('kein Betrieb-Match → Gutschrift ignoriert, Forderung bleibt offen', () {
    final r = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(99.0, 'Unbekannt AG')],
      offeneForderungen: [_rg('r4', 'b1', 67.85)],
      betriebe: betriebe,
    );
    expect(r.auto, isEmpty);
    expect(r.keineZahlung.single.id, 'r4');
  });

  test('Betrieb mit offener Forderung, Betrag passt nicht → manuell', () {
    final r = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(40.0, 'Hotel Alpina')],
      offeneForderungen: [_rg('r5', 'b1', 67.85)],
      betriebe: betriebe,
    );
    expect(r.auto, isEmpty);
    expect(r.manuell.single.betriebId, 'b1');
    expect(r.manuell.single.gutschriften.single.amount, 40.0);
    expect(r.manuell.single.forderungen.single.id, 'r5');
  });

  test('Gutschrift nur einmal verbraucht', () {
    final r = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(67.85, 'Hotel Alpina')],
      offeneForderungen: [_rg('r1', 'b1', 67.85), _rg('r2', 'b1', 67.85)],
      betriebe: betriebe,
    );
    // Eine Gutschrift kann nur EINE der zwei gleich-teuren Forderungen schliessen → mehrdeutig → manuell
    expect(r.auto, isEmpty);
    expect(r.manuell.single.forderungen.length, 2);
  });
}
```

- [ ] **Step 2: Test → FAIL** (`flutter test test/forderungs_abgleich_service_test.dart`)

- [ ] **Step 3: Service implementieren**

```dart
// lib/services/camt/forderungs_abgleich_service.dart
import 'package:sbs_projer_app/data/models/camt_transaction.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/services/camt/camt_betrieb_matcher.dart';
import 'package:sbs_projer_app/services/camt/rechnung_matcher.dart';
import 'package:sbs_projer_app/services/camt/zahlername.dart';

/// Ein eindeutiger Auto-Treffer: eine Gutschrift schliesst eine/mehrere Forderungen.
class AutoTreffer {
  final CamtTransaction gutschrift;
  final List<Rechnung> forderungen;
  AutoTreffer(this.gutschrift, this.forderungen);
}

/// Ein manuell zu klärender Fall: ein Betrieb mit übrigen Gutschriften + Forderungen.
class ManuellFall {
  final String betriebId;
  final String betriebName;
  final List<CamtTransaction> gutschriften;
  final List<Rechnung> forderungen;
  ManuellFall(this.betriebId, this.betriebName, this.gutschriften, this.forderungen);
}

class AbgleichErgebnis {
  final List<AutoTreffer> auto;
  final List<ManuellFall> manuell;
  final List<Rechnung> keineZahlung; // offene Forderungen ohne passende Gutschrift
  AbgleichErgebnis(this.auto, this.manuell, this.keineZahlung);
}

class ForderungsAbgleichService {
  /// Forderungs-getriebener Abgleich (rein, ohne IO — testbar).
  static AbgleichErgebnis abgleich({
    required List<CamtTransaction> gutschriften,
    required List<Rechnung> offeneForderungen,
    required List<Map<String, String>> betriebe,
  }) {
    // 1. Gutschriften pro Betrieb gruppieren (über effektiven Zahlernamen).
    final gutProBetrieb = <String, List<CamtTransaction>>{};
    for (final g in gutschriften.where((g) => g.isCredit)) {
      final name = effektiverZahlername(partyName: g.partyName, additionalInfo: g.additionalInfo);
      if (name == null) continue;
      final match = CamtBetriebMatcher.findBestMatch(name, betriebe);
      if (match == null) continue;
      gutProBetrieb.putIfAbsent(match['id']!, () => []).add(g);
    }

    // 2. Offene Forderungen pro Betrieb gruppieren.
    final fordProBetrieb = <String, List<Rechnung>>{};
    for (final r in offeneForderungen) {
      if (r.betriebId == null) continue;
      fordProBetrieb.putIfAbsent(r.betriebId!, () => []).add(r);
    }

    final auto = <AutoTreffer>[];
    final manuell = <ManuellFall>[];
    final keineZahlung = <Rechnung>[];
    final betriebName = {for (final b in betriebe) b['id']!: b['name']!};

    // 3. Pro Betrieb mit offenen Forderungen matchen.
    for (final entry in fordProBetrieb.entries) {
      final betriebId = entry.key;
      final offen = List<Rechnung>.from(entry.value);
      final guts = List<CamtTransaction>.from(gutProBetrieb[betriebId] ?? const []);

      if (guts.isEmpty) {
        keineZahlung.addAll(offen);
        continue;
      }

      // Pro Gutschrift eindeutige Subset-Summe der noch offenen Forderungen.
      for (final g in List<CamtTransaction>.from(guts)) {
        final m = RechnungMatcher.match(zahlbetrag: g.amount, offeneRechnungen: offen);
        if (m.eindeutig) {
          auto.add(AutoTreffer(g, m.rechnungen));
          offen.removeWhere((r) => m.rechnungen.any((x) => x.id == r.id));
          guts.remove(g);
        }
      }

      // Rest dieses Betriebs → manuell (wenn Gutschriften ODER Forderungen übrig).
      if (guts.isNotEmpty && offen.isNotEmpty) {
        manuell.add(ManuellFall(betriebId, betriebName[betriebId] ?? '?', guts, offen));
      } else if (offen.isNotEmpty) {
        keineZahlung.addAll(offen);
      }
    }

    return AbgleichErgebnis(auto, manuell, keineZahlung);
  }
}
```

- [ ] **Step 4: Test → PASS** (`flutter test test/forderungs_abgleich_service_test.dart`) — alle 6 Tests grün.

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/services/camt/forderungs_abgleich_service.dart sbs_projer_app/test/forderungs_abgleich_service_test.dart
git commit -m "feat(camt): ForderungsAbgleichService (Pull-Matching, getestet)"
```

---

## Task 6: Verbuchung eines Treffers (Service-Methode)

Verbindet einen `AutoTreffer`/manuelle Auswahl mit der bestehenden Verbuchung + Status-Update.

**Files:**
- Modify: `sbs_projer_app/lib/services/camt/forderungs_abgleich_service.dart`
- Test: erweitert `test/forderungs_abgleich_service_test.dart` (nur Reiner-Logik-Teil; Verbuchung wird im Screen integrationsgetestet)

- [ ] **Step 1: Methode `verbuche` ergänzen** (am Ende der Klasse `ForderungsAbgleichService`)

```dart
  /// Verbucht eine Zahlung gegen die gewählten Forderungen + markiert sie bezahlt.
  /// Nutzt die bestehende Sammel-Verbuchung (Bank 1020 ← Debitoren 1100 + Differenz).
  static Future<void> verbuche({
    required double zahlbetrag,
    required DateTime datum,
    required List<Rechnung> forderungen,
  }) async {
    if (forderungen.isEmpty) return;
    await ZahlungsdifferenzService.verbuchenSammel(
      rechnungen: forderungen, zahlungBetrag: zahlbetrag, datum: datum,
    );
    final datumStr = datum.toIso8601String().split('T').first;
    for (final r in forderungen) {
      await RechnungRepository.update(r.id, {
        'zahlungsstatus': 'bezahlt',
        'zahlung_eingegangen_am': datumStr,
        'zahlung_betrag': r.betragBrutto,
      });
    }
  }
```

Ergänze oben die Imports:
```dart
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/services/buchhaltung/zahlungsdifferenz_service.dart';
```

- [ ] **Step 2: `flutter analyze lib/services/camt/forderungs_abgleich_service.dart`** → No issues found.

- [ ] **Step 3: Commit**

```bash
git add sbs_projer_app/lib/services/camt/forderungs_abgleich_service.dart
git commit -m "feat(camt): Abgleich-Verbuchung (verbuche-Methode)"
```

---

## Task 7: Provider für Abgleich + camt-Dateien

**Files:**
- Create: `sbs_projer_app/lib/presentation/providers/camt_abgleich_providers.dart`

- [ ] **Step 1: Provider implementieren**

```dart
// lib/presentation/providers/camt_abgleich_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/models/camt_datei.dart';
import 'package:sbs_projer_app/data/repositories/camt_datei_repository.dart';

/// Alle archivierten camt-Dateien (chronologisch nach Zeitraum).
final camtDateienProvider = FutureProvider<List<CamtDatei>>((ref) {
  return CamtDateiRepository.getAll();
});

/// Letzte erfasste Periode (zeitraum_bis der jüngsten Datei) — für die Erinnerung.
final letzteCamtPeriodeProvider = FutureProvider<DateTime?>((ref) async {
  final dateien = await ref.watch(camtDateienProvider.future);
  DateTime? max;
  for (final d in dateien) {
    if (d.zeitraumBis != null && (max == null || d.zeitraumBis!.isAfter(max))) {
      max = d.zeitraumBis;
    }
  }
  return max;
});
```

- [ ] **Step 2: `flutter analyze`** der Datei → No issues.

- [ ] **Step 3: Commit**

```bash
git add sbs_projer_app/lib/presentation/providers/camt_abgleich_providers.dart
git commit -m "feat(camt): Provider für Abgleich/Archiv"
```

---

## Task 8: `CamtAbgleichScreen` — Upload + Vorschau + Verbuchen

Folgt dem Muster von `camt_import_screen.dart` (File-Picker via `file_picker_export.dart`, Parser-Aufruf, Laden offener Rechnungen + Betriebe).

**Files:**
- Create: `sbs_projer_app/lib/presentation/screens/buchhaltung/camt_abgleich_screen.dart`

- [ ] **Step 1: Screen-Grundgerüst + Upload**

`ConsumerStatefulWidget`. State: `AbgleichErgebnis? _ergebnis; bool _loading;`. AppBar „Forderungs-Abgleich". Body: wenn `_ergebnis==null` → Button „camt-Datei wählen"; sonst die drei Gruppen (Step 3).

Upload-Handler (Muster aus `camt_import_screen.dart`):
```dart
Future<void> _waehleDatei() async {
  setState(() => _loading = true);
  final bytes = await FilePickerHelper.pickXmlBytes(); // wie in camt_import_screen
  if (bytes == null) { setState(() => _loading = false); return; }
  final xml = String.fromCharCodes(bytes);
  final stmt = Camt053Parser.parse(xml);

  // Archivieren (Task 11 integriert dies; hier minimal):
  final gut = stmt.transactions.where((t) => t.isCredit).length;
  await CamtDateiRepository.speichern(
    CamtDatei(id: '', userId: '', dateiname: _dateiname ?? 'camt.xml',
      zeitraumVon: stmt.fromDate, zeitraumBis: stmt.toDate, iban: stmt.iban,
      anzahlEintraege: stmt.transactions.length, anzahlGutschriften: gut, storagePfad: ''),
    Uint8List.fromList(bytes));

  final offen = (await RechnungRepository.getAll())
      .where((r) => r.rechnungstyp == 'kundenrechnung' &&
          (r.zahlungsstatus == 'offen' || r.zahlungsstatus == 'gesendet'))
      .map((l) => /* RechnungLocal→Rechnung bzw. direkt Rechnung, siehe camt_import_screen */ l)
      .toList();
  final betriebe = await _ladeBetriebe(); // List<Map<String,String>> {id,name} — wie camt_import_screen
  final erg = ForderungsAbgleichService.abgleich(
    gutschriften: stmt.transactions, offeneForderungen: offen, betriebe: betriebe);
  setState(() { _ergebnis = erg; _loading = false; });
}
```
> Hinweis: `RechnungRepository.getAll()` liefert `List<Rechnung>` (Web) — exakt wie in `camt_import_screen.dart:287` verwenden. `_ladeBetriebe()` und `FilePickerHelper` 1:1 aus `camt_import_screen.dart` übernehmen.

- [ ] **Step 2: Drei Ergebnis-Gruppen rendern**

```dart
ListView(children: [
  _Gruppe(titel: '🟢 Auto-gematcht (${_ergebnis!.auto.length})',
    child: Column(children: [
      for (final t in _ergebnis!.auto)
        ListTile(
          title: Text('${t.gutschrift.amount.toStringAsFixed(2)} CHF — '
              '${t.forderungen.map((f) => f.rechnungsnummer).join(", ")}'),
          subtitle: Text('Datum ${_fmt(t.gutschrift.bookingDate)}'),
          trailing: FilledButton(child: const Text('Verbuchen'),
            onPressed: () => _verbuche(t.gutschrift, t.forderungen)),
        ),
      if (_ergebnis!.auto.isNotEmpty)
        FilledButton(child: const Text('Alle auto-Treffer verbuchen'),
          onPressed: _verbucheAlle),
    ])),
  _Gruppe(titel: '🟡 Manuell zuordnen (${_ergebnis!.manuell.length})',
    child: Column(children: [
      for (final f in _ergebnis!.manuell)
        ListTile(
          title: Text(f.betriebName),
          subtitle: Text('${f.gutschriften.length} Zahlung(en), ${f.forderungen.length} offene Forderung(en)'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _oeffneManuell(f), // Task 9
        ),
    ])),
  _Gruppe(titel: '🔴 Keine Zahlung gefunden (${_ergebnis!.keineZahlung.length})',
    child: Column(children: [
      for (final r in _ergebnis!.keineZahlung)
        ListTile(dense: true,
          title: Text('${r.rechnungsnummer} — ${r.betragBrutto.toStringAsFixed(2)} CHF')),
    ])),
]);
```

`_verbuche` ruft `ForderungsAbgleichService.verbuche(zahlbetrag: g.amount, datum: g.bookingDate, forderungen: f)`, invalidiert `rechnungenStreamProvider` + `buchungenStreamProvider`, entfernt den Treffer aus `_ergebnis!.auto` via `setState`, zeigt SnackBar.

- [ ] **Step 3: `flutter analyze`** des Screens → No issues found.

- [ ] **Step 4: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/buchhaltung/camt_abgleich_screen.dart
git commit -m "feat(camt): Abgleich-Screen (Upload + Vorschau + Auto-Verbuchung)"
```

---

## Task 9: Manuelle Zuordnung (Dialog)

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/buchhaltung/camt_abgleich_screen.dart` (Dialog `_oeffneManuell`)

- [ ] **Step 1: Dialog implementieren**

`showDialog` mit `StatefulBuilder`. Zeigt die Gutschriften (Multi-Select-Checkbox) und die offenen Forderungen (Multi-Select). Live-Summen:
```dart
final zahlSumme = gewaehlteGutschriften.fold<double>(0, (s, g) => s + g.amount);
final fordSumme = gewaehlteForderungen.fold<double>(0, (s, f) => s + f.betragBrutto);
final diff = ((zahlSumme - fordSumme) * 20).roundToDouble() / 20;
```
Anzeige der Differenz mit Hinweis (Unterzahlung → Debitorenverlust 3805; Überzahlung → Ertrag 8000), genau wie im `rechnung_detail_screen.dart`-Dialog. Button „Verbuchen" aktiv wenn ≥1 Gutschrift + ≥1 Forderung gewählt:
```dart
onPressed: () async {
  await ForderungsAbgleichService.verbuche(
    zahlbetrag: zahlSumme, datum: gewaehlteGutschriften.first.bookingDate,
    forderungen: gewaehlteForderungen);
  // Fall aus _ergebnis!.manuell entfernen / aktualisieren, Provider invalidieren
  Navigator.pop(ctx, true);
}
```

- [ ] **Step 2: `flutter analyze`** → No issues found.

- [ ] **Step 3: Manueller Klicktest (Web)** — `flutter run -d edge`, camt hochladen, einen 🟡-Fall öffnen, Gutschrift + Forderung wählen, Differenz prüfen, verbuchen; Eintrag verschwindet, Forderung im Hub auf „bezahlt".

- [ ] **Step 4: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/buchhaltung/camt_abgleich_screen.dart
git commit -m "feat(camt): manuelle Zuordnung (Sammelzahlung-Split + Differenz)"
```

---

## Task 10: `CamtDateienScreen` — erfasste Zeiträume + Lücken + Download

**Files:**
- Create: `sbs_projer_app/lib/presentation/screens/buchhaltung/camt_dateien_screen.dart`

- [ ] **Step 1: Screen implementieren**

`ConsumerWidget`, `ref.watch(camtDateienProvider)`. Liste chronologisch; zwischen aufeinanderfolgenden Dateien Lücke berechnen:
```dart
// dateien ist nach zeitraum_von sortiert (Repository)
for (int i = 0; i < dateien.length; i++) {
  final d = dateien[i];
  // Lücken-Warnung vor d, wenn Vorgänger.zeitraumBis + 3 Tage < d.zeitraumVon
  if (i > 0) {
    final prevBis = dateien[i - 1].zeitraumBis;
    if (prevBis != null && d.zeitraumVon != null &&
        d.zeitraumVon!.difference(prevBis).inDays > 3) {
      // Container mit AppColors.warning: „Lücke: <prevBis> – <d.von>"
    }
  }
  // Card: Zeitraum von–bis, anzahlGutschriften, Download-Icon (signedUrl → launchUrl)
}
```
Leerer Zustand: „Noch keine camt-Datei erfasst".

- [ ] **Step 2: `flutter analyze`** → No issues found.

- [ ] **Step 3: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/buchhaltung/camt_dateien_screen.dart
git commit -m "feat(camt): Datei-Übersicht (Zeiträume + Lücken + Download)"
```

---

## Task 11: Router/Dashboard-Verdrahtung + Wochen-Erinnerung + Verifikation

**Files:**
- Modify: `sbs_projer_app/lib/core/config/router.dart`
- Modify: `sbs_projer_app/lib/presentation/screens/buchhaltung/buchhaltung_dashboard_screen.dart`

- [ ] **Step 1: Routen ergänzen** (Muster wie bestehende camt-Routen, ~Zeile 142)

```dart
GoRoute(path: '/buchhaltung/camt-abgleich',
    builder: (c, s) => const CamtAbgleichScreen()),
GoRoute(path: '/buchhaltung/camt-dateien',
    builder: (c, s) => const CamtDateienScreen()),
```
Plus die zwei Imports oben.

- [ ] **Step 2: Dashboard-Kacheln** „Forderungs-Abgleich" (→ `/buchhaltung/camt-abgleich`) und „camt-Dateien" (→ `/buchhaltung/camt-dateien`) ergänzen (Muster der bestehenden Buchhaltungs-Kacheln).

- [ ] **Step 3: Wochen-Erinnerung im Dashboard**

`ConsumerWidget`; oben im Dashboard:
```dart
final letzte = ref.watch(letzteCamtPeriodeProvider).valueOrNull;
if (letzte == null || DateTime.now().difference(letzte).inDays > 7)
  Container(
    margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AppColors.warning.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withAlpha(60))),
    child: Row(children: [
      const Icon(Icons.upload_file, color: AppColors.warning),
      const SizedBox(width: 8),
      Expanded(child: Text(letzte == null
          ? 'Noch kein Bankauszug erfasst — camt-Datei hochladen'
          : 'Letzter Auszug bis ${_fmt(letzte)} — neuen camt-Auszug hochladen')),
      TextButton(onPressed: () => context.push('/buchhaltung/camt-abgleich'),
          child: const Text('Hochladen')),
    ]),
  ),
```

- [ ] **Step 4: Gesamt-Verifikation**

Run: `cd sbs_projer_app && flutter analyze 2>&1 | grep -E "error •" || echo "0 errors"` → 0 errors.
Run: `flutter test test/camt_stichtag_test.dart test/camt_datei_model_test.dart test/zahlername_test.dart test/forderungs_abgleich_service_test.dart` → alle PASS.

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/core/config/router.dart sbs_projer_app/lib/presentation/screens/buchhaltung/buchhaltung_dashboard_screen.dart
git commit -m "feat(camt): Routen + Dashboard-Kacheln + Wochen-Erinnerung"
```

---

## Task 12: Deploy

- [ ] **Step 1: Version bumpen** `sbs_projer_app/pubspec.yaml` Zeile 4 (beide Teile +1).
- [ ] **Step 2: Build** `cd sbs_projer_app && export MSYS_NO_PATHCONV=1 && flutter build web --base-href "/sbs-projer-dev/" --pwa-strategy=none`
- [ ] **Step 3: Cache-Bust** mainJsPath in `flutter_bootstrap.js` mit Version + `rm flutter_service_worker.js` (CLAUDE.md-Prozedur).
- [ ] **Step 4: Deploy** gh-pages (Dateien kopieren, committen, pushen) + main pushen — echter Push-Retry (kein `| tail`).

---

## Self-Review (Plan-Autor)
- **Spec-Abdeckung:** Stichtag (T1) ✓; Archiv-Tabelle+Bucket (T2/T3, §6) ✓; Parser-Zahlername (T4, §0/§11) ✓; Abgleich-Engine forderungs-getrieben + Subset-Summe (T5, §3) ✓; Verbuchung Bank←Debitoren + Status (T6, §5) ✓; Vorschau 🟢/🟡/🔴 (T8, §4) ✓; manuelle Sammelzahlung-Zuordnung (T9, §4) ✓; Zeitraum-Übersicht+Lücken+Download (T10, §6) ✓; Wochen-Erinnerung (T11, §7) ✓; keine Doppelbuchung (nur offene, verbuchenSammel-Dedup, §5) ✓; reversibel/Vorschau-vor-Verbuchung (T8) ✓.
- **Platzhalter:** UI-Tasks (T8–T11) referenzieren bewusst die bestehenden Muster `camt_import_screen.dart` (FilePicker, Betriebe/Rechnungen laden) statt Boilerplate zu duplizieren — die neue Logik (Gruppen, Dialog, Verbuchung) ist vollständig gezeigt.
- **Typ-Konsistenz:** `AbgleichErgebnis{auto,manuell,keineZahlung}`, `AutoTreffer{gutschrift,forderungen}`, `ManuellFall{betriebId,betriebName,gutschriften,forderungen}` durchgängig in T5/T8/T9; `ForderungsAbgleichService.abgleich(...)`/`.verbuche(...)` in T5/T6/T8/T9; `effektiverZahlername` (T4) in T5; `CamtDateiRepository`/`camtDateienProvider` in T3/T7/T10/T11.
- **Risiken:** Parser-Kompatibilität camt.053.001.04 (gleiche Bank → ok, T4-Test deckt Zahlername ab); `RechnungRepository.getAll()`-Rückgabetyp im Web exakt wie `camt_import_screen.dart` nutzen; Performance unkritisch (pro Betrieb klein).

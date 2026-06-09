# Phase 0a – Buchungs-Modell (Geschäftsfall + Zahlungsweg) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Die Buchungsvorlagen zu echten Geschäftsfällen umbauen (Geschäftsfall = *was*, Zahlungsweg = *wie*), die MWST datumsabhängig machen und den Kontenrahmen bereinigen — sodass eine Ausgabe über „Geschäftsfall + Zahlungsweg (Kasse/Bank/Privat/Kreditor)" korrekt gebucht wird.

**Architecture:** Supabase-only (wie bestehende Buchhaltung). Bestehende Tabellen `konten`, `buchungs_vorlagen`, `buchungen` werden erweitert; neue Tabelle `mwst_satz`. Die Auflösung Geschäftsfall+Zahlungsweg → Soll/Haben/MWST passiert in einem reinen Dart-Service (`GeschaeftsfallResolver`), der unit-testbar ist. `BuchungService.createFromVorlage` nutzt den Resolver + Datums-MWST.

**Tech Stack:** Flutter/Dart, Riverpod, Supabase (PostgreSQL + RLS), `flutter_test`. Spec: [Phase-0-Spec](../specs/2026-06-09-phase0-fundament-buchhaltung-design.md).

**Konventionen aus dem Projekt:** Migrationen in `Datenbank/migrations/NNN_*.sql` (durchnummeriert, mit RLS, `user_id`-Spalte, `kontenklasse` GENERATED). Repositories sind statische Klassen mit `SupabaseService.dataUserId`. MWST bisher in `BuchungService` inline. Bestehende Vorlage-`zahlungsweg`-Werte: `kasse|bank|privat|alle`.

---

## Zahlungsweg → Gegenkonto (Referenz für alle Tasks)

| Zahlungsweg | Konto |
|---|---|
| `kasse` | 1000 |
| `bank` | 1020 |
| `privat` | 2260 |
| `kreditor` | 2000 |
| `debitor` (nur Einnahmen) | 1100 |

**Auflösungsregeln:**
- `art = ausgabe`: Soll = `hauptkonto`, Haben = Gegenkonto(Zahlungsweg), MWST-Konto = `mwst_konto` (Vorsteuer 1170/1171)
- `art = einnahme`: Soll = Gegenkonto(Zahlungsweg), Haben = `hauptkonto`, MWST-Konto = `mwst_konto` (Umsatzsteuer 2200)
- `art = fix`: Soll = `soll_konto`, Haben = `haben_konto` (kein Zahlungsweg)

---

## Task 1: Migration – Schema-Erweiterung Geschäftsfall + mwst_satz + neue Konten

**Files:**
- Create: `Datenbank/migrations/089_geschaeftsfall_zahlungsweg.sql`

- [ ] **Step 1: Migration schreiben**

```sql
-- 089_geschaeftsfall_zahlungsweg.sql
-- Phase 0a: Geschäftsfall + Zahlungsweg, datumsabhängige MWST, Kontenrahmen-Ergänzung

-- 1) buchungs_vorlagen → Geschäftsfall-Felder
ALTER TABLE buchungs_vorlagen
  ADD COLUMN IF NOT EXISTS art TEXT NOT NULL DEFAULT 'fix'
    CHECK (art IN ('ausgabe', 'einnahme', 'fix')),
  ADD COLUMN IF NOT EXISTS hauptkonto INTEGER,
  ADD COLUMN IF NOT EXISTS mwst_pflichtig BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS erlaubte_zahlungswege TEXT[] NOT NULL DEFAULT '{}';

-- soll/haben künftig nur für art='fix' nötig → nullable machen
ALTER TABLE buchungs_vorlagen ALTER COLUMN soll_konto DROP NOT NULL;
ALTER TABLE buchungs_vorlagen ALTER COLUMN haben_konto DROP NOT NULL;

-- alte UNIQUE(user_id, geschaeftsfall_id, zahlungsweg) entfernen (Variante wandert in erlaubte_zahlungswege)
ALTER TABLE buchungs_vorlagen DROP CONSTRAINT IF EXISTS buchungs_vorlagen_user_id_geschaeftsfall_id_zahlungsweg_key;
CREATE UNIQUE INDEX IF NOT EXISTS buchungs_vorlagen_user_gf_uidx
  ON buchungs_vorlagen (user_id, geschaeftsfall_id);

-- buchungen: zahlungsweg um 'kreditor' und 'debitor' erweitern
ALTER TABLE buchungen DROP CONSTRAINT IF EXISTS buchungen_zahlungsweg_check;
ALTER TABLE buchungen ADD CONSTRAINT buchungen_zahlungsweg_check
  CHECK (zahlungsweg IS NULL OR zahlungsweg IN ('kasse','bank','privat','kreditor','debitor'));

-- 2) MWST-Satz-Tabelle (datumsabhängig)
CREATE TABLE IF NOT EXISTS mwst_satz (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  gueltig_ab DATE NOT NULL,
  satz DECIMAL(4,2) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id, gueltig_ab)
);
ALTER TABLE mwst_satz ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS mwst_satz_own ON mwst_satz;
CREATE POLICY mwst_satz_own ON mwst_satz
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- 3) Fehlende Konten ergänzen (Delkredere + Debitorenverluste)
--    (idempotent: nur einfügen, wenn Kontonummer für den User fehlt)
INSERT INTO konten (id, user_id, kontonummer, bezeichnung, kategorie)
SELECT gen_random_uuid(), u.user_id, v.kontonummer, v.bezeichnung, v.kategorie
FROM (SELECT DISTINCT user_id FROM konten) u
CROSS JOIN (VALUES
  (1109, 'Delkredere (Wertberichtigung Forderungen)', 'Umlaufvermögen'),
  (3805, 'Debitorenverluste',                          'Betriebsertrag')
) AS v(kontonummer, bezeichnung, kategorie)
WHERE NOT EXISTS (
  SELECT 1 FROM konten k WHERE k.user_id = u.user_id AND k.kontonummer = v.kontonummer
);
```

- [ ] **Step 2: Migration anwenden (Supabase MCP) und prüfen**

Anwenden via `mcp__supabase__apply_migration` (project_id `pltbaqqwpnmdajwgnhpd`), dann:
```sql
SELECT column_name FROM information_schema.columns
WHERE table_name='buchungs_vorlagen' AND column_name IN ('art','hauptkonto','mwst_pflichtig','erlaubte_zahlungswege');
SELECT kontonummer,bezeichnung FROM konten WHERE kontonummer IN (1109,3805) ORDER BY kontonummer;
```
Expected: 4 Spalten gelistet; Konten 1109 + 3805 vorhanden.

- [ ] **Step 3: MWST-Sätze seeden**

```sql
INSERT INTO mwst_satz (user_id, gueltig_ab, satz)
SELECT DISTINCT user_id, d.gueltig_ab, d.satz FROM konten
CROSS JOIN (VALUES (DATE '2010-01-01', 7.7), (DATE '2024-01-01', 8.1)) AS d(gueltig_ab, satz)
ON CONFLICT (user_id, gueltig_ab) DO NOTHING;
```
Prüfen: `SELECT gueltig_ab, satz FROM mwst_satz ORDER BY gueltig_ab;` → 2 Zeilen (7.7, 8.1).

- [ ] **Step 4: Commit**

```bash
git add Datenbank/migrations/089_geschaeftsfall_zahlungsweg.sql
git commit -m "feat(db): Geschäftsfall+Zahlungsweg-Schema, mwst_satz, Konten 1109/3805"
```

---

## Task 2: Modell – BuchungsVorlage um Geschäftsfall-Felder erweitern

**Files:**
- Modify: `sbs_projer_app/lib/data/models/buchungs_vorlage.dart`

- [ ] **Step 1: Felder ergänzen**

In der Klasse `BuchungsVorlage` neue Felder + Konstruktor + fromJson/toJson ergänzen. `sollKonto`/`habenKonto` werden nullable.

```dart
class BuchungsVorlage {
  final String id;
  final String userId;
  final String geschaeftsfallId;
  final String bezeichnung;
  final String art;                 // 'ausgabe' | 'einnahme' | 'fix'
  final int? hauptkonto;            // bei ausgabe/einnahme
  final bool mwstPflichtig;
  final List<String> erlaubteZahlungswege;
  final int? sollKonto;            // nur bei art='fix'
  final int? habenKonto;          // nur bei art='fix'
  final int? mwstKonto;
  final double? mwstSatz;          // bleibt für Altdaten; neu i.d.R. null (Datum entscheidet)
  final String? zahlungsweg;
  final String? belegordner;
  final String? autoTrigger;
  final bool istAktiv;
  final String? notizen;
  final DateTime? createdAt;

  BuchungsVorlage({
    required this.id,
    required this.userId,
    required this.geschaeftsfallId,
    required this.bezeichnung,
    this.art = 'fix',
    this.hauptkonto,
    this.mwstPflichtig = false,
    this.erlaubteZahlungswege = const [],
    this.sollKonto,
    this.habenKonto,
    this.mwstKonto,
    this.mwstSatz,
    this.zahlungsweg,
    this.belegordner,
    this.autoTrigger,
    this.istAktiv = true,
    this.notizen,
    this.createdAt,
  });

  factory BuchungsVorlage.fromJson(Map<String, dynamic> json) {
    return BuchungsVorlage(
      id: json['id'],
      userId: json['user_id'],
      geschaeftsfallId: json['geschaeftsfall_id'],
      bezeichnung: json['bezeichnung'],
      art: json['art'] ?? 'fix',
      hauptkonto: json['hauptkonto'],
      mwstPflichtig: json['mwst_pflichtig'] ?? false,
      erlaubteZahlungswege:
          (json['erlaubte_zahlungswege'] as List?)?.cast<String>() ?? const [],
      sollKonto: json['soll_konto'],
      habenKonto: json['haben_konto'],
      mwstKonto: json['mwst_konto'],
      mwstSatz: json['mwst_satz'] != null
          ? double.tryParse(json['mwst_satz'].toString())
          : null,
      zahlungsweg: json['zahlungsweg'],
      belegordner: json['belegordner'],
      autoTrigger: json['auto_trigger'],
      istAktiv: json['ist_aktiv'] ?? true,
      notizen: json['notizen'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'geschaeftsfall_id': geschaeftsfallId,
      'bezeichnung': bezeichnung,
      'art': art,
      'hauptkonto': hauptkonto,
      'mwst_pflichtig': mwstPflichtig,
      'erlaubte_zahlungswege': erlaubteZahlungswege,
      'soll_konto': sollKonto,
      'haben_konto': habenKonto,
      'mwst_konto': mwstKonto,
      'mwst_satz': mwstSatz,
      'zahlungsweg': zahlungsweg,
      'belegordner': belegordner,
      'auto_trigger': autoTrigger,
      'ist_aktiv': istAktiv,
      'notizen': notizen,
    };
  }
}
```

- [ ] **Step 2: Analyse**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze lib/data/models/buchungs_vorlage.dart`
Expected: No issues (ggf. bestehende Verwender von `sollKonto!`/`habenKonto!` werden in Task 4/5 angepasst).

- [ ] **Step 3: Commit**

```bash
git add sbs_projer_app/lib/data/models/buchungs_vorlage.dart
git commit -m "feat(model): BuchungsVorlage um Geschäftsfall-Felder (art/hauptkonto/zahlungswege)"
```

---

## Task 3: GeschaeftsfallResolver – reine Auflösungslogik (TDD)

**Files:**
- Create: `sbs_projer_app/lib/services/buchhaltung/geschaeftsfall_resolver.dart`
- Test: `sbs_projer_app/test/geschaeftsfall_resolver_test.dart`

- [ ] **Step 1: Failing Test schreiben**

```dart
// test/geschaeftsfall_resolver_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/buchungs_vorlage.dart';
import 'package:sbs_projer_app/services/buchhaltung/geschaeftsfall_resolver.dart';

BuchungsVorlage _v({
  String art = 'ausgabe', int? hauptkonto, int? soll, int? haben, int? mwstKonto,
}) => BuchungsVorlage(
      id: 'x', userId: 'u', geschaeftsfallId: 'g', bezeichnung: 'b',
      art: art, hauptkonto: hauptkonto, sollKonto: soll, habenKonto: haben,
      mwstKonto: mwstKonto, erlaubteZahlungswege: const ['kasse','bank','privat','kreditor'],
    );

void main() {
  test('ausgabe + bank → Soll=Hauptkonto, Haben=1020', () {
    final r = GeschaeftsfallResolver.aufloesen(_v(hauptkonto: 6200, mwstKonto: 1171), 'bank');
    expect(r.sollKonto, 6200);
    expect(r.habenKonto, 1020);
    expect(r.mwstKonto, 1171);
  });

  test('ausgabe + kreditor → Haben=2000', () {
    final r = GeschaeftsfallResolver.aufloesen(_v(hauptkonto: 6301), 'kreditor');
    expect(r.habenKonto, 2000);
  });

  test('ausgabe + privat → Haben=2260', () {
    final r = GeschaeftsfallResolver.aufloesen(_v(hauptkonto: 6500), 'privat');
    expect(r.habenKonto, 2260);
  });

  test('einnahme + debitor → Soll=1100, Haben=Hauptkonto, MWST=Umsatzsteuer', () {
    final r = GeschaeftsfallResolver.aufloesen(
        _v(art: 'einnahme', hauptkonto: 3400, mwstKonto: 2200), 'debitor');
    expect(r.sollKonto, 1100);
    expect(r.habenKonto, 3400);
    expect(r.mwstKonto, 2200);
  });

  test('fix → Soll/Haben direkt aus Vorlage', () {
    final r = GeschaeftsfallResolver.aufloesen(
        _v(art: 'fix', soll: 6301, haben: 2000, mwstKonto: 1170), null);
    expect(r.sollKonto, 6301);
    expect(r.habenKonto, 2000);
  });

  test('unbekannter Zahlungsweg → ArgumentError', () {
    expect(() => GeschaeftsfallResolver.aufloesen(_v(hauptkonto: 6200), 'paypal'),
        throwsArgumentError);
  });
}
```

- [ ] **Step 2: Test laufen lassen → FAIL**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test test/geschaeftsfall_resolver_test.dart`
Expected: FAIL (`geschaeftsfall_resolver.dart` existiert nicht / `aufloesen` undefiniert).

- [ ] **Step 3: Resolver implementieren**

```dart
// lib/services/buchhaltung/geschaeftsfall_resolver.dart
import '../../data/models/buchungs_vorlage.dart';

/// Aufgelöste Konten einer Buchung.
class AufgeloesteBuchung {
  final int sollKonto;
  final int habenKonto;
  final int? mwstKonto;
  const AufgeloesteBuchung(this.sollKonto, this.habenKonto, this.mwstKonto);
}

/// Löst Geschäftsfall (was) + Zahlungsweg (wie) zu Soll/Haben/MWST auf.
class GeschaeftsfallResolver {
  /// Zahlungsweg → Gegenkonto.
  static int gegenkonto(String zahlungsweg) {
    switch (zahlungsweg) {
      case 'kasse':
        return 1000;
      case 'bank':
        return 1020;
      case 'privat':
        return 2260;
      case 'kreditor':
        return 2000;
      case 'debitor':
        return 1100;
      default:
        throw ArgumentError('Unbekannter Zahlungsweg: $zahlungsweg');
    }
  }

  static AufgeloesteBuchung aufloesen(BuchungsVorlage v, String? zahlungsweg) {
    switch (v.art) {
      case 'fix':
        return AufgeloesteBuchung(v.sollKonto!, v.habenKonto!, v.mwstKonto);
      case 'ausgabe':
        final g = gegenkonto(zahlungsweg!);
        return AufgeloesteBuchung(v.hauptkonto!, g, v.mwstKonto);
      case 'einnahme':
        final g = gegenkonto(zahlungsweg!);
        return AufgeloesteBuchung(g, v.hauptkonto!, v.mwstKonto);
      default:
        throw ArgumentError('Unbekannte Geschäftsfall-Art: ${v.art}');
    }
  }
}
```

- [ ] **Step 4: Test laufen lassen → PASS**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test test/geschaeftsfall_resolver_test.dart`
Expected: PASS (6 Tests).

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/services/buchhaltung/geschaeftsfall_resolver.dart sbs_projer_app/test/geschaeftsfall_resolver_test.dart
git commit -m "feat(buchhaltung): GeschaeftsfallResolver (Zahlungsweg→Gegenkonto) + Tests"
```

---

## Task 4: MwstSatzService – datumsabhängiger Satz (TDD für Lookup)

**Files:**
- Create: `sbs_projer_app/lib/services/buchhaltung/mwst_satz_service.dart`
- Test: `sbs_projer_app/test/mwst_satz_lookup_test.dart`

- [ ] **Step 1: Failing Test schreiben** (reine Lookup-Funktion über eine übergebene Satz-Liste, ohne Supabase)

```dart
// test/mwst_satz_lookup_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/buchhaltung/mwst_satz_service.dart';

void main() {
  final saetze = [
    MwstSatz(DateTime(2010, 1, 1), 7.7),
    MwstSatz(DateTime(2024, 1, 1), 8.1),
  ];

  test('Datum 2023 → 7.7', () {
    expect(MwstSatzService.satzFuer(DateTime(2023, 6, 1), saetze), 7.7);
  });
  test('Datum 2024 → 8.1', () {
    expect(MwstSatzService.satzFuer(DateTime(2024, 1, 1), saetze), 8.1);
  });
  test('Datum 2026 → 8.1 (jüngster gültiger)', () {
    expect(MwstSatzService.satzFuer(DateTime(2026, 6, 9), saetze), 8.1);
  });
  test('Datum vor erstem Eintrag → 0.0', () {
    expect(MwstSatzService.satzFuer(DateTime(2000, 1, 1), saetze), 0.0);
  });
}
```

- [ ] **Step 2: Test laufen lassen → FAIL**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test test/mwst_satz_lookup_test.dart`
Expected: FAIL (Klasse/Methoden fehlen).

- [ ] **Step 3: Service implementieren** (Lookup pur + Laden aus Supabase)

```dart
// lib/services/buchhaltung/mwst_satz_service.dart
import '../supabase/supabase_service.dart';

class MwstSatz {
  final DateTime gueltigAb;
  final double satz;
  const MwstSatz(this.gueltigAb, this.satz);
}

class MwstSatzService {
  /// Reiner Lookup: jüngster Satz mit gueltigAb <= datum; sonst 0.0.
  static double satzFuer(DateTime datum, List<MwstSatz> saetze) {
    final sorted = [...saetze]..sort((a, b) => a.gueltigAb.compareTo(b.gueltigAb));
    double result = 0.0;
    for (final s in sorted) {
      if (!datum.isBefore(s.gueltigAb)) {
        result = s.satz;
      }
    }
    return result;
  }

  static List<MwstSatz>? _cache;

  static Future<List<MwstSatz>> laden() async {
    if (_cache != null) return _cache!;
    final rows = await SupabaseService.client
        .from('mwst_satz')
        .select('gueltig_ab, satz')
        .eq('user_id', SupabaseService.dataUserId);
    _cache = (rows as List)
        .map((r) => MwstSatz(
            DateTime.parse(r['gueltig_ab']),
            double.parse(r['satz'].toString())))
        .toList();
    return _cache!;
  }

  /// Satz für ein Buchungsdatum (lädt + cached).
  static Future<double> satzFuerDatum(DateTime datum) async {
    return satzFuer(datum, await laden());
  }
}
```

- [ ] **Step 4: Test laufen lassen → PASS**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test test/mwst_satz_lookup_test.dart`
Expected: PASS (4 Tests).

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/services/buchhaltung/mwst_satz_service.dart sbs_projer_app/test/mwst_satz_lookup_test.dart
git commit -m "feat(buchhaltung): MwstSatzService (datumsabhängiger Satz) + Tests"
```

---

## Task 5: BuchungService.createFromVorlage auf Resolver + Datums-MWST umstellen

**Files:**
- Modify: `sbs_projer_app/lib/services/rechnung/buchung_service.dart`

**Kontext:** Bisher nutzt `createFromVorlage` `vorlage.sollKonto`/`habenKonto` direkt und `vorlage.mwstSatz`. Neu: bei `art != 'fix'` über `GeschaeftsfallResolver` + `zahlungsweg`-Parameter; MWST-Satz aus dem Datum, wenn `mwstPflichtig`.

- [ ] **Step 1: Methode anpassen**

```dart
// in buchung_service.dart – import ergänzen:
import '../buchhaltung/geschaeftsfall_resolver.dart';
import '../buchhaltung/mwst_satz_service.dart';

// Signatur erweitern um zahlungsweg:
static Future<Buchung> createFromVorlage(
  BuchungsVorlage vorlage, {
  required DateTime datum,
  required double betragNetto,
  String? zahlungsweg,           // NEU: bei art ausgabe/einnahme erforderlich
  String? beschreibung,
  String? belegnummer,
  String? belegTyp,
  String? belegId,
}) async {
  final aufgeloest = GeschaeftsfallResolver.aufloesen(vorlage, zahlungsweg);

  // MWST: Satz aus Datum, nur wenn Vorlage steuerpflichtig
  final double mwstSatz = vorlage.mwstPflichtig
      ? await MwstSatzService.satzFuerDatum(datum)
      : 0;
  final double mwstBetrag = betragNetto * mwstSatz / 100;
  final double betragBrutto = betragNetto + mwstBetrag;

  final json = {
    'datum': datum.toIso8601String().substring(0, 10),
    'vorlage_id': vorlage.id,
    'soll_konto': aufgeloest.sollKonto,
    'haben_konto': aufgeloest.habenKonto,
    'mwst_konto': vorlage.mwstPflichtig ? aufgeloest.mwstKonto : null,
    'betrag_netto': betragNetto,
    'mwst_satz': mwstSatz,
    'mwst_betrag': mwstBetrag,
    'betrag_brutto': betragBrutto,
    'beschreibung': beschreibung ?? vorlage.bezeichnung,
    'belegnummer': belegnummer,
    'zahlungsweg': zahlungsweg,
    'belegordner': vorlage.belegordner,
    'beleg_typ': belegTyp,
    'beleg_id': belegId,
    'geschaeftsjahr': datum.year,
  };
  return BuchungRepository.create(json);
}
```

- [ ] **Step 2: Bestehende Aufrufer prüfen**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && grep -rn "createFromVorlage" lib/`
Für jeden Aufrufer (z. B. `reinigung_buchung_service.dart`, camt-Booker): wo die Vorlage `art='fix'` ist, bleibt `zahlungsweg` `null` → kompatibel. Wo eine Ausgabe gebucht wird, `zahlungsweg` mitgeben. (Reinigung nutzt eigene Logik in `ReinigungBuchungService`, nicht createFromVorlage — unverändert.)

- [ ] **Step 3: Analyse**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze lib/services/rechnung/buchung_service.dart`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add sbs_projer_app/lib/services/rechnung/buchung_service.dart
git commit -m "feat(buchhaltung): createFromVorlage nutzt Resolver + datumsabhängige MWST"
```

---

## Task 6: Geschäftsfälle neu seeden (~30, optimiert + korrigiert)

**Files:**
- Create: `Datenbank/migrations/090_geschaeftsfaelle_seed.sql`

**Kontext:** Die alten flachen Vorlagen werden durch die neue, schlanke Struktur ersetzt. MWST-Flags nach KMU-Korrektheit (Versicherungen/Bussen/Fahrbewilligung/Miete = MwSt-frei; Material → Vorsteuer 1170; übriger Aufwand → 1171). `art`/`hauptkonto`/`erlaubte_zahlungswege` gesetzt.

- [ ] **Step 1: Seed-Migration schreiben**

```sql
-- 090_geschaeftsfaelle_seed.sql – Neue Geschäftsfälle (Phase 0a)
-- Ersetzt die flachen Vorlagen je User. auto_trigger-Vorlagen (Reinigung/Heineken/MWST)
-- werden NICHT angefasst (separate Pflege).

DO $$
DECLARE u RECORD;
BEGIN
FOR u IN (SELECT DISTINCT user_id FROM konten) LOOP
  -- alte manuelle (nicht-auto-trigger) Ausgaben-Vorlagen entfernen
  DELETE FROM buchungs_vorlagen
   WHERE user_id = u.user_id AND auto_trigger IS NULL;

  INSERT INTO buchungs_vorlagen
    (id, user_id, geschaeftsfall_id, bezeichnung, art, hauptkonto, mwst_pflichtig, mwst_konto, erlaubte_zahlungswege, soll_konto, haben_konto, belegordner)
  VALUES
  -- AUSGABEN (Zahlungswege kasse/bank/privat/kreditor; mwst_konto Vorsteuer)
  (gen_random_uuid(), u.user_id, 'A-spesen','Spesen (Essen/Getränke)','ausgabe',5820,true,1171,'{kasse,bank,privat,kreditor}',NULL,NULL,'030_Spesen'),
  (gen_random_uuid(), u.user_id, 'A-tanken','Tanken Geschäftsauto','ausgabe',6200,true,1171,'{kasse,bank,privat,kreditor}',NULL,NULL,'040_Tanken'),
  (gen_random_uuid(), u.user_id, 'A-park','Parkgebühren','ausgabe',6270,true,1171,'{kasse,bank,privat,kreditor}',NULL,NULL,'050_Parkgebuehren'),
  (gen_random_uuid(), u.user_id, 'A-busse','Bussen','ausgabe',6280,false,NULL,'{kasse,bank,privat,kreditor}',NULL,NULL,'060_Bussen'),
  (gen_random_uuid(), u.user_id, 'A-fahrbew','Fahrbewilligung','ausgabe',6275,false,NULL,'{kasse,bank,privat,kreditor}',NULL,NULL,'070_Fahrbewilligung'),
  (gen_random_uuid(), u.user_id, 'A-autorep','Autoreparatur/Selbstbehalt','ausgabe',6250,true,1171,'{kasse,bank,privat,kreditor}',NULL,NULL,'080_Autoreperaturen'),
  (gen_random_uuid(), u.user_id, 'A-buero','Büromaterial','ausgabe',6500,true,1171,'{kasse,bank,privat,kreditor}',NULL,NULL,'090_Bueromaterial'),
  (gen_random_uuid(), u.user_id, 'A-material','Werkzeug/Material','ausgabe',4004,true,1170,'{kasse,bank,privat,kreditor}',NULL,NULL,'100_Werkzeug_Material'),
  (gen_random_uuid(), u.user_id, 'A-kleider','Berufskleider','ausgabe',5850,true,1171,'{kasse,bank,privat,kreditor}',NULL,NULL,'110_Berufskleider'),
  (gen_random_uuid(), u.user_id, 'A-kaffee','Kaffee','ausgabe',5880,true,1171,'{kasse,bank,privat,kreditor}',NULL,NULL,'120_Kaffee'),
  (gen_random_uuid(), u.user_id, 'A-entsorg','Entsorgung/Kehricht','ausgabe',6460,true,1171,'{kasse,bank,privat,kreditor}',NULL,NULL,'130_Kehricht'),
  (gen_random_uuid(), u.user_id, 'A-porto','Briefmarken/Porto','ausgabe',6510,false,NULL,'{kasse,bank,privat,kreditor}',NULL,NULL,'140_Briefmarken'),
  (gen_random_uuid(), u.user_id, 'A-telekom','Internet/Mobile (Telekom)','ausgabe',6510,true,1171,'{kasse,bank,privat,kreditor}',NULL,NULL,'150_Internet'),
  (gen_random_uuid(), u.user_id, 'A-software','Software','ausgabe',6560,true,1171,'{kasse,bank,privat,kreditor}',NULL,NULL,'170_Software'),
  (gen_random_uuid(), u.user_id, 'A-miete','Büromiete','ausgabe',6000,false,NULL,'{bank,kreditor}',NULL,NULL,'180_Bueromiete'),
  (gen_random_uuid(), u.user_id, 'A-buchf','Buchführung/Beratung','ausgabe',6530,true,1171,'{bank,kreditor}',NULL,NULL,'210_Buchfuehrung'),
  (gen_random_uuid(), u.user_id, 'A-sachvers','Sachversicherung/Haftpflicht','ausgabe',6300,false,NULL,'{bank,kreditor}',NULL,NULL,'240_Versicherung'),
  (gen_random_uuid(), u.user_id, 'A-sozvers','Sozialversicherung (AHV/BVG/SUVA)','ausgabe',5700,false,NULL,'{bank,kreditor}',NULL,NULL,'230_Sozialversicherungen'),
  -- FIXE Geschäftsfälle (explizit Soll/Haben)
  (gen_random_uuid(), u.user_id, 'F-fran-rg','Franchise Rechnung (Heineken)','fix',6301,true,1170,'{}',6301,2000,'190_Franchisegebuehr'),
  (gen_random_uuid(), u.user_id, 'F-fran-zg','Franchise Zahlung','fix',NULL,false,NULL,'{}',2000,1020,'190_Franchisegebuehr'),
  (gen_random_uuid(), u.user_id, 'F-bankgeb','Bankgebühren','fix',NULL,false,NULL,'{}',6940,1020,'200_Bankgebuehren'),
  (gen_random_uuid(), u.user_id, 'F-steuer-rst','Steuer-Rückstellung (Jahresende)','fix',NULL,false,NULL,'{}',8900,2208,'300_Steuern'),
  (gen_random_uuid(), u.user_id, 'F-steuer-zg','Steuer-Zahlung','fix',NULL,false,NULL,'{}',2208,1020,'300_Steuern'),
  (gen_random_uuid(), u.user_id, 'F-steuer-rk','Steuer-Rückerstattung','fix',NULL,false,NULL,'{}',1020,2208,'300_Steuern'),
  (gen_random_uuid(), u.user_id, 'F-debverlust','Debitorenverlust (netto)','fix',NULL,false,NULL,'{}',3805,1100,'019_Abschreibungen'),
  (gen_random_uuid(), u.user_id, 'F-debverlust-mwst','Debitorenverlust MWST-Rückholung','fix',NULL,false,NULL,'{}',2200,1100,'019_Abschreibungen'),
  (gen_random_uuid(), u.user_id, 'F-delkredere','Delkredere bilden','fix',NULL,false,NULL,'{}',3805,1109,'019_Abschreibungen'),
  (gen_random_uuid(), u.user_id, 'F-corona-kredit','Corona-Kredit Bezug','fix',NULL,false,NULL,'{}',1020,2500,'610_Coronakredit'),
  (gen_random_uuid(), u.user_id, 'F-corona-tilg','Corona-Kredit Rückzahlung','fix',NULL,false,NULL,'{}',2500,1020,'610_Coronakredit'),
  (gen_random_uuid(), u.user_id, 'F-kae','Kurzarbeit/EO-Eingang','fix',NULL,false,NULL,'{}',1020,2276,'600_KAE_Corona'),
  (gen_random_uuid(), u.user_id, 'F-haertefall','Härtefallgelder','fix',NULL,false,NULL,'{}',1020,8510,'620_Haertefall'),
  (gen_random_uuid(), u.user_id, 'F-gruend-kapital','Gründung Stammkapital','fix',NULL,false,NULL,'{}',1020,2800,'990_Firmengruendung'),
  (gen_random_uuid(), u.user_id, 'F-gruend-kosten','Gründungskosten','fix',6550,true,1170,'{}',6550,1020,'990_Firmengruendung');
END LOOP;
END $$;
```

- [ ] **Step 2: Anwenden + prüfen**

Anwenden via `mcp__supabase__apply_migration`, dann:
```sql
SELECT art, count(*) FROM buchungs_vorlagen WHERE auto_trigger IS NULL GROUP BY art ORDER BY art;
SELECT geschaeftsfall_id, bezeichnung, mwst_pflichtig FROM buchungs_vorlagen
 WHERE geschaeftsfall_id IN ('A-busse','A-sachvers','A-material') ORDER BY geschaeftsfall_id;
```
Expected: `ausgabe`-Zeilen + `fix`-Zeilen vorhanden; `A-busse`/`A-sachvers` = `mwst_pflichtig=false`, `A-material` = true (mwst_konto 1170).

- [ ] **Step 3: Commit**

```bash
git add Datenbank/migrations/090_geschaeftsfaelle_seed.sql
git commit -m "feat(db): ~30 optimierte Geschäftsfälle (MWST-korrigiert, Zahlungswege)"
```

---

## Task 7: Buchungsformular auf „Geschäftsfall + Zahlungsweg" umstellen

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/buchhaltung/buchung_form_screen.dart`

**Kontext:** Bisher füllt `_onVorlageSelected` Soll/Haben/MWST aus der Vorlage. Neu: bei `art != 'fix'` zeigt das Formular einen **Zahlungsweg-Auswahl** (Dropdown aus `vorlage.erlaubteZahlungswege`); Soll/Haben werden nicht mehr manuell gesetzt, sondern beim Speichern via `BuchungService.createFromVorlage(..., zahlungsweg: _zahlungsweg)` aufgelöst. MWST-Satz wird nicht mehr eingegeben (kommt aus dem Datum).

- [ ] **Step 1: Formular-Logik anpassen**

```dart
// State ergänzen:
String? _zahlungsweg;

// Bei Vorlagenauswahl:
void _onVorlageSelected(BuchungsVorlage v) {
  setState(() {
    _selectedVorlage = v;
    _zahlungsweg = v.erlaubteZahlungswege.isNotEmpty
        ? v.erlaubteZahlungswege.first
        : null;
  });
}

// Im Build, NUR wenn art != 'fix' und erlaubteZahlungswege nicht leer:
if (_selectedVorlage != null &&
    _selectedVorlage!.art != 'fix' &&
    _selectedVorlage!.erlaubteZahlungswege.isNotEmpty)
  DropdownButtonFormField<String>(
    value: _zahlungsweg,
    decoration: const InputDecoration(labelText: 'Zahlungsweg'),
    items: _selectedVorlage!.erlaubteZahlungswege
        .map((z) => DropdownMenuItem(
            value: z,
            child: Text(const {
              'kasse': 'Bar (Kasse)',
              'bank': 'Bank',
              'privat': 'Privat bezahlt',
              'kreditor': 'Kreditor (offene Rechnung)',
              'debitor': 'Debitor (Kundenrechnung)',
            }[z] ?? z)))
        .toList(),
    onChanged: (v) => setState(() => _zahlungsweg = v),
  ),

// Beim Speichern:
await BuchungService.createFromVorlage(
  _selectedVorlage!,
  datum: _datum,
  betragNetto: double.parse(_betragController.text.replaceAll(',', '.')),
  zahlungsweg: _zahlungsweg,
  beschreibung: _beschreibungController.text.isEmpty ? null : _beschreibungController.text,
  belegnummer: _belegnummerController.text.isEmpty ? null : _belegnummerController.text,
);
```

Die alten manuellen Felder `_sollKontoController`/`_habenKontoController`/`_mwstSatzController` für den Vorlagen-Modus ausblenden (nur im „frei buchen"-Modus belassen, falls vorhanden).

- [ ] **Step 2: Analyse + App startet**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze lib/presentation/screens/buchhaltung/buchung_form_screen.dart`
Expected: No issues.

- [ ] **Step 3: Manuelle Verifikation**

App starten (`flutter run -d edge`), `/buchhaltung/buchungen/neu`: Geschäftsfall „Tanken" wählen → Zahlungsweg-Dropdown erscheint (Bar/Bank/Privat/Kreditor); Betrag 100, Datum 2026-06-09, speichern. In `/buchhaltung/buchungen` prüfen: Soll 6200 / Haben gewählter Zahlungsweg / MWST 8.1 %.

- [ ] **Step 4: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/buchhaltung/buchung_form_screen.dart
git commit -m "feat(ui): Buchungsformular Geschäftsfall + Zahlungsweg"
```

---

## Task 8: Abschluss-Verifikation

- [ ] **Step 1: Alle Tests + Analyse**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test && flutter analyze`
Expected: Alle Tests PASS, analyze ohne neue Fehler.

- [ ] **Step 2: Erfolgskriterien prüfen** (manuell, gegen Spec §8)
  - Ausgabe via Geschäftsfall+Zahlungsweg buchbar (inkl. Kreditor) ✔
  - MWST-Satz aus Datum (7.7 vor 2024 / 8.1 ab 2024) ✔
  - Konten 1109/3805 vorhanden, MWST-Flags korrigiert (Bussen/Versicherung/Fahrbewilligung MwSt-frei) ✔
  - Bestehende Buchungen/Screens funktionieren weiter ✔

---

## Hinweise für die Umsetzung

- **DB-Zugriff:** bevorzugt Supabase MCP (`mcp__supabase__apply_migration` / `execute_sql`), project_id `pltbaqqwpnmdajwgnhpd`.
- **Kein Deploy** in diesem Plan — reine Logik/DB/Screen-Änderungen. Deploy erst, wenn 0a–0c stehen.
- **Folge-Pläne:** 0b (Auswertungen Bilanz/ER/MWST), 0c (Offene-Posten-Sicht) — bauen auf den hier definierten Typen (`BuchungsVorlage.art`, `GeschaeftsfallResolver`, `MwstSatzService`) auf.

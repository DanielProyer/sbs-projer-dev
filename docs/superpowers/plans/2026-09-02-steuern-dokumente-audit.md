# Steuern-Screen, Dokumente-Modul, Abschlussprüfung — Implementation Plan

> **Status 02.09.2026:** Tasks 1–15 umgesetzt (subagent-driven, je Spec- + Quality-Review), live als **v0.96.0** (gh-pages `d56cda9`), Import-Echtlauf 76/7/63 verifiziert. Browser-Klicktest durch Daniel offen (siehe `ToDo.md`).

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Steuerunterlagen 2019 ff. in der App ablegen (generisches Dokumente-Modul), ein Steuern-Screen mit Soll/Ist je Jahr, und der Audit-Screen als regelbasierte Abschlussprüfung mit Jahreswahl.

**Architecture:** Drei Migrationen (`dokumente` + Bucket, `steuerjahre`, `buchungen.steuerjahr/steuerart` + View). Reine Dart-Services (`SteuerjahrRechner`, `AbschlussPruefService` mit Regelklassen) werden mit `flutter_test` getestet; Repositories folgen dem `BuchungsBelegRepository`-Muster (Supabase-Client, `SupabaseService.dataUserId`, Pagination `.order(...).order('id').range(...)`). Screens sind Smartphone-first und CanvasKit-sicher (`GestureDetector` + `Container` statt Material-Buttons, kein `ExpansionTile dense`). Ein Python-Skript befüllt den Altbestand.

**Tech Stack:** Flutter/Dart, Riverpod, go_router, Supabase (MCP `apply_migration`/`execute_sql`, project `pltbaqqwpnmdajwgnhpd`), `flutter_test`, Python 3.9 (`py -3`) mit `supabase` + `python-dotenv` für den Import. Spec: `docs/superpowers/specs/2026-09-02-steuern-dokumente-audit-design.md`. Flutter: `export PATH="$PATH:/c/flutter/bin"`, Arbeitsverzeichnis `sbs_projer_app`. Daniel `user_id = 1e1ec2dd-7836-4d8e-8256-c5649d994ee2`.

**Konventionen aus CLAUDE.md:** deutsche Bezeichner/Texte, Pagination immer mit `.order('id')` als letztem Schlüssel, keine `pw.Document()`, keine `FilledButton`/`OutlinedButton` für kritische Aktionen, Version in `pubspec.yaml` UND `lib/core/app_version.dart` bumpen.

---

## Dateiübersicht

**Neu (Datenbank)**
- `Datenbank/migrations/182_dokumente.sql` — Tabelle `dokumente`, Bucket `dokumente`, RLS
- `Datenbank/migrations/183_steuerjahre.sql` — Tabelle `steuerjahre`
- `Datenbank/migrations/184_buchungen_steuerjahr.sql` — Spalten + `view_steuerjahr_zahlungen`
- `Datenbank/import/import_steuer_dokumente.py`, `Datenbank/import/steuer_dokumente_katalog.csv`, `Datenbank/import/steuerjahre_seed.csv`, `Datenbank/import/steuerzahlungen_zuordnung.csv`

**Neu (App)**
- `lib/data/models/dokument.dart`, `lib/data/models/steuerjahr.dart`
- `lib/data/repositories/dokument_repository.dart`, `lib/data/repositories/steuerjahr_repository.dart`, `lib/data/repositories/steuerzahlung_repository.dart`
- `lib/services/steuern/dokument_pfad.dart` (reine Pfad-/Typ-Logik), `lib/services/steuern/steuerjahr_rechner.dart`
- `lib/services/buchhaltung/abschluss_pruef_service.dart`, `lib/services/buchhaltung/abschluss_regeln.dart`
- `lib/presentation/providers/dokument_providers.dart`, `lib/presentation/providers/steuern_providers.dart`
- `lib/presentation/widgets/tap_knopf.dart`, `lib/presentation/widgets/dokumente/dokument_liste.dart`, `lib/presentation/widgets/dokumente/dokument_upload_dialog.dart`
- `lib/presentation/screens/dokumente/dokumente_screen.dart`
- `lib/presentation/screens/buchhaltung/steuern/steuern_screen.dart`, `lib/presentation/screens/buchhaltung/steuern/steuerjahr_screen.dart`, `lib/presentation/screens/buchhaltung/steuern/steuer_zuordnung_dialog.dart`
- Tests: `test/dokument_pfad_test.dart`, `test/steuerjahr_rechner_test.dart`, `test/abschluss_pruef_service_test.dart`, `test/audit_service_entfernt_test.dart`

**Geändert (App)**
- `lib/data/models/buchung.dart` (+ `steuerjahr`, `steuerart`)
- `lib/data/repositories/rechnung_repository.dart` (+ `getOffene`)
- `lib/presentation/providers/buchhaltung_providers.dart` (Audit-Provider ersetzt, `_toSaldoInput` öffentlich)
- `lib/presentation/screens/buchhaltung/audit_screen.dart` (Neubau)
- `lib/presentation/screens/buchhaltung/buchhaltung_dashboard_screen.dart` (Kachel Steuern, Link Details)
- `lib/presentation/screens/home_screen.dart` (Menüeintrag Dokumente)
- `lib/core/config/router.dart` (4 Routen)
- `lib/services/camt/camt_ausgabe_booker.dart`, `lib/services/camt/camt_auto_booker.dart`, `lib/presentation/screens/buchhaltung/camt/camt_import_tab.dart` (Steuerjahr/Steuerart)
- `lib/core/app_version.dart`, `pubspec.yaml` (v0.96.0)

**Gelöscht:** `lib/services/buchhaltung/audit_service.dart`, `test/audit_service_test.dart`

---

### Task 1: Migration 182 — `dokumente` + Bucket

**Files:**
- Create: `Datenbank/migrations/182_dokumente.sql`

- [ ] **Step 1: Migrationsdatei schreiben**

```sql
-- 182: Generisches Dokumente-Modul (Steuern zuerst), 02.09.2026
-- Spec: docs/superpowers/specs/2026-09-02-steuern-dokumente-audit-design.md
CREATE TABLE IF NOT EXISTS dokumente (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id),
    bereich TEXT NOT NULL CHECK (bereich IN ('steuern','versicherungen','vertraege','behoerden','bank','sonstiges')),
    typ TEXT NOT NULL,
    kategorie TEXT,
    jahr INTEGER,
    dokument_datum DATE,
    betrag NUMERIC(12,2),
    referenz TEXT,
    titel TEXT NOT NULL,
    notizen TEXT,
    dateiname TEXT NOT NULL,
    dateityp TEXT NOT NULL,
    groesse_bytes INTEGER,
    seiten INTEGER,
    storage_pfad TEXT NOT NULL UNIQUE,
    buchung_id UUID REFERENCES buchungen(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_dokumente_user_bereich_jahr ON dokumente(user_id, bereich, jahr);
CREATE INDEX IF NOT EXISTS idx_dokumente_buchung ON dokumente(buchung_id);

ALTER TABLE dokumente ENABLE ROW LEVEL SECURITY;
CREATE POLICY "dokumente_select" ON dokumente FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "dokumente_insert" ON dokumente FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "dokumente_update" ON dokumente FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "dokumente_delete" ON dokumente FOR DELETE USING (auth.uid() = user_id);

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('dokumente', 'dokumente', false, 20971520, ARRAY['application/pdf','image/jpeg','image/png'])
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "dokumente_storage_select" ON storage.objects FOR SELECT
  USING (bucket_id = 'dokumente' AND auth.uid()::text = (string_to_array(name, '/'))[1]);
CREATE POLICY "dokumente_storage_insert" ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'dokumente' AND auth.uid()::text = (string_to_array(name, '/'))[1]);
CREATE POLICY "dokumente_storage_update" ON storage.objects FOR UPDATE
  USING (bucket_id = 'dokumente' AND auth.uid()::text = (string_to_array(name, '/'))[1]);
CREATE POLICY "dokumente_storage_delete" ON storage.objects FOR DELETE
  USING (bucket_id = 'dokumente' AND auth.uid()::text = (string_to_array(name, '/'))[1]);
```

- [ ] **Step 2: Anwenden** via `mcp__…__apply_migration` (name `182_dokumente`, query = Dateiinhalt).

- [ ] **Step 3: Verifizieren** via `execute_sql`:
```sql
SELECT (SELECT COUNT(*) FROM information_schema.columns WHERE table_name='dokumente') spalten,
       (SELECT COUNT(*) FROM storage.buckets WHERE id='dokumente') bucket;
```
Expected: `spalten = 20`, `bucket = 1`.

- [ ] **Step 4: Commit**
```bash
git add Datenbank/migrations/182_dokumente.sql
git commit -m "db: Migration 182 dokumente (Tabelle, Bucket, RLS)"
```

---

### Task 2: Migration 183 — `steuerjahre`

**Files:**
- Create: `Datenbank/migrations/183_steuerjahre.sql`

- [ ] **Step 1: Migrationsdatei schreiben**

```sql
-- 183: Steuerjahre (Veranlagung Soll je Jahr), 02.09.2026
CREATE TABLE IF NOT EXISTS steuerjahre (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id),
    jahr INTEGER NOT NULL,
    status TEXT NOT NULL DEFAULT 'offen' CHECK (status IN ('offen','eingereicht','veranlagt','ermessen')),
    eingereicht_am DATE,
    veranlagt_am DATE,
    steuerbarer_gewinn NUMERIC(12,2),
    steuerbares_kapital NUMERIC(12,2),
    verlustvortrag_verrechnet NUMERIC(12,2),
    bund_provisorisch NUMERIC(12,2),
    bund_definitiv NUMERIC(12,2),
    kanton_provisorisch NUMERIC(12,2),
    kanton_definitiv NUMERIC(12,2),
    notizen TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (user_id, jahr)
);
ALTER TABLE steuerjahre ENABLE ROW LEVEL SECURITY;
CREATE POLICY "steuerjahre_select" ON steuerjahre FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "steuerjahre_insert" ON steuerjahre FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "steuerjahre_update" ON steuerjahre FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "steuerjahre_delete" ON steuerjahre FOR DELETE USING (auth.uid() = user_id);
```

- [ ] **Step 2: Anwenden** via `apply_migration` (name `183_steuerjahre`).
- [ ] **Step 3: Verifizieren:** `SELECT COUNT(*) FROM information_schema.columns WHERE table_name='steuerjahre';` → `16`.
- [ ] **Step 4: Commit** `git add Datenbank/migrations/183_steuerjahre.sql && git commit -m "db: Migration 183 steuerjahre"`

---

### Task 3: Migration 184 — `buchungen.steuerjahr/steuerart` + View

**Files:**
- Create: `Datenbank/migrations/184_buchungen_steuerjahr.sql`

- [ ] **Step 1: Migrationsdatei schreiben**

```sql
-- 184: Steuerzahlungen einem Steuerjahr/Steuerart zuordnen, 02.09.2026
ALTER TABLE buchungen
  ADD COLUMN IF NOT EXISTS steuerjahr INTEGER,
  ADD COLUMN IF NOT EXISTS steuerart TEXT CHECK (steuerart IS NULL OR steuerart IN ('bund','kanton','mwst','busse'));
CREATE INDEX IF NOT EXISTS idx_buchungen_steuerjahr ON buchungen(user_id, steuerjahr) WHERE steuerjahr IS NOT NULL;

-- Bezahlt je Jahr/Steuerart: Zahlung (Soll Steuerkonto / Haben Geld) positiv,
-- Rückzahlung (Soll Geld / Haben Steuerkonto) negativ.
CREATE OR REPLACE VIEW view_steuerjahr_zahlungen AS
SELECT user_id, steuerjahr, steuerart,
       ROUND(SUM(CASE
         WHEN soll_konto IN (8900,2208,2202) AND haben_konto IN (1000,1020) THEN betrag_brutto
         WHEN soll_konto IN (1000,1020) AND haben_konto IN (8900,2208,2202) THEN -betrag_brutto
         ELSE 0 END)::numeric, 2) AS bezahlt,
       COUNT(*) AS anzahl
FROM buchungen
WHERE NOT ist_storniert AND storno_von_id IS NULL AND steuerjahr IS NOT NULL
GROUP BY user_id, steuerjahr, steuerart;
```

- [ ] **Step 2: Anwenden** via `apply_migration` (name `184_buchungen_steuerjahr`).
- [ ] **Step 3: Verifizieren:** `SELECT column_name FROM information_schema.columns WHERE table_name='buchungen' AND column_name IN ('steuerjahr','steuerart');` → 2 Zeilen; `SELECT COUNT(*) FROM view_steuerjahr_zahlungen;` → `0` (noch nichts zugeordnet).
- [ ] **Step 4: Commit** `git add Datenbank/migrations/184_buchungen_steuerjahr.sql && git commit -m "db: Migration 184 buchungen.steuerjahr/steuerart + view_steuerjahr_zahlungen"`

---

### Task 4: Modelle, Pfad-Logik, Repositories

**Files:**
- Create: `sbs_projer_app/lib/services/steuern/dokument_pfad.dart`
- Create: `sbs_projer_app/lib/data/models/dokument.dart`
- Create: `sbs_projer_app/lib/data/models/steuerjahr.dart`
- Create: `sbs_projer_app/lib/data/repositories/dokument_repository.dart`
- Create: `sbs_projer_app/lib/data/repositories/steuerjahr_repository.dart`
- Create: `sbs_projer_app/lib/data/repositories/steuerzahlung_repository.dart`
- Modify: `sbs_projer_app/lib/data/models/buchung.dart` (Felder + fromJson/toJson)
- Modify: `sbs_projer_app/lib/data/repositories/rechnung_repository.dart` (+ `getOffene`)
- Test: `sbs_projer_app/test/dokument_pfad_test.dart`

- [ ] **Step 1: Failing Test für die reine Pfad-/Typ-Logik**

```dart
// test/dokument_pfad_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/steuern/dokument_pfad.dart';

void main() {
  test('Storage-Pfad: user/bereich/jahr/id_dateiname', () {
    expect(
      dokumentStoragePfad(userId: 'u1', bereich: 'steuern', jahr: 2025, dokumentId: 'd1', dateiname: 'Rg 1.pdf'),
      'u1/steuern/2025/d1_Rg_1.pdf',
    );
  });
  test('Storage-Pfad ohne Jahr nutzt ohne-jahr', () {
    expect(
      dokumentStoragePfad(userId: 'u1', bereich: 'bank', jahr: null, dokumentId: 'd2', dateiname: 'a.pdf'),
      'u1/bank/ohne-jahr/d2_a.pdf',
    );
  });
  test('Typ-Vorschläge je Bereich: steuern enthält veranlagung, sonstiges immer dabei', () {
    expect(dokumentTypen('steuern'), contains('veranlagung'));
    expect(dokumentTypen('versicherungen'), contains('sonstiges'));
    expect(dokumentTypLabel('rechnung_definitiv'), 'Rechnung definitiv');
  });
  test('Pflicht-Typen: abgeschlossenes Jahr 6, laufendes Jahr 3', () {
    expect(pflichtTypen(jahr: 2024, heute: DateTime(2026, 9, 2)).length, 6);
    expect(pflichtTypen(jahr: 2026, heute: DateTime(2026, 9, 2)), ['jahresrechnung', 'lohnausweis', 'zinsausweis']);
  });
}
```

- [ ] **Step 2: Test → FAIL** — `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test test/dokument_pfad_test.dart` → Fehler «dokument_pfad.dart nicht gefunden».

- [ ] **Step 3: Pfad-/Typ-Logik implementieren**

```dart
// lib/services/steuern/dokument_pfad.dart
/// Reine Hilfsfunktionen des Dokumente-Moduls (kein DB-Zugriff, testbar).

const dokumentBereiche = <String, String>{
  'steuern': 'Steuern',
  'versicherungen': 'Versicherungen',
  'vertraege': 'Verträge',
  'behoerden': 'Behörden',
  'bank': 'Bank',
  'sonstiges': 'Sonstiges',
};

const _typLabels = <String, String>{
  'steuererklaerung': 'Steuererklärung',
  'jahresrechnung': 'Jahresrechnung',
  'veranlagung': 'Veranlagungsverfügung',
  'rechnung_provisorisch': 'Rechnung provisorisch',
  'rechnung_definitiv': 'Rechnung definitiv',
  'mahnung': 'Mahnung',
  'einspracheentscheid': 'Einspracheentscheid',
  'bussverfuegung': 'Bussverfügung',
  'bewertung_stammanteile': 'Bewertung Stammanteile',
  'zinsausweis': 'Zins-/Kapitalausweis',
  'lohnausweis': 'Lohnausweis',
  'police': 'Police',
  'vertrag': 'Vertrag',
  'brief': 'Brief',
  'sonstiges': 'Sonstiges',
};

const _typenJeBereich = <String, List<String>>{
  'steuern': ['steuererklaerung', 'jahresrechnung', 'veranlagung', 'rechnung_provisorisch',
    'rechnung_definitiv', 'mahnung', 'einspracheentscheid', 'bussverfuegung',
    'bewertung_stammanteile', 'zinsausweis', 'lohnausweis', 'brief', 'sonstiges'],
  'versicherungen': ['police', 'rechnung_definitiv', 'brief', 'sonstiges'],
  'vertraege': ['vertrag', 'brief', 'sonstiges'],
  'behoerden': ['brief', 'veranlagung', 'sonstiges'],
  'bank': ['zinsausweis', 'vertrag', 'brief', 'sonstiges'],
  'sonstiges': ['brief', 'sonstiges'],
};

const steuerarten = <String, String>{
  'bund': 'Bund',
  'kanton': 'Kanton/Gemeinde',
  'mwst': 'MWST',
  'busse': 'Busse',
};

List<String> dokumentTypen(String bereich) => _typenJeBereich[bereich] ?? const ['sonstiges'];

String dokumentTypLabel(String typ) => _typLabels[typ] ?? typ;

/// `$userId/$bereich/$jahr/$id_$dateiname`; Leerzeichen im Dateinamen → `_`.
String dokumentStoragePfad({
  required String userId,
  required String bereich,
  required int? jahr,
  required String dokumentId,
  required String dateiname,
}) {
  final safe = dateiname.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  return '$userId/$bereich/${jahr ?? 'ohne-jahr'}/${dokumentId}_$safe';
}

/// Pflicht-Dokumenttypen eines Steuerjahres für die Dossier-Vollständigkeit.
/// Laufendes/künftiges Jahr: nur die Unterlagen, die vor der Einreichung
/// entstehen. Abgeschlossen: zusätzlich Erklärung und beide Verfügungen
/// (Kategorie bund/kanton werden im Rechner geprüft).
List<String> pflichtTypen({required int jahr, required DateTime heute}) {
  if (jahr >= heute.year) return const ['jahresrechnung', 'lohnausweis', 'zinsausweis'];
  return const ['jahresrechnung', 'lohnausweis', 'zinsausweis', 'steuererklaerung',
    'veranlagung:bund', 'veranlagung:kanton'];
}
```

- [ ] **Step 4: Test → PASS** — `flutter test test/dokument_pfad_test.dart`.

- [ ] **Step 5: Modelle schreiben**

```dart
// lib/data/models/dokument.dart
double _d(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;

class Dokument {
  final String id;
  final String userId;
  final String bereich;
  final String typ;
  final String? kategorie;
  final int? jahr;
  final DateTime? dokumentDatum;
  final double? betrag;
  final String? referenz;
  final String titel;
  final String? notizen;
  final String dateiname;
  final String dateityp;
  final int? groesseBytes;
  final int? seiten;
  final String storagePfad;
  final String? buchungId;
  final DateTime? createdAt;

  const Dokument({
    required this.id, required this.userId, required this.bereich, required this.typ,
    this.kategorie, this.jahr, this.dokumentDatum, this.betrag, this.referenz,
    required this.titel, this.notizen, required this.dateiname, required this.dateityp,
    this.groesseBytes, this.seiten, required this.storagePfad, this.buchungId, this.createdAt,
  });

  factory Dokument.fromJson(Map<String, dynamic> j) => Dokument(
        id: j['id'], userId: j['user_id'], bereich: j['bereich'], typ: j['typ'],
        kategorie: j['kategorie'], jahr: j['jahr'],
        dokumentDatum: j['dokument_datum'] != null ? DateTime.parse(j['dokument_datum']) : null,
        betrag: j['betrag'] != null ? _d(j['betrag']) : null,
        referenz: j['referenz'], titel: j['titel'], notizen: j['notizen'],
        dateiname: j['dateiname'], dateityp: j['dateityp'],
        groesseBytes: j['groesse_bytes'], seiten: j['seiten'],
        storagePfad: j['storage_pfad'], buchungId: j['buchung_id'],
        createdAt: j['created_at'] != null ? DateTime.parse(j['created_at']) : null,
      );

  bool get istPdf => dateityp == 'application/pdf';
}
```

```dart
// lib/data/models/steuerjahr.dart
double? _dn(dynamic v) => v == null ? null : double.tryParse(v.toString());

class Steuerjahr {
  final String? id;
  final int jahr;
  final String status; // offen | eingereicht | veranlagt | ermessen
  final DateTime? eingereichtAm;
  final DateTime? veranlagtAm;
  final double? steuerbarerGewinn;
  final double? steuerbaresKapital;
  final double? verlustvortragVerrechnet;
  final double? bundProvisorisch;
  final double? bundDefinitiv;
  final double? kantonProvisorisch;
  final double? kantonDefinitiv;
  final String? notizen;

  const Steuerjahr({
    this.id, required this.jahr, this.status = 'offen', this.eingereichtAm, this.veranlagtAm,
    this.steuerbarerGewinn, this.steuerbaresKapital, this.verlustvortragVerrechnet,
    this.bundProvisorisch, this.bundDefinitiv, this.kantonProvisorisch, this.kantonDefinitiv,
    this.notizen,
  });

  factory Steuerjahr.fromJson(Map<String, dynamic> j) => Steuerjahr(
        id: j['id'], jahr: j['jahr'], status: j['status'] ?? 'offen',
        eingereichtAm: j['eingereicht_am'] != null ? DateTime.parse(j['eingereicht_am']) : null,
        veranlagtAm: j['veranlagt_am'] != null ? DateTime.parse(j['veranlagt_am']) : null,
        steuerbarerGewinn: _dn(j['steuerbarer_gewinn']),
        steuerbaresKapital: _dn(j['steuerbares_kapital']),
        verlustvortragVerrechnet: _dn(j['verlustvortrag_verrechnet']),
        bundProvisorisch: _dn(j['bund_provisorisch']), bundDefinitiv: _dn(j['bund_definitiv']),
        kantonProvisorisch: _dn(j['kanton_provisorisch']), kantonDefinitiv: _dn(j['kanton_definitiv']),
        notizen: j['notizen'],
      );

  Map<String, dynamic> toJson() => {
        'jahr': jahr, 'status': status,
        'eingereicht_am': eingereichtAm?.toIso8601String().split('T').first,
        'veranlagt_am': veranlagtAm?.toIso8601String().split('T').first,
        'steuerbarer_gewinn': steuerbarerGewinn, 'steuerbares_kapital': steuerbaresKapital,
        'verlustvortrag_verrechnet': verlustvortragVerrechnet,
        'bund_provisorisch': bundProvisorisch, 'bund_definitiv': bundDefinitiv,
        'kanton_provisorisch': kantonProvisorisch, 'kanton_definitiv': kantonDefinitiv,
        'notizen': notizen,
      };

  static const statusLabels = {'offen': 'offen', 'eingereicht': 'eingereicht', 'veranlagt': 'veranlagt', 'ermessen': 'Ermessen'};
}
```

- [ ] **Step 6: `Buchung` um `steuerjahr`/`steuerart` erweitern** — in `lib/data/models/buchung.dart`: Felder `final int? steuerjahr; final String? steuerart;` (nach `notizen`), im Konstruktor `this.steuerjahr, this.steuerart,`, in `fromJson` `steuerjahr: json['steuerjahr'], steuerart: json['steuerart'],`, in `toJson` `'steuerjahr': steuerjahr, 'steuerart': steuerart,`.

- [ ] **Step 7: Repositories schreiben**

```dart
// lib/data/repositories/dokument_repository.dart
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:sbs_projer_app/data/models/dokument.dart';
import 'package:sbs_projer_app/services/steuern/dokument_pfad.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class DokumentRepository {
  static String get _userId => SupabaseService.dataUserId;
  static const _bucket = 'dokumente';

  /// Alle Dokumente eines Bereichs (optional eines Jahres), neueste zuerst.
  static Future<List<Dokument>> getAll({String? bereich, int? jahr}) async {
    final all = <Map<String, dynamic>>[];
    const pageSize = 1000;
    int from = 0;
    while (true) {
      var q = SupabaseService.client.from('dokumente').select().eq('user_id', _userId);
      if (bereich != null) q = q.eq('bereich', bereich);
      if (jahr != null) q = q.eq('jahr', jahr);
      final rows = await q
          .order('jahr', ascending: false)
          .order('dokument_datum', ascending: false)
          .order('id')
          .range(from, from + pageSize - 1);
      all.addAll(rows);
      if (rows.length < pageSize) break;
      from += pageSize;
    }
    return all.map(Dokument.fromJson).toList();
  }

  /// Datei hochladen + Metadaten anlegen. Die Dokument-ID wird vorab erzeugt,
  /// damit sie Teil des Storage-Pfads ist (eindeutig, ohne Timestamp-Raten).
  static Future<Dokument> upload({
    required String bereich, required String typ, String? kategorie, int? jahr,
    DateTime? dokumentDatum, double? betrag, String? referenz, required String titel,
    String? notizen, required String dateiname, required String dateityp,
    required Uint8List bytes, String? buchungId,
  }) async {
    final id = const Uuid().v4();
    final pfad = dokumentStoragePfad(userId: _userId, bereich: bereich, jahr: jahr, dokumentId: id, dateiname: dateiname);
    await SupabaseService.client.storage.from(_bucket).uploadBinary(
          pfad, bytes, fileOptions: FileOptions(contentType: dateityp, upsert: true));
    final rows = await SupabaseService.client.from('dokumente').insert({
      'id': id, 'user_id': _userId, 'bereich': bereich, 'typ': typ, 'kategorie': kategorie,
      'jahr': jahr, 'dokument_datum': dokumentDatum?.toIso8601String().split('T').first,
      'betrag': betrag, 'referenz': referenz, 'titel': titel, 'notizen': notizen,
      'dateiname': dateiname, 'dateityp': dateityp, 'groesse_bytes': bytes.length,
      'storage_pfad': pfad, 'buchung_id': buchungId,
    }).select();
    return Dokument.fromJson(rows.first);
  }

  static Future<void> update(String id, Map<String, dynamic> felder) async {
    await SupabaseService.client.from('dokumente')
        .update({...felder, 'updated_at': DateTime.now().toIso8601String()}).eq('id', id);
  }

  static Future<void> delete(Dokument d) async {
    await SupabaseService.client.from('dokumente').delete().eq('id', d.id);
    await SupabaseService.client.storage.from(_bucket).remove([d.storagePfad]);
  }

  static Future<String> signedUrl(String storagePfad) =>
      SupabaseService.client.storage.from(_bucket).createSignedUrl(storagePfad, 3600);

  static Future<Uint8List> download(String storagePfad) =>
      SupabaseService.client.storage.from(_bucket).download(storagePfad);
}
```
(`uuid` muss in `pubspec.yaml` unter `dependencies` stehen — prüfen mit `grep -n "^  uuid" pubspec.yaml`; fehlt es: `uuid: ^4.4.0` ergänzen und `flutter pub get`.)

```dart
// lib/data/repositories/steuerjahr_repository.dart
import 'package:sbs_projer_app/data/models/steuerjahr.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class SteuerjahrRepository {
  static String get _userId => SupabaseService.dataUserId;

  static Future<List<Steuerjahr>> getAll() async {
    final rows = await SupabaseService.client.from('steuerjahre').select()
        .eq('user_id', _userId).order('jahr', ascending: false).order('id');
    return rows.map((r) => Steuerjahr.fromJson(r)).toList();
  }

  /// Anlegen oder aktualisieren (eindeutig über user_id + jahr).
  static Future<Steuerjahr> upsert(Steuerjahr s) async {
    final rows = await SupabaseService.client.from('steuerjahre')
        .upsert({...s.toJson(), 'user_id': _userId, 'updated_at': DateTime.now().toIso8601String()},
            onConflict: 'user_id,jahr')
        .select();
    return Steuerjahr.fromJson(rows.first);
  }
}
```

```dart
// lib/data/repositories/steuerzahlung_repository.dart
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Steuerzahlungen = Buchungen mit 8900/2208 im Soll oder Haben sowie
/// ESTV-Zahlungen über 2202 gegen Bank/Kasse.
class SteuerzahlungRepository {
  static String get _userId => SupabaseService.dataUserId;
  static const steuerKonten = [8900, 2208, 2202];

  static Future<List<Buchung>> _lade({int? steuerjahr, bool nurOhneJahr = false}) async {
    var q = SupabaseService.client.from('buchungen').select()
        .eq('user_id', _userId).eq('ist_storniert', false)
        .or('soll_konto.in.(8900,2208,2202),haben_konto.in.(8900,2208,2202)');
    if (steuerjahr != null) q = q.eq('steuerjahr', steuerjahr);
    if (nurOhneJahr) q = q.isFilter('steuerjahr', null);
    final rows = await q.order('datum', ascending: false).order('id').range(0, 999);
    // 2202-Umsatzsteuer-Saldierungen (2200 an 2202 usw.) sind keine Zahlungen:
    // nur Zeilen gegen Bank/Kasse behalten, ausser sie sind schon zugeordnet.
    return rows.map((r) => Buchung.fromJson(r)).where((b) {
      if (b.steuerjahr != null) return true;
      final geld = {1000, 1020};
      return geld.contains(b.sollKonto) || geld.contains(b.habenKonto);
    }).toList();
  }

  static Future<List<Buchung>> getByJahr(int jahr) => _lade(steuerjahr: jahr);
  static Future<List<Buchung>> getNichtZugeordnet() => _lade(nurOhneJahr: true);

  static Future<void> zuordnen(String buchungId, {required int steuerjahr, required String steuerart}) async {
    await SupabaseService.client.from('buchungen')
        .update({'steuerjahr': steuerjahr, 'steuerart': steuerart}).eq('id', buchungId);
  }

  /// Bezahlt je (jahr, steuerart) aus der View.
  static Future<Map<(int, String), double>> bezahltJeJahr() async {
    final rows = await SupabaseService.client.from('view_steuerjahr_zahlungen').select().eq('user_id', _userId);
    return {
      for (final r in rows)
        (r['steuerjahr'] as int, (r['steuerart'] ?? 'kanton') as String):
            double.tryParse(r['bezahlt'].toString()) ?? 0,
    };
  }
}
```

- [ ] **Step 8: `RechnungRepository.getOffene()` ergänzen** (in `rechnung_repository.dart`, nach `countOffene`):

```dart
  /// Alle offenen Rechnungen (nicht bezahlt/abgeschrieben), älteste zuerst.
  static Future<List<Rechnung>> getOffene() async {
    final all = <Map<String, dynamic>>[];
    const pageSize = 1000;
    int from = 0;
    while (true) {
      final rows = await SupabaseService.client.from('rechnungen').select()
          .eq('user_id', _userId)
          .not('zahlungsstatus', 'in', '("bezahlt","abgeschrieben")')
          .order('rechnungsdatum').order('id').range(from, from + pageSize - 1);
      all.addAll(rows);
      if (rows.length < pageSize) break;
      from += pageSize;
    }
    return all.map((r) => Rechnung.fromJson(r)).toList();
  }
```
(`_userId` heisst in diesem Repository ggf. anders — den bestehenden Getter aus `countOffene` übernehmen.)

- [ ] **Step 9: Analyse** — `flutter analyze lib/data lib/services/steuern` → No issues.

- [ ] **Step 10: Commit**
```bash
git add lib/services/steuern/dokument_pfad.dart lib/data/models/dokument.dart lib/data/models/steuerjahr.dart lib/data/models/buchung.dart lib/data/repositories/dokument_repository.dart lib/data/repositories/steuerjahr_repository.dart lib/data/repositories/steuerzahlung_repository.dart lib/data/repositories/rechnung_repository.dart test/dokument_pfad_test.dart
git commit -m "feat(dokumente): Modelle, Pfadlogik, Repositories für Dokumente/Steuerjahre/Steuerzahlungen"
```

---

### Task 5: `SteuerjahrRechner` (reine Soll/Ist- und Dossier-Logik, TDD)

**Files:**
- Create: `sbs_projer_app/lib/services/steuern/steuerjahr_rechner.dart`
- Test: `sbs_projer_app/test/steuerjahr_rechner_test.dart`

- [ ] **Step 1: Failing Tests**

```dart
// test/steuerjahr_rechner_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/steuerjahr.dart';
import 'package:sbs_projer_app/services/steuern/steuerjahr_rechner.dart';

void main() {
  group('SollIst', () {
    test('definitiv vorhanden: offen = definitiv - bezahlt', () {
      final s = SteuerjahrRechner.sollIst(
        jahr: const Steuerjahr(jahr: 2024, bundProvisorisch: 1088, bundDefinitiv: 2405.50, kantonProvisorisch: 1279, kantonDefinitiv: 2748),
        bezahlt: {'bund': 2405.50, 'kanton': 2748.00},
      );
      expect(s.zeile('bund').offen, closeTo(0, 0.001));
      expect(s.zeile('kanton').definitiv, 2748.00);
      expect(s.totalDefinitiv, 5153.50);
      expect(s.totalOffen, closeTo(0, 0.001));
    });
    test('ohne definitiv: offen = provisorisch - bezahlt; Guthaben negativ', () {
      final s = SteuerjahrRechner.sollIst(
        jahr: const Steuerjahr(jahr: 2025, bundProvisorisch: 2405.50, kantonProvisorisch: 2748),
        bezahlt: {'bund': 2405.50, 'kanton': 2748.00, 'busse': 0},
      );
      expect(s.zeile('bund').offen, closeTo(0, 0.001));
      expect(s.zeile('bund').istProvisorisch, isTrue);
    });
    test('Guthaben: bezahlt > definitiv', () {
      final s = SteuerjahrRechner.sollIst(
        jahr: const Steuerjahr(jahr: 2019, bundDefinitiv: 0, kantonDefinitiv: 47),
        bezahlt: {'bund': -9.20, 'kanton': 47.0},
      );
      expect(s.zeile('bund').offen, closeTo(9.20, 0.001)); // Zins-Guthaben schon zurückbezahlt → 0 offen? nein: bezahlt −9.20 = Rückzahlung erhalten
      expect(s.ampel, SteuerAmpel.schuld);
    });
  });

  group('Dossier', () {
    test('abgeschlossenes Jahr: 4 von 6', () {
      final d = SteuerjahrRechner.dossier(jahr: 2024, heute: DateTime(2026, 9, 2), vorhanden: [
        ('jahresrechnung', null), ('lohnausweis', null), ('steuererklaerung', null), ('veranlagung', 'bund'),
      ]);
      expect(d.vorhanden, 4);
      expect(d.total, 6);
      expect(d.fehlend, ['zinsausweis', 'veranlagung:kanton']);
    });
    test('laufendes Jahr: 3 Pflichttypen', () {
      final d = SteuerjahrRechner.dossier(jahr: 2026, heute: DateTime(2026, 9, 2), vorhanden: []);
      expect(d.total, 3);
    });
  });
}
```
Hinweis zum dritten SollIst-Test: `bezahlt` ist die Netto-Summe aus der View (Zahlungen positiv, Rückzahlungen negativ). Bund 2019: 425 bezahlt, 434.20 zurück → netto −9.20; definitiv 0 → offen = 0 − (−9.20) = +9.20 heisst «die Firma hat 9.20 mehr erhalten als geschuldet» — das war der Rückerstattungszins. Erwartung im Test bleibt 9.20 mit Ampel `schuld` (rechnerisch), der Screen zeigt es als Betrag mit Hinweis «Zins». Kein Sonderfall im Rechner.

- [ ] **Step 2: Test → FAIL** — `flutter test test/steuerjahr_rechner_test.dart`.

- [ ] **Step 3: Rechner implementieren**

```dart
// lib/services/steuern/steuerjahr_rechner.dart
import 'package:sbs_projer_app/data/models/steuerjahr.dart';
import 'package:sbs_projer_app/services/steuern/dokument_pfad.dart';

enum SteuerAmpel { ausgeglichen, schuld, guthaben }

class SollIstZeile {
  final String steuerart;
  final double? provisorisch;
  final double? definitiv;
  final double bezahlt;
  const SollIstZeile({required this.steuerart, this.provisorisch, this.definitiv, required this.bezahlt});
  bool get istProvisorisch => definitiv == null;
  double get soll => definitiv ?? provisorisch ?? 0;
  double get offen => _r(soll - bezahlt);
}

class SollIst {
  final List<SollIstZeile> zeilen;
  const SollIst(this.zeilen);
  SollIstZeile zeile(String art) => zeilen.firstWhere((z) => z.steuerart == art,
      orElse: () => SollIstZeile(steuerart: art, bezahlt: 0));
  double get totalDefinitiv => _r(zeilen.fold(0.0, (s, z) => s + (z.definitiv ?? 0)));
  double get totalBezahlt => _r(zeilen.fold(0.0, (s, z) => s + z.bezahlt));
  double get totalOffen => _r(zeilen.fold(0.0, (s, z) => s + z.offen));
  SteuerAmpel get ampel {
    if (totalOffen.abs() <= 0.05) return SteuerAmpel.ausgeglichen;
    return totalOffen > 0 ? SteuerAmpel.schuld : SteuerAmpel.guthaben;
  }
}

class Dossier {
  final int total;
  final int vorhanden;
  final List<String> fehlend;
  const Dossier({required this.total, required this.vorhanden, required this.fehlend});
}

double _r(double v) => (v * 100).roundToDouble() / 100;

class SteuerjahrRechner {
  /// [bezahlt] je Steuerart aus `view_steuerjahr_zahlungen` (Rückzahlungen negativ).
  static SollIst sollIst({required Steuerjahr jahr, required Map<String, double> bezahlt}) {
    return SollIst([
      SollIstZeile(steuerart: 'bund', provisorisch: jahr.bundProvisorisch, definitiv: jahr.bundDefinitiv, bezahlt: bezahlt['bund'] ?? 0),
      SollIstZeile(steuerart: 'kanton', provisorisch: jahr.kantonProvisorisch, definitiv: jahr.kantonDefinitiv, bezahlt: bezahlt['kanton'] ?? 0),
      SollIstZeile(steuerart: 'busse', definitiv: bezahlt['busse'] ?? 0, bezahlt: bezahlt['busse'] ?? 0),
      SollIstZeile(steuerart: 'mwst', definitiv: bezahlt['mwst'] ?? 0, bezahlt: bezahlt['mwst'] ?? 0),
    ]);
  }

  /// [vorhanden]: (typ, kategorie) der Dokumente des Jahres.
  static Dossier dossier({required int jahr, required DateTime heute, required List<(String, String?)> vorhanden}) {
    final pflicht = pflichtTypen(jahr: jahr, heute: heute);
    final fehlend = <String>[];
    for (final p in pflicht) {
      final teile = p.split(':');
      final ok = vorhanden.any((v) => v.$1 == teile[0] && (teile.length == 1 || v.$2 == teile[1]));
      if (!ok) fehlend.add(p);
    }
    return Dossier(total: pflicht.length, vorhanden: pflicht.length - fehlend.length, fehlend: fehlend);
  }
}
```

- [ ] **Step 4: Test → PASS.**
- [ ] **Step 5: Commit** `git add lib/services/steuern/steuerjahr_rechner.dart test/steuerjahr_rechner_test.dart && git commit -m "feat(steuern): SteuerjahrRechner (Soll/Ist, Dossier) + Tests"`

---

### Task 6: Provider

**Files:**
- Create: `sbs_projer_app/lib/presentation/providers/dokument_providers.dart`
- Create: `sbs_projer_app/lib/presentation/providers/steuern_providers.dart`
- Modify: `sbs_projer_app/lib/presentation/providers/buchhaltung_providers.dart` — `_toSaldoInput` in `toSaldoInput` umbenennen (öffentlich; alle internen Aufrufer anpassen).

- [ ] **Step 1: Dokument-Provider**

```dart
// lib/presentation/providers/dokument_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/models/dokument.dart';
import 'package:sbs_projer_app/data/repositories/dokument_repository.dart';

typedef DokumentFilter = ({String? bereich, int? jahr});

final dokumenteProvider = FutureProvider.family<List<Dokument>, DokumentFilter>(
    (ref, f) => DokumentRepository.getAll(bereich: f.bereich, jahr: f.jahr));

/// Jahre, in denen Dokumente eines Bereichs liegen (für Filter-Dropdowns).
final dokumentJahreProvider = FutureProvider.family<List<int>, String?>((ref, bereich) async {
  final docs = await DokumentRepository.getAll(bereich: bereich);
  final jahre = docs.map((d) => d.jahr).whereType<int>().toSet().toList()..sort((a, b) => b.compareTo(a));
  return jahre;
});
```

- [ ] **Step 2: Steuern-Provider**

```dart
// lib/presentation/providers/steuern_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/data/models/dokument.dart';
import 'package:sbs_projer_app/data/models/steuerjahr.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/data/repositories/dokument_repository.dart';
import 'package:sbs_projer_app/data/repositories/steuerjahr_repository.dart';
import 'package:sbs_projer_app/data/repositories/steuerzahlung_repository.dart';
import 'package:sbs_projer_app/presentation/providers/buchhaltung_providers.dart' show toSaldoInput;
import 'package:sbs_projer_app/services/buchhaltung/erfolgsrechnung_service.dart';
import 'package:sbs_projer_app/services/steuern/steuerjahr_rechner.dart';

/// Eine Zeile der Steuern-Übersicht.
class SteuerjahrZeile {
  final Steuerjahr jahr;
  final SollIst sollIst;
  final double buchhaltungsgewinn;
  final Dossier dossier;
  const SteuerjahrZeile({required this.jahr, required this.sollIst, required this.buchhaltungsgewinn, required this.dossier});
}

final steuerjahreProvider = FutureProvider<List<Steuerjahr>>((ref) => SteuerjahrRepository.getAll());

/// Übersicht: Vereinigung aus steuerjahre, zugeordneten Zahlungen und Dokumenten.
final steuernUebersichtProvider = FutureProvider<List<SteuerjahrZeile>>((ref) async {
  final jahre = await ref.watch(steuerjahreProvider.future);
  final bezahlt = await SteuerzahlungRepository.bezahltJeJahr();
  final docs = await DokumentRepository.getAll(bereich: 'steuern');
  final buchungen = await BuchungRepository.getAll();
  final saldoInput = toSaldoInput(buchungen);
  final heute = DateTime.now();

  final alleJahre = <int>{...jahre.map((j) => j.jahr), ...bezahlt.keys.map((k) => k.$1), ...docs.map((d) => d.jahr).whereType<int>()};
  final zeilen = <SteuerjahrZeile>[];
  for (final j in alleJahre.toList()..sort((a, b) => b.compareTo(a))) {
    final sj = jahre.firstWhere((x) => x.jahr == j, orElse: () => Steuerjahr(jahr: j));
    final bez = {for (final e in bezahlt.entries) if (e.key.$1 == j) e.key.$2: e.value};
    final er = ErfolgsrechnungService.berechne(saldoInput, von: DateTime(j, 1, 1), bis: DateTime(j, 12, 31));
    zeilen.add(SteuerjahrZeile(
      jahr: sj,
      sollIst: SteuerjahrRechner.sollIst(jahr: sj, bezahlt: bez),
      buchhaltungsgewinn: er.jahresergebnis,
      dossier: SteuerjahrRechner.dossier(jahr: j, heute: heute,
          vorhanden: docs.where((d) => d.jahr == j).map((d) => (d.typ, d.kategorie)).toList()),
    ));
  }
  return zeilen;
});

final steuerjahrZeileProvider = FutureProvider.family<SteuerjahrZeile, int>((ref, jahr) async {
  final alle = await ref.watch(steuernUebersichtProvider.future);
  return alle.firstWhere((z) => z.jahr.jahr == jahr,
      orElse: () => SteuerjahrZeile(jahr: Steuerjahr(jahr: jahr), sollIst: const SollIst([]), buchhaltungsgewinn: 0,
          dossier: SteuerjahrRechner.dossier(jahr: jahr, heute: DateTime.now(), vorhanden: [])));
});

final steuerzahlungenProvider = FutureProvider.family<List<Buchung>, int>((ref, jahr) => SteuerzahlungRepository.getByJahr(jahr));
final nichtZugeordneteSteuerbuchungenProvider = FutureProvider<List<Buchung>>((ref) => SteuerzahlungRepository.getNichtZugeordnet());
final steuerDokumenteProvider = FutureProvider.family<List<Dokument>, int>((ref, jahr) => DokumentRepository.getAll(bereich: 'steuern', jahr: jahr));

/// Nach jeder Änderung im Steuern-Bereich alles neu laden.
void invalidateSteuern(WidgetRef ref) {
  ref.invalidate(steuerjahreProvider);
  ref.invalidate(steuernUebersichtProvider);
  ref.invalidate(steuerzahlungenProvider);
  ref.invalidate(nichtZugeordneteSteuerbuchungenProvider);
  ref.invalidate(steuerDokumenteProvider);
}
```

- [ ] **Step 3: `_toSaldoInput` → `toSaldoInput`** in `buchhaltung_providers.dart` (Definition + alle Aufrufer in derselben Datei; `grep -n "_toSaldoInput" lib` muss danach leer sein).

- [ ] **Step 4: Analyse** — `flutter analyze lib/presentation/providers` → No issues.
- [ ] **Step 5: Commit** `git add lib/presentation/providers && git commit -m "feat(steuern): Provider für Dokumente, Steuerjahre, Soll/Ist-Übersicht"`

---

### Task 7: Bausteine — `TapKnopf`, `DokumentListe`, `DokumentUploadDialog`

**Files:**
- Create: `sbs_projer_app/lib/presentation/widgets/tap_knopf.dart`
- Create: `sbs_projer_app/lib/presentation/widgets/dokumente/dokument_liste.dart`
- Create: `sbs_projer_app/lib/presentation/widgets/dokumente/dokument_upload_dialog.dart`

- [ ] **Step 1: `TapKnopf`** (CanvasKit-sicher, Vorbild `ArbeitBeendenKnopf`)

```dart
// lib/presentation/widgets/tap_knopf.dart
import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';

/// Knopf aus GestureDetector + Container: Material-Buttons rendern auf
/// CanvasKit-Web nicht zuverlässig (CLAUDE.md, Vorfälle 20.06./13.08.2026).
class TapKnopf extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool primaer;
  final IconData? icon;
  const TapKnopf({super.key, required this.text, required this.onTap, this.primaer = true, this.icon});

  @override
  Widget build(BuildContext context) {
    final farbe = primaer ? Theme.of(context).colorScheme.primary : Colors.white;
    final textFarbe = primaer ? Colors.white : AppColors.textPrimary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: onTap == null ? Colors.grey.shade400 : farbe,
          borderRadius: BorderRadius.circular(8),
          border: primaer ? null : Border.all(color: Colors.grey.shade400),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 18, color: textFarbe), const SizedBox(width: 6)],
          Text(text, style: TextStyle(color: textFarbe, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}
```

- [ ] **Step 2: `DokumentListe`** — Zeilen aus `InkWell` + `Container`, gruppiert nach Typ, öffnet PDF im neuen Tab, Bilder in Dialog.

```dart
// lib/presentation/widgets/dokumente/dokument_liste.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/dokument.dart';
import 'package:sbs_projer_app/data/repositories/dokument_repository.dart';
import 'package:sbs_projer_app/services/pdf/pdf_tab_oeffner_export.dart';
import 'package:sbs_projer_app/services/steuern/dokument_pfad.dart';

class DokumentListe extends StatelessWidget {
  final List<Dokument> dokumente;
  final void Function(Dokument)? onLoeschen;
  const DokumentListe({super.key, required this.dokumente, this.onLoeschen});

  static final _df = DateFormat('dd.MM.yyyy');
  static final _chf = NumberFormat('#,##0.00', 'de_CH');

  @override
  Widget build(BuildContext context) {
    if (dokumente.isEmpty) {
      return const Padding(padding: EdgeInsets.all(12),
          child: Text('Keine Dokumente.', style: TextStyle(color: AppColors.textSecondary)));
    }
    final gruppen = <String, List<Dokument>>{};
    for (final d in dokumente) gruppen.putIfAbsent(d.typ, () => []).add(d);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final g in gruppen.entries) ...[
        Padding(padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
            child: Text('${dokumentTypLabel(g.key)} (${g.value.length})',
                style: const TextStyle(fontWeight: FontWeight.w700))),
        for (final d in g.value) _zeile(context, d),
      ],
    ]);
  }

  Widget _zeile(BuildContext context, Dokument d) => InkWell(
        onTap: () => oeffnen(context, d),
        onLongPress: onLoeschen == null ? null : () => _loeschenFragen(context, d),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0)))),
          child: Row(children: [
            Icon(d.istPdf ? Icons.picture_as_pdf : Icons.image, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.titel, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text([
                if (d.dokumentDatum != null) _df.format(d.dokumentDatum!),
                if (d.kategorie != null) steuerarten[d.kategorie] ?? d.kategorie!,
                if (d.referenz != null) d.referenz!,
              ].join(' · '), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ])),
            if (d.betrag != null) Text('${_chf.format(d.betrag)} CHF',
                style: TextStyle(fontWeight: FontWeight.w600, color: d.betrag! < 0 ? Colors.blue : AppColors.textPrimary)),
            if (d.buchungId != null) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.link, size: 16)),
          ]),
        ),
      );

  static Future<void> oeffnen(BuildContext context, Dokument d) async {
    try {
      if (d.istPdf) {
        final bytes = await DokumentRepository.download(d.storagePfad);
        await oeffnePdfImNeuenTab(bytes, d.dateiname);
      } else {
        final url = await DokumentRepository.signedUrl(d.storagePfad);
        if (!context.mounted) return;
        showDialog(context: context, builder: (_) => Dialog(child: InteractiveViewer(child: Image.network(url))));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Öffnen fehlgeschlagen: $e')));
    }
  }

  Future<void> _loeschenFragen(BuildContext context, Dokument d) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Dokument löschen?'), content: Text(d.titel),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Löschen')),
      ]));
    if (ok == true) onLoeschen!(d);
  }
}
```

- [ ] **Step 3: `DokumentUploadDialog`** — Datei aus PDF/Galerie/Kamera (gleiche Picker wie `beleg_upload_widget.dart`: `FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], withData: true)` und `ImagePicker().pickImage(...)` — die genauen Aufrufe aus `beleg_upload_widget.dart` Zeilen 51–120 übernehmen), Felder Typ (Dropdown aus `dokumentTypen(bereich)`, mit «Anderer…» → Textfeld), Kategorie (bei `steuern`: Dropdown `steuerarten`, sonst Textfeld), Jahr, Datum, Betrag, Referenz, Titel, Notizen, optional Buchung (`Buchung`-Liste per Parameter).

```dart
// lib/presentation/widgets/dokumente/dokument_upload_dialog.dart
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/data/models/dokument.dart';
import 'package:sbs_projer_app/data/repositories/dokument_repository.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';
import 'package:sbs_projer_app/services/steuern/dokument_pfad.dart';

/// Rückgabe: das angelegte Dokument oder null (abgebrochen).
Future<Dokument?> showDokumentUploadDialog(BuildContext context, {
  required String bereich, bool bereichFix = true, int? jahr, List<Buchung> buchungen = const [],
}) => showDialog<Dokument>(context: context, builder: (_) => _UploadDialog(bereich: bereich, bereichFix: bereichFix, jahr: jahr, buchungen: buchungen));

class _UploadDialog extends StatefulWidget {
  final String bereich; final bool bereichFix; final int? jahr; final List<Buchung> buchungen;
  const _UploadDialog({required this.bereich, required this.bereichFix, this.jahr, required this.buchungen});
  @override State<_UploadDialog> createState() => _UploadDialogState();
}

class _UploadDialogState extends State<_UploadDialog> {
  late String _bereich = widget.bereich;
  late String _typ = dokumentTypen(widget.bereich).first;
  String? _kategorie;
  late final _jahr = TextEditingController(text: widget.jahr?.toString() ?? '');
  final _titel = TextEditingController(); final _betrag = TextEditingController();
  final _referenz = TextEditingController(); final _notizen = TextEditingController();
  DateTime? _datum; String? _buchungId;
  Uint8List? _bytes; String? _dateiname; String? _dateityp;
  bool _laeuft = false;

  Future<void> _pdfWaehlen() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], withData: true);
    final f = r?.files.single;
    if (f?.bytes == null) return;
    setState(() { _bytes = f!.bytes; _dateiname = f.name; _dateityp = 'application/pdf'; if (_titel.text.isEmpty) _titel.text = f.name.replaceAll('.pdf', ''); });
  }

  Future<void> _bildWaehlen(ImageSource q) async {
    final x = await ImagePicker().pickImage(source: q, maxWidth: 2000, imageQuality: 85);
    if (x == null) return;
    final b = await x.readAsBytes();
    setState(() { _bytes = b; _dateiname = x.name; _dateityp = 'image/jpeg'; if (_titel.text.isEmpty) _titel.text = x.name; });
  }

  Future<void> _speichern() async {
    if (_bytes == null || _titel.text.trim().isEmpty) return;
    setState(() => _laeuft = true);
    try {
      final d = await DokumentRepository.upload(
        bereich: _bereich, typ: _typ, kategorie: _kategorie, jahr: int.tryParse(_jahr.text),
        dokumentDatum: _datum, betrag: double.tryParse(_betrag.text.replaceAll(',', '.')),
        referenz: _referenz.text.trim().isEmpty ? null : _referenz.text.trim(),
        titel: _titel.text.trim(), notizen: _notizen.text.trim().isEmpty ? null : _notizen.text.trim(),
        dateiname: _dateiname!, dateityp: _dateityp!, bytes: _bytes!, buchungId: _buchungId,
      );
      if (mounted) Navigator.pop(context, d);
    } catch (e) {
      if (mounted) { setState(() => _laeuft = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload fehlgeschlagen: $e'))); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd.MM.yyyy');
    return AlertDialog(
      title: const Text('Dokument hochladen'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!widget.bereichFix)
          DropdownButtonFormField<String>(value: _bereich, decoration: const InputDecoration(labelText: 'Bereich'),
            items: [for (final e in dokumentBereiche.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
            onChanged: (v) => setState(() { _bereich = v!; _typ = dokumentTypen(v).first; _kategorie = null; })),
        DropdownButtonFormField<String>(value: _typ, decoration: const InputDecoration(labelText: 'Typ'),
          items: [for (final t in dokumentTypen(_bereich)) DropdownMenuItem(value: t, child: Text(dokumentTypLabel(t)))],
          onChanged: (v) => setState(() => _typ = v!)),
        if (_bereich == 'steuern')
          DropdownButtonFormField<String?>(value: _kategorie, decoration: const InputDecoration(labelText: 'Steuerart'),
            items: [const DropdownMenuItem(value: null, child: Text('—')), for (final e in steuerarten.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
            onChanged: (v) => setState(() => _kategorie = v))
        else
          TextField(decoration: const InputDecoration(labelText: 'Kategorie'), onChanged: (v) => _kategorie = v.trim().isEmpty ? null : v.trim()),
        TextField(controller: _jahr, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Jahr')),
        Row(children: [
          Expanded(child: Text('Datum: ${_datum == null ? '—' : df.format(_datum!)}')),
          TextButton(onPressed: () async {
            final p = await showDatePicker(context: context, initialDate: _datum ?? DateTime.now(), firstDate: DateTime(2015), lastDate: DateTime(2035));
            if (p != null) setState(() => _datum = p);
          }, child: const Text('wählen')),
        ]),
        TextField(controller: _betrag, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Betrag CHF (Guthaben negativ)')),
        TextField(controller: _referenz, decoration: const InputDecoration(labelText: 'Referenz / Rechnungs-Nr.')),
        TextField(controller: _titel, decoration: const InputDecoration(labelText: 'Titel *')),
        TextField(controller: _notizen, decoration: const InputDecoration(labelText: 'Notizen'), maxLines: 2),
        if (widget.buchungen.isNotEmpty)
          DropdownButtonFormField<String?>(value: _buchungId, isExpanded: true, decoration: const InputDecoration(labelText: 'Zahlung verknüpfen'),
            items: [const DropdownMenuItem(value: null, child: Text('—')),
              for (final b in widget.buchungen) DropdownMenuItem(value: b.id, child: Text('${df.format(b.datum)} ${b.betragBrutto.toStringAsFixed(2)} ${b.beschreibung}', overflow: TextOverflow.ellipsis))],
            onChanged: (v) => setState(() => _buchungId = v)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          TapKnopf(text: 'PDF', icon: Icons.picture_as_pdf, primaer: false, onTap: _pdfWaehlen),
          TapKnopf(text: 'Galerie', icon: Icons.photo, primaer: false, onTap: () => _bildWaehlen(ImageSource.gallery)),
          TapKnopf(text: 'Kamera', icon: Icons.camera_alt, primaer: false, onTap: () => _bildWaehlen(ImageSource.camera)),
        ]),
        if (_dateiname != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Datei: $_dateiname')),
      ])),
      actions: [
        TextButton(onPressed: _laeuft ? null : () => Navigator.pop(context), child: const Text('Abbrechen')),
        TapKnopf(text: _laeuft ? 'Lädt…' : 'Speichern', onTap: (_laeuft || _bytes == null) ? null : _speichern),
      ],
    );
  }
}
```
Prüfen, dass `file_picker` und `image_picker` in `pubspec.yaml` stehen (werden vom `beleg_upload_widget.dart` bereits genutzt; falls dort andere Picker-Aufrufe stehen, diese übernehmen).

- [ ] **Step 4: Analyse** — `flutter analyze lib/presentation/widgets` → No issues.
- [ ] **Step 5: Commit** `git add lib/presentation/widgets/tap_knopf.dart lib/presentation/widgets/dokumente && git commit -m "feat(dokumente): TapKnopf, DokumentListe, DokumentUploadDialog"`

---

### Task 8: `DokumenteScreen` + Route + Home-Menü

**Files:**
- Create: `sbs_projer_app/lib/presentation/screens/dokumente/dokumente_screen.dart`
- Modify: `sbs_projer_app/lib/core/config/router.dart`, `sbs_projer_app/lib/presentation/screens/home_screen.dart`

- [ ] **Step 1: Screen**

```dart
// lib/presentation/screens/dokumente/dokumente_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/repositories/dokument_repository.dart';
import 'package:sbs_projer_app/presentation/providers/dokument_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/dokumente/dokument_liste.dart';
import 'package:sbs_projer_app/presentation/widgets/dokumente/dokument_upload_dialog.dart';
import 'package:sbs_projer_app/presentation/widgets/filter/app_filter_bar.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';
import 'package:sbs_projer_app/services/steuern/dokument_pfad.dart';

class DokumenteScreen extends ConsumerStatefulWidget {
  const DokumenteScreen({super.key});
  @override ConsumerState<DokumenteScreen> createState() => _S();
}

class _S extends ConsumerState<DokumenteScreen> {
  String? _bereich = 'steuern';
  int? _jahr;

  void _reload() { ref.invalidate(dokumenteProvider); ref.invalidate(dokumentJahreProvider); }

  @override
  Widget build(BuildContext context) {
    final docs = ref.watch(dokumenteProvider((bereich: _bereich, jahr: _jahr)));
    final jahre = ref.watch(dokumentJahreProvider(_bereich)).value ?? const <int>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Dokumente')),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 4), child: Row(children: [
          Expanded(child: AppFilterDropdown<String>(hint: 'Bereich', value: _bereich, isExpanded: true,
            options: [for (final e in dokumentBereiche.entries) (e.key, e.value)],
            onChanged: (v) => setState(() { _bereich = v; _jahr = null; }))),
          const SizedBox(width: 8),
          Expanded(child: AppFilterDropdown<int>(hint: 'Jahr', value: _jahr, isExpanded: true,
            options: [for (final j in jahre) (j, '$j')], onChanged: (v) => setState(() => _jahr = v))),
        ])),
        Expanded(child: docs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Fehler: $e')),
          data: (list) => ListView(padding: const EdgeInsets.all(12), children: [
            DokumentListe(dokumente: list, onLoeschen: (d) async { await DokumentRepository.delete(d); _reload(); }),
          ]),
        )),
        Padding(padding: const EdgeInsets.all(12), child: TapKnopf(text: 'Dokument hochladen', icon: Icons.upload_file,
          onTap: () async {
            final d = await showDokumentUploadDialog(context, bereich: _bereich ?? 'sonstiges', bereichFix: false, jahr: _jahr);
            if (d != null) _reload();
          })),
      ]),
    );
  }
}
```

- [ ] **Step 2: Route** in `router.dart` (neben `/buchhaltung`-Routen): `GoRoute(path: '/dokumente', builder: (c, s) => const DokumenteScreen())` + Import.
- [ ] **Step 3: Home-Menü** in `home_screen.dart` nach dem Eintrag «Buchhaltung»:
```dart
        if (!SupabaseService.isGuest)
          _MenuListTile(icon: Icons.folder_open, label: 'Dokumente', onTap: () => context.push('/dokumente')),
```
- [ ] **Step 4: Analyse** `flutter analyze lib/presentation/screens/dokumente lib/core/config/router.dart lib/presentation/screens/home_screen.dart`.
- [ ] **Step 5: Commit** `git add lib/presentation/screens/dokumente lib/core/config/router.dart lib/presentation/screens/home_screen.dart && git commit -m "feat(dokumente): Dokumente-Screen mit Bereich/Jahr-Filter, Route, Home-Menü"`

---

### Task 9: `SteuernScreen` (Übersicht) + Route + Dashboard-Kachel

**Files:**
- Create: `sbs_projer_app/lib/presentation/screens/buchhaltung/steuern/steuern_screen.dart`
- Modify: `router.dart`, `buchhaltung_dashboard_screen.dart`

- [ ] **Step 1: Screen**

```dart
// lib/presentation/screens/buchhaltung/steuern/steuern_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/steuerjahr.dart';
import 'package:sbs_projer_app/presentation/providers/steuern_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';
import 'package:sbs_projer_app/services/steuern/steuerjahr_rechner.dart';

final _chf = NumberFormat('#,##0.00', 'de_CH');

Color ampelFarbe(SteuerAmpel a) => switch (a) {
      SteuerAmpel.ausgeglichen => Colors.green,
      SteuerAmpel.schuld => AppColors.error,
      SteuerAmpel.guthaben => Colors.blue,
    };

class SteuernScreen extends ConsumerWidget {
  const SteuernScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(steuernUebersichtProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Steuern')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (zeilen) {
          final total = zeilen.fold(0.0, (s, z) => s + z.sollIst.totalBezahlt);
          return ListView(padding: const EdgeInsets.all(12), children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Expanded(child: Text('Total bezahlte Steuern', style: TextStyle(fontWeight: FontWeight.w600))),
                Text('${_chf.format(total)} CHF', style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
            ),
            const SizedBox(height: 8),
            for (final z in zeilen) _JahrCard(z),
            const SizedBox(height: 12),
            TapKnopf(text: 'Jahr anlegen', icon: Icons.add, primaer: false, onTap: () => _jahrAnlegen(context, ref, zeilen)),
          ]);
        },
      ),
    );
  }

  Future<void> _jahrAnlegen(BuildContext context, WidgetRef ref, List<SteuerjahrZeile> zeilen) async {
    final vorhanden = zeilen.map((z) => z.jahr.jahr).toSet();
    final kandidat = [for (var j = DateTime.now().year; j >= 2019; j--) if (!vorhanden.contains(j)) j];
    if (kandidat.isEmpty) return;
    final jahr = await showDialog<int>(context: context, builder: (ctx) => SimpleDialog(title: const Text('Jahr anlegen'),
      children: [for (final j in kandidat) SimpleDialogOption(onPressed: () => Navigator.pop(ctx, j), child: Text('$j'))]));
    if (jahr != null && context.mounted) context.push('/buchhaltung/steuern/$jahr');
  }
}

class _JahrCard extends StatelessWidget {
  final SteuerjahrZeile z;
  const _JahrCard(this.z);

  @override
  Widget build(BuildContext context) {
    final s = z.sollIst;
    return InkWell(
      onTap: () => context.push('/buchhaltung/steuern/${z.jahr.jahr}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('${z.jahr.jahr}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10)),
              child: Text(Steuerjahr.statusLabels[z.jahr.status] ?? z.jahr.status, style: const TextStyle(fontSize: 12))),
            const Spacer(),
            Icon(Icons.folder, size: 16, color: z.dossier.fehlend.isEmpty ? Colors.green : AppColors.textSecondary),
            const SizedBox(width: 4),
            Text('${z.dossier.vorhanden}/${z.dossier.total}', style: const TextStyle(fontSize: 12)),
          ]),
          const SizedBox(height: 6),
          _zahlen('Gewinn', z.buchhaltungsgewinn, 'steuerbar', z.jahr.steuerbarerGewinn, 'Steuern def.', s.totalDefinitiv),
          const SizedBox(height: 4),
          Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: ampelFarbe(s.ampel))),
            const SizedBox(width: 6),
            Text('bezahlt ${_chf.format(s.totalBezahlt)} · ${s.ampel == SteuerAmpel.guthaben ? 'Guthaben' : 'offen'} ${_chf.format(s.totalOffen.abs())}',
                style: const TextStyle(fontSize: 12)),
          ]),
        ]),
      ),
    );
  }

  Widget _zahlen(String l1, double v1, String l2, double? v2, String l3, double v3) => Row(children: [
        _z(l1, v1), _z(l2, v2), _z(l3, v3),
      ]);
  Widget _z(String label, double? v) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        Text(v == null ? '—' : _chf.format(v), style: const TextStyle(fontWeight: FontWeight.w600)),
      ]));
}
```

- [ ] **Step 2: Route** `GoRoute(path: '/buchhaltung/steuern', builder: (c, s) => const SteuernScreen())` — **vor** der `:jahr`-Route aus Task 10 eintragen.
- [ ] **Step 3: Dashboard-Kachel** in `buchhaltung_dashboard_screen.dart` (nach der Audit-Kachel):
```dart
          _NavTile(icon: Icons.account_balance, title: 'Steuern', subtitle: 'Veranlagungen, Zahlungen, Unterlagen', onTap: () => context.push('/buchhaltung/steuern')),
```
- [ ] **Step 4: Analyse + Commit** `git add lib/presentation/screens/buchhaltung/steuern/steuern_screen.dart lib/core/config/router.dart lib/presentation/screens/buchhaltung/buchhaltung_dashboard_screen.dart && git commit -m "feat(steuern): Übersichts-Screen mit Jahreskarten, Route, Dashboard-Kachel"`

---

### Task 10: `SteuerjahrScreen` (Jahresdetail) + Zuordnungs-Dialog

**Files:**
- Create: `sbs_projer_app/lib/presentation/screens/buchhaltung/steuern/steuer_zuordnung_dialog.dart`
- Create: `sbs_projer_app/lib/presentation/screens/buchhaltung/steuern/steuerjahr_screen.dart`
- Modify: `router.dart`

- [ ] **Step 1: Zuordnungs-Dialog**

```dart
// lib/presentation/screens/buchhaltung/steuern/steuer_zuordnung_dialog.dart
import 'package:flutter/material.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/data/repositories/steuerzahlung_repository.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';
import 'package:sbs_projer_app/services/steuern/dokument_pfad.dart';

/// Ordnet eine Steuerbuchung Jahr + Steuerart zu. Rückgabe true = gespeichert.
Future<bool> showSteuerZuordnungDialog(BuildContext context, Buchung b, {int? vorschlagJahr}) async {
  int jahr = vorschlagJahr ?? b.datum.year - 1;
  String art = b.beschreibung.contains('Eidgen') ? 'mwst' : (b.beschreibung.toLowerCase().contains('busse') ? 'busse' : 'kanton');
  final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
    title: const Text('Steuerzahlung zuordnen'),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('${b.datum.day}.${b.datum.month}.${b.datum.year} · ${b.betragBrutto.toStringAsFixed(2)} CHF\n${b.beschreibung}'),
      DropdownButtonFormField<int>(value: jahr, decoration: const InputDecoration(labelText: 'Steuerjahr'),
        items: [for (var j = DateTime.now().year; j >= 2019; j--) DropdownMenuItem(value: j, child: Text('$j'))],
        onChanged: (v) => setS(() => jahr = v!)),
      DropdownButtonFormField<String>(value: art, decoration: const InputDecoration(labelText: 'Steuerart'),
        items: [for (final e in steuerarten.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
        onChanged: (v) => setS(() => art = v!)),
    ]),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
      TapKnopf(text: 'Zuordnen', onTap: () => Navigator.pop(ctx, true)),
    ],
  )));
  if (ok != true) return false;
  await SteuerzahlungRepository.zuordnen(b.id, steuerjahr: jahr, steuerart: art);
  return true;
}
```

- [ ] **Step 2: Jahresdetail-Screen** (vier Abschnitte)

```dart
// lib/presentation/screens/buchhaltung/steuern/steuerjahr_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/data/models/steuerjahr.dart';
import 'package:sbs_projer_app/data/repositories/dokument_repository.dart';
import 'package:sbs_projer_app/data/repositories/steuerjahr_repository.dart';
import 'package:sbs_projer_app/presentation/providers/steuern_providers.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/steuern/steuer_zuordnung_dialog.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/steuern/steuern_screen.dart' show ampelFarbe;
import 'package:sbs_projer_app/presentation/widgets/dokumente/dokument_liste.dart';
import 'package:sbs_projer_app/presentation/widgets/dokumente/dokument_upload_dialog.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';
import 'package:sbs_projer_app/services/steuern/dokument_pfad.dart';
import 'package:sbs_projer_app/services/steuern/steuerjahr_rechner.dart';

final _chf = NumberFormat('#,##0.00', 'de_CH');
final _df = DateFormat('dd.MM.yyyy');

class SteuerjahrScreen extends ConsumerStatefulWidget {
  final int jahr;
  const SteuerjahrScreen({super.key, required this.jahr});
  @override ConsumerState<SteuerjahrScreen> createState() => _S();
}

class _S extends ConsumerState<SteuerjahrScreen> {
  // Formularfelder der Veranlagung
  String _status = 'offen';
  DateTime? _eingereicht, _veranlagt;
  final _c = {for (final k in ['gewinn', 'kapital', 'verlust', 'bp', 'bd', 'kp', 'kd', 'notizen']) k: TextEditingController()};
  bool _geladen = false;

  void _fuelle(Steuerjahr s) {
    if (_geladen) return;
    _geladen = true;
    _status = s.status; _eingereicht = s.eingereichtAm; _veranlagt = s.veranlagtAm;
    String t(double? v) => v == null ? '' : v.toStringAsFixed(2);
    _c['gewinn']!.text = t(s.steuerbarerGewinn); _c['kapital']!.text = t(s.steuerbaresKapital);
    _c['verlust']!.text = t(s.verlustvortragVerrechnet);
    _c['bp']!.text = t(s.bundProvisorisch); _c['bd']!.text = t(s.bundDefinitiv);
    _c['kp']!.text = t(s.kantonProvisorisch); _c['kd']!.text = t(s.kantonDefinitiv);
    _c['notizen']!.text = s.notizen ?? '';
  }

  double? _n(String k) => double.tryParse(_c[k]!.text.replaceAll("'", '').replaceAll(',', '.'));

  Future<void> _speichern(Steuerjahr alt) async {
    try {
      await SteuerjahrRepository.upsert(Steuerjahr(
        id: alt.id, jahr: widget.jahr, status: _status, eingereichtAm: _eingereicht, veranlagtAm: _veranlagt,
        steuerbarerGewinn: _n('gewinn'), steuerbaresKapital: _n('kapital'), verlustvortragVerrechnet: _n('verlust'),
        bundProvisorisch: _n('bp'), bundDefinitiv: _n('bd'), kantonProvisorisch: _n('kp'), kantonDefinitiv: _n('kd'),
        notizen: _c['notizen']!.text.trim().isEmpty ? null : _c['notizen']!.text.trim(),
      ));
      invalidateSteuern(ref);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veranlagung gespeichert')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final zeile = ref.watch(steuerjahrZeileProvider(widget.jahr));
    final zahlungen = ref.watch(steuerzahlungenProvider(widget.jahr));
    final offen = ref.watch(nichtZugeordneteSteuerbuchungenProvider);
    final docs = ref.watch(steuerDokumenteProvider(widget.jahr));
    return Scaffold(
      appBar: AppBar(title: Text('Steuern ${widget.jahr}')),
      body: zeile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (z) {
          _fuelle(z.jahr);
          return ListView(padding: const EdgeInsets.all(12), children: [
            _titel('1 · Veranlagung'),
            _veranlagungForm(z.jahr),
            _titel('2 · Soll / Ist'),
            _sollIstTabelle(z),
            _titel('3 · Zahlungen'),
            zahlungen.when(loading: () => const LinearProgressIndicator(), error: (e, _) => Text('$e'),
                data: (l) => Column(children: [for (final b in l) _zahlungZeile(b, docs.value?.any((d) => d.buchungId == b.id) ?? false)])),
            offen.when(loading: () => const SizedBox(), error: (e, _) => Text('$e'), data: (l) => l.isEmpty ? const SizedBox() : Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(padding: EdgeInsets.only(top: 8), child: Text('Nicht zugeordnete Steuerbuchungen', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.warning))),
                for (final b in l) _zahlungZeile(b, false, zuordnen: true),
              ])),
            _titel('4 · Dokumente'),
            _dossier(z.dossier),
            docs.when(loading: () => const LinearProgressIndicator(), error: (e, _) => Text('$e'),
                data: (l) => DokumentListe(dokumente: l, onLoeschen: (d) async { await DokumentRepository.delete(d); invalidateSteuern(ref); })),
            const SizedBox(height: 8),
            TapKnopf(text: 'Dokument hochladen', icon: Icons.upload_file, onTap: () async {
              final d = await showDokumentUploadDialog(context, bereich: 'steuern', jahr: widget.jahr, buchungen: zahlungen.value ?? const []);
              if (d != null) invalidateSteuern(ref);
            }),
            const SizedBox(height: 24),
          ]);
        },
      ),
    );
  }

  Widget _titel(String t) => Padding(padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
      child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)));

  Widget _feld(String key, String label) => Expanded(child: TextField(controller: _c[key]!,
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: InputDecoration(labelText: label, isDense: true)));

  Widget _datumZeile(String label, DateTime? v, void Function(DateTime) set) => Row(children: [
        Expanded(child: Text('$label: ${v == null ? '—' : _df.format(v)}')),
        TextButton(onPressed: () async {
          final p = await showDatePicker(context: context, initialDate: v ?? DateTime.now(), firstDate: DateTime(2019), lastDate: DateTime(2035));
          if (p != null) setState(() => set(p));
        }, child: const Text('wählen')),
      ]);

  Widget _veranlagungForm(Steuerjahr s) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
        child: Column(children: [
          DropdownButtonFormField<String>(value: _status, decoration: const InputDecoration(labelText: 'Status', isDense: true),
            items: [for (final e in Steuerjahr.statusLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
            onChanged: (v) => setState(() => _status = v!)),
          _datumZeile('Eingereicht', _eingereicht, (d) => _eingereicht = d),
          _datumZeile('Veranlagt', _veranlagt, (d) => _veranlagt = d),
          Row(children: [_feld('gewinn', 'Steuerbarer Gewinn'), const SizedBox(width: 8), _feld('kapital', 'Steuerbares Kapital')]),
          Row(children: [_feld('verlust', 'Verlust verrechnet'), const SizedBox(width: 8), const Expanded(child: SizedBox())]),
          Row(children: [_feld('bp', 'Bund provisorisch'), const SizedBox(width: 8), _feld('bd', 'Bund definitiv')]),
          Row(children: [_feld('kp', 'Kanton provisorisch'), const SizedBox(width: 8), _feld('kd', 'Kanton definitiv')]),
          TextField(controller: _c['notizen']!, decoration: const InputDecoration(labelText: 'Notizen', isDense: true), maxLines: 2),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerRight, child: TapKnopf(text: 'Speichern', onTap: () => _speichern(s))),
        ]),
      );

  Widget _sollIstTabelle(SteuerjahrZeile z) {
    final s = z.sollIst;
    Widget cell(String t, {bool bold = false, Color? c}) => Expanded(child: Text(t, textAlign: TextAlign.right,
        style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.w700 : FontWeight.w400, color: c)));
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
      child: Column(children: [
        Row(children: [const Expanded(flex: 2, child: Text('')), cell('prov.', bold: true), cell('def.', bold: true), cell('bezahlt', bold: true), cell('offen', bold: true)]),
        for (final zl in s.zeilen) Row(children: [
          Expanded(flex: 2, child: Text(steuerarten[zl.steuerart] ?? zl.steuerart)),
          cell(zl.provisorisch == null ? '—' : _chf.format(zl.provisorisch)),
          cell(zl.definitiv == null ? '—' : _chf.format(zl.definitiv)),
          cell(_chf.format(zl.bezahlt)),
          cell(_chf.format(zl.offen), c: zl.offen.abs() <= 0.05 ? Colors.green : (zl.offen > 0 ? AppColors.error : Colors.blue)),
        ]),
        const Divider(),
        Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: ampelFarbe(s.ampel))),
          const SizedBox(width: 6),
          Expanded(child: Text('Gewinn Buchhaltung ${_chf.format(z.buchhaltungsgewinn)}'
              '${z.jahr.steuerbarerGewinn == null ? '' : ' · steuerbar ${_chf.format(z.jahr.steuerbarerGewinn)} · Differenz ${_chf.format(z.jahr.steuerbarerGewinn! - z.buchhaltungsgewinn)}'}',
              style: const TextStyle(fontSize: 12))),
        ]),
      ]),
    );
  }

  Widget _zahlungZeile(Buchung b, bool hatBeleg, {bool zuordnen = false}) => InkWell(
        onTap: zuordnen ? () async { if (await showSteuerZuordnungDialog(context, b, vorschlagJahr: widget.jahr)) invalidateSteuern(ref); } : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0)))),
          child: Row(children: [
            Text(_df.format(b.datum), style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 8),
            Expanded(child: Text(b.beschreibung, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
            if (b.steuerart != null) Container(margin: const EdgeInsets.only(right: 6), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                child: Text(steuerarten[b.steuerart] ?? b.steuerart!, style: const TextStyle(fontSize: 10))),
            Text('${_chf.format(b.betragBrutto)} ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            if (hatBeleg) const Icon(Icons.attach_file, size: 14),
            if (zuordnen) const Icon(Icons.edit, size: 16, color: AppColors.warning),
          ]),
        ),
      );

  Widget _dossier(Dossier d) => Wrap(spacing: 6, runSpacing: 4, children: [
        for (final p in pflichtTypen(jahr: widget.jahr, heute: DateTime.now()))
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: d.fehlend.contains(p) ? Colors.orange.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
            child: Text('${d.fehlend.contains(p) ? '–' : '✓'} ${dokumentTypLabel(p.split(':').first)}${p.contains(':') ? ' ${steuerarten[p.split(':').last]}' : ''}',
                style: const TextStyle(fontSize: 11))),
      ]);
}
```

- [ ] **Step 3: Route** `GoRoute(path: '/buchhaltung/steuern/:jahr', builder: (c, s) => SteuerjahrScreen(jahr: int.parse(s.pathParameters['jahr']!)))`.
- [ ] **Step 4: Analyse** `flutter analyze lib/presentation/screens/buchhaltung/steuern lib/core/config/router.dart` → No issues.
- [ ] **Step 5: Commit** `git add lib/presentation/screens/buchhaltung/steuern lib/core/config/router.dart && git commit -m "feat(steuern): Jahresdetail (Veranlagung, Soll/Ist, Zahlungen, Dokumente) + Zuordnungsdialog"`

---

### Task 11: `AbschlussPruefService` — Regeln (TDD)

**Files:**
- Create: `sbs_projer_app/lib/services/buchhaltung/abschluss_regeln.dart`
- Create: `sbs_projer_app/lib/services/buchhaltung/abschluss_pruef_service.dart`
- Test: `sbs_projer_app/test/abschluss_pruef_service_test.dart`

- [ ] **Step 1: Failing Tests** (eine Gruppe je Regel; Hilfsfunktion `k(...)` baut einen Kontext)

```dart
// test/abschluss_pruef_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/buchhaltung/abschluss_pruef_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/bilanz_service.dart';

BuchungSaldo b(int soll, int haben, double betrag, DateTime datum, {int? mwstKonto, double mwst = 0}) => BuchungSaldo(
    sollKonto: soll, habenKonto: haben, betrag: betrag, datum: datum, storniert: false,
    mwstKonto: mwstKonto, betragNetto: betrag - mwst, mwstBetrag: mwst);

final d = DateTime(2025, 6, 30);
final stichtag = DateTime(2025, 12, 31);

AbschlussKontext k({
  List<BuchungSaldo> buchungen = const [], List<KontoInfo> konten = const [],
  List<CamtDateiInfo> camt = const [], List<OffeneRechnungInfo> rechnungen = const [],
  int steuerbuchungenOhneJahr = 0, Set<String> dokumentTypen = const {}, String steuerjahrStatus = 'offen',
  Set<String> offeneRechnungenMitZahlung = const {},
}) => AbschlussKontext(jahr: 2025, heute: DateTime(2026, 9, 2), buchungen: buchungen, konten: konten, camtDateien: camt,
    offeneRechnungen: rechnungen, steuerbuchungenOhneJahr: steuerbuchungenOhneJahr, dokumentTypen: dokumentTypen,
    steuerjahrStatus: steuerjahrStatus, offeneRechnungenMitZahlung: offeneRechnungenMitZahlung);

Pruefbefund f(List<Pruefbefund> l, String id) => l.firstWhere((x) => x.regelId == id);

void main() {
  test('Bank = camt-Schlusssaldo → grün; Differenz → rot; ohne camt → gelb', () {
    final bu = [b(1020, 2800, 12202.73, d)];
    final camt = [CamtDateiInfo(von: DateTime(2025, 1, 1), bis: DateTime(2025, 12, 31), anfangssaldo: 0, schlusssaldo: 12202.73)];
    expect(f(AbschlussPruefService.pruefe(k(buchungen: bu, camt: camt)), 'bank_camt').status, PruefStatus.gruen);
    expect(f(AbschlussPruefService.pruefe(k(buchungen: bu, camt: [CamtDateiInfo(von: DateTime(2025, 1, 1), bis: DateTime(2025, 12, 31), anfangssaldo: 0, schlusssaldo: 12000)])), 'bank_camt').status, PruefStatus.rot);
    expect(f(AbschlussPruefService.pruefe(k(buchungen: bu)), 'bank_camt').status, PruefStatus.gelb);
  });
  test('camt-Lückenkette: Saldosprung rot, Tageslücke gelb, lückenlos grün', () {
    final a = CamtDateiInfo(von: DateTime(2025, 1, 1), bis: DateTime(2025, 3, 31), anfangssaldo: 0, schlusssaldo: 100);
    expect(f(AbschlussPruefService.pruefe(k(camt: [a, CamtDateiInfo(von: DateTime(2025, 4, 1), bis: DateTime(2025, 6, 30), anfangssaldo: 100, schlusssaldo: 200)])), 'camt_kette').status, PruefStatus.gruen);
    expect(f(AbschlussPruefService.pruefe(k(camt: [a, CamtDateiInfo(von: DateTime(2025, 4, 3), bis: DateTime(2025, 6, 30), anfangssaldo: 100, schlusssaldo: 200)])), 'camt_kette').status, PruefStatus.gelb);
    expect(f(AbschlussPruefService.pruefe(k(camt: [a, CamtDateiInfo(von: DateTime(2025, 4, 1), bis: DateTime(2025, 6, 30), anfangssaldo: 90, schlusssaldo: 200)])), 'camt_kette').status, PruefStatus.rot);
  });
  test('Kasse: negativ rot, > 10000 gelb', () {
    expect(f(AbschlussPruefService.pruefe(k(buchungen: [b(6200, 1000, 50, d)])), 'kasse').status, PruefStatus.rot);
    expect(f(AbschlussPruefService.pruefe(k(buchungen: [b(1000, 3400, 12000, d)])), 'kasse').status, PruefStatus.gelb);
  });
  test('MWST-Konten nach Saldierung 0 → grün, Rest → rot (Stichtag am Quartalsende)', () {
    expect(f(AbschlussPruefService.pruefe(k(buchungen: [b(1100, 3400, 108.1, d, mwstKonto: 2200, mwst: 8.1), b(2200, 2202, 8.1, d)])), 'mwst_saldiert').status, PruefStatus.gruen);
    expect(f(AbschlussPruefService.pruefe(k(buchungen: [b(1100, 3400, 108.1, d, mwstKonto: 2200, mwst: 8.1)])), 'mwst_saldiert').status, PruefStatus.rot);
  });
  test('2202 im Soll → gelb', () {
    expect(f(AbschlussPruefService.pruefe(k(buchungen: [b(2202, 1020, 100, d)])), 'mwst_2202').status, PruefStatus.gelb);
  });
  test('Offene Rechnungen älter als 5 Jahre → rot mit Anzahl/Summe', () {
    final r = f(AbschlussPruefService.pruefe(k(rechnungen: [OffeneRechnungInfo(id: 'r1', datum: DateTime(2020, 5, 1), brutto: 67.85)])), 'debitoren_verjaehrt');
    expect(r.status, PruefStatus.rot);
    expect(r.ist, contains('1'));
    expect(f(AbschlussPruefService.pruefe(k(rechnungen: [OffeneRechnungInfo(id: 'r2', datum: DateTime(2021, 5, 1), brutto: 67.85)])), 'debitoren_verjaehrt').status, PruefStatus.gruen);
  });
  test('Delkredere 5 %: passt grün, fehlt rot, weicht ab gelb', () {
    final deb = b(1100, 3400, 10000, d);
    expect(f(AbschlussPruefService.pruefe(k(buchungen: [deb, b(3805, 1109, 500, d)])), 'delkredere').status, PruefStatus.gruen);
    expect(f(AbschlussPruefService.pruefe(k(buchungen: [deb])), 'delkredere').status, PruefStatus.rot);
    expect(f(AbschlussPruefService.pruefe(k(buchungen: [deb, b(3805, 1109, 300, d)])), 'delkredere').status, PruefStatus.gelb);
  });
  test('Offene Rechnungen mit verknüpfter Zahlung → gelb', () {
    expect(f(AbschlussPruefService.pruefe(k(offeneRechnungenMitZahlung: {'r9'})), 'debitoren_status').status, PruefStatus.gelb);
  });
  test('Steuerrückstellung: abgeschlossenes Jahr ohne 2208 → rot, laufendes → gelb', () {
    expect(f(AbschlussPruefService.pruefe(k()), 'rueckstellung').status, PruefStatus.rot);
    final laufend = AbschlussKontext(jahr: 2026, heute: DateTime(2026, 9, 2), buchungen: const [], konten: const [], camtDateien: const [],
        offeneRechnungen: const [], steuerbuchungenOhneJahr: 0, dokumentTypen: const {}, steuerjahrStatus: 'offen', offeneRechnungenMitZahlung: const {});
    expect(f(AbschlussPruefService.pruefe(laufend), 'rueckstellung').status, PruefStatus.gelb);
    expect(f(AbschlussPruefService.pruefe(k(buchungen: [b(8900, 2208, 4000, d)])), 'rueckstellung').status, PruefStatus.gruen);
  });
  test('Negative Salden: Aktiv < 0 rot (1109 ausgenommen), Passiv im Soll rot', () {
    expect(f(AbschlussPruefService.pruefe(k(buchungen: [b(3805, 1109, 5, d)])), 'negative_salden').status, PruefStatus.gruen);
    expect(f(AbschlussPruefService.pruefe(k(buchungen: [b(6200, 1020, 5, d)])), 'negative_salden').status, PruefStatus.rot);
    expect(f(AbschlussPruefService.pruefe(k(buchungen: [b(2000, 1020, 5, d)])), 'negative_salden').status, PruefStatus.rot);
  });
  test('Lohnkonten im Soll → gelb', () {
    expect(f(AbschlussPruefService.pruefe(k(buchungen: [b(2271, 1020, 5, d)])), 'lohnkonten').status, PruefStatus.gelb);
  });
  test('FEHLER-Konto mit Saldo → rot', () {
    final konten = [const KontoInfo(kontonummer: 8090, bezeichnung: 'FEHLER alt', kategorie: 'x')];
    expect(f(AbschlussPruefService.pruefe(k(buchungen: [b(8090, 1020, 5, d)], konten: konten)), 'fehler_konten').status, PruefStatus.rot);
  });
  test('Steuerbuchungen ohne Jahr → gelb; Erklärung fehlt → gelb', () {
    expect(f(AbschlussPruefService.pruefe(k(steuerbuchungenOhneJahr: 3)), 'steuer_zuordnung').status, PruefStatus.gelb);
    expect(f(AbschlussPruefService.pruefe(k()), 'steuererklaerung').status, PruefStatus.gelb);
    expect(f(AbschlussPruefService.pruefe(k(dokumentTypen: {'steuererklaerung'})), 'steuererklaerung').status, PruefStatus.gruen);
  });
  test('Sortierung: rot vor gelb vor grün', () {
    final l = AbschlussPruefService.pruefe(k(buchungen: [b(6200, 1020, 5, d)]));
    expect(l.first.status, PruefStatus.rot);
    expect(l.last.status, PruefStatus.gruen);
  });
}
```

- [ ] **Step 2: Test → FAIL.**

- [ ] **Step 3: Regeln + Service implementieren**

```dart
// lib/services/buchhaltung/abschluss_regeln.dart
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/util/bank_waechter.dart';
import 'package:sbs_projer_app/services/buchhaltung/abschluss_pruef_service.dart';

final _chf = NumberFormat('#,##0.00', 'de_CH');
String chf(double v) => _chf.format(v);

abstract class AbschlussRegel {
  String get id;
  String get gruppe;
  String get titel;
  Pruefbefund pruefe(AbschlussKontext k);
  Pruefbefund b(PruefStatus s, {String ist = '', String soll = '', String hinweis = '', String? route}) =>
      Pruefbefund(regelId: id, gruppe: gruppe, status: s, titel: titel, ist: ist, soll: soll, hinweis: hinweis, aktionRoute: route);
}

class BankCamtRegel extends AbschlussRegel {
  @override String get id => 'bank_camt'; @override String get gruppe => 'Bank & Kasse'; @override String get titel => 'Bank 1020 = Bank-Schlusssaldo';
  @override Pruefbefund pruefe(AbschlussKontext k) {
    final letzte = k.letzteCamtDateiBis(k.stichtag);
    if (letzte == null) return b(PruefStatus.gelb, hinweis: 'Keine camt-Datei bis zum Stichtag — Bankauszug importieren.', route: '/buchhaltung/camt-import');
    final journal = k.saldo(1020);
    final diff = journal - letzte.schlusssaldo;
    return b(diff.abs() <= 0.05 ? PruefStatus.gruen : PruefStatus.rot, ist: chf(journal), soll: chf(letzte.schlusssaldo),
        hinweis: diff.abs() <= 0.05 ? 'per ${DateFormat('dd.MM.yyyy').format(letzte.bis)}' : 'Differenz ${chf(diff)} — Buchungen fehlen oder sind doppelt.', route: '/buchhaltung/camt-import');
  }
}

class CamtKetteRegel extends AbschlussRegel {
  @override String get id => 'camt_kette'; @override String get gruppe => 'Bank & Kasse'; @override String get titel => 'camt-Exporte lückenlos';
  @override Pruefbefund pruefe(AbschlussKontext k) {
    final l = k.camtDateien.where((c) => !c.von.isAfter(k.stichtag)).toList()..sort((a, c) => a.von.compareTo(c.von));
    final probleme = <String>[]; var status = PruefStatus.gruen;
    for (var i = 1; i < l.length; i++) {
      final luecke = BankWaechter.luecke(letztesBis: l[i - 1].bis, neuesVon: l[i].von);
      if (luecke != null) { probleme.add(luecke); if (status == PruefStatus.gruen) status = PruefStatus.gelb; }
      if ((l[i].anfangssaldo - l[i - 1].schlusssaldo).abs() > 0.05) {
        probleme.add('Saldosprung ${chf(l[i - 1].schlusssaldo)} → ${chf(l[i].anfangssaldo)} am ${DateFormat('dd.MM.yyyy').format(l[i].von)}');
        status = PruefStatus.rot;
      }
    }
    return b(status, ist: '${l.length} Dateien', hinweis: probleme.isEmpty ? 'Anschluss aller Exporte stimmt.' : probleme.join(' · '));
  }
}

class KasseRegel extends AbschlussRegel {
  @override String get id => 'kasse'; @override String get gruppe => 'Bank & Kasse'; @override String get titel => 'Kasse 1000 plausibel';
  @override Pruefbefund pruefe(AbschlussKontext k) {
    final s = k.saldo(1000);
    if (s < -0.05) return b(PruefStatus.rot, ist: chf(s), hinweis: 'Negative Kasse — Buchung in falscher Periode.');
    if (s > 10000) return b(PruefStatus.gelb, ist: chf(s), hinweis: 'Hoher Kassenbestand — Kassensturz/Privatbezug buchen.');
    return b(PruefStatus.gruen, ist: chf(s));
  }
}

class MwstSaldiertRegel extends AbschlussRegel {
  @override String get id => 'mwst_saldiert'; @override String get gruppe => 'MWST'; @override String get titel => '2200/1170/1171 saldiert';
  @override Pruefbefund pruefe(AbschlussKontext k) {
    // Letztes abgeschlossenes Quartalsende ≤ Stichtag (und < heute).
    final q = k.letztesQuartalsende();
    final saldi = k.saldiPer(q);
    final reste = [2200, 1170, 1171].where((kt) => (saldi[kt] ?? 0).abs() > 0.05).map((kt) => '$kt ${chf(saldi[kt]!)}').toList();
    return b(reste.isEmpty ? PruefStatus.gruen : PruefStatus.rot, ist: reste.isEmpty ? '0.00' : reste.join(' · '), soll: '0.00 per ${DateFormat('dd.MM.yyyy').format(q)}',
        hinweis: reste.isEmpty ? '' : 'Quartals-Saldierung auf 2202 fehlt.', route: '/buchhaltung/mwst');
  }
}

class Mwst2202Regel extends AbschlussRegel {
  @override String get id => 'mwst_2202'; @override String get gruppe => 'MWST'; @override String get titel => '2202 nicht im Soll';
  @override Pruefbefund pruefe(AbschlussKontext k) {
    final s = k.saldo(2202); // roh Soll−Haben; Haben-Saldo negativ = Schuld
    return b(s > 0.05 ? PruefStatus.gelb : PruefStatus.gruen, ist: chf(-s), hinweis: s > 0.05 ? 'Mehr an die ESTV bezahlt als saldiert — Saldierung oder Rückzahlung prüfen.' : 'Geschuldete MWST');
  }
}

class DebitorenVerjaehrtRegel extends AbschlussRegel {
  @override String get id => 'debitoren_verjaehrt'; @override String get gruppe => 'Debitoren'; @override String get titel => 'Offene Rechnungen älter als 5 Jahre';
  @override Pruefbefund pruefe(AbschlussKontext k) {
    final grenze = DateTime(k.stichtag.year - 5, k.stichtag.month, k.stichtag.day);
    final alt = k.offeneRechnungen.where((r) => r.datum.isBefore(grenze)).toList();
    final summe = alt.fold(0.0, (s, r) => s + r.brutto);
    return b(alt.isEmpty ? PruefStatus.gruen : PruefStatus.rot, ist: '${alt.length} Rechnungen · ${chf(summe)}', soll: '0',
        hinweis: alt.isEmpty ? '' : 'Verjährt (Art. 128 OR) — abschreiben.', route: '/rechnungen');
  }
}

class DelkredereRegel extends AbschlussRegel {
  @override String get id => 'delkredere'; @override String get gruppe => 'Debitoren'; @override String get titel => 'Delkredere = 5 % Debitoren';
  @override Pruefbefund pruefe(AbschlussKontext k) {
    final deb = k.saldo(1100); final wb = -k.saldo(1109); final soll = (deb * 0.05 * 100).roundToDouble() / 100;
    if (deb <= 0.05) return b(PruefStatus.gruen, ist: chf(wb), soll: '0.00');
    if (wb <= 0.05) return b(PruefStatus.rot, ist: '0.00', soll: chf(soll), hinweis: 'Kein Delkredere gebildet (3805 an 1109).');
    return b((wb - soll).abs() <= 50 ? PruefStatus.gruen : PruefStatus.gelb, ist: chf(wb), soll: chf(soll), hinweis: (wb - soll).abs() <= 50 ? '' : 'Auf 5 % nachführen.');
  }
}

class DebitorenStatusRegel extends AbschlussRegel {
  @override String get id => 'debitoren_status'; @override String get gruppe => 'Debitoren'; @override String get titel => 'Rechnungen «offen» mit gebuchter Zahlung';
  @override Pruefbefund pruefe(AbschlussKontext k) {
    final n = k.offeneRechnungenMitZahlung.length;
    return b(n == 0 ? PruefStatus.gruen : PruefStatus.gelb, ist: '$n', soll: '0', hinweis: n == 0 ? '' : 'Status auf «bezahlt» nachziehen.', route: '/rechnungen');
  }
}

class RueckstellungRegel extends AbschlussRegel {
  @override String get id => 'rueckstellung'; @override String get gruppe => 'Abschluss'; @override String get titel => 'Steuerrückstellung 2208';
  @override Pruefbefund pruefe(AbschlussKontext k) {
    final s = -k.saldo(2208);
    if (s > 0.05) return b(PruefStatus.gruen, ist: chf(s));
    return b(k.jahrAbgeschlossen ? PruefStatus.rot : PruefStatus.gelb, ist: '0.00', hinweis: 'Rückstellung für Gewinn-/Kapitalsteuern buchen (8900 an 2208).', route: '/buchhaltung/steuern');
  }
}

class NegativeSaldenRegel extends AbschlussRegel {
  @override String get id => 'negative_salden'; @override String get gruppe => 'Abschluss'; @override String get titel => 'Keine vorzeichenwidrigen Bilanzsalden';
  @override Pruefbefund pruefe(AbschlussKontext k) {
    final probleme = <String>[];
    k.saldi.forEach((kt, v) {
      if (kt >= 1000 && kt < 2000 && kt != 1109 && v < -0.05) probleme.add('$kt ${chf(v)}');
      if (kt >= 2000 && kt < 3000 && kt != 2970 && kt != 2980 && v > 0.05) probleme.add('$kt ${chf(v)} im Soll');
    });
    return b(probleme.isEmpty ? PruefStatus.gruen : PruefStatus.rot, ist: probleme.isEmpty ? 'keine' : probleme.join(' · '), hinweis: probleme.isEmpty ? '' : 'Aufbau- oder Abgrenzungsbuchung fehlt.');
  }
}

class LohnkontenRegel extends AbschlussRegel {
  @override String get id => 'lohnkonten'; @override String get gruppe => 'Abschluss'; @override String get titel => 'Lohnkonten 2270–2273';
  @override Pruefbefund pruefe(AbschlussKontext k) {
    final soll = [2270, 2271, 2272, 2273].where((kt) => (k.saldo(kt)) > 0.05).map((kt) => '$kt ${chf(k.saldo(kt))}').toList();
    return b(soll.isEmpty ? PruefStatus.gruen : PruefStatus.gelb, ist: soll.isEmpty ? 'alle im Haben/0' : soll.join(' · '), hinweis: soll.isEmpty ? '' : 'Vorauszahlung oder fehlender Lohnlauf — als Forderung (1180) ausweisen oder Lohnlauf nachholen.', route: '/buchhaltung/lohn');
  }
}

class FehlerKontenRegel extends AbschlussRegel {
  @override String get id => 'fehler_konten'; @override String get gruppe => 'Abschluss'; @override String get titel => 'FEHLER-Konten leer';
  @override Pruefbefund pruefe(AbschlussKontext k) {
    final t = k.konten.where((ko) => ko.bezeichnung.toUpperCase().contains('FEHLER') && (k.saldo(ko.kontonummer)).abs() > 0.05).map((ko) => '${ko.kontonummer} ${chf(k.saldo(ko.kontonummer))}').toList();
    return b(t.isEmpty ? PruefStatus.gruen : PruefStatus.rot, ist: t.isEmpty ? 'leer' : t.join(' · '), hinweis: t.isEmpty ? '' : 'Umbuchen auf das richtige Konto.');
  }
}

class SteuerZuordnungRegel extends AbschlussRegel {
  @override String get id => 'steuer_zuordnung'; @override String get gruppe => 'Steuern'; @override String get titel => 'Steuerzahlungen einem Jahr zugeordnet';
  @override Pruefbefund pruefe(AbschlussKontext k) => b(k.steuerbuchungenOhneJahr == 0 ? PruefStatus.gruen : PruefStatus.gelb,
      ist: '${k.steuerbuchungenOhneJahr} ohne Jahr', soll: '0', hinweis: k.steuerbuchungenOhneJahr == 0 ? '' : 'Im Steuern-Screen zuordnen.', route: '/buchhaltung/steuern');
}

class SteuererklaerungRegel extends AbschlussRegel {
  @override String get id => 'steuererklaerung'; @override String get gruppe => 'Steuern'; @override String get titel => 'Steuererklärung eingereicht';
  @override Pruefbefund pruefe(AbschlussKontext k) {
    if (!k.jahrAbgeschlossen) return b(PruefStatus.gruen, hinweis: 'Jahr läuft noch.');
    final ok = k.dokumentTypen.contains('steuererklaerung') || k.steuerjahrStatus != 'offen';
    return b(ok ? PruefStatus.gruen : PruefStatus.gelb, ist: k.steuerjahrStatus, hinweis: ok ? '' : 'Einreichung bis 30.09. des Folgejahres; Dokument unter Steuern ablegen.', route: '/buchhaltung/steuern/${k.jahr}');
  }
}

List<AbschlussRegel> alleAbschlussRegeln() => [
      BankCamtRegel(), CamtKetteRegel(), KasseRegel(), MwstSaldiertRegel(), Mwst2202Regel(),
      DebitorenVerjaehrtRegel(), DelkredereRegel(), DebitorenStatusRegel(), RueckstellungRegel(),
      NegativeSaldenRegel(), LohnkontenRegel(), FehlerKontenRegel(), SteuerZuordnungRegel(), SteuererklaerungRegel(),
    ];
```

```dart
// lib/services/buchhaltung/abschluss_pruef_service.dart
import 'package:sbs_projer_app/services/buchhaltung/abschluss_regeln.dart';
import 'package:sbs_projer_app/services/buchhaltung/bilanz_service.dart';

enum PruefStatus { rot, gelb, gruen }

class Pruefbefund {
  final String regelId, gruppe, titel, ist, soll, hinweis;
  final PruefStatus status;
  final String? aktionRoute;
  const Pruefbefund({required this.regelId, required this.gruppe, required this.status, required this.titel,
      this.ist = '', this.soll = '', this.hinweis = '', this.aktionRoute});
}

class CamtDateiInfo {
  final DateTime von, bis; final double anfangssaldo, schlusssaldo;
  const CamtDateiInfo({required this.von, required this.bis, required this.anfangssaldo, required this.schlusssaldo});
}

class OffeneRechnungInfo {
  final String id; final DateTime datum; final double brutto;
  const OffeneRechnungInfo({required this.id, required this.datum, required this.brutto});
}

/// Alles, was die Regeln brauchen — vorab geladen, damit die Regeln rein bleiben.
class AbschlussKontext {
  final int jahr; final DateTime heute;
  final List<BuchungSaldo> buchungen; final List<KontoInfo> konten;
  final List<CamtDateiInfo> camtDateien; final List<OffeneRechnungInfo> offeneRechnungen;
  final int steuerbuchungenOhneJahr; final Set<String> dokumentTypen; final String steuerjahrStatus;
  final Set<String> offeneRechnungenMitZahlung;
  late final Map<int, double> saldi = BilanzService.saldiPerStichtag(buchungen, stichtag);

  AbschlussKontext({required this.jahr, required this.heute, required this.buchungen, required this.konten,
      required this.camtDateien, required this.offeneRechnungen, required this.steuerbuchungenOhneJahr,
      required this.dokumentTypen, required this.steuerjahrStatus, required this.offeneRechnungenMitZahlung});

  bool get jahrAbgeschlossen => jahr < heute.year;
  DateTime get stichtag => jahrAbgeschlossen ? DateTime(jahr, 12, 31) : heute;
  double saldo(int konto) => saldi[konto] ?? 0;
  Map<int, double> saldiPer(DateTime d) => BilanzService.saldiPerStichtag(buchungen, d);

  CamtDateiInfo? letzteCamtDateiBis(DateTime d) {
    CamtDateiInfo? l;
    for (final c in camtDateien) { if (!c.bis.isAfter(d) && (l == null || c.bis.isAfter(l.bis))) l = c; }
    return l;
  }

  /// Letztes Quartalsende ≤ Stichtag, das schon vollständig vor «heute» liegt.
  /// Stichtag 31.12.2025 (heute 02.09.2026) → 31.12.2025; Stichtag = heute
  /// 02.09.2026 → 30.06.2026 (Q3 läuft noch).
  DateTime letztesQuartalsende() {
    DateTime qEnde(DateTime d) => DateTime(d.year, ((d.month - 1) ~/ 3) * 3 + 4, 0);
    var q = qEnde(stichtag);
    if (q.isAfter(stichtag) || !q.isBefore(heute)) q = qEnde(DateTime(q.year, q.month - 3, 1));
    return q;
  }
}

class AbschlussPruefService {
  static List<Pruefbefund> pruefe(AbschlussKontext k) {
    final l = alleAbschlussRegeln().map((r) => r.pruefe(k)).toList();
    l.sort((a, b) => a.status.index.compareTo(b.status.index));
    return l;
  }
}
```
Hinweis `letztesQuartalsende`: `DateTime(jahr, monat, 0)` ist der letzte Tag des Vormonats — `qEnde` liefert damit den letzten Tag des Quartals, in dem `d` liegt. Für Stichtag 31.12.2025 und heute 02.09.2026 ergibt sich der 31.12.2025. Im Test «MWST saldiert» sind die Buchungen per 30.06.2025 gebucht, Stichtag 31.12.2025 → Saldi per 31.12.2025.
- [ ] **Step 4: Test → PASS.** Bei Rundungsdifferenzen `closeTo` verwenden; Regel-Logik nicht an Tests anpassen, sondern Fehler in der Regel beheben.
- [ ] **Step 5: Commit** `git add lib/services/buchhaltung/abschluss_regeln.dart lib/services/buchhaltung/abschluss_pruef_service.dart test/abschluss_pruef_service_test.dart && git commit -m "feat(audit): AbschlussPruefService mit 14 Regeln (TDD)"`

---

### Task 12: Audit-Screen neu, Provider, `AuditService` entfernen

**Files:**
- Modify: `sbs_projer_app/lib/presentation/providers/buchhaltung_providers.dart` (Audit-Provider ersetzen)
- Modify: `sbs_projer_app/lib/presentation/screens/buchhaltung/audit_screen.dart` (Neubau)
- Modify: `router.dart` (`?jahr=`), `buchhaltung_dashboard_screen.dart` (Details-Link)
- Delete: `sbs_projer_app/lib/services/buchhaltung/audit_service.dart`, `sbs_projer_app/test/audit_service_test.dart`
- Create: `sbs_projer_app/test/audit_service_entfernt_test.dart`

- [ ] **Step 1: Guard-Test (failing)**

```dart
// test/audit_service_entfernt_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AuditService ist abgelöst — kein Import mehr in lib/', () {
    expect(File('lib/services/buchhaltung/audit_service.dart').existsSync(), isFalse);
    final treffer = Directory('lib').listSync(recursive: true).whereType<File>()
        .where((f) => f.path.endsWith('.dart') && f.readAsStringSync().contains('audit_service.dart'));
    expect(treffer, isEmpty, reason: 'Die Abschlussprüfung ersetzt AuditService (Spec 02.09.2026).');
  });
}
```

- [ ] **Step 2: Provider ersetzen** — in `buchhaltung_providers.dart` `auditBefundeProvider` und den Import von `audit_service.dart` löschen; neu:

```dart
final abschlussPruefungProvider = FutureProvider.family<List<Pruefbefund>, int>((ref, jahr) async {
  ref.watch(buchungenStreamProvider);
  final buchungen = await BuchungRepository.getAll();
  final konten = await KontoRepository.getAll();
  final dateien = await CamtDateiRepository.getAll();
  final offene = await RechnungRepository.getOffene();
  final ohneJahr = await SteuerzahlungRepository.getNichtZugeordnet();
  final docs = await DokumentRepository.getAll(bereich: 'steuern', jahr: jahr);
  final steuerjahre = await SteuerjahrRepository.getAll();
  final statusListe = steuerjahre.where((s) => s.jahr == jahr).map((s) => s.status).toList();
  final offeneIds = offene.map((r) => r.id).toSet();
  final mitZahlung = buchungen.where((b) => !b.istStorniert && b.habenKonto == 1100 && b.belegId != null && offeneIds.contains(b.belegId)).map((b) => b.belegId!).toSet();
  return AbschlussPruefService.pruefe(AbschlussKontext(
    jahr: jahr, heute: DateTime.now(), buchungen: toSaldoInput(buchungen),
    konten: konten.map((k) => KontoInfo(kontonummer: k.kontonummer, bezeichnung: k.bezeichnung, kategorie: k.kategorie ?? '—')).toList(),
    camtDateien: [for (final d in dateien) if (d.zeitraumVon != null && d.zeitraumBis != null && d.anfangssaldo != null && d.schlusssaldo != null)
        CamtDateiInfo(von: d.zeitraumVon!, bis: d.zeitraumBis!, anfangssaldo: d.anfangssaldo!, schlusssaldo: d.schlusssaldo!)],
    offeneRechnungen: offene.map((r) => OffeneRechnungInfo(id: r.id, datum: r.rechnungsdatum, brutto: r.betragBrutto)).toList(),
    steuerbuchungenOhneJahr: ohneJahr.length,
    dokumentTypen: docs.map((d) => d.typ).toSet(),
    steuerjahrStatus: statusListe.isEmpty ? 'offen' : statusListe.first,
    offeneRechnungenMitZahlung: mitZahlung,
  ));
});
```
(Imports ergänzen: `abschluss_pruef_service.dart`, `camt_datei_repository.dart`, `rechnung_repository.dart`, `steuerzahlung_repository.dart`, `dokument_repository.dart`, `steuerjahr_repository.dart`.)

- [ ] **Step 3: Screen neu bauen**

```dart
// lib/presentation/screens/buchhaltung/audit_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/presentation/providers/buchhaltung_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/filter/app_filter_bar.dart';
import 'package:sbs_projer_app/services/buchhaltung/abschluss_pruef_service.dart';

class AuditScreen extends ConsumerStatefulWidget {
  final int? jahr;
  const AuditScreen({super.key, this.jahr});
  @override ConsumerState<AuditScreen> createState() => _S();
}

class _S extends ConsumerState<AuditScreen> {
  late int _jahr = widget.jahr ?? DateTime.now().year;
  bool _grueneZeigen = false;

  Color _farbe(PruefStatus s) => switch (s) { PruefStatus.rot => AppColors.error, PruefStatus.gelb => AppColors.warning, PruefStatus.gruen => Colors.green };

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(abschlussPruefungProvider(_jahr));
    return Scaffold(
      appBar: AppBar(title: const Text('Abschlussprüfung')),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 0), child: Row(children: [
          Expanded(child: AppFilterDropdown<int>(hint: 'Jahr', value: _jahr, nullable: false, isExpanded: true,
            options: [for (var j = DateTime.now().year; j >= 2019; j--) (j, '$j')], onChanged: (v) => setState(() => _jahr = v ?? _jahr))),
        ])),
        Expanded(child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Fehler: $e')),
          data: (befunde) {
            int n(PruefStatus s) => befunde.where((b) => b.status == s).length;
            final gruppen = <String, List<Pruefbefund>>{};
            for (final b in befunde) { if (b.status == PruefStatus.gruen && !_grueneZeigen) continue; gruppen.putIfAbsent(b.gruppe, () => []).add(b); }
            return ListView(padding: const EdgeInsets.all(12), children: [
              InkWell(onTap: () => setState(() => _grueneZeigen = !_grueneZeigen), child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  _punkt(PruefStatus.rot), Text(' ${n(PruefStatus.rot)} rot   '), _punkt(PruefStatus.gelb), Text(' ${n(PruefStatus.gelb)} gelb   '),
                  _punkt(PruefStatus.gruen), Text(' ${n(PruefStatus.gruen)} grün'),
                  const Spacer(), Text(_grueneZeigen ? 'grüne ausblenden' : 'grüne zeigen', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ]))),
              for (final g in gruppen.entries) Container(
                margin: const EdgeInsets.only(top: 10), padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(g.key, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const Divider(),
                  for (final b in g.value) _zeile(b),
                ])),
            ]);
          })),
      ]),
    );
  }

  Widget _punkt(PruefStatus s) => Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: _farbe(s)));

  Widget _zeile(Pruefbefund b) => InkWell(
        onTap: b.aktionRoute == null ? null : () => context.push(b.aktionRoute!),
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 4), child: _punkt(b.status)),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(b.titel, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (b.ist.isNotEmpty || b.soll.isNotEmpty)
              Text('Ist: ${b.ist}${b.soll.isEmpty ? '' : ' · Soll: ${b.soll}'}', style: const TextStyle(fontSize: 12)),
            if (b.hinweis.isNotEmpty) Text(b.hinweis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ])),
          if (b.aktionRoute != null) const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
        ])),
      );
}
```

- [ ] **Step 4: Route** `/buchhaltung/audit` → `AuditScreen(jahr: int.tryParse(state.uri.queryParameters['jahr'] ?? ''))`. **Dashboard:** in `_BankWaechterCard` unter dem Text einen `InkWell` «Details →» mit `context.push('/buchhaltung/audit?jahr=${DateTime.now().year}')` (die Karte braucht dafür `BuildContext` — sie ist `StatelessWidget`, `build(context)` reicht).
- [ ] **Step 5: Löschen** `git rm lib/services/buchhaltung/audit_service.dart test/audit_service_test.dart`.
- [ ] **Step 6: Tests + Analyse** `flutter test test/audit_service_entfernt_test.dart test/abschluss_pruef_service_test.dart && flutter analyze` → PASS / No issues.
- [ ] **Step 7: Commit** `git add -A lib/presentation/screens/buchhaltung/audit_screen.dart lib/presentation/providers/buchhaltung_providers.dart lib/core/config/router.dart lib/presentation/screens/buchhaltung/buchhaltung_dashboard_screen.dart test/audit_service_entfernt_test.dart && git commit -m "feat(audit): Abschlussprüfung mit Jahreswahl ersetzt AuditService"`

---

### Task 13: camt — Steuerjahr/Steuerart beim Bestätigen

**Files:**
- Modify: `sbs_projer_app/lib/services/camt/camt_ausgabe_booker.dart`
- Modify: `sbs_projer_app/lib/services/camt/camt_auto_booker.dart` (`bucheVorschlag` reicht die Zuordnung weiter)
- Modify: `sbs_projer_app/lib/presentation/screens/buchhaltung/camt/camt_import_tab.dart`
- Test: `sbs_projer_app/test/camt_ausgabe_booker_test.dart` (bestehende Datei ergänzen, sonst anlegen)

- [ ] **Step 1: Failing Test für die reine Kontowahl**

```dart
  group('steuerKontoFuer', () {
    test('Bund/Kanton mit Rückstellung → 2208, ohne → 8900; Busse → 8900; MWST → 2202', () {
      expect(steuerKontoFuer(steuerart: 'bund', hatRueckstellung: true), 2208);
      expect(steuerKontoFuer(steuerart: 'kanton', hatRueckstellung: false), 8900);
      expect(steuerKontoFuer(steuerart: 'busse', hatRueckstellung: true), 8900);
      expect(steuerKontoFuer(steuerart: 'mwst', hatRueckstellung: true), 2202);
    });
    test('istSteuerVorlage erkennt 8900/2208/2202 im Soll', () {
      expect(istSteuerKonto(8900), isTrue);
      expect(istSteuerKonto(6200), isFalse);
    });
  });
```

- [ ] **Step 2: Test → FAIL.**

- [ ] **Step 3: Booker erweitern** (in `camt_ausgabe_booker.dart`, oberhalb der Klasse):

```dart
/// Zuordnung einer Steuerzahlung beim camt-Bestätigen (Spec 02.09.2026, Abschnitt 5).
class SteuerZuordnung {
  final int steuerjahr;
  final String steuerart; // bund | kanton | mwst | busse
  final bool hatRueckstellung; // 2208-Saldo des Jahres > 0
  const SteuerZuordnung({required this.steuerjahr, required this.steuerart, required this.hatRueckstellung});
}

bool istSteuerKonto(int konto) => konto == 8900 || konto == 2208 || konto == 2202;

int steuerKontoFuer({required String steuerart, required bool hatRueckstellung}) {
  if (steuerart == 'mwst') return 2202;
  if (steuerart == 'busse') return 8900;
  return hatRueckstellung ? 2208 : 8900;
}
```
`book` bekommt einen optionalen Parameter `SteuerZuordnung? steuer`; wenn gesetzt und `!tx.isCredit`: `felder['soll_konto'] = steuerKontoFuer(...)` (nur bei Belastung; Gutschrift = Rückzahlung: `felder['haben_konto']` ersetzen), und in der `create`-Map `'steuerjahr': steuer?.steuerjahr, 'steuerart': steuer?.steuerart`.

```dart
  static Future<Buchung> book(CamtTransaction tx, BuchungsVorlage vorlage, {SteuerZuordnung? steuer}) async {
    final konten = kontenFuerCamt(vorlage);
    final felder = ausgabeBuchungsFelder(
      betrag: tx.amount,
      isCredit: tx.isCredit,
      mwstSatz: vorlage.mwstSatz ?? 0,
      vorlageSoll: konten.sollKonto,
      vorlageHaben: konten.habenKonto,
      vorlageMwstKonto: konten.mwstKonto,
    );
    if (steuer != null) {
      // Steuerkonto nach Steuerart/Rückstellung; Gutschrift = Rückzahlung → Habenseite.
      final konto = steuerKontoFuer(steuerart: steuer.steuerart, hatRueckstellung: steuer.hatRueckstellung);
      if (tx.isCredit) { felder['haben_konto'] = konto; } else { felder['soll_konto'] = konto; }
    }
    final datumStr = tx.bookingDate.toIso8601String().split('T').first;
    final beschreibung = tx.partyName != null
        ? '${tx.isCredit ? "Zahlung" : "Belastung"} ${tx.partyName}'
        : (tx.additionalInfo ?? vorlage.bezeichnung);
    final notizen = <String>[
      if (kontenWerdenGetauscht(isCredit: tx.isCredit, vorlageSoll: konten.sollKonto))
        'GUTSCHRIFT auf Ausgabe-Regel (Konten getauscht) — MwSt manuell prüfen',
      if (steuer != null) 'Steuer ${steuer.steuerjahr} ${steuer.steuerart}',
      if (tx.strukturierteReferenz != null) 'Ref: ${tx.strukturierteReferenz}',
      if (tx.partyIban != null) 'IBAN: ${tx.partyIban}',
    ].join('\n');

    return BuchungRepository.create({
      'datum': datumStr,
      'belegnummer': tx.accountServiceRef,
      'vorlage_id': vorlage.id,
      ...felder,
      'beschreibung': beschreibung,
      'zahlungsweg': vorlage.zahlungsweg ?? 'bank',
      'belegordner': vorlage.belegordner ?? 'bank',
      'beleg_typ': 'camt053',
      'geschaeftsjahr': tx.bookingDate.year,
      'camt_tx_key': tx.txKey,
      'notizen': notizen,
      'steuerjahr': steuer?.steuerjahr,
      'steuerart': steuer?.steuerart,
    });
  }
```
`CamtAutoBooker.bucheVorschlag(CamtVorschlag v, {SteuerZuordnung? steuer})` reicht `steuer` im Fall `ausgabe` an `book` weiter.

- [ ] **Step 4: Import-Tab** — in `camt_import_tab.dart`:
  - State: `final _steuer = <String, SteuerZuordnung>{};` (Key `v.tx.txKey`).
  - In `_vorschlagZeile(v)`: wenn `v.typ == CamtVorschlagTyp.ausgabe && v.vorlage != null && istSteuerKonto(kontenFuerCamt(v.vorlage!).sollKonto)`, unter der Zeile zwei `DropdownButton`s (Steuerjahr: `DateTime.now().year` … 2019, Vorschlag `v.tx.bookingDate.year - 1`, bei ESTV (`partyName` enthält «Eidgen») das laufende Jahr; Steuerart: Vorschlag `mwst` bei ESTV, sonst `kanton`) — Änderung schreibt `_steuer[v.tx.txKey] = SteuerZuordnung(steuerjahr: j, steuerart: a, hatRueckstellung: _rueckstellungJahre.contains(j))`. Initialwert beim Aufbau der Vorschläge setzen, damit «Alle bestätigen» ohne Klick funktioniert.
  - `_rueckstellungJahre`: nach dem Laden der Vorschläge per `BuchungRepository.getAll()` die Jahre mit `haben_konto == 2208 && !istStorniert` sammeln (`Set<int>` aus `geschaeftsjahr`).
  - `_bucheAlleVorschlaege` und Einzel-Bestätigen: `CamtAutoBooker.bucheVorschlag(v, steuer: _steuer[v.tx.txKey])`.

- [ ] **Step 5: Test → PASS; Analyse** `flutter analyze lib/services/camt lib/presentation/screens/buchhaltung/camt`.
- [ ] **Step 6: Commit** `git add lib/services/camt lib/presentation/screens/buchhaltung/camt test/camt_ausgabe_booker_test.dart && git commit -m "feat(camt): Steuerjahr/Steuerart beim Bestätigen, Kontierung 2208/8900/2202"`

---

### Task 14: Import-Skript Altbestand + Kataloge

**Files:**
- Create: `Datenbank/import/steuer_dokumente_katalog.csv`, `Datenbank/import/steuerjahre_seed.csv`, `Datenbank/import/steuerzahlungen_zuordnung.csv`, `Datenbank/import/import_steuer_dokumente.py`

- [ ] **Step 1: Kataloge** — die drei CSV-Dateien werden von der Hauptsession aus den Session-Katalogen erzeugt und liegen vor Ausführung dieses Tasks im Repo (`git log -- Datenbank/import/steuer_dokumente_katalog.csv` zeigt den Commit). Der Task prüft nur Vollständigkeit: jede PDF in `01_Steuern/`, `Unterlagen/` und den Jahresordnern hat eine Zeile (`--dry-run` meldet kein «FEHLT», und `ls` der drei Ordner minus `.softaxj*/.zip/.xlsm` = Zeilenzahl). Format (Semikolon-getrennt, UTF-8): `steuer_dokumente_katalog.csv` Spalten `datei;jahr;typ;kategorie;datum;betrag;referenz;titel;zahlung_belegnummer` — eine Zeile je PDF aus `00_Rechnungen/01_Steuern/` (22), `Unterlagen/` (27) und `Steuererklärungen 2019-2024/<jahr>/` (11a → `steuererklaerung`, `_Q`/`_DB` → `steuererklaerung` mit Titel «Quittung»/«Deckblatt», Bilanz/ER → `jahresrechnung`, Zinsausweis → `zinsausweis`, `.softaxj*`/`.zip`/`.xlsm` werden nicht importiert). Werte aus `docs/buchhaltung/jahresabschluss-2025.md` Abschnitt 8 und den `_Index_PDF-zu-Originalscan.txt`. Beispielzeilen:
```
datei;jahr;typ;kategorie;datum;betrag;referenz;titel;zahlung_belegnummer
00_Rechnungen/01_Steuern/2024_Kanton_definitiv_Rg14926769_1469.00.pdf;2024;rechnung_definitiv;kanton;2026-01-09;1469.00;14926769;Kanton 2024 definitiv (Saldo 1'469.00);ZV20260415/076670/1
00_Rechnungen/01_Steuern/Unterlagen/2024_Kanton_Veranlagungsverfuegung_22.12.2025_Total2748.00.pdf;2024;veranlagung;kanton;2025-12-22;2748.00;;Veranlagungsverfügung Kanton 2024;
00_Rechnungen/01_Steuern/Steuererklärungen 2019-2024/2024/Ems, 11a_2024.pdf;2024;steuererklaerung;;2025-11-10;;;Steuererklärung 2024 (Formular 11a);
```
`steuerjahre_seed.csv` Spalten `jahr;status;eingereicht_am;veranlagt_am;steuerbarer_gewinn;steuerbares_kapital;verlustvortrag_verrechnet;bund_provisorisch;bund_definitiv;kanton_provisorisch;kanton_definitiv;notizen` mit den Werten aus Spec Abschnitt 6 (2019: veranlagt;;2021-01-12;-4973;15000;0;425;0;600;47;Rumpfjahr ab 18.04.2019 … 2025: offen;;;;;;2405.50;;2748;;Rückstellung 4'000 gebucht).
`steuerzahlungen_zuordnung.csv` Spalten `belegnummer;steuerjahr;steuerart` — eine Zeile je der 28 Buchungen (Belegnummern aus Task-Kontext, z. B. `301_2025_05_14_Steu_00127900;2024;kanton`, `ZV20260505/864008/2;2025;kanton`, `254_2022_11_03_MWST_00039420` bleibt MWST/2022 falls vorhanden — die 8900-Buchung `301_2022_11_03_Steu_00039420;2022;mwst`).

- [ ] **Step 2: Skript**

```python
# Datenbank/import/import_steuer_dokumente.py — einmalige Erstbefüllung (idempotent)
# Aufruf: cd Datenbank/import && py -3 import_steuer_dokumente.py [--dry-run]
import csv, os, sys, uuid
from pathlib import Path
from dotenv import load_dotenv
from supabase import create_client

ROOT = Path(__file__).resolve().parents[2]
load_dotenv(Path(__file__).parent / '.env')
sb = create_client(os.environ['SUPABASE_URL'], os.environ['SUPABASE_SERVICE_KEY'])
USER = '1e1ec2dd-7836-4d8e-8256-c5649d994ee2'
DRY = '--dry-run' in sys.argv

def lese(name):
    with open(Path(__file__).parent / name, encoding='utf-8') as f:
        return list(csv.DictReader(f, delimiter=';'))

def safe(n): return ''.join(c if c.isalnum() or c in '._-' else '_' for c in n)

# 1) Steuerjahre
for r in lese('steuerjahre_seed.csv'):
    row = {k: (v if v != '' else None) for k, v in r.items()}
    row['jahr'] = int(row['jahr']); row['user_id'] = USER
    print('steuerjahr', row['jahr'], row['status'])
    if not DRY: sb.table('steuerjahre').upsert(row, on_conflict='user_id,jahr').execute()

# 2) Zahlungen zuordnen
for r in lese('steuerzahlungen_zuordnung.csv'):
    print('zuordnung', r['belegnummer'], r['steuerjahr'], r['steuerart'])
    if not DRY:
        sb.table('buchungen').update({'steuerjahr': int(r['steuerjahr']), 'steuerart': r['steuerart']}) \
          .eq('user_id', USER).eq('belegnummer', r['belegnummer']).execute()

# 3) Dokumente
vorhanden = {d['storage_pfad'] for d in sb.table('dokumente').select('storage_pfad').eq('user_id', USER).execute().data}
for r in lese('steuer_dokumente_katalog.csv'):
    pfad = ROOT / r['datei']
    if not pfad.exists(): print('FEHLT', pfad); continue
    jahr = int(r['jahr']) if r['jahr'] else None
    doc_id = str(uuid.uuid5(uuid.NAMESPACE_URL, r['datei']))  # stabil → idempotent
    storage = f"{USER}/steuern/{jahr or 'ohne-jahr'}/{doc_id}_{safe(pfad.name)}"
    if storage in vorhanden: print('schon da', pfad.name); continue
    buchung_id = None
    if r['zahlung_belegnummer']:
        res = sb.table('buchungen').select('id').eq('user_id', USER).eq('belegnummer', r['zahlung_belegnummer']).limit(1).execute().data
        buchung_id = res[0]['id'] if res else None
    print('upload', storage, '→ buchung', buchung_id)
    if DRY: continue
    data = pfad.read_bytes()
    mime = 'application/pdf' if pfad.suffix.lower() == '.pdf' else 'image/jpeg'
    sb.storage.from_('dokumente').upload(storage, data, {'content-type': mime, 'upsert': 'true'})
    sb.table('dokumente').insert({
        'id': doc_id, 'user_id': USER, 'bereich': 'steuern', 'typ': r['typ'], 'kategorie': r['kategorie'] or None,
        'jahr': jahr, 'dokument_datum': r['datum'] or None, 'betrag': float(r['betrag']) if r['betrag'] else None,
        'referenz': r['referenz'] or None, 'titel': r['titel'], 'dateiname': pfad.name, 'dateityp': mime,
        'groesse_bytes': len(data), 'storage_pfad': storage, 'buchung_id': buchung_id,
    }).execute()
print('fertig')
```
`.env` in `Datenbank/import/` braucht `SUPABASE_URL` und `SUPABASE_SERVICE_KEY` (Service-Rolle, weil RLS; Schlüssel aus dem Supabase-Dashboard, nie committen — `.gitignore` deckt `.env` ab). Pakete: `py -3 -m pip install supabase python-dotenv`.

- [ ] **Step 3: Trockenlauf** `py -3 import_steuer_dokumente.py --dry-run` → alle Dateien gefunden («FEHLT» darf nicht erscheinen), 28 Zuordnungen, 7 Steuerjahre.
- [ ] **Step 4: Commit** (ohne `.env`): `git add Datenbank/import/import_steuer_dokumente.py Datenbank/import/*.csv && git commit -m "import: Erstbefüllung Steuerdokumente/Steuerjahre/Zahlungszuordnung (Skript + Kataloge)"`
- [ ] **Step 5: Echtlauf erst nach Task 15 (Deploy)**, dann verifizieren:
```sql
SELECT jahr, COUNT(*) FROM dokumente WHERE bereich='steuern' GROUP BY jahr ORDER BY jahr;
SELECT steuerjahr, steuerart, bezahlt FROM view_steuerjahr_zahlungen ORDER BY 1,2;
```
Expected: Dokumente 2019–2025 (Summe ≈ 49 + 6 Jahresordner × 3–6 Dateien); View 2024 bund 2405.50 / kanton 2748.00, 2025 bund 2405.50 / kanton 2748.00, 2019 bund −9.20.

---

### Task 15: Version, Gesamttests, Browser-Check, Deploy

**Files:**
- Modify: `sbs_projer_app/pubspec.yaml` Zeile 4 → `version: 0.96.0+712`, `sbs_projer_app/lib/core/app_version.dart` → `kAppVersion = '0.96.0'`

- [ ] **Step 1:** Version bumpen (beide Stellen).
- [ ] **Step 2:** `flutter test` → alle grün (≥ 1'212 + neue); `flutter analyze` → No issues.
- [ ] **Step 3: Browser-Check** (Pflicht laut Memory «UI vor Deploy testen»): `flutter run -d edge` bzw. Preview; Handy-Breite (375 px). Prüfen: Dashboard-Kachel Steuern sichtbar → Übersicht rendert Karten (auch ohne Daten: nur Summenzeile + «Jahr anlegen») → Jahresdetail: Formular speichern, Dokument hochladen (PDF), Dokument öffnen, Zahlung zuordnen → Audit: Jahr wechseln, rote/gelbe Zeilen, Aktion-Link → Dokumente-Screen Filter. Screenshot je Screen für Daniel.
- [ ] **Step 4: Deploy** nach CLAUDE.md (alle Änderungen committet; Build `--pwa-strategy=none`, Cache-Bust, gh-pages, Commit «deploy v0.96.0 — Steuern-Screen, Dokumente, Abschlussprüfung»).
- [ ] **Step 5: Import-Skript Echtlauf** (Task 14 Step 5), danach Übersicht im Live-System prüfen: 2024 grün ausgeglichen, 2025 Ampel blau (Guthaben 1'153.50 provisorisch über Rückstellung — erwartet), Dossier 2024 = 6/6 wenn Zinsausweis/Lohnausweis hochgeladen sind (Lohnausweise 2019–2024 fehlen im Ordner → bleiben «–»).
- [ ] **Step 6: Doku** — `ToDo.md` (Session-Übergabe: neuer Screen, Daniels 2025er-Uploads: Jahresrechnung, Lohnausweis, Zinsausweis), `docs/buchhaltung/jahresabschluss-2025.md` Abschnitt «Dossier in der App», Memory `jahresabschluss_2025.md` (Steuern-Screen vorhanden). Commit + Push.

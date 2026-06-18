# Geschäfts-Einstellungen + Settings-Umbau — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Neue „Geschäft"-Stammdaten als Einstellungs-Kategorie, davon Lohn (Arbeitgeber + Arbeitnehmer-Vorbefüllung), Report-Mail-Empfänger und PDF-Firmendaten speisen, und den Einstellungen-Screen sauber gruppieren — mit Fallback auf die heutigen Werte, sodass die App unverändert weiterläuft.

**Architecture:** Neue Supabase-Tabelle `geschaeft_einstellungen` (1 Zeile/User) + Dart-Model mit Fallback-Gettern + Repository/Provider. Reine Mapping-Logik (TDD). UI-Form + Settings-Reorg. Verdrahtung über optionale Parameter mit Default = heutige Konstanten.

**Tech Stack:** Flutter, Riverpod, Supabase (Postgres + RLS), `pdf`/`printing`.

**Spec:** `docs/superpowers/specs/2026-06-18-geschaeft-einstellungen-design.md`

**Arbeitsverzeichnis:** `flutter`-Befehle in `sbs_projer_app/` (vorher `export PATH="$PATH:/c/flutter/bin"`). DB-Migration via Supabase MCP (`apply_migration`, project_id `pltbaqqwpnmdajwgnhpd`).

---

## Datei-Übersicht

**Neu:**
- `Datenbank/migrations/096_geschaeft_einstellungen.sql`
- `sbs_projer_app/lib/data/models/geschaeft_einstellungen.dart`
- `sbs_projer_app/lib/data/repositories/geschaeft_repository.dart`
- `sbs_projer_app/lib/presentation/providers/geschaeft_providers.dart`
- `sbs_projer_app/lib/services/buchhaltung/geschaeft_mapping.dart`
- `sbs_projer_app/lib/presentation/screens/einstellungen/widgets/geschaeft_form.dart`
- Tests: `test/data/models/geschaeft_einstellungen_test.dart`, `test/services/buchhaltung/geschaeft_mapping_test.dart`

**Geändert:**
- `einstellungen_screen.dart` (Reorg + Geschäft + Lohn-Tile)
- `lohn_einstellungen_screen.dart` (AG-Block raus, AN-Prefill, AG-Snapshot)
- `services/mail/bericht_mail_service.dart` (`send(to:)`)
- `services/pdf/bericht_pdf_common.dart` (kopf Firma-Params)
- `services/pdf/bilanz_pdf_service.dart`, `services/pdf/erfolgsrechnung_pdf_service.dart` (Firma durchreichen)
- `presentation/screens/buchhaltung/berichte_screen.dart` (Mail-Empfänger + Firma)
- `services/pdf/rechnung_pdf_service.dart` (+ 4 Aufrufstellen)

---

## Task 1: Migration 096 — Tabelle `geschaeft_einstellungen`

**Files:** Create `Datenbank/migrations/096_geschaeft_einstellungen.sql`

- [ ] **Step 1: SQL-Datei schreiben**

```sql
-- 096_geschaeft_einstellungen.sql
-- Firmen-Stammdaten (eine Zeile pro User). Speist Lohn, Report-Mail, PDF-Firmendaten.
CREATE TABLE IF NOT EXISTS geschaeft_einstellungen (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE,
  firma_name text,
  strasse text,
  plz_ort text,
  gf_vorname text,
  gf_name text,
  telefon text,
  mail_geschaeft text,
  mail_privat text,
  mwst_nummer text,
  uid_nummer text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE geschaeft_einstellungen ENABLE ROW LEVEL SECURITY;

CREATE POLICY geschaeft_einstellungen_user ON geschaeft_einstellungen
  FOR ALL USING (auth.uid() = user_id);

-- Default-Zeile = heutige fix codierte Werte (Verhalten bleibt identisch)
INSERT INTO geschaeft_einstellungen
  (user_id, firma_name, strasse, plz_ort, gf_vorname, gf_name, telefon,
   mail_geschaeft, mail_privat, mwst_nummer, uid_nummer)
VALUES
  ('1e1ec2dd-7836-4d8e-8256-c5649d994ee2', 'SBS Projer GmbH', 'Via Rezia 8',
   '7013 Domat/Ems', 'Daniel', 'Projer', '076 566 58 06',
   'sbs.projer@gmail.com', 'dani.proyer@gmail.com', '', '')
ON CONFLICT (user_id) DO NOTHING;
```

- [ ] **Step 2: Migration anwenden (Supabase MCP)**

Tool `apply_migration` mit project_id `pltbaqqwpnmdajwgnhpd`, name `geschaeft_einstellungen`, query = obiger SQL-Inhalt.
Expected: `{"success":true}`.

- [ ] **Step 3: Verifizieren**

Tool `execute_sql`: `SELECT firma_name, gf_vorname, gf_name, mail_geschaeft FROM geschaeft_einstellungen WHERE user_id='1e1ec2dd-7836-4d8e-8256-c5649d994ee2';`
Expected: eine Zeile `SBS Projer GmbH / Daniel / Projer / sbs.projer@gmail.com`.

- [ ] **Step 4: Commit**

```bash
git add Datenbank/migrations/096_geschaeft_einstellungen.sql
git commit -m "feat(db): Tabelle geschaeft_einstellungen + Default-Zeile (Migration 096)"
```

---

## Task 2: Model `GeschaeftEinstellungen` + Fallback-Getter

**Files:**
- Create: `sbs_projer_app/lib/data/models/geschaeft_einstellungen.dart`
- Test: `sbs_projer_app/test/data/models/geschaeft_einstellungen_test.dart`

- [ ] **Step 1: Failing test**

```dart
// test/data/models/geschaeft_einstellungen_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/geschaeft_einstellungen.dart';

void main() {
  test('leeres Model liefert Fallback-Konstanten', () {
    const g = GeschaeftEinstellungen();
    expect(g.firma, 'SBS Projer GmbH');
    expect(g.adresseStrasse, 'Via Rezia 8');
    expect(g.adressePlzOrt, '7013 Domat/Ems');
    expect(g.mailEmpfaenger, 'dani.proyer@gmail.com');
  });

  test('mailEmpfaenger Reihenfolge geschaeft → privat → default', () {
    expect(const GeschaeftEinstellungen(mailGeschaeft: 'a@x.ch').mailEmpfaenger, 'a@x.ch');
    expect(const GeschaeftEinstellungen(mailPrivat: 'b@x.ch').mailEmpfaenger, 'b@x.ch');
    expect(const GeschaeftEinstellungen(mailGeschaeft: '  ', mailPrivat: 'b@x.ch').mailEmpfaenger, 'b@x.ch');
  });

  test('gesetzte Werte überschreiben Fallback; gfVollname + mwstZeile', () {
    const g = GeschaeftEinstellungen(
      firmaName: 'Meine AG', gfVorname: 'Max', gfName: 'Muster', mwstNummer: 'CHE-123.456.789');
    expect(g.firma, 'Meine AG');
    expect(g.gfVollname, 'Max Muster');
    expect(g.mwstZeile, 'MWST CHE-123.456.789');
    expect(const GeschaeftEinstellungen().mwstZeile, '');
  });
}
```

- [ ] **Step 2: Run → fails** (`cd sbs_projer_app && flutter test test/data/models/geschaeft_einstellungen_test.dart`).

- [ ] **Step 3: Implement**

```dart
// lib/data/models/geschaeft_einstellungen.dart
class GeschaeftEinstellungen {
  final String id;
  final String userId;
  final String? firmaName;
  final String? strasse;
  final String? plzOrt;
  final String? gfVorname;
  final String? gfName;
  final String? telefon;
  final String? mailGeschaeft;
  final String? mailPrivat;
  final String? mwstNummer;
  final String? uidNummer;

  const GeschaeftEinstellungen({
    this.id = '',
    this.userId = '',
    this.firmaName,
    this.strasse,
    this.plzOrt,
    this.gfVorname,
    this.gfName,
    this.telefon,
    this.mailGeschaeft,
    this.mailPrivat,
    this.mwstNummer,
    this.uidNummer,
  });

  // Fallback-Konstanten = heutige fix codierte Werte.
  static const kFirma = 'SBS Projer GmbH';
  static const kStrasse = 'Via Rezia 8';
  static const kPlzOrt = '7013 Domat/Ems';
  static const kTelefon = '076 566 58 06';
  static const kMail = 'dani.proyer@gmail.com';

  static String? _clean(String? s) => (s != null && s.trim().isNotEmpty) ? s.trim() : null;

  String get firma => _clean(firmaName) ?? kFirma;
  String get adresseStrasse => _clean(strasse) ?? kStrasse;
  String get adressePlzOrt => _clean(plzOrt) ?? kPlzOrt;
  String get telefonOrFallback => _clean(telefon) ?? kTelefon;
  String get gfVollname => '${gfVorname ?? ''} ${gfName ?? ''}'.trim();
  String get mailEmpfaenger => _clean(mailGeschaeft) ?? _clean(mailPrivat) ?? kMail;
  String get mwstZeile {
    final m = _clean(mwstNummer);
    return m == null ? '' : 'MWST $m';
  }

  factory GeschaeftEinstellungen.fromJson(Map<String, dynamic> j) => GeschaeftEinstellungen(
        id: j['id']?.toString() ?? '',
        userId: j['user_id']?.toString() ?? '',
        firmaName: j['firma_name'],
        strasse: j['strasse'],
        plzOrt: j['plz_ort'],
        gfVorname: j['gf_vorname'],
        gfName: j['gf_name'],
        telefon: j['telefon'],
        mailGeschaeft: j['mail_geschaeft'],
        mailPrivat: j['mail_privat'],
        mwstNummer: j['mwst_nummer'],
        uidNummer: j['uid_nummer'],
      );

  Map<String, dynamic> toJson() => {
        'firma_name': firmaName,
        'strasse': strasse,
        'plz_ort': plzOrt,
        'gf_vorname': gfVorname,
        'gf_name': gfName,
        'telefon': telefon,
        'mail_geschaeft': mailGeschaeft,
        'mail_privat': mailPrivat,
        'mwst_nummer': mwstNummer,
        'uid_nummer': uidNummer,
      };
}
```

- [ ] **Step 4: Run → passes.**

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/data/models/geschaeft_einstellungen.dart sbs_projer_app/test/data/models/geschaeft_einstellungen_test.dart
git commit -m "feat(geschaeft): Model GeschaeftEinstellungen mit Fallback-Gettern"
```

---

## Task 3: Repository + Provider

**Files:**
- Create: `sbs_projer_app/lib/data/repositories/geschaeft_repository.dart`
- Create: `sbs_projer_app/lib/presentation/providers/geschaeft_providers.dart`

- [ ] **Step 1: Repository**

```dart
// lib/data/repositories/geschaeft_repository.dart
import 'package:sbs_projer_app/data/models/geschaeft_einstellungen.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class GeschaeftRepository {
  static String get _userId => SupabaseService.dataUserId;

  /// Lädt die Geschäfts-Zeile des Users. Falls keine existiert, gibt es ein
  /// leeres Model zurück (dessen Getter auf die Konstanten zurückfallen).
  static Future<GeschaeftEinstellungen> get() async {
    final rows = await SupabaseService.client
        .from('geschaeft_einstellungen')
        .select()
        .eq('user_id', _userId)
        .limit(1);
    if ((rows as List).isEmpty) return const GeschaeftEinstellungen();
    return GeschaeftEinstellungen.fromJson(rows.first);
  }

  /// Upsert auf user_id (eine Zeile pro User).
  static Future<GeschaeftEinstellungen> save(Map<String, dynamic> fields) async {
    final json = {
      ...fields,
      'user_id': _userId,
      'updated_at': DateTime.now().toIso8601String(),
    };
    final rows = await SupabaseService.client
        .from('geschaeft_einstellungen')
        .upsert(json, onConflict: 'user_id')
        .select();
    return GeschaeftEinstellungen.fromJson(rows.first);
  }
}
```

- [ ] **Step 2: Provider**

```dart
// lib/presentation/providers/geschaeft_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/models/geschaeft_einstellungen.dart';
import 'package:sbs_projer_app/data/repositories/geschaeft_repository.dart';

final geschaeftProvider = FutureProvider<GeschaeftEinstellungen>((ref) {
  return GeschaeftRepository.get();
});
```

- [ ] **Step 3: Analyze**

Run: `cd sbs_projer_app && flutter analyze lib/data/repositories/geschaeft_repository.dart lib/presentation/providers/geschaeft_providers.dart`
Expected: keine Errors.

- [ ] **Step 4: Commit**

```bash
git add sbs_projer_app/lib/data/repositories/geschaeft_repository.dart sbs_projer_app/lib/presentation/providers/geschaeft_providers.dart
git commit -m "feat(geschaeft): Repository + geschaeftProvider"
```

---

## Task 4: Mapping-Logik (Arbeitgeber + Arbeitnehmer-Prefill)

**Files:**
- Create: `sbs_projer_app/lib/services/buchhaltung/geschaeft_mapping.dart`
- Test: `sbs_projer_app/test/services/buchhaltung/geschaeft_mapping_test.dart`

- [ ] **Step 1: Failing test**

```dart
// test/services/buchhaltung/geschaeft_mapping_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/geschaeft_einstellungen.dart';
import 'package:sbs_projer_app/services/buchhaltung/geschaeft_mapping.dart';

void main() {
  const g = GeschaeftEinstellungen(
    firmaName: 'SBS Projer GmbH',
    strasse: 'Via Rezia 8',
    plzOrt: '7013 Domat/Ems',
    gfVorname: 'Daniel',
    gfName: 'Projer',
  );

  test('arbeitgeber liefert Firma/Strasse/PLZ-Ort aus Geschäft', () {
    final ag = GeschaeftMapping.arbeitgeber(g);
    expect(ag.name, 'SBS Projer GmbH');
    expect(ag.adresse, 'Via Rezia 8');
    expect(ag.plzOrt, '7013 Domat/Ems');
  });

  test('arbeitnehmerPrefill füllt nur leere Felder', () {
    final pf = GeschaeftMapping.arbeitnehmerPrefill(
      (name: null, vorname: '', adresse: 'Eigene Strasse 1', plzOrt: null), g);
    expect(pf.name, 'Projer'); // war leer → aus Geschäft
    expect(pf.vorname, 'Daniel'); // war leer → aus Geschäft
    expect(pf.adresse, 'Eigene Strasse 1'); // war gesetzt → bleibt
    expect(pf.plzOrt, '7013 Domat/Ems'); // war null → aus Geschäft
  });
}
```

- [ ] **Step 2: Run → fails.**

- [ ] **Step 3: Implement**

```dart
// lib/services/buchhaltung/geschaeft_mapping.dart
import 'package:sbs_projer_app/data/models/geschaeft_einstellungen.dart';

/// Arbeitnehmer-Namens-/Adressfelder (für Prefill).
typedef AnFelder = ({String? name, String? vorname, String? adresse, String? plzOrt});

class GeschaeftMapping {
  /// Arbeitgeber-Felder für den Lohnausweis aus dem Geschäft.
  static ({String name, String adresse, String plzOrt}) arbeitgeber(GeschaeftEinstellungen g) =>
      (name: g.firma, adresse: g.adresseStrasse, plzOrt: g.adressePlzOrt);

  /// Vorbefüllung: leere Arbeitnehmer-Felder werden aus dem Geschäft gefüllt,
  /// bereits gesetzte bleiben unverändert.
  static AnFelder arbeitnehmerPrefill(AnFelder current, GeschaeftEinstellungen g) {
    String? pick(String? cur, String fallback) {
      if (cur != null && cur.trim().isNotEmpty) return cur;
      return fallback.trim().isEmpty ? null : fallback;
    }

    return (
      name: pick(current.name, g.gfName ?? ''),
      vorname: pick(current.vorname, g.gfVorname ?? ''),
      adresse: pick(current.adresse, g.adresseStrasse),
      plzOrt: pick(current.plzOrt, g.adressePlzOrt),
    );
  }
}
```

- [ ] **Step 4: Run → passes (2 tests).**

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/services/buchhaltung/geschaeft_mapping.dart sbs_projer_app/test/services/buchhaltung/geschaeft_mapping_test.dart
git commit -m "feat(geschaeft): Mapping Arbeitgeber + Arbeitnehmer-Prefill"
```

---

## Task 5: Geschäft-Formular-Widget

**Files:** Create `sbs_projer_app/lib/presentation/screens/einstellungen/widgets/geschaeft_form.dart`

- [ ] **Step 1: Implement**

```dart
// lib/presentation/screens/einstellungen/widgets/geschaeft_form.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/models/geschaeft_einstellungen.dart';
import 'package:sbs_projer_app/data/repositories/geschaeft_repository.dart';
import 'package:sbs_projer_app/presentation/providers/geschaeft_providers.dart';

class GeschaeftForm extends ConsumerStatefulWidget {
  final GeschaeftEinstellungen geschaeft;
  const GeschaeftForm({super.key, required this.geschaeft});

  @override
  ConsumerState<GeschaeftForm> createState() => _GeschaeftFormState();
}

class _GeschaeftFormState extends ConsumerState<GeschaeftForm> {
  late final Map<String, TextEditingController> _c;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final g = widget.geschaeft;
    _c = {
      'firma_name': TextEditingController(text: g.firmaName ?? ''),
      'strasse': TextEditingController(text: g.strasse ?? ''),
      'plz_ort': TextEditingController(text: g.plzOrt ?? ''),
      'mwst_nummer': TextEditingController(text: g.mwstNummer ?? ''),
      'uid_nummer': TextEditingController(text: g.uidNummer ?? ''),
      'gf_vorname': TextEditingController(text: g.gfVorname ?? ''),
      'gf_name': TextEditingController(text: g.gfName ?? ''),
      'telefon': TextEditingController(text: g.telefon ?? ''),
      'mail_geschaeft': TextEditingController(text: g.mailGeschaeft ?? ''),
      'mail_privat': TextEditingController(text: g.mailPrivat ?? ''),
    };
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await GeschaeftRepository.save(
          {for (final e in _c.entries) e.key: e.value.text.trim()});
      ref.invalidate(geschaeftProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Geschäft gespeichert')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(String key, String label, {TextInputType? kb}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: _c[key],
          keyboardType: kb,
          decoration: InputDecoration(
              labelText: label, border: const OutlineInputBorder(), isDense: true),
        ),
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 6),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Firma'),
        _field('firma_name', 'Name'),
        _field('strasse', 'Strasse / Nr.'),
        _field('plz_ort', 'PLZ Ort'),
        _field('mwst_nummer', 'MWST-Nummer'),
        _field('uid_nummer', 'UID-Nummer'),
        _label('Geschäftsführer'),
        _field('gf_vorname', 'Vorname'),
        _field('gf_name', 'Name'),
        _label('Kontakt'),
        _field('telefon', 'Telefon', kb: TextInputType.phone),
        _field('mail_geschaeft', 'Mail Geschäft', kb: TextInputType.emailAddress),
        _field('mail_privat', 'Mail Privat', kb: TextInputType.emailAddress),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save, size: 18),
            label: const Text('Geschäft speichern'),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Analyze**

Run: `cd sbs_projer_app && flutter analyze lib/presentation/screens/einstellungen/widgets/geschaeft_form.dart`
Expected: keine Errors.

- [ ] **Step 3: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/einstellungen/widgets/geschaeft_form.dart
git commit -m "feat(einstellungen): Geschäft-Formular-Widget"
```

---

## Task 6: Einstellungen-Screen reorganisieren + Geschäft + Lohn

**Files:** Modify `sbs_projer_app/lib/presentation/screens/einstellungen/einstellungen_screen.dart`

Ziel: Top-Level-Reihenfolge **Geschäft · Lohn · Preise · Heineken · Biersorten**. Die bestehenden Preis-/Heineken-/Biersorten-Inhalte bleiben funktional unverändert, werden nur umgeordnet. Geschäft + Lohn kommen neu oben dazu.

- [ ] **Step 1: Importe ergänzen** (oben):

```dart
import 'package:sbs_projer_app/presentation/providers/geschaeft_providers.dart';
import 'package:sbs_projer_app/presentation/screens/einstellungen/widgets/geschaeft_form.dart';
```

- [ ] **Step 2: Geschäft-Provider mitlesen + oben einsetzen.** In `build` zusätzlich:

```dart
final geschaeftAsync = ref.watch(geschaeftProvider);
```

Im `data:`-Branch (innerhalb des `ListView(children: [...])`) **als allererste beiden Einträge** (vor der „Biersorten"-Card) einfügen:

```dart
              // Geschäft (neu)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  leading: const Icon(Icons.store, color: AppColors.primary),
                  title: const Text('Geschäft',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Firma, Geschäftsführer, Kontakt, MWST/UID'),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  children: [
                    geschaeftAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Text('Fehler: $e'),
                      data: (g) => GeschaeftForm(key: ValueKey(g.id), geschaeft: g),
                    ),
                  ],
                ),
              ),

              // Lohn (Einstieg)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.payments, color: AppColors.primary),
                  title: const Text('Lohn-Einstellungen',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Sätze & Lohnausweis pro Jahr'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/buchhaltung/lohn'),
                ),
              ),
```

- [ ] **Step 3: Reihenfolge prüfen.** Sicherstellen, dass danach die bestehenden Blöcke in dieser Reihenfolge stehen: Biersorten-Card → Heineken `_SectionCard` → „Aktuelle Preise"-Header → Reinigungspreise → Störungspreise → Weitere Preise → MwSt-Sätze → „Neue Preise erfassen". (Die Heineken-/Biersorten-Position darf bleiben; nur Geschäft+Lohn kommen oben dazu.) **Keine** Preis-Logik ändern.

- [ ] **Step 4: Analyze**

Run: `cd sbs_projer_app && flutter analyze lib/presentation/screens/einstellungen/einstellungen_screen.dart`
Expected: keine Errors. (`context` ist via `go_router` bereits importiert.)

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/einstellungen/einstellungen_screen.dart
git commit -m "feat(einstellungen): Geschäft-Sektion + Lohn-Einstieg, Gruppierung"
```

---

## Task 7: Lohn-Einstellungen umbauen (AG aus Geschäft, AN-Prefill)

**Files:** Modify `sbs_projer_app/lib/presentation/screens/buchhaltung/lohn_einstellungen_screen.dart`

- [ ] **Step 1: Importe ergänzen**

```dart
import 'package:sbs_projer_app/data/models/geschaeft_einstellungen.dart';
import 'package:sbs_projer_app/presentation/providers/geschaeft_providers.dart';
import 'package:sbs_projer_app/services/buchhaltung/geschaeft_mapping.dart';
```

- [ ] **Step 2: AG-Controller entfernen.** Die drei Felder `_agNameCtrl`, `_agAdresseCtrl`, `_agPlzOrtCtrl` (Deklaration Zeilen 45–47) löschen; in `dispose()` aus der Liste entfernen; in `_fillFromEinstellungen` die drei `_ag*`-Zeilen (90–92) löschen.

- [ ] **Step 3: Geschäft in `build` lesen + AN-Prefill.** In `build`, vor dem `einst.whenData(...)`-Block:

```dart
    final geschaeftAsync = ref.watch(geschaeftProvider);
    final geschaeft = geschaeftAsync.valueOrNull ?? const GeschaeftEinstellungen();
```

Den Lade-Block ersetzen durch (füllt auch bei noch fehlendem Jahrgang die AN-Felder vor):

```dart
    if (!_loaded && geschaeftAsync.hasValue && !einst.isLoading) {
      final e = einst.valueOrNull;
      if (e != null) _fillFromEinstellungen(e);
      final pf = GeschaeftMapping.arbeitnehmerPrefill(
        (name: _nameCtrl.text, vorname: _vornameCtrl.text,
         adresse: _adresseCtrl.text, plzOrt: _plzOrtCtrl.text),
        geschaeft,
      );
      _nameCtrl.text = pf.name ?? '';
      _vornameCtrl.text = pf.vorname ?? '';
      _adresseCtrl.text = pf.adresse ?? '';
      _plzOrtCtrl.text = pf.plzOrt ?? '';
      _loaded = true;
    }
```

(Die `body: einst.when(... data: (_) => _buildForm())`-Struktur bleibt; `_buildForm` bekommt Zugriff auf `geschaeft` über ein Feld — siehe Step 4.)

- [ ] **Step 4: Geschäft an `_buildForm` reichen + AG-Block ersetzen.** `geschaeft` als Parameter an `_buildForm` übergeben: `data: (_) => _buildForm(geschaeft)`, Signatur `Widget _buildForm(GeschaeftEinstellungen geschaeft)`. Den AG-Abschnitt (Zeilen 180–184: Header „Lohnausweis — Arbeitgeber" + drei `_textField`) ersetzen durch eine read-only Info:

```dart
          const SizedBox(height: 24),
          _sectionHeader('Lohnausweis — Arbeitgeber (aus Geschäft)'),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${geschaeft.firma}\n${geschaeft.adresseStrasse}\n${geschaeft.adressePlzOrt}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
```

- [ ] **Step 5: AG-Snapshot beim Speichern.** In `_save()`: vor dem Erstellen von `LohnEinstellungen` die Geschäfts-Daten holen und die `arbeitgeber*`-Felder daraus setzen (statt aus den entfernten Controllern):

```dart
      final geschaeft = ref.read(geschaeftProvider).valueOrNull ?? const GeschaeftEinstellungen();
      final ag = GeschaeftMapping.arbeitgeber(geschaeft);
```

und im `LohnEinstellungen(...)`-Aufruf:

```dart
        arbeitgeberName: ag.name,
        arbeitgeberAdresse: ag.adresse,
        arbeitgeberPlzOrt: ag.plzOrt,
```

- [ ] **Step 6: Analyze + alle Tests**

Run: `cd sbs_projer_app && flutter analyze && flutter test`
Expected: 0 Errors; alle Tests grün. (Falls `_agNameCtrl` o.ä. noch referenziert wird, meldet analyze es — restlos entfernen.)

- [ ] **Step 7: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/buchhaltung/lohn_einstellungen_screen.dart
git commit -m "feat(lohn): Arbeitgeber aus Geschäft (Snapshot), Arbeitnehmer-Prefill"
```

---

## Task 8: Report-Mail-Empfänger aus Geschäft

**Files:**
- Modify: `sbs_projer_app/lib/services/mail/bericht_mail_service.dart`
- Modify: `sbs_projer_app/lib/presentation/screens/buchhaltung/berichte_screen.dart`

- [ ] **Step 1: `BerichtMailService.send` mit `to`-Parameter.** Datei ersetzen:

```dart
// lib/services/mail/bericht_mail_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class BerichtMailService {
  /// Fallback, falls kein Empfänger ermittelbar.
  static const fallbackEmpfaenger = 'dani.proyer@gmail.com';

  static Future<void> send({
    required String to,
    required String subject,
    required String bodyText,
    required String filename,
    required Uint8List pdf,
  }) async {
    await SupabaseService.client.functions.invoke('send-pdf-mail', body: {
      'to': to,
      'subject': subject,
      'bodyText': bodyText,
      'filename': filename,
      'pdfBase64': base64Encode(pdf),
    });
  }
}
```

- [ ] **Step 2: `berichte_screen.dart` Empfänger aus Geschäft.** Import ergänzen:

```dart
import 'package:sbs_projer_app/presentation/providers/geschaeft_providers.dart';
```

In `_mail()` den Empfänger ermitteln und verwenden — zu Beginn der Methode:

```dart
    final geschaeft = ref.read(geschaeftProvider).valueOrNull;
    final empfaenger = geschaeft?.mailEmpfaenger ?? BerichtMailService.fallbackEmpfaenger;
```

Im Bestätigungsdialog `BerichtMailService.empfaenger` → `empfaenger` ersetzen; der Versand:

```dart
      await BerichtMailService.send(
        to: empfaenger,
        subject: '$was SBS Projer GmbH',
        bodyText: 'Im Anhang die $was.\n\nSBS Projer GmbH',
        filename: filename,
        pdf: bytes,
      );
```

und die SnackBar-Erfolgsmeldung auf `empfaenger` umstellen.

- [ ] **Step 3: Analyze**

Run: `cd sbs_projer_app && flutter analyze lib/services/mail/bericht_mail_service.dart lib/presentation/screens/buchhaltung/berichte_screen.dart`
Expected: keine Errors.

- [ ] **Step 4: Commit**

```bash
git add sbs_projer_app/lib/services/mail/bericht_mail_service.dart sbs_projer_app/lib/presentation/screens/buchhaltung/berichte_screen.dart
git commit -m "feat(berichte): Report-Mail-Empfänger aus Geschäft (Fallback)"
```

---

## Task 9: Bericht-PDF-Briefkopf aus Geschäft

**Files:**
- Modify: `sbs_projer_app/lib/services/pdf/bericht_pdf_common.dart`
- Modify: `sbs_projer_app/lib/services/pdf/bilanz_pdf_service.dart`
- Modify: `sbs_projer_app/lib/services/pdf/erfolgsrechnung_pdf_service.dart`
- Modify: `sbs_projer_app/lib/presentation/screens/buchhaltung/berichte_screen.dart`

- [ ] **Step 1: `kopf` nimmt Firma-Daten (Fallback Konstanten).** In `bericht_pdf_common.dart` die `kopf`-Signatur erweitern und Werte verwenden:

```dart
  static pw.Widget kopf(String titel, String periode,
          {String? firmaName, String? firmaStrasse, String? firmaOrt, String? mwstZeile}) =>
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(firmaName ?? firma,
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: dunkel)),
                pw.Text(firmaStrasse ?? strasse, style: const pw.TextStyle(fontSize: 9)),
                pw.Text(firmaOrt ?? ort, style: const pw.TextStyle(fontSize: 9)),
                if (mwstZeile != null && mwstZeile.isNotEmpty)
                  pw.Text(mwstZeile, style: const pw.TextStyle(fontSize: 9)),
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
```

- [ ] **Step 2: Firma in die PDF-Services durchreichen.** In `bilanz_pdf_service.dart` und `erfolgsrechnung_pdf_service.dart` je den Import ergänzen und der `generate(...)`-Signatur **optionale** Parameter `{String? firmaName, String? firmaStrasse, String? firmaOrt, String? mwstZeile}` geben; im `BerichtPdfCommon.kopf(...)`-Aufruf durchreichen. Beispiel (Bilanz):

```dart
  static Future<Uint8List> generate(BilanzDaten b, DateTime stichtag,
      {String? firmaName, String? firmaStrasse, String? firmaOrt, String? mwstZeile}) async {
    ...
          BerichtPdfCommon.kopf('Bilanz', 'per ${df.format(stichtag)}',
              firmaName: firmaName, firmaStrasse: firmaStrasse, firmaOrt: firmaOrt, mwstZeile: mwstZeile),
    ...
```

Gleiches für beide `kopf`-Aufrufe in `erfolgsrechnung_pdf_service.dart` (Seite 1 + „Kontenklassen").

- [ ] **Step 3: `berichte_screen.dart` übergibt Geschäft.** In `_pdf()` und `_mail()` vor der PDF-Erzeugung:

```dart
      final g = ref.read(geschaeftProvider).valueOrNull;
```

und bei **jedem** `BilanzPdfService.generate(...)` / `ErfolgsrechnungPdfService.generate(...)`-Aufruf ergänzen:

```dart
        firmaName: g?.firma, firmaStrasse: g?.adresseStrasse, firmaOrt: g?.adressePlzOrt, mwstZeile: g?.mwstZeile,
```

(`geschaeftProvider` ist seit Task 8 importiert.)

- [ ] **Step 4: Analyze**

Run: `cd sbs_projer_app && flutter analyze lib/services/pdf/bericht_pdf_common.dart lib/services/pdf/bilanz_pdf_service.dart lib/services/pdf/erfolgsrechnung_pdf_service.dart lib/presentation/screens/buchhaltung/berichte_screen.dart`
Expected: keine Errors.

- [ ] **Step 5: PDF-Smoke-Test prüfen.** `cd sbs_projer_app && flutter test test/services/pdf/erfolgsrechnung_pdf_test.dart` (bestehender Test bleibt grün; generate ohne Firma-Param = Fallback).

- [ ] **Step 6: Commit**

```bash
git add sbs_projer_app/lib/services/pdf/bericht_pdf_common.dart sbs_projer_app/lib/services/pdf/bilanz_pdf_service.dart sbs_projer_app/lib/services/pdf/erfolgsrechnung_pdf_service.dart sbs_projer_app/lib/presentation/screens/buchhaltung/berichte_screen.dart
git commit -m "feat(pdf): Bericht-Briefkopf aus Geschäft (Fallback Konstanten)"
```

---

## Task 10: Kundenrechnung-PDF — Firmenkopf aus Geschäft (QR/IBAN unverändert)

**Files:**
- Modify: `sbs_projer_app/lib/services/pdf/rechnung_pdf_service.dart`
- Modify (4 Aufrufstellen): `services/rechnung/rechnung_service.dart:112`, `services/rechnung/jahresrechnung_service.dart:213`, `presentation/screens/buchhaltung/rechnungen_nachversand_screen.dart:243`, `presentation/screens/rechnungen/rechnung_detail_screen.dart:336`

**WICHTIG:** Nur der **angezeigte Briefkopf** (`_buildHeader`) darf die neuen Firma-Werte nutzen. IBAN, QR-Zahlteil (`_buildQrZahlteil`) und Zahlungsangaben bleiben **unverändert** auf den Konstanten.

- [ ] **Step 1: Optionale Firma-Parameter an `generate`.** In `rechnung_pdf_service.dart` `RechnungPdfService.generate(...)` zusätzliche optionale benannte Parameter geben (Default `null` → Konstante):

```dart
  static Future<Uint8List> generate({
    required Rechnung rechnung,
    required List<RechnungsPosition> positionen,
    required BetriebLocal betrieb,
    BetriebRechnungsadresse? rechnungsadresse,
    String? mitteilung,
    String? firmaName,
    String? firmaStrasse,
    String? firmaPlzOrt,
    String? firmaMwst,
  }) async {
```

Zuerst `_buildHeader` lesen, dann **nur dort** die Firmen-Anzeige auf die Parameter umstellen mit Fallback auf die bestehenden Konstanten, z. B. `firmaName ?? _firmaName`, `firmaStrasse ?? '$_firmaStrasse $_firmaNr'`, `firmaPlzOrt ?? '$_firmaPlz $_firmaOrt'`, und optional `firmaMwst` als zusätzliche Kopfzeile, falls nicht leer. `_buildHeader` muss dafür die Werte als Argumente erhalten (Signatur entsprechend erweitern). **`_buildQrZahlteil` und alle QR-/IBAN-Stellen NICHT anfassen.**

- [ ] **Step 2: Aufrufstellen — Geschäft laden und übergeben.**
  - In `rechnung_service.dart` und `jahresrechnung_service.dart` (beides Services): vor dem `RechnungPdfService.generate(...)` `final g = await GeschaeftRepository.get();` (Import ergänzen) und ergänzen: `firmaName: g.firma, firmaStrasse: g.adresseStrasse, firmaPlzOrt: g.adressePlzOrt, firmaMwst: g.mwstZeile,`.
  - In `rechnungen_nachversand_screen.dart` und `rechnung_detail_screen.dart` (ConsumerWidgets): `final g = ref.read(geschaeftProvider).valueOrNull;` (Import ergänzen) und die gleichen vier Parameter mit `g?.firma` etc. (bei `null` greift der Default).

- [ ] **Step 3: Analyze + alle Tests**

Run: `cd sbs_projer_app && flutter analyze && flutter test`
Expected: 0 Errors; alle Tests grün. (Da das Geschäft mit den heutigen Konstanten geseedet ist, bleibt die erzeugte Rechnung byte-gleich.)

- [ ] **Step 4: Commit**

```bash
git add sbs_projer_app/lib/services/pdf/rechnung_pdf_service.dart sbs_projer_app/lib/services/rechnung/rechnung_service.dart sbs_projer_app/lib/services/rechnung/jahresrechnung_service.dart sbs_projer_app/lib/presentation/screens/buchhaltung/rechnungen_nachversand_screen.dart sbs_projer_app/lib/presentation/screens/rechnungen/rechnung_detail_screen.dart
git commit -m "feat(rechnung): Firmenkopf aus Geschäft (QR/IBAN unverändert)"
```

---

## Task 11: Gesamt-Verifikation + Deploy

**Files:** keine Code-Änderung.

- [ ] **Step 1: Voll-Analyse + Tests**

Run: `cd sbs_projer_app && flutter analyze && flutter test`
Expected: 0 Errors; alle Tests grün.

- [ ] **Step 2: Manueller Klicktest (Web)**

`cd sbs_projer_app && flutter run -d edge`. Prüfen:
- Einstellungen → „Geschäft" erfassen/speichern; „Lohn-Einstellungen" öffnet `/buchhaltung/lohn`.
- Lohn: kein AG-Eingabeblock, AG-Info aus Geschäft; AN-Felder vorbefüllt; Speichern ok; Lohnausweis-PDF zeigt AG korrekt.
- Bilanz/ER → PDF-Briefkopf zeigt Geschäfts-Firma; Mail-Dialog zeigt Geschäfts-/GF-Mail.
- Eine Kundenrechnung (Detail) → PDF unverändert inkl. QR.

- [ ] **Step 3: Version bump + Deploy** (gemäss `CLAUDE.md`): `pubspec.yaml` Zeile 4 erhöhen, Build, Cache-Bust, gh-pages-Deploy. (Deploy nach Freigabe durch Daniel.)

---

## Self-Review (vom Plan-Autor)

- **Spec-Abdeckung:** Geschäft-Tabelle/Model/Repo/Provider (T1–T3) ✓; Mapping (T4) ✓; Geschäft-UI (T5) + Settings-Reorg (T6) ✓; Lohn AG-aus-Geschäft + AN-Prefill (T7) ✓; Report-Mail (T8) ✓; Bericht-PDF (T9) ✓; Rechnung-PDF konservativ (T10) ✓; Fallback/Default-Zeile durchgängig (T1 Seed, T2 Getter) ✓; Tests reine Logik (T2, T4) ✓.
- **Typ-Konsistenz:** `GeschaeftEinstellungen` Getter (`firma`/`adresseStrasse`/`adressePlzOrt`/`mailEmpfaenger`/`mwstZeile`/`gfVollname`) einheitlich in T4/T7/T8/T9/T10; `AnFelder`-Record + `GeschaeftMapping.arbeitnehmerPrefill`/`arbeitgeber` konsistent (T4→T7); `geschaeftProvider` (T3) in T6/T7/T8/T9/T10; `BerichtMailService.send(to:)` (T8) im berichte_screen genutzt.
- **Kompilierbarkeit/Reihenfolge:** Foundation (T1–T4) zuerst; UI/Wiring danach; jeder Task committet eigenständig. Optionale Parameter mit Default = Konstante → kein Bruch an nicht angepassten Aufrufstellen.
- **Risiko T10:** klar isoliert (nur `_buildHeader`, QR/IBAN unangetastet, Seed = Konstanten → byte-gleich); bei Bedarf deferrierbar, ohne T1–T9 zu beeinträchtigen.
```

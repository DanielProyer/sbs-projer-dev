# Material abgeholt → Bestände in einem Klick — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Nach dem Abholen einer Materialbestellung bei Heineken werden alle Lager-Bestände über eine Kontroll-Liste mit einem Klick nachgeführt (mit Rückgängig).

**Architecture:** Zwei atomare Postgres-RPCs (relatives `bestand_aktuell + delta`, Status-Guard) statt einer Update-Schleife — dadurch kein Teilausfall/Doppelzählen. Darüber eine neue Bestellungen-Liste (`/materialien/bestellungen`) mit Kontroll-Dialog; die Auswahl-Logik liegt in einer reinen, TDD-getesteten Funktion.

**Tech Stack:** Flutter (Material 3) + Riverpod + GoRouter, Supabase (Postgres RPC, RLS via SECURITY INVOKER), url_launcher.

**Spec:** `docs/superpowers/specs/2026-07-15-material-abgeholt-bestand-design.md`

---

## File Structure

| Datei | Verantwortung |
|---|---|
| `Datenbank/migrations/141_material_abgeholt.sql` | **Create** — Status `abgeholt`, `abgeholt_am`, `menge_erhalten`, 2 RPCs |
| `sbs_projer_app/lib/data/models/material_bestellung.dart` | **Modify** — DTO um `abgeholtAm` / `mengeErhalten` |
| `sbs_projer_app/lib/core/util/bestand_buchung.dart` | **Create** — reine Logik: `istBuchbar`, `abholPayload`, `positionenNachKategorie` |
| `sbs_projer_app/test/bestand_buchung_test.dart` | **Create** — TDD dazu |
| `sbs_projer_app/lib/data/repositories/material_bestellung_repository.dart` | **Modify** — `abholen` / `abholungRueckgaengig` (RPC) |
| `sbs_projer_app/lib/presentation/screens/materialien/widgets/abhol_dialog.dart` | **Create** — Kontroll-Dialog (nach Kategorie gruppiert) |
| `sbs_projer_app/lib/presentation/screens/materialien/material_bestellungen_screen.dart` | **Create** — Bestellungen-Liste |
| `sbs_projer_app/lib/core/config/router.dart` | **Modify** — Route `/materialien/bestellungen` |
| `sbs_projer_app/lib/presentation/screens/materialien/materialien_list_screen.dart` | **Modify** — AppBar-Action |

**Unverändert:** `material_bestellung_screen.dart` (Erfassungs-Wizard).

---

### Task 1: Migration 141 — Schema + atomare RPCs

**Files:**
- Create: `Datenbank/migrations/141_material_abgeholt.sql`

- [ ] **Step 1: Migrationsdatei schreiben**

```sql
-- Migration 141: Material abgeholt → Bestände in einem Klick
--
-- Status-Flow neu: entwurf → gesendet → abgeholt (storniert bleibt).
-- Die Buchung läuft über zwei RPCs in EINER Transaktion mit RELATIVEM Update
-- (bestand_aktuell + delta). Grund: eine client-seitige Schleife könnte nach
-- halbem Durchlauf abbrechen → einige Bestände erhöht, Status noch 'gesendet'
-- → der zweite Klick würde doppelt zählen (stiller Lagerfehler).
-- SECURITY INVOKER: die bestehenden RLS-Policies (user_isolation) greifen.

ALTER TABLE material_bestellungen DROP CONSTRAINT IF EXISTS material_bestellungen_status_check;
ALTER TABLE material_bestellungen ADD CONSTRAINT material_bestellungen_status_check
  CHECK (status IN ('entwurf','gesendet','abgeholt','storniert'));

ALTER TABLE material_bestellungen     ADD COLUMN IF NOT EXISTS abgeholt_am date;
ALTER TABLE material_bestellpositionen ADD COLUMN IF NOT EXISTS menge_erhalten numeric;

-- Bucht die Abholung atomar. p_mengen: {"<positionId>": <menge>, …}
CREATE OR REPLACE FUNCTION material_bestellung_abholen(
  p_bestellung_id uuid, p_mengen jsonb)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER AS $$
DECLARE r record;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM material_bestellungen
                 WHERE id = p_bestellung_id AND status = 'gesendet') THEN
    RAISE EXCEPTION 'Bestellung ist nicht im Status "gesendet" (bereits gebucht?)';
  END IF;

  FOR r IN SELECT p.id, p.lager_id, (p_mengen ->> p.id::text)::numeric AS menge
           FROM material_bestellpositionen p
           WHERE p.bestellung_id = p_bestellung_id
             AND p.lager_id IS NOT NULL
             AND (p_mengen ->> p.id::text)::numeric > 0
  LOOP
    -- Relativ: mehrere Positionen auf denselben Lager-Artikel summieren sich
    -- dadurch automatisch korrekt.
    UPDATE lager SET bestand_aktuell = bestand_aktuell + r.menge WHERE id = r.lager_id;
    UPDATE material_bestellpositionen SET menge_erhalten = r.menge WHERE id = r.id;
  END LOOP;

  UPDATE material_bestellungen
     SET status = 'abgeholt', abgeholt_am = CURRENT_DATE, updated_at = now()
   WHERE id = p_bestellung_id;
END; $$;

-- Macht die Abholung atomar rückgängig.
CREATE OR REPLACE FUNCTION material_bestellung_abholung_rueckgaengig(
  p_bestellung_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER AS $$
DECLARE r record;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM material_bestellungen
                 WHERE id = p_bestellung_id AND status = 'abgeholt') THEN
    RAISE EXCEPTION 'Bestellung ist nicht im Status "abgeholt"';
  END IF;

  FOR r IN SELECT p.id, p.lager_id, p.menge_erhalten AS menge
           FROM material_bestellpositionen p
           WHERE p.bestellung_id = p_bestellung_id
             AND p.lager_id IS NOT NULL
             AND p.menge_erhalten IS NOT NULL
  LOOP
    -- Klemmung bei 0: negativer Bestand ist fachlich unsinnig (falls seit dem
    -- Buchen bereits Material verbraucht wurde).
    UPDATE lager SET bestand_aktuell = GREATEST(0, bestand_aktuell - r.menge)
     WHERE id = r.lager_id;
    UPDATE material_bestellpositionen SET menge_erhalten = NULL WHERE id = r.id;
  END LOOP;

  UPDATE material_bestellungen
     SET status = 'gesendet', abgeholt_am = NULL, updated_at = now()
   WHERE id = p_bestellung_id;
END; $$;
```

- [ ] **Step 2: Migration auf Prod anwenden**

Nutze `mcp__supabase__apply_migration` mit `project_id: pltbaqqwpnmdajwgnhpd`, `name: 141_material_abgeholt`, `query` = exakt der SQL-Inhalt aus Step 1.
Erwartet: `{"success": true}`

- [ ] **Step 3: Schema verifizieren**

Führe via `mcp__supabase__execute_sql` aus:

```sql
SELECT
  (SELECT pg_get_constraintdef(oid) FROM pg_constraint
     WHERE conrelid='public.material_bestellungen'::regclass AND conname='material_bestellungen_status_check') AS status_check,
  (SELECT COUNT(*) FROM information_schema.columns
     WHERE table_name='material_bestellungen' AND column_name='abgeholt_am') AS hat_abgeholt_am,
  (SELECT COUNT(*) FROM information_schema.columns
     WHERE table_name='material_bestellpositionen' AND column_name='menge_erhalten') AS hat_menge_erhalten,
  (SELECT COUNT(*) FROM pg_proc WHERE proname IN
     ('material_bestellung_abholen','material_bestellung_abholung_rueckgaengig')) AS anz_rpcs;
```

Erwartet: `status_check` enthält `'abgeholt'`, `hat_abgeholt_am=1`, `hat_menge_erhalten=1`, `anz_rpcs=2`.

- [ ] **Step 4: RPCs gegen eine echte Bestellung verifizieren (kritisch — Buchhaltung/Lager)**

Merke dir zuerst den Ausgangszustand einer `gesendet`-Bestellung:

```sql
SELECT b.id AS bestellung_id, b.bestell_nr, b.status,
       p.id AS position_id, p.name, p.menge, p.lager_id,
       l.bestand_aktuell AS bestand_vorher
FROM material_bestellungen b
JOIN material_bestellpositionen p ON p.bestellung_id = b.id
LEFT JOIN lager l ON l.id = p.lager_id
WHERE b.status = 'gesendet'
ORDER BY b.datum DESC, p.sortierung
LIMIT 5;
```

Buchen (ersetze `<bestellung_id>` und baue `p_mengen` aus zwei `position_id`s der Liste):

```sql
SELECT material_bestellung_abholen('<bestellung_id>'::uuid,
  '{"<position_id_1>": 2, "<position_id_2>": 3}'::jsonb);
```

Prüfen: Bestände sind um genau 2 bzw. 3 gestiegen, `menge_erhalten` gesetzt, Status `abgeholt`, `abgeholt_am` = heute.
Doppelbuchungs-Schutz prüfen — denselben Aufruf **nochmal** absetzen:
Erwartet: **Exception** „Bestellung ist nicht im Status "gesendet" (bereits gebucht?)" und **keine** Bestandsänderung.

Rückgängig:

```sql
SELECT material_bestellung_abholung_rueckgaengig('<bestellung_id>'::uuid);
```

Erwartet: Bestände exakt wie `bestand_vorher`, `menge_erhalten` NULL, Status `gesendet`, `abgeholt_am` NULL.
**Erst wenn alle drei Prüfungen stimmen, weiter.**

- [ ] **Step 5: Commit**

```bash
git add Datenbank/migrations/141_material_abgeholt.sql
git commit -m "feat(material): Migration 141 — Status abgeholt + atomare Abhol-RPCs"
```

---

### Task 2: DTO um `abgeholtAm` / `mengeErhalten` erweitern

**Files:**
- Modify: `sbs_projer_app/lib/data/models/material_bestellung.dart`

- [ ] **Step 1: `MaterialBestellung` erweitern**

Feld nach `final String? notizen;` ergänzen:

```dart
  final DateTime? abgeholtAm;
```

Konstruktor-Parameter nach `this.notizen,` ergänzen:

```dart
    this.abgeholtAm,
```

In `fromJson` nach `notizen: json['notizen'],` ergänzen:

```dart
      abgeholtAm: json['abgeholt_am'] != null
          ? DateTime.parse(json['abgeholt_am'])
          : null,
```

In `toJson` nach `'notizen': notizen,` ergänzen:

```dart
      'abgeholt_am': abgeholtAm?.toIso8601String().substring(0, 10),
```

- [ ] **Step 2: `MaterialBestellposition` erweitern**

Feld nach `final double? bestandOptimal;` ergänzen:

```dart
  /// Tatsächlich erhaltene Menge (null = noch nicht abgeholt/gebucht).
  final double? mengeErhalten;
```

Konstruktor-Parameter nach `this.bestandOptimal,` ergänzen:

```dart
    this.mengeErhalten,
```

In `fromJson` nach dem `bestandOptimal:`-Block ergänzen:

```dart
      mengeErhalten: json['menge_erhalten'] != null
          ? double.tryParse(json['menge_erhalten'].toString())
          : null,
```

In `toJson` nach `'bestand_optimal': bestandOptimal,` ergänzen:

```dart
      'menge_erhalten': mengeErhalten,
```

- [ ] **Step 3: Analyze**

Run: `export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter analyze lib/data/models/material_bestellung.dart`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add sbs_projer_app/lib/data/models/material_bestellung.dart
git commit -m "feat(material): DTO um abgeholtAm + mengeErhalten erweitert"
```

---

### Task 3: Reine Funktionen `bestand_buchung.dart` (TDD)

**Files:**
- Create: `sbs_projer_app/lib/core/util/bestand_buchung.dart`
- Test: `sbs_projer_app/test/bestand_buchung_test.dart`

- [ ] **Step 1: Failing Test schreiben**

Erstelle `sbs_projer_app/test/bestand_buchung_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/bestand_buchung.dart';
import 'package:sbs_projer_app/data/models/material_bestellung.dart';

MaterialBestellposition _pos({
  required String id,
  String? lagerId,
  String? kategorieName,
  double menge = 1,
  int sortierung = 0,
  String name = 'Artikel',
}) =>
    MaterialBestellposition(
      id: id,
      bestellungId: 'b1',
      lagerId: lagerId,
      name: name,
      menge: menge,
      kategorieName: kategorieName,
      sortierung: sortierung,
    );

void main() {
  group('istBuchbar', () {
    test('mit lagerId → true', () {
      expect(istBuchbar(_pos(id: 'p1', lagerId: 'l1')), isTrue);
    });

    test('ohne lagerId (Freitext) → false', () {
      expect(istBuchbar(_pos(id: 'p1')), isFalse);
    });

    test('leere lagerId → false', () {
      expect(istBuchbar(_pos(id: 'p1', lagerId: '')), isFalse);
    });
  });

  group('abholPayload', () {
    test('buchbare Position mit Menge > 0 → im Payload', () {
      final payload = abholPayload(
        positionen: [_pos(id: 'p1', lagerId: 'l1')],
        mengen: {'p1': 3},
      );
      expect(payload, {'p1': 3.0});
    });

    test('Position ohne lagerId → nicht im Payload', () {
      final payload = abholPayload(
        positionen: [_pos(id: 'p1')],
        mengen: {'p1': 3},
      );
      expect(payload, isEmpty);
    });

    test('Menge fehlt / 0 / negativ → nicht im Payload', () {
      final positionen = [
        _pos(id: 'p1', lagerId: 'l1'),
        _pos(id: 'p2', lagerId: 'l2'),
        _pos(id: 'p3', lagerId: 'l3'),
      ];
      final payload = abholPayload(
        positionen: positionen,
        mengen: {'p2': 0, 'p3': -5},
      );
      expect(payload, isEmpty);
    });

    test('mehrere Positionen auf dasselbe Lager bleiben getrennt (Positions-Bezug)', () {
      final payload = abholPayload(
        positionen: [
          _pos(id: 'p1', lagerId: 'l1'),
          _pos(id: 'p2', lagerId: 'l1'),
        ],
        mengen: {'p1': 2, 'p2': 3},
      );
      expect(payload, {'p1': 2.0, 'p2': 3.0});
    });

    test('leere Eingabe → leere Map', () {
      expect(abholPayload(positionen: [], mengen: {}), isEmpty);
    });
  });

  group('positionenNachKategorie', () {
    test('gruppiert nach Kategorie, Reihenfolge des ersten Auftretens', () {
      final gruppen = positionenNachKategorie([
        _pos(id: 'p1', kategorieName: 'Reinigungsmaterial'),
        _pos(id: 'p2', kategorieName: 'Verbrauchsmaterial'),
        _pos(id: 'p3', kategorieName: 'Reinigungsmaterial'),
      ]);
      expect(gruppen.map((g) => g.name).toList(),
          ['Reinigungsmaterial', 'Verbrauchsmaterial']);
      expect(gruppen.first.positionen.map((p) => p.id).toList(), ['p1', 'p3']);
    });

    test('Positionen ohne Kategorie landen in „Übrige" ganz am Schluss', () {
      final gruppen = positionenNachKategorie([
        _pos(id: 'p1'),
        _pos(id: 'p2', kategorieName: 'Reinigungsmaterial'),
      ]);
      expect(gruppen.map((g) => g.name).toList(), ['Reinigungsmaterial', 'Übrige']);
      expect(gruppen.last.positionen.single.id, 'p1');
    });

    test('leere Liste → leer', () {
      expect(positionenNachKategorie([]), isEmpty);
    });
  });
}
```

- [ ] **Step 2: Test laufen lassen — muss fehlschlagen**

Run: `export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter test test/bestand_buchung_test.dart`
Expected: FAIL — „Target of URI doesn't exist: 'package:sbs_projer_app/core/util/bestand_buchung.dart'"

- [ ] **Step 3: Implementierung schreiben**

Erstelle `sbs_projer_app/lib/core/util/bestand_buchung.dart`:

```dart
import 'package:sbs_projer_app/data/models/material_bestellung.dart';

/// Eine Kategorie-Gruppe für den Abhol-Dialog (gleiche Gliederung wie das
/// Bestell-PDF).
class KategorieGruppe {
  final String name;
  final List<MaterialBestellposition> positionen;
  const KategorieGruppe({required this.name, required this.positionen});
}

/// Sammelname für Positionen ohne Kategorie.
const String kUebrigeKategorie = 'Übrige';

/// True, wenn die Position auf einen Lager-Artikel gebucht werden kann.
/// Freitext-Positionen ohne `lagerId` haben keinen Lager-Bezug.
bool istBuchbar(MaterialBestellposition p) =>
    p.lagerId != null && p.lagerId!.isNotEmpty;

/// Filtert die im Kontroll-Dialog erfassten Mengen auf die tatsächlich
/// buchbaren Positionen — die Nutzlast (`p_mengen`) für die Abhol-RPC.
///
/// [mengen]: positionId → erhaltene Menge. Fehlt der Eintrag oder ist er <= 0,
/// gilt die Position als „nicht erhalten" und wird übersprungen.
///
/// Bewusst **positionId-basiert**: die RPC schreibt `menge_erhalten` pro
/// Position und bucht relativ — mehrere Positionen auf denselben Lager-Artikel
/// summieren sich dort automatisch korrekt.
Map<String, double> abholPayload({
  required List<MaterialBestellposition> positionen,
  required Map<String, double> mengen,
}) {
  final payload = <String, double>{};
  for (final p in positionen) {
    if (!istBuchbar(p)) continue;
    final menge = mengen[p.id];
    if (menge == null || menge <= 0) continue;
    payload[p.id] = menge;
  }
  return payload;
}

/// Gruppiert die Positionen nach `kategorieName` — Gruppen in der Reihenfolge
/// ihres ersten Auftretens (= Reihenfolge der Bestellung), innerhalb der Gruppe
/// die eingehende Reihenfolge. Positionen ohne Kategorie kommen als „Übrige"
/// ganz am Schluss.
List<KategorieGruppe> positionenNachKategorie(
    List<MaterialBestellposition> positionen) {
  final nachName = <String, List<MaterialBestellposition>>{};
  final uebrige = <MaterialBestellposition>[];
  for (final p in positionen) {
    final kat = p.kategorieName;
    if (kat == null || kat.isEmpty) {
      uebrige.add(p);
    } else {
      nachName.putIfAbsent(kat, () => []).add(p);
    }
  }
  final gruppen = nachName.entries
      .map((e) => KategorieGruppe(name: e.key, positionen: e.value))
      .toList();
  if (uebrige.isNotEmpty) {
    gruppen.add(KategorieGruppe(name: kUebrigeKategorie, positionen: uebrige));
  }
  return gruppen;
}
```

- [ ] **Step 4: Test laufen lassen — muss grün sein**

Run: `export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter test test/bestand_buchung_test.dart`
Expected: `All tests passed!` (12 Tests)

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/core/util/bestand_buchung.dart sbs_projer_app/test/bestand_buchung_test.dart
git commit -m "feat(material): reine Abhol-Logik (Payload + Kategorie-Gruppierung) mit TDD"
```

---

### Task 4: Repository — `abholen` / `abholungRueckgaengig`

**Files:**
- Modify: `sbs_projer_app/lib/data/repositories/material_bestellung_repository.dart`

- [ ] **Step 1: RPC-Methoden ergänzen**

Nach der Methode `updateStatus` einfügen:

```dart
  /// Bucht die Abholung **atomar** (Bestände +, `menge_erhalten`, Status
  /// 'abgeholt'). [mengen]: positionId → erhaltene Menge (aus `abholPayload`).
  /// Wirft, wenn die Bestellung nicht im Status 'gesendet' ist — dann wurde
  /// nichts geschrieben (Transaktion).
  static Future<void> abholen(
      String bestellungId, Map<String, double> mengen) async {
    await SupabaseService.client.rpc('material_bestellung_abholen', params: {
      'p_bestellung_id': bestellungId,
      'p_mengen': mengen,
    });
  }

  /// Macht die Abholung **atomar** rückgängig (Bestände −, `menge_erhalten`
  /// gelöscht, Status zurück auf 'gesendet').
  static Future<void> abholungRueckgaengig(String bestellungId) async {
    await SupabaseService.client.rpc(
      'material_bestellung_abholung_rueckgaengig',
      params: {'p_bestellung_id': bestellungId},
    );
  }
```

- [ ] **Step 2: Analyze**

Run: `export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter analyze lib/data/repositories/material_bestellung_repository.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add sbs_projer_app/lib/data/repositories/material_bestellung_repository.dart
git commit -m "feat(material): Repository-Methoden abholen + abholungRueckgaengig (RPC)"
```

---

### Task 5: Kontroll-Dialog `abhol_dialog.dart`

**Files:**
- Create: `sbs_projer_app/lib/presentation/screens/materialien/widgets/abhol_dialog.dart`

- [ ] **Step 1: Dialog schreiben**

Erstelle die Datei:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/bestand_buchung.dart';
import 'package:sbs_projer_app/data/models/material_bestellung.dart';

/// Kontroll-Dialog „Material abgeholt": Positionen nach Kategorie gruppiert,
/// Mengen mit der Bestellmenge vorbefüllt und korrigierbar, Zeilen abwählbar.
///
/// Liefert das RPC-Payload (positionId → Menge) oder null bei Abbruch.
Future<Map<String, double>?> zeigeAbholDialog(
  BuildContext context, {
  required MaterialBestellung bestellung,
  required List<MaterialBestellposition> positionen,
}) {
  return showDialog<Map<String, double>>(
    context: context,
    builder: (_) => _AbholDialog(bestellung: bestellung, positionen: positionen),
  );
}

class _AbholDialog extends StatefulWidget {
  final MaterialBestellung bestellung;
  final List<MaterialBestellposition> positionen;
  const _AbholDialog({required this.bestellung, required this.positionen});

  @override
  State<_AbholDialog> createState() => _AbholDialogState();
}

class _AbholDialogState extends State<_AbholDialog> {
  final _dateFormat = DateFormat('dd.MM.yyyy');
  final _gewaehlt = <String>{};
  final _controller = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    for (final p in widget.positionen) {
      if (!istBuchbar(p)) continue;
      _gewaehlt.add(p.id); // default: erhalten
      _controller[p.id] =
          TextEditingController(text: p.menge.toStringAsFixed(0));
    }
  }

  @override
  void dispose() {
    for (final c in _controller.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, double> get _payload {
    final mengen = <String, double>{};
    for (final id in _gewaehlt) {
      final val = double.tryParse(_controller[id]?.text ?? '');
      if (val != null) mengen[id] = val;
    }
    return abholPayload(positionen: widget.positionen, mengen: mengen);
  }

  @override
  Widget build(BuildContext context) {
    final gruppen = positionenNachKategorie(widget.positionen);
    final anzahl = _payload.length;
    return AlertDialog(
      title: Text('Material abgeholt — ${widget.bestellung.bestellNr}'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bestellung vom ${_dateFormat.format(widget.bestellung.datum)} — '
                'Mengen prüfen, dann buchen.',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              for (final g in gruppen) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(g.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ),
                ),
                for (final p in g.positionen) _zeile(p),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed:
              anzahl == 0 ? null : () => Navigator.pop(context, _payload),
          child: Text('Bestände buchen ($anzahl)'),
        ),
      ],
    );
  }

  Widget _zeile(MaterialBestellposition p) {
    final buchbar = istBuchbar(p);
    final nr = p.sapNr ?? p.dboNr;
    if (!buchbar) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            const SizedBox(width: 40),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      style: TextStyle(
                          fontSize: 14, color: AppColors.textSecondary)),
                  const Text('kein Lager-Bezug — wird nicht gebucht',
                      style: TextStyle(
                          fontSize: 11, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: _gewaehlt.contains(p.id),
      onChanged: (sel) => setState(() {
        if (sel == true) {
          _gewaehlt.add(p.id);
        } else {
          _gewaehlt.remove(p.id);
        }
      }),
      title: Text(nr != null ? '$nr – ${p.name}' : p.name,
          style: const TextStyle(fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      subtitle: Text('bestellt: ${p.menge.toStringAsFixed(0)} ${p.einheit}',
          style: const TextStyle(fontSize: 11)),
      secondary: SizedBox(
        width: 64,
        height: 40,
        child: TextFormField(
          controller: _controller[p.id],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            isDense: true,
          ),
          onChanged: (_) => setState(() {}), // Zähler im Button aktualisieren
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Analyze**

Run: `export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter analyze lib/presentation/screens/materialien/widgets/abhol_dialog.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/materialien/widgets/abhol_dialog.dart
git commit -m "feat(material): Kontroll-Dialog Material abgeholt (nach Kategorie gruppiert)"
```

---

### Task 6: Bestellungen-Liste + Route + Einstieg

**Files:**
- Create: `sbs_projer_app/lib/presentation/screens/materialien/material_bestellungen_screen.dart`
- Modify: `sbs_projer_app/lib/core/config/router.dart:535` (nach der `/materialien/bestellen`-Route)
- Modify: `sbs_projer_app/lib/presentation/screens/materialien/materialien_list_screen.dart:76-82` (AppBar-actions)

- [ ] **Step 1: Screen schreiben**

Erstelle `sbs_projer_app/lib/presentation/screens/materialien/material_bestellungen_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/material_bestellung.dart';
import 'package:sbs_projer_app/data/repositories/material_bestellung_repository.dart';
import 'package:sbs_projer_app/presentation/providers/material_providers.dart';
import 'package:sbs_projer_app/presentation/screens/materialien/widgets/abhol_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

/// Liste aller Materialbestellungen mit Status, Bestell-PDF und der
/// Abhol-Buchung („Material abgeholt" / „Buchung rückgängig").
class MaterialBestellungenScreen extends ConsumerStatefulWidget {
  const MaterialBestellungenScreen({super.key});

  @override
  ConsumerState<MaterialBestellungenScreen> createState() =>
      _MaterialBestellungenScreenState();
}

class _MaterialBestellungenScreenState
    extends ConsumerState<MaterialBestellungenScreen> {
  final _dateFormat = DateFormat('dd.MM.yyyy');
  bool _loading = true;
  bool _busy = false;
  List<MaterialBestellung> _bestellungen = [];
  final _positionen = <String, List<MaterialBestellposition>>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await MaterialBestellungRepository.getAll();
      if (!mounted) return;
      setState(() {
        _bestellungen = list;
        _positionen.clear();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Fehler beim Laden: $e')));
    }
  }

  Future<List<MaterialBestellposition>> _ladePositionen(String id) async {
    final cached = _positionen[id];
    if (cached != null) return cached;
    final list = await MaterialBestellungRepository.getPositionen(id);
    _positionen[id] = list;
    return list;
  }

  Future<void> _oeffnePdf(MaterialBestellung b) async {
    final pfad = b.pdfStoragePath;
    if (pfad == null || pfad.isEmpty) return;
    try {
      final url = await MaterialBestellungRepository.getSignedPdfUrl(pfad);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('PDF konnte nicht geöffnet werden: $e')));
      }
    }
  }

  Future<void> _abholen(MaterialBestellung b) async {
    final positionen = await _ladePositionen(b.id);
    if (!mounted) return;
    final payload = await zeigeAbholDialog(context,
        bestellung: b, positionen: positionen);
    if (payload == null || payload.isEmpty) return;

    setState(() => _busy = true);
    try {
      await MaterialBestellungRepository.abholen(b.id, payload);
      ref.invalidate(materialienStreamProvider); // Bestände sind neu
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${payload.length} Artikel gebucht — Bestände aktualisiert.')));
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler beim Buchen: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rueckgaengig(MaterialBestellung b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buchung rückgängig?'),
        content: Text(
            'Die Bestände aus Bestellung ${b.bestellNr} werden wieder abgezogen '
            'und die Bestellung geht zurück auf „gesendet".'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Rückgängig')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await MaterialBestellungRepository.abholungRueckgaengig(b.id);
      ref.invalidate(materialienStreamProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Buchung rückgängig gemacht.')));
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bestellungen')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _bestellungen.isEmpty
              ? const Center(child: Text('Noch keine Bestellungen.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _bestellungen.length,
                    itemBuilder: (_, i) => _karte(_bestellungen[i]),
                  ),
                ),
    );
  }

  /// Karte einer Bestellung. Badge, PDF und der Aktions-Button liegen bewusst
  /// im **subtitle** (also ohne Aufklappen erreichbar) — „Material abgeholt"
  /// soll ein Klick sein. Das `Wrap` verhindert horizontales Scrollen auf dem
  /// Handy. Die Positionen sind das Aufklapp-Detail.
  Widget _karte(MaterialBestellung b) {
    final istGesendet = b.status == 'gesendet';
    final istAbgeholt = b.status == 'abgeholt';
    final hatPdf = b.pdfStoragePath != null && b.pdfStoragePath!.isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        title: Text('${b.bestellNr} · ${_dateFormat.format(b.datum)}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _badge(b),
              if (hatPdf)
                GestureDetector(
                  onTap: () => _oeffnePdf(b),
                  behavior: HitTestBehavior.opaque,
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.picture_as_pdf,
                        size: 15, color: AppColors.primary),
                    SizedBox(width: 3),
                    Text('PDF',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              if (istGesendet)
                _tapButton('Material abgeholt',
                    _busy ? null : () => _abholen(b), true),
              if (istAbgeholt)
                _tapButton('Buchung rückgängig',
                    _busy ? null : () => _rueckgaengig(b), false),
            ],
          ),
        ),
        onExpansionChanged: (offen) async {
          if (!offen || _positionen.containsKey(b.id)) return;
          await _ladePositionen(b.id);
          if (mounted) setState(() {});
        },
        children: _positionsZeilen(b),
      ),
    );
  }

  List<Widget> _positionsZeilen(MaterialBestellung b) {
    final positionen = _positionen[b.id];
    if (positionen == null) {
      return const [
        Padding(
          padding: EdgeInsets.all(16),
          child: Center(
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))),
        )
      ];
    }
    return positionen.map((p) {
      final erhalten = p.mengeErhalten;
      final abweichung = erhalten != null && erhalten != p.menge;
      return ListTile(
        dense: true,
        title: Text(p.name, style: const TextStyle(fontSize: 13)),
        trailing: Text(
          erhalten == null
              ? '${p.menge.toStringAsFixed(0)} ${p.einheit}'
              : 'bestellt ${p.menge.toStringAsFixed(0)} · '
                  'erhalten ${erhalten.toStringAsFixed(0)} ${p.einheit}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: abweichung ? FontWeight.w700 : FontWeight.normal,
            color: abweichung ? AppColors.warning : AppColors.textSecondary,
          ),
        ),
      );
    }).toList();
  }

  Widget _badge(MaterialBestellung b) {
    final (text, farbe) = switch (b.status) {
      'gesendet' => ('gesendet', AppColors.primary),
      'abgeholt' => (
          'abgeholt${b.abgeholtAm != null ? ' am ${_dateFormat.format(b.abgeholtAm!)}' : ''}',
          AppColors.success
        ),
      'storniert' => ('storniert', AppColors.error),
      _ => ('Entwurf', AppColors.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: farbe.withAlpha(30),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, color: farbe, fontWeight: FontWeight.w700)),
    );
  }

  /// Material-Buttons rendern im Material-Bereich unter CanvasKit teils nicht
  /// → GestureDetector-Pill (bestehendes Projekt-Muster).
  Widget _tapButton(String label, VoidCallback? onTap, bool primaer) {
    final farbe = primaer ? AppColors.primary : AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: onTap == null ? Colors.grey.shade300 : farbe,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }
}
```

- [ ] **Step 2: Route ergänzen**

In `sbs_projer_app/lib/core/config/router.dart` bei den Imports ergänzen:

```dart
import 'package:sbs_projer_app/presentation/screens/materialien/material_bestellungen_screen.dart';
```

Und die Route **direkt nach** der `/materialien/bestellen`-Route einfügen (⚠️ **muss vor `/materialien/:id` stehen**, sonst fängt `:id` das Wort „bestellungen" ab):

```dart
    GoRoute(
      path: '/materialien/bestellungen',
      builder: (context, state) => const MaterialBestellungenScreen(),
    ),
```

- [ ] **Step 3: AppBar-Action ergänzen**

In `sbs_projer_app/lib/presentation/screens/materialien/materialien_list_screen.dart` die `actions:`-Liste (aktuell nur der Warenkorb) ergänzen — die neue Action **vor** dem Warenkorb:

```dart
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'Bestellungen',
            onPressed: () => context.push('/materialien/bestellungen'),
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            tooltip: 'Materialbestellung',
            onPressed: () => context.push('/materialien/bestellen'),
          ),
        ],
```

- [ ] **Step 4: Analyze**

Run: `export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter analyze lib/presentation/screens/materialien/ lib/core/config/router.dart`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/materialien/material_bestellungen_screen.dart \
        sbs_projer_app/lib/core/config/router.dart \
        sbs_projer_app/lib/presentation/screens/materialien/materialien_list_screen.dart
git commit -m "feat(material): Bestellungen-Liste mit Abhol-Buchung + Rückgängig"
```

---

### Task 7: Gesamtverifikation + Deploy

**Files:**
- Modify: `sbs_projer_app/pubspec.yaml:4` (Version)

- [ ] **Step 1: Volle Analyse (keine `| tail`-Falle — Fehler zählen)**

Run:
```bash
export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter analyze 2>&1 | grep -cE "error •|error -"
```
Expected: `0`

- [ ] **Step 2: Volle Test-Suite**

Run: `export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter test 2>&1 | tail -3`
Expected: `All tests passed!` (388 bestehende + 12 neue = 400)

- [ ] **Step 3: Version bumpen**

In `sbs_projer_app/pubspec.yaml` Zeile 4: `version: 0.46.26+573` → `version: 0.47.0+574`

- [ ] **Step 4: Web-Build**

Run:
```bash
export PATH="$PATH:/c/flutter/bin" && export MSYS_NO_PATHCONV=1 && cd sbs_projer_app && \
flutter build web --base-href "/sbs-projer-dev/" --pwa-strategy=none 2>&1 | tail -2
```
Expected: `√ Built build\web`

- [ ] **Step 5: Cache-Bust + Service Worker entfernen**

Run:
```bash
cd "D:/01_SBS_Projer_GmbH/00_Entwicklung/SBS Projer DEV" && \
VER=$(grep -o '"version":"[^"]*"' sbs_projer_app/build/web/version.json | cut -d'"' -f4) && \
sed -i "s/\"mainJsPath\":\"main.dart.js\"/\"mainJsPath\":\"main.dart.js?v=$VER\"/g" \
  sbs_projer_app/build/web/flutter_bootstrap.js && \
rm -f sbs_projer_app/build/web/flutter_service_worker.js && echo "busted=$VER"
```
Expected: `busted=0.47.0`

- [ ] **Step 6: main committen + pushen**

```bash
cd "D:/01_SBS_Projer_GmbH/00_Entwicklung/SBS Projer DEV" && \
git add sbs_projer_app/pubspec.yaml && \
git commit -m "feat(material): Material abgeholt → Bestände in einem Klick (v0.47.0)" && \
git push origin main
```

- [ ] **Step 7: gh-pages deployen (mit Branch-Guard!)**

⚠️ **Nie `git checkout gh-pages | tail`** — der Exit-Code wird verschluckt und die `rm`-Befehle laufen auf main (Vorfall 14.07.).

```bash
cd "D:/01_SBS_Projer_GmbH/00_Entwicklung/SBS Projer DEV" && \
git checkout gh-pages && CUR=$(git branch --show-current) && echo "BRANCH: $CUR" && \
if [ "$CUR" != "gh-pages" ]; then echo "GUARD ABBRUCH"; exit 1; fi && \
rm -rf assets canvaskit icons main.dart.js* flutter*.js index.html manifest.json favicon.png version.json docs && \
cp -r sbs_projer_app/build/web/* . && touch .nojekyll && \
git add index.html main.dart.js* flutter*.js manifest.json favicon.png version.json .nojekyll assets/ canvaskit/ icons/ && \
git commit -m "deploy v0.47.0 — Material abgeholt" && \
git push origin gh-pages && git checkout main && echo "ZURUECK: $(git branch --show-current)"
```
Expected: `BRANCH: gh-pages` … `ZURUECK: main`

- [ ] **Step 8: Doku nachziehen**

- `ToDo.md`: Stand-Zeile auf `**Stand:** 15.07.2026 · **Live:** v0.47.0`; neuen 🟢-Abschnitt „Material abgeholt → Bestände in einem Klick (live v0.47.0)" mit den Kernpunkten (Status `abgeholt`, atomare RPCs, Kontroll-Dialog, Bestellungen-Liste, Rückgängig).
- `Projekt.md`: `**Stand**` + `**Version**` auf 15.07.2026 / 0.47.0+574; neue `> Zuletzt (15.07.2026):`-Zeile ganz oben im Log-Block.

```bash
git add ToDo.md Projekt.md && git commit -m "docs: Material abgeholt live v0.47.0" && git push origin main
```

- [ ] **Step 9: Live-Test durch Daniel anfordern**

Der eingeloggte Screen ist für Claude nicht erreichbar → Daniel testet:
1. `/materialien` → Icon „Bestellungen" → Liste zeigt die bestehenden Bestellungen mit Status-Badge.
2. Bei einer `gesendet`-Bestellung „Material abgeholt" → Dialog ist nach Kategorie gruppiert, Mengen vorbefüllt.
3. Eine Menge ändern + eine Zeile abwählen → „Bestände buchen".
4. Lager-Bestände prüfen (nur die gebuchten Artikel, mit der korrigierten Menge).
5. Karte aufklappen → „bestellt X · erhalten Y" (Abweichung hervorgehoben).
6. „Buchung rückgängig" → Bestände exakt wie vorher, Status wieder `gesendet`.

---

## Verifikations-Checkliste (Definition of Done)

- [ ] Migration 141 auf Prod, RPCs gegen echte Bestellung geprüft (buchen / Doppelbuchung wirft / rückgängig stellt exakt her)
- [ ] `flutter analyze` = 0 Fehler
- [ ] Volle Test-Suite grün (inkl. 12 neuer Tests)
- [ ] v0.47.0 auf gh-pages deployed, main + gh-pages gepusht
- [ ] ToDo.md + Projekt.md aktualisiert
- [ ] Live-Test durch Daniel bestanden

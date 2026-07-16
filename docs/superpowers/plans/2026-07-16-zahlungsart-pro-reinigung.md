# Zahlungsart pro Reinigung — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Die Zahlungsart wird pro Reinigung gespeichert (`reinigungen.zahlungsart`) und ist ALLEIN massgebend für Buchung + Rechnung; der Betrieb liefert nur noch den Default. Behebt die Ursache der 38 fehlenden Rechnungen (heineken-Durchfall + veralteter Cache).

**Architecture:** Neue nullable Spalte auf `reinigungen` (Migration 144), Entity-Erweiterung nach Projektmuster (DTO/Isar-Local/Web-Stub/Mapper), reine Auflösungslogik in `core/util/zahlungsart.dart` (TDD), Abschluss-Dialog mit explizitem Standard-Übernehmen (Checkbox) + Klartext + Rechnungsadresse-Erfassung, Services lesen den Reinigungs-Wert mit Betriebs-Fallback für Altdaten. Mail-Versand nur noch via `betrieb_rechnungsadressen.email`.

**Tech Stack:** Flutter Web (CanvasKit), Supabase (PostgREST + MCP `execute_sql`/`apply_migration`, project_id `pltbaqqwpnmdajwgnhpd`), Isar (Native), Riverpod.

**Spec:** `docs/superpowers/specs/2026-07-16-zahlungsart-pro-reinigung-design.md`

**Projektregeln (aus CLAUDE.md/Memory, für den Implementer verbindlich):**
- Bash: `export PATH="$PATH:/c/flutter/bin"`, App-Verzeichnis `sbs_projer_app`.
- Migrationen SOFORT auf Prod anwenden (MCP `apply_migration`) und verifizieren.
- `flutter analyze` vollständig prüfen (`grep -cE "error -"` = 0), nie nur `tail`.
- `reinigung_repository.dart` nutzt eine **Positivliste `_listCols`** — jede neue
  Spalte MUSS dort ergänzt werden, sonst fehlt sie still in Listen-Objekten.
- Generierte `*.g.dart` sind gitignored — nie stagen.
- Arbeit direkt auf `main` (Projekt-Workflow), Commit pro Task.

---

### Task 1: Migration 144 — `reinigungen.zahlungsart`

**Files:**
- Create: `Datenbank/migrations/144_reinigung_zahlungsart.sql`

- [ ] **Step 1: Migrationsdatei schreiben**

```sql
-- Migration 144: Zahlungsart pro Reinigung
--
-- Ursache der 38 fehlenden Rechnungen (26.06.-13.07.2026): Buchung + Rechnung
-- entstanden aus betriebe.rechnungsstellung ZUM ABSCHLUSS-ZEITPUNKT. 34 Faelle:
-- Betrieb war noch 'heineken' (Umstellung auf Tresen erst 10.07.) -> beide
-- Services fallen lautlos durch. 4 Faelle: veralteter Formular-Cache.
--
-- Ab jetzt: Die Zahlungsart wird beim Abschluss AUF DER REINIGUNG gespeichert
-- und ist allein massgebend. betriebe.rechnungsstellung bleibt als Default.
-- Altbestand bleibt NULL (Lesekette: reinigung.zahlungsart ?? betrieb).

ALTER TABLE reinigungen ADD COLUMN IF NOT EXISTS zahlungsart text;

ALTER TABLE reinigungen DROP CONSTRAINT IF EXISTS reinigungen_zahlungsart_check;
ALTER TABLE reinigungen ADD CONSTRAINT reinigungen_zahlungsart_check
  CHECK (zahlungsart IS NULL OR zahlungsart IN
    ('barzahlung','rechnung_tresen','rechnung_mail','rechnung_post',
     'jahresrechnung','heineken'));

COMMENT ON COLUMN reinigungen.zahlungsart IS
  'Zahlungsart DIESER Reinigung (beim Abschluss fixiert). Massgebend fuer Buchung+Rechnung. NULL = Altbestand vor v0.50 -> Fallback betriebe.rechnungsstellung.';
```

- [ ] **Step 2: Auf Prod anwenden**

MCP `apply_migration` (project_id `pltbaqqwpnmdajwgnhpd`, name `144_reinigung_zahlungsart`) mit dem SQL aus Step 1.

- [ ] **Step 3: Verifizieren**

MCP `execute_sql`:
```sql
SELECT column_name, is_nullable FROM information_schema.columns
WHERE table_name='reinigungen' AND column_name='zahlungsart';
```
Erwartet: 1 Zeile, `is_nullable = YES`.

- [ ] **Step 4: Commit**

```bash
git add Datenbank/migrations/144_reinigung_zahlungsart.sql
git commit -m "feat(db): Migration 144 — reinigungen.zahlungsart (pro Reinigung fixiert)"
```

---

### Task 2: Entity-Erweiterung — DTO, Local, Web-Stub, Mapper, Positivliste

**Files:**
- Modify: `sbs_projer_app/lib/data/models/reinigung.dart` (Muster: `serviceArt` Z. 55/111/171/231)
- Modify: `sbs_projer_app/lib/data/local/reinigung_local.dart` (Muster: `serviceArt` Z. 73)
- Modify: `sbs_projer_app/lib/data/local/web/reinigung_local_web.dart` (Muster: Z. 64)
- Modify: `sbs_projer_app/lib/data/mappers/reinigung_mapper.dart` (Muster: Z. 57/120)
- Modify: `sbs_projer_app/lib/data/repositories/reinigung_repository.dart` (`_listCols`!)

- [ ] **Step 1: DTO `reinigung.dart`** — an den vier `serviceArt`-Stellen jeweils direkt darunter ergänzen:

```dart
  final String? zahlungsart;            // Feld-Deklaration (bei Z. 55)
    this.zahlungsart,                   // Konstruktor (bei Z. 111)
      zahlungsart: json['zahlungsart'], // fromJson (bei Z. 171)
      'zahlungsart': zahlungsart,       // toJson (bei Z. 231)
```

- [ ] **Step 2: Isar-Local + Web-Stub** — in BEIDEN Dateien unter `serviceArt`:

```dart
  /// Zahlungsart dieser Reinigung (beim Abschluss fixiert; null = Altbestand).
  String? zahlungsart;
```

- [ ] **Step 3: Mapper** — `fromDto` und `toJson` unter den `serviceArt`-Zeilen:

```dart
    local.zahlungsart = dto.zahlungsart;      // in fromDto (bei Z. 57)
      'zahlungsart': local.zahlungsart,       // in toJson (bei Z. 120)
```

- [ ] **Step 4: Positivliste ergänzen** — in `reinigung_repository.dart` die Konstante `_listCols` suchen (`grep -n "_listCols" …`) und `zahlungsart` in die Spaltenliste aufnehmen. OHNE das fehlt der Wert still in allen Listen-Loads.

- [ ] **Step 5: build_runner (Isar-Schema)**

```bash
cd sbs_projer_app && dart run build_runner build --delete-conflicting-outputs
```
Erwartet: `Succeeded`.

- [ ] **Step 6: Analyze**

```bash
flutter analyze lib/data/ 2>&1 | grep -cE "error -"
```
Erwartet: `0`.

- [ ] **Step 7: Commit** (KEINE `.g.dart` stagen!)

```bash
git add lib/data/models/reinigung.dart lib/data/local/reinigung_local.dart \
  lib/data/local/web/reinigung_local_web.dart lib/data/mappers/reinigung_mapper.dart \
  lib/data/repositories/reinigung_repository.dart
git commit -m "feat(reinigung): zahlungsart-Feld durch alle Schichten (DTO/Local/Web/Mapper/_listCols)"
```

---

### Task 3: Reine Logik `core/util/zahlungsart.dart` (TDD)

**Files:**
- Create: `sbs_projer_app/lib/core/util/zahlungsart.dart`
- Test: `sbs_projer_app/test/zahlungsart_test.dart`

- [ ] **Step 1: Failing Tests schreiben**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/zahlungsart.dart';

void main() {
  group('resolveZahlungsart', () {
    test('Reinigungs-Wert gewinnt immer', () {
      expect(resolveZahlungsart('rechnung_mail', 'rechnung_tresen'), 'rechnung_mail');
      expect(resolveZahlungsart('barzahlung', 'heineken'), 'barzahlung');
    });
    test('NULL/leer auf der Reinigung -> Betriebs-Default', () {
      expect(resolveZahlungsart(null, 'rechnung_tresen'), 'rechnung_tresen');
      expect(resolveZahlungsart('', 'barzahlung'), 'barzahlung');
    });
    test('beides leer -> rechnung_tresen (sicherster Default: erzeugt Rechnung)', () {
      expect(resolveZahlungsart(null, null), 'rechnung_tresen');
      expect(resolveZahlungsart('', ''), 'rechnung_tresen');
    });
  });

  group('istRechnungsart', () {
    test('tresen/mail/post -> true, Rest -> false', () {
      expect(istRechnungsart('rechnung_tresen'), isTrue);
      expect(istRechnungsart('rechnung_mail'), isTrue);
      expect(istRechnungsart('rechnung_post'), isTrue);
      expect(istRechnungsart('barzahlung'), isFalse);
      expect(istRechnungsart('heineken'), isFalse);
      expect(istRechnungsart('jahresrechnung'), isFalse);
      expect(istRechnungsart(null), isFalse);
    });
  });

  group('zahlungsartKlartext', () {
    test('jede Art hat einen erklaerenden Satz', () {
      expect(zahlungsartKlartext('rechnung_tresen', kundenEmail: null),
          'Rechnung + Einzahlungsschein, Übergabe vor Ort, kein Versand');
      expect(zahlungsartKlartext('rechnung_mail', kundenEmail: 'a@b.ch'),
          'Rechnung per Mail an a@b.ch');
      expect(zahlungsartKlartext('rechnung_mail', kundenEmail: null),
          '⚠ Keine Rechnungsadresse-E-Mail — Rechnung geht NICHT an den Kunden');
      expect(zahlungsartKlartext('rechnung_post', kundenEmail: null),
          'Rechnung per Mail an dich (Ausdrucken + Post)');
      expect(zahlungsartKlartext('barzahlung', kundenEmail: null),
          'Bar kassiert → Kasse, keine Rechnung');
      expect(zahlungsartKlartext('heineken', kundenEmail: null),
          'Keine Einzelrechnung — läuft über die Heineken-Monatsabrechnung');
      expect(zahlungsartKlartext('jahresrechnung', kundenEmail: null),
          'Keine Einzelrechnung — läuft über die Jahresrechnung');
    });
  });
}
```

- [ ] **Step 2: Test laufen lassen — MUSS failen**

```bash
flutter test test/zahlungsart_test.dart
```
Erwartet: Compile-Fehler (Datei existiert nicht).

- [ ] **Step 3: Implementation**

```dart
/// Zahlungsart-Auflösung für Reinigungen.
///
/// Regel (Daniel, 16.07.2026): Die Zahlungsart der REINIGUNG ist allein
/// massgebend für Buchung + Rechnung. Der Betriebs-Wert ist nur der Default
/// (Vorbelegung + Fallback für Altbestand vor v0.50, dessen Feld NULL ist).
library;

const zahlungsarten = [
  'rechnung_mail', 'rechnung_post', 'rechnung_tresen',
  'barzahlung', 'jahresrechnung', 'heineken',
];

/// Arten, die eine EINZELrechnung mit QR erzeugen (camt-abgleichbar).
const rechnungsarten = {'rechnung_tresen', 'rechnung_mail', 'rechnung_post'};

String resolveZahlungsart(String? reinigungsWert, String? betriebsWert) {
  if (reinigungsWert != null && reinigungsWert.isNotEmpty) return reinigungsWert;
  if (betriebsWert != null && betriebsWert.isNotEmpty) return betriebsWert;
  // Sicherster Default: erzeugt Rechnung + Buchung — lieber eine Rechnung zu
  // viel (sichtbar, stornierbar) als eine lautlos fehlende.
  return 'rechnung_tresen';
}

bool istRechnungsart(String? art) => rechnungsarten.contains(art);

/// Erklärt VOR dem Abschluss, was die gewählte Art auslöst — die 38 fehlenden
/// Rechnungen blieben 3 Wochen unsichtbar, weil genau das nirgends stand.
String zahlungsartKlartext(String art, {required String? kundenEmail}) {
  switch (art) {
    case 'rechnung_tresen':
      return 'Rechnung + Einzahlungsschein, Übergabe vor Ort, kein Versand';
    case 'rechnung_mail':
      return kundenEmail == null || kundenEmail.isEmpty
          ? '⚠ Keine Rechnungsadresse-E-Mail — Rechnung geht NICHT an den Kunden'
          : 'Rechnung per Mail an $kundenEmail';
    case 'rechnung_post':
      return 'Rechnung per Mail an dich (Ausdrucken + Post)';
    case 'barzahlung':
      return 'Bar kassiert → Kasse, keine Rechnung';
    case 'heineken':
      return 'Keine Einzelrechnung — läuft über die Heineken-Monatsabrechnung';
    case 'jahresrechnung':
      return 'Keine Einzelrechnung — läuft über die Jahresrechnung';
    default:
      return art;
  }
}
```

- [ ] **Step 4: Tests grün**

```bash
flutter test test/zahlungsart_test.dart
```
Erwartet: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/core/util/zahlungsart.dart test/zahlungsart_test.dart
git commit -m "feat(util): Zahlungsart-Auflösung + Klartext (TDD)"
```

---

### Task 4: Services lesen die Reinigung (nicht den Betrieb)

**Files:**
- Modify: `sbs_projer_app/lib/services/buchhaltung/reinigung_buchung_service.dart:59-64`
- Modify: `sbs_projer_app/lib/services/rechnung/rechnung_service.dart:38-45` (im `createFromReinigung`)
- Modify: `sbs_projer_app/lib/services/rechnung/reinigung_rechnung_versand.dart:85, 91, 141, 187-205`
- Modify: `sbs_projer_app/lib/presentation/screens/reinigungen/reinigung_detail_screen.dart:324-340` (Guard)

- [ ] **Step 1: Buchungs-Service** — in `reinigung_buchung_service.dart` Import ergänzen und Z. 59 ersetzen:

```dart
import 'package:sbs_projer_app/core/util/zahlungsart.dart';
// ...
    // Massgebend ist die Zahlungsart der REINIGUNG (Ursache der 38: hier stand
    // betrieb.rechnungsstellung — heineken fiel lautlos durch, Cache veraltete).
    final rs = resolveZahlungsart(reinigung.zahlungsart, betrieb.rechnungsstellung);
```
(Die Zeilen `istBar`/`istRechnung`/Guards bleiben unverändert — `heineken`/`jahresrechnung` fallen weiterhin durch, das ist für echte Heineken-Reinigungen korrekt und wird durch Task 7 sichtbar gemacht.)

- [ ] **Step 2: Rechnungs-Service** — in `rechnung_service.dart` denselben Import ergänzen; in `createFromReinigung` den Eingangs-Guard ersetzen:

```dart
    final art = resolveZahlungsart(reinigung.zahlungsart, betrieb.rechnungsstellung);
    if (!_invoiceRechnungsstellungen.contains(art)) {
      return null;
    }
```
Weiter unten (`'versandart': betrieb.rechnungsstellung`) → `'versandart': art`.

- [ ] **Step 3: Versand-Service** — in `reinigung_rechnung_versand.dart`:
  - Z. 85: `final rs = resolveZahlungsart(r.zahlungsart, betrieb.rechnungsstellung);` (+ Import).
  - `_kundenEmail` (Z. 187-205): **Betrieb-Fallback entfernen** — nach dem try-Block nur noch `return null;` statt `betrieb.email`-Rückgabe. Doc-Kommentar anpassen: `Versand IMMER via betrieb_rechnungsadressen.email — betriebe.email ist reine Info (Entscheid Daniel 16.07.2026).`

- [ ] **Step 4: Detail-Screen-Guard** — in `reinigung_detail_screen.dart` (Z. 324-332) den Guard auf die aufgelöste Art umstellen:

```dart
    final rs = resolveZahlungsart(reinigung.zahlungsart, betrieb.rechnungsstellung);
    const rechnungsArten = {'rechnung_post', 'rechnung_mail', 'rechnung_tresen'};
    if (!rechnungsArten.contains(rs)) {
```
(+ Import; `istTresen = rs == 'rechnung_tresen'` bleibt.)

- [ ] **Step 5: Inline-Versandzweige im Formular** — in `reinigung_form_screen.dart` (Z. 543-736): direkt nach dem `betrieb != null`-Check EINMAL auflösen und die drei Stellen umstellen:

```dart
          final zahlungsart =
              resolveZahlungsart(r.zahlungsart, betrieb.rechnungsstellung);
```
Z. 553: `betrieb.rechnungsstellung == 'rechnung_mail'` → `zahlungsart == 'rechnung_mail'`.
Z. 641: analog für `'rechnung_post'`.
Z. 718: `betrieb.rechnungsstellung == 'barzahlung'` → `zahlungsart == 'barzahlung'`.
Inline-`_kundenEmail`-Logik (Z. 555-572): den `betrieb.email`-Fallback (`kundenEmail ??= …`) ersatzlos streichen.

- [ ] **Step 6: Analyze + volle Tests**

```bash
flutter analyze lib/ 2>&1 | grep -cE "error -"   # Erwartet: 0
flutter test 2>&1 | tail -1                       # Erwartet: All tests passed!
```

- [ ] **Step 7: Commit**

```bash
git add lib/services/ lib/presentation/screens/reinigungen/
git commit -m "feat(reinigung): Buchung/Rechnung/Versand lesen zahlungsart der Reinigung; Mail nur via Rechnungsadresse"
```

---

### Task 5: Abschluss-Dialog — Checkbox, Klartext, E-Mail-Erfassung, frischer Betrieb

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/reinigungen/reinigung_form_screen.dart:816-893` (`_showAbschlussDialog`) und `:425-431` (`_save`, Status-Block)

- [ ] **Step 1: `_save` setzt die Zahlungsart auf die Reinigung** — im Status-Block (Z. 425-431):

```dart
      if (abschliessen) {
        r.status = 'abgeschlossen';
        r.uhrzeitEnde ??= _formatTime(TimeOfDay.now());
        // Zahlungsart auf der Reinigung fixieren — ab hier ist NUR dieser Wert
        // massgebend (nie mehr die Betriebs-Einstellung zum Buchungszeitpunkt).
        r.zahlungsart = _rechnungsstellung ?? 'rechnung_tresen';
      } else {
        r.status = _status;
      }
```

- [ ] **Step 2: `_showAbschlussDialog` komplett ersetzen** (Z. 816-893) durch:

```dart
  Future<void> _showAbschlussDialog() async {
    // Heineken-Monteur/Kulanz: direkt abschliessen ohne Rechnungsdialog
    if (_istHeinekenMonteur || _istKulanz) {
      _save(abschliessen: true);
      return;
    }

    // Betrieb FRISCH laden — der Formular-Cache kann veraltet sein (4 der 38
    // fehlenden Rechnungen entstanden genau so).
    BetriebLocal? betrieb = _betrieb;
    final betriebId = widget.betriebId ?? _existing?.betriebId;
    if (betriebId != null && betriebId.isNotEmpty) {
      try {
        final frisch = await BetriebRepository.getByServerId(betriebId);
        if (frisch != null) betrieb = frisch;
      } catch (e) {
        debugPrint('[Abschluss] Betrieb-Refresh fehlgeschlagen: $e');
      }
    }
    if (!mounted) return;

    var selected = resolveZahlungsart(null, betrieb?.rechnungsstellung);
    var alsStandard = false;

    // Rechnungsadresse-E-Mail (Versand läuft NUR darüber; betriebe.email = Info).
    String? raEmail;
    try {
      final ra = betriebId == null
          ? null
          : await BetriebRechnungsadresseRepository.getByBetrieb(betriebId);
      raEmail = (ra?.email != null && ra!.email!.isNotEmpty) ? ra.email : null;
    } catch (e) {
      debugPrint('[Abschluss] Rechnungsadresse-Load fehlgeschlagen: $e');
    }
    if (!mounted) return;
    final emailCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Reinigung abschliessen'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Zahlungsart für DIESE Reinigung:'),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selected,
                  decoration: const InputDecoration(
                    labelText: 'Zahlungsart',
                    prefixIcon: Icon(Icons.receipt),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'rechnung_mail', child: Text('Per E-Mail')),
                    DropdownMenuItem(value: 'rechnung_post', child: Text('Per Post')),
                    DropdownMenuItem(value: 'rechnung_tresen', child: Text('Rechnung Tresen (EZS)')),
                    DropdownMenuItem(value: 'barzahlung', child: Text('Barzahlung')),
                    DropdownMenuItem(value: 'jahresrechnung', child: Text('Jahresrechnung')),
                    DropdownMenuItem(value: 'heineken', child: Text('Via Heineken (monatlich)')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selected = v);
                  },
                ),
                const SizedBox(height: 8),
                // Klartext: WAS löst der Abschluss aus? (Die 38 fehlenden
                // Rechnungen blieben unsichtbar, weil das nirgends stand.)
                Text(
                  zahlungsartKlartext(selected, kundenEmail: raEmail),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected == 'rechnung_mail' && raEmail == null
                        ? AppColors.error
                        : AppColors.textSecondary,
                  ),
                ),
                // Mail ohne Rechnungsadresse-E-Mail: sofort erfassen können.
                if (selected == 'rechnung_mail' && raEmail == null) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Rechnungs-E-Mail jetzt erfassen',
                      prefixIcon: Icon(Icons.alternate_email, size: 18),
                      isDense: true,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: alsStandard,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Auch als Standard für diesen Betrieb übernehmen',
                      style: TextStyle(fontSize: 13)),
                  onChanged: (v) => setDialogState(() => alsStandard = v ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.check_circle, size: 18),
              label: const Text('Abschliessen'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    // Neu erfasste Rechnungs-E-Mail speichern: Rechnungsadresse anlegen
    // (vorbefüllt aus Betriebsdaten, damit der PDF-Adressblock stimmt) bzw.
    // nur die E-Mail ergänzen.
    final neueEmail = emailCtrl.text.trim();
    if (selected == 'rechnung_mail' && raEmail == null && neueEmail.isNotEmpty &&
        betriebId != null) {
      try {
        var ra = await BetriebRechnungsadresseRepository.getByBetrieb(betriebId);
        if (ra == null) {
          ra = BetriebRechnungsadresseLocal()
            ..betriebId = betriebId
            ..firma = betrieb?.name
            ..strasse = betrieb?.strasse
            ..plz = betrieb?.plz
            ..ort = betrieb?.ort;
        }
        ra.email = neueEmail;
        await BetriebRechnungsadresseRepository.save(ra);
      } catch (e) {
        debugPrint('[Abschluss] Rechnungsadresse speichern fehlgeschlagen: $e');
      }
    }

    // Betriebs-Default NUR auf expliziten Wunsch aktualisieren (Checkbox) —
    // der frühere STILLE Rückschreib-Effekt hat zu den 38 beigetragen.
    if (alsStandard && betrieb != null &&
        selected != betrieb.rechnungsstellung) {
      betrieb.rechnungsstellung = selected;
      await BetriebRepository.save(betrieb);
      if (kIsWeb && mounted) ref.invalidate(betriebeStreamProvider);
    }

    setState(() => _rechnungsstellung = selected);
    _save(abschliessen: true);
  }
```

Hinweis Implementer: Feldnamen von `BetriebRechnungsadresseLocal`/`BetriebLocal`
(`strasse`, `plz`, `ort`, `nr`) VOR dem Einbau gegen die Modelldateien prüfen
(`grep -n "String?" lib/data/local/betrieb_rechnungsadresse_local.dart`) und
die Vorbefüllung an die real existierenden Felder anpassen. Benötigte Imports:
`core/util/zahlungsart.dart`, `data/repositories/betrieb_rechnungsadresse_repository.dart`,
`data/local/betrieb_rechnungsadresse_local_export.dart`.

- [ ] **Step 3: Analyze + volle Tests** (Kommandos wie Task 4 Step 6, gleiche Erwartung).

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/screens/reinigungen/reinigung_form_screen.dart
git commit -m "feat(reinigung): Abschluss-Dialog — Zahlungsart pro Reinigung, Standard-Checkbox, Klartext, E-Mail-Erfassung"
```

---

### Task 6: QR-Tab trägt die SCOR-Referenz (bei Rechnungsarten)

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/reinigungen/reinigung_qr_dialog.dart:8-77`
- Modify: `sbs_projer_app/lib/presentation/screens/reinigungen/reinigung_form_screen.dart:1579-1607` (`_zeigeQrZahlung`)
- Test: `sbs_projer_app/test/zahlungsart_test.dart` (erweitern)

- [ ] **Step 1: Failing Test ergänzen** (in `zahlungsart_test.dart`):

```dart
  group('qrReferenzFuerReinigung', () {
    test('Rechnungsart -> deterministische SCOR-Referenz (Datum+BetriebNr)', () {
      final ref = qrReferenzFuerReinigung(
          zahlungsart: 'rechnung_tresen',
          datum: DateTime(2026, 6, 26),
          betriebNr: '0476');
      expect(ref, isNotNull);
      expect(ref, startsWith('RF'));
      expect(ref, contains('202606260476')); // gleiche Ziffern wie die Rechnung
    });
    test('barzahlung/heineken -> null (QR bleibt referenzlos)', () {
      expect(qrReferenzFuerReinigung(zahlungsart: 'barzahlung',
          datum: DateTime(2026, 6, 26), betriebNr: '0476'), isNull);
      expect(qrReferenzFuerReinigung(zahlungsart: 'heineken',
          datum: DateTime(2026, 6, 26), betriebNr: '0476'), isNull);
    });
    test('fehlende BetriebNr -> Ziffernfallback 0000 wie die Rechnung', () {
      final ref = qrReferenzFuerReinigung(zahlungsart: 'rechnung_mail',
          datum: DateTime(2026, 6, 26), betriebNr: null);
      expect(ref, contains('202606260000'));
    });
  });
```

- [ ] **Step 2: Test failt** (`flutter test test/zahlungsart_test.dart` → Compile-Fehler).

- [ ] **Step 3: Funktion in `zahlungsart.dart` ergänzen** (Import `scor_referenz.dart`):

```dart
import 'package:sbs_projer_app/core/util/scor_referenz.dart';

/// SCOR-Referenz für den Direkt-Zahlen-QR im Reinigungstab — DIESELBE Referenz,
/// die die Rechnung bekommt (Ziffern aus 'YYYY-MM-DD-<betriebNr>', identisch zu
/// RechnungService.createFromReinigung). Damit ist auch eine spontane
/// Direktzahlung im camt über die Referenz zuordenbar. Bar/Heineken -> null.
String? qrReferenzFuerReinigung({
  required String? zahlungsart,
  required DateTime datum,
  required String? betriebNr,
}) {
  if (!istRechnungsart(zahlungsart)) return null;
  final nr = (betriebNr == null || betriebNr.isEmpty) ? '0000' : betriebNr.padLeft(4, '0');
  final nummer = '${datum.year}-${datum.month.toString().padLeft(2, '0')}-'
      '${datum.day.toString().padLeft(2, '0')}-$nr';
  return qrReferenzAusNummer('kundenrechnung', nummer);
}
```

- [ ] **Step 4: Tests grün** (`flutter test test/zahlungsart_test.dart`).

- [ ] **Step 5: Dialog + Aufrufer verdrahten**
  - `reinigung_qr_dialog.dart`: neues Feld `final String? referenz;` (Konstruktor `this.referenz`), im `swissQrPayload`-Aufruf (Z. 68-77) `referenz: widget.referenz,` ergänzen (der Parameter existiert bereits in `swissQrPayload`; gesetzt → SCOR statt NON).
  - `_zeigeQrZahlung` im Formular: beim Dialog-Aufruf ergänzen:

```dart
        referenz: qrReferenzFuerReinigung(
          zahlungsart: _rechnungsstellung ?? _betrieb?.rechnungsstellung,
          datum: _datum,
          betriebNr: _betrieb?.betriebNr,
        ),
```

- [ ] **Step 6: Analyze + Commit**

```bash
flutter analyze lib/ 2>&1 | grep -cE "error -"   # 0
git add lib/core/util/zahlungsart.dart test/zahlungsart_test.dart \
  lib/presentation/screens/reinigungen/
git commit -m "feat(qr): Reinigungstab-QR trägt SCOR-Referenz bei Rechnungsarten (camt-zuordenbar)"
```

---

### Task 7: Warnung — Bar-Ausschluss + „ohne Buchung"-Check

**Files:**
- Modify: `sbs_projer_app/lib/core/util/zahlungsart.dart` (+ reine Filter-Funktion)
- Modify: `sbs_projer_app/lib/services/rechnung/reinigungen_ohne_rechnung.dart`
- Test: `sbs_projer_app/test/zahlungsart_test.dart` (erweitern)

- [ ] **Step 0a: Failing Tests für den reinen Filter** (in `zahlungsart_test.dart`):

```dart
  group('warnungsGrund', () {
    test('Kasse gebucht -> nie flaggen (bar erledigt, egal welche Art)', () {
      expect(warnungsGrund(art: 'rechnung_tresen', hatRechnung: false,
          hatBuchung: true, kasseGebucht: true), isNull);
    });
    test('heineken/jahresrechnung -> nie flaggen', () {
      expect(warnungsGrund(art: 'heineken', hatRechnung: false,
          hatBuchung: false, kasseGebucht: false), isNull);
      expect(warnungsGrund(art: 'jahresrechnung', hatRechnung: false,
          hatBuchung: false, kasseGebucht: false), isNull);
    });
    test('Rechnungsart ohne Rechnung -> ohneRechnung', () {
      expect(warnungsGrund(art: 'rechnung_tresen', hatRechnung: false,
          hatBuchung: true, kasseGebucht: false), WarnungsGrund.ohneRechnung);
    });
    test('gar keine Buchung -> ohneBuchung (auch bei barzahlung)', () {
      expect(warnungsGrund(art: 'barzahlung', hatRechnung: false,
          hatBuchung: false, kasseGebucht: false), WarnungsGrund.ohneBuchung);
    });
    test('alles da -> null', () {
      expect(warnungsGrund(art: 'rechnung_mail', hatRechnung: true,
          hatBuchung: true, kasseGebucht: false), isNull);
    });
  });
```

- [ ] **Step 0b: Failing** (`flutter test test/zahlungsart_test.dart` → Compile-Fehler), dann Implementation in `zahlungsart.dart`:

```dart
enum WarnungsGrund { ohneRechnung, ohneBuchung }

/// Entscheidet, ob eine abgeschlossene Reinigung in der Warnung erscheint.
/// Kasse-Buchung (1000) = bar erledigt -> nie flaggen, egal was die heutige
/// Betriebs-Einstellung sagt (die 10 Fehlalarme vom 16.07.).
WarnungsGrund? warnungsGrund({
  required String art,
  required bool hatRechnung,
  required bool hatBuchung,
  required bool kasseGebucht,
}) {
  if (art == 'heineken' || art == 'jahresrechnung') return null;
  if (kasseGebucht) return null;
  if (!hatBuchung) return WarnungsGrund.ohneBuchung;
  if (istRechnungsart(art) && !hatRechnung) return WarnungsGrund.ohneRechnung;
  return null;
}
```

Danach Tests grün (`flutter test test/zahlungsart_test.dart`).

- [ ] **Step 1: Umbau** — in `finde()` nach dem Laden der `verrechnet`-Menge zusätzlich die Buchungen der Kandidaten GEZIELT laden (gleiches 200er-Block-Muster wie `rechnungs_positionen` — PostgREST-1000er-Limit!):

```dart
    // Tatsächliche Verbuchung je Reinigung: Kasse (1000) = bar erledigt,
    // KEINE Rechnung nötig (Entscheid Daniel 16.07. — die Betriebs-Einstellung
    // kann sich seither geändert haben). Debitor (1100) erwartet eine Rechnung.
    final kasseGebucht = <String>{};
    final hatBuchung = <String>{};
    for (var i = 0; i < ids.length; i += 200) {
      final teil = ids.sublist(i, (i + 200).clamp(0, ids.length));
      final bu = List<Map<String, dynamic>>.from(
        await client
            .from('buchungen')
            .select('beleg_id, soll_konto, beleg_typ, ist_storniert')
            .inFilter('beleg_id', teil)
            .eq('ist_storniert', false),
      );
      for (final b in bu) {
        final id = b['beleg_id']?.toString();
        if (id == null || id.isEmpty) continue;
        hatBuchung.add(id);
        if (b['beleg_typ'] == 'rechnung' && b['soll_konto'] == 1000) {
          kasseGebucht.add(id);
        }
      }
    }
```

In der Kandidaten-Schleife die Filterlogik ersetzen:

```dart
      final r = ReinigungMapper.fromDto(Reinigung.fromJson(row));
      final sid = r.serverId;
      if (sid == null) continue;
      if (r.istKulanz || r.istHeinekenMonteur) continue;

      final betrieb = await BetriebRepository.getByServerId(r.betriebId);
      if (betrieb == null) continue;
      final art = resolveZahlungsart(r.zahlungsart, betrieb.rechnungsstellung);

      final grund = warnungsGrund(
        art: art,
        hatRechnung: verrechnet.contains(sid),
        hatBuchung: hatBuchung.contains(sid),
        kasseGebucht: kasseGebucht.contains(sid),
      );
      if (grund == null) continue;
      final fehltBuchung = grund == WarnungsGrund.ohneBuchung;

      treffer.add(ReinigungOhneRechnung(
        reinigungId: sid,
        datum: r.datum,
        betriebName: betrieb.ort != null && betrieb.ort!.isNotEmpty
            ? '${betrieb.name} ${betrieb.ort}'
            : betrieb.name,
        brutto: r.preisBrutto ?? 0,
        fehltBuchung: fehltBuchung,
      ));
```

`ReinigungOhneRechnung` bekommt `final bool fehltBuchung;` (Konstruktor
`this.fehltBuchung = false`), und `zeile` hängt bei `fehltBuchung`
` · OHNE BUCHUNG` an. Imports ergänzen: `core/util/zahlungsart.dart`.
`RechnungService.brauchtRechnung`-Aufruf entfällt (ersetzt durch `istRechnungsart`).

- [ ] **Step 2: Analyze + volle Tests** (wie Task 4 Step 6).

- [ ] **Step 3: Verifikation gegen DB-Erwartung** — MCP `execute_sql`: die Warnung darf nach diesem Umbau für die 10 Bar-Fälle vom 16.07. NICHT mehr anschlagen. Gegenprobe (muss 10 liefern, alle `kasse`):

```sql
SELECT count(*) FROM reinigungen r JOIN buchungen b
  ON b.beleg_id=r.id AND b.beleg_typ='rechnung' AND NOT b.ist_storniert
WHERE r.datum >= '2025-12-01' AND coalesce(r.quelle,'app') <> 'excel_import'
  AND b.soll_konto=1000
  AND NOT EXISTS (SELECT 1 FROM rechnungs_positionen p WHERE p.service_id=r.id);
```

- [ ] **Step 4: Commit**

```bash
git add lib/services/rechnung/reinigungen_ohne_rechnung.dart
git commit -m "feat(warnung): Bar-Ausschluss via Kasse-Buchung + ohne-Buchung-Check"
```

---

### Task 8: Suchläufe, Gesamtverifikation, Deploy v0.50.0

**Files:**
- Modify: `sbs_projer_app/pubspec.yaml:4`, `sbs_projer_app/lib/core/app_version.dart`, `ToDo.md`

- [ ] **Step 1: Suchlauf 1 — verlorene Reinigungen** (MCP `execute_sql`, Ergebnis an Daniel melden, NICHTS automatisch reparieren):

```sql
SELECT r.datum, b.name, b.ort, r.preis_brutto, b.rechnungsstellung
FROM reinigungen r JOIN betriebe b ON b.id=r.betrieb_id
WHERE r.status='abgeschlossen' AND r.datum >= '2025-12-01'
  AND coalesce(r.quelle,'app') <> 'excel_import'
  AND NOT r.ist_kulanz AND NOT r.ist_heineken_monteur
  AND b.rechnungsstellung <> 'heineken'
  AND NOT EXISTS (SELECT 1 FROM buchungen bu
                  WHERE bu.beleg_id=r.id AND NOT bu.ist_storniert)
ORDER BY r.datum;
```

- [ ] **Step 2: Suchlauf 2 — Mail-Betriebe ohne Rechnungsadresse-E-Mail** (Ergebnis an Daniel):

```sql
SELECT b.name, b.ort, b.email AS info_email
FROM betriebe b
WHERE b.rechnungsstellung='rechnung_mail'
  AND NOT EXISTS (SELECT 1 FROM betrieb_rechnungsadressen ra
                  WHERE ra.betrieb_id=b.id
                    AND ra.email IS NOT NULL AND ra.email <> '')
ORDER BY b.name;
```

- [ ] **Step 3: Version + kAppVersion bumpen**

```bash
sed -i '4s/.*/version: 0.50.0+584/' pubspec.yaml
sed -i "s/kAppVersion = '.*'/kAppVersion = '0.50.0'/" lib/core/app_version.dart
```

- [ ] **Step 4: Gesamtverifikation**

```bash
flutter analyze lib/ 2>&1 | grep -cE "error -"   # 0
flutter test 2>&1 | tail -1                       # All tests passed!
```

- [ ] **Step 5: Commit + Build + Deploy** (Projekt-Workflow; Branch-Guard zwingend):

```bash
cd .. && git add -A && git commit -m "feat(reinigung): Zahlungsart pro Reinigung (v0.50.0) — Ursache der 38 behoben"
cd sbs_projer_app && export MSYS_NO_PATHCONV=1 && flutter build web --base-href "/sbs-projer-dev/" --pwa-strategy=none
cd .. && VER=$(grep -o '"version":"[^"]*"' sbs_projer_app/build/web/version.json | cut -d'"' -f4) \
  && sed -i "s/\"mainJsPath\":\"main.dart.js\"/\"mainJsPath\":\"main.dart.js?v=$VER\"/g" sbs_projer_app/build/web/flutter_bootstrap.js \
  && rm -f sbs_projer_app/build/web/flutter_service_worker.js
git checkout gh-pages
CUR=$(git rev-parse --abbrev-ref HEAD); if [ "$CUR" != "gh-pages" ]; then echo ABBRUCH; exit 1; fi
rm -rf assets canvaskit icons main.dart.js* flutter*.js index.html manifest.json favicon.png version.json docs
cp -r sbs_projer_app/build/web/* . && touch .nojekyll
git add index.html main.dart.js* flutter*.js manifest.json favicon.png version.json .nojekyll assets/ canvaskit/ icons/
git commit -m "deploy v0.50.0 — Zahlungsart pro Reinigung"
git push origin gh-pages && git checkout main && git push origin main
```

- [ ] **Step 6: ToDo.md** — neuen 🟢-Abschnitt „Zahlungsart pro Reinigung (v0.50.0)" mit Spec-/Plan-Link ergänzen, offenen 🔴-Punkt zur Juni-Ursache als GELÖST markieren (heineken-Durchfall + Cache, Verweis auf Spec-Problemabschnitt), Suchlauf-Ergebnisse (Step 1/2) als Entscheidungspunkte für Daniel eintragen. Commit `docs: ToDo — Zahlungsart pro Reinigung live`.

- [ ] **Step 7: Live-Test durch Daniel** (aus Spec „Manuelle Verifikation"): 1× Tresen mit Checkbox aus (Betrieb bleibt), 1× Mail mit Checkbox an (Betrieb wechselt), 1× Mail ohne E-Mail (Warnung + Feld erscheint), Forderungen-Titel zeigt v0.50.0, Warnung zeigt keine neuen Fehlalarme. Testdaten danach auf Zuruf zurückrollen (Reinigungen/Rechnungen/Buchungen der Tests löschen, Sequenz zurücksetzen — Muster vom 15.07.).

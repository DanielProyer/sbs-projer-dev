# Reinigung-QR Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Beim Erfassen einer neuen Reinigung einen Swiss-QR-Code aufs Firmenkonto auf dem Bildschirm anzeigen, den der Kunde direkt per E-Banking scannen und zahlen kann.

**Architecture:** Die bestehende Swiss-QR-Payload-Logik wird in eine reine, testbare Funktion `swissQrPayload(...)` extrahiert (der Rechnungs-QR nutzt sie danach byte-identisch weiter). Ein Widget rendert den Payload on-screen (`barcode`→SVG + Schweizerkreuz). Ein Dialog im Reinigungs-Formular lädt die Firmendaten (`GeschaeftRepository.get()`), füllt den Betrag aus `preisBrutto` vor (editierbar) und zeigt den QR. Keine DB-Migration.

**Tech Stack:** Dart/Flutter, `barcode`, `flutter_svg`, Supabase.

**Referenz-Spec:** `docs/superpowers/specs/2026-07-10-reinigung-qr-design.md`

**Reihenfolge:** Payload-Funktion (TDD) → Rechnungs-QR umstellen (byte-identisch) → QR-Widget → Dialog+Button im Formular → Verifikation+Deploy. **Deploy v0.28.0. Keine Migration.**

**Vorab verifizierte Fakten:**
- **Rechnungs-QR** (`lib/services/pdf/rechnung_pdf_service.dart`): private Methode
  `static String _buildQrData(double betrag, _KundeAdresse kunde, {String? mitteilung, String? referenz})`
  baut den SPC-Payload. Firmen-Konstanten: `_iban='CH6600774010376550601'`,
  `_ibanFormatted='CH66 0077 4010 3765 5060 1'`, `_firmaName='SBS Projer GmbH'`,
  `_firmaStrasse='Via Rezia'`, `_firmaNr='8'`, `_firmaPlz='7013'`, `_firmaOrt='Domat/Ems'`,
  `_firmaLand='CH'`. `_KundeAdresse` hat `name`, `strasseOnly`, `nrOnly`, `plzOnly`, `ortOnly`.
- **Payload-Struktur** (31 Zeilen, join `\n`): `SPC / 0200 / 1 / IBAN / 'S' / Name / Strasse / Nr /
  PLZ / Ort / Land / 7× '' (Ultimate Creditor) / Betrag / 'CHF' / DebtorType / DebtorName /
  DebtorStreet / DebtorNr / DebtorPlz / DebtorOrt / DebtorCountry / RefType / Ref / Ustrd / 'EPD'`.
  Heute: `betrag.toStringAsFixed(2)`; DebtorType/`DebtorCountry` = `kunde.name.isNotEmpty ? 'S'/_firmaLand : ''`;
  RefType = `referenz != null && referenz.isNotEmpty ? 'SCOR' : 'NON'`; Ustrd = mitteilung auf 140 gekürzt.
- **Firmendaten-Loader**: `GeschaeftRepository.get()` → `GeschaeftEinstellungen` (Getter mit Fallbacks:
  `firma`, `adresseStrasse` z.B. „Via Rezia 8", `adressePlzOrt` z.B. „7013 Domat/Ems"; Feld
  `firmenIban` (String?, DB-Wert `CH6600774010376550601`)). Import
  `data/repositories/geschaeft_repository.dart`, Model `data/models/geschaeft_einstellungen.dart`.
- **Reinigungs-Formular** (`lib/presentation/screens/reinigungen/reinigung_form_screen.dart`):
  `_ReinigungFormScreenState extends ConsumerState`; State: `DateTime _datum`, `BetriebLocal? _betrieb`,
  `Map<String,dynamic>? _preisliste`, `String? _serviceTyp`; Methode
  `Map<String, double> _calculatePreis()` → Map mit `'brutto'` (leer `{}` wenn keine Preisliste/Service).
  Preis-Block wird gerendert wenn `_preisliste != null && _serviceTyp != null` (~Zeile 1512).
- **QR-Rendering** (Muster aus rechnung_pdf_service): `Barcode.qrCode(errorCorrectLevel:
  BarcodeQRCorrectionLevel.medium)`. On-Screen: `.toSvg(payload, width:, height:, drawText:false)` +
  `SvgPicture.string(...)` (Paket `flutter_svg`, `barcode` sind Dependencies).
- Flutter-PATH in Bash: `export PATH="$PATH:/c/flutter/bin"`.

---

## File Structure

**Neu:**
- `sbs_projer_app/lib/core/util/swiss_qr_bill.dart` — reine Funktion `swissQrPayload`.
- `sbs_projer_app/test/swiss_qr_bill_test.dart` — Tests.
- `sbs_projer_app/lib/presentation/widgets/swiss_qr_ansicht.dart` — On-Screen-QR-Widget.
- `sbs_projer_app/lib/presentation/screens/reinigungen/reinigung_qr_dialog.dart` — QR-Dialog.

**Geändert:**
- `rechnung_pdf_service.dart` — `_buildQrData` ruft `swissQrPayload` (byte-identisch).
- `reinigung_form_screen.dart` — Button „QR-Zahlung" + Dialog-Aufruf.
- `pubspec.yaml` — v0.28.0.

---

## Task 1: Reine Funktion `swissQrPayload` (TDD)

**Files:**
- Create: `sbs_projer_app/lib/core/util/swiss_qr_bill.dart`
- Test: `sbs_projer_app/test/swiss_qr_bill_test.dart`

- [ ] **Step 1: Failing test** (`test/swiss_qr_bill_test.dart`):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/swiss_qr_bill.dart';

void main() {
  group('swissQrPayload', () {
    List<String> lines(String p) => p.split('\n');

    test('Grundstruktur: 31 Zeilen, Header/Trailer, IBAN, Creditor', () {
      final p = swissQrPayload(
        iban: 'CH6600774010376550601',
        creditorName: 'SBS Projer GmbH',
        creditorStreet: 'Via Rezia',
        creditorNr: '8',
        creditorPlz: '7013',
        creditorOrt: 'Domat/Ems',
        betrag: 120.5,
      );
      final l = lines(p);
      expect(l.length, 31);
      expect(l[0], 'SPC');
      expect(l[1], '0200');
      expect(l[2], '1');
      expect(l[3], 'CH6600774010376550601');
      expect(l[4], 'S');
      expect(l[5], 'SBS Projer GmbH');
      expect(l[18], '120.50'); // Betrag
      expect(l[19], 'CHF');
      expect(l.last, 'EPD');
    });

    test('Betrag null/<=0 -> leere Betragszeile (offen)', () {
      final p = swissQrPayload(
        iban: 'CH00', creditorName: 'X', creditorStreet: 'Y', creditorNr: '1',
        creditorPlz: '1000', creditorOrt: 'Z', betrag: null,
      );
      expect(lines(p)[18], '');
    });

    test('kein Debitor -> leerer Address-Type + leeres Land; Referenztyp NON', () {
      final l = lines(swissQrPayload(
        iban: 'CH00', creditorName: 'X', creditorStreet: 'Y', creditorNr: '1',
        creditorPlz: '1000', creditorOrt: 'Z', betrag: 10,
      ));
      expect(l[20], ''); // Debtor Address Type
      expect(l[26], ''); // Debtor Country
      expect(l[27], 'NON'); // Reference Type
    });

    test('mit Debitor + Referenz + Mitteilung', () {
      final l = lines(swissQrPayload(
        iban: 'CH00', creditorName: 'X', creditorStreet: 'Y', creditorNr: '1',
        creditorPlz: '1000', creditorOrt: 'Z', betrag: 10,
        debtorName: 'Bar Sonne', debtorStreet: 'Weg', debtorNr: '2',
        debtorPlz: '7000', debtorOrt: 'Chur',
        referenz: 'RF12', mitteilung: 'Reinigung',
      ));
      expect(l[20], 'S');
      expect(l[21], 'Bar Sonne');
      expect(l[26], 'CH'); // Debtor Country = creditorLand
      expect(l[27], 'SCOR');
      expect(l[28], 'RF12');
      expect(l[29], 'Reinigung');
    });

    test('Mitteilung > 140 Zeichen wird gekürzt', () {
      final lang = 'x' * 200;
      final l = lines(swissQrPayload(
        iban: 'CH00', creditorName: 'X', creditorStreet: 'Y', creditorNr: '1',
        creditorPlz: '1000', creditorOrt: 'Z', betrag: 10, mitteilung: lang,
      ));
      expect(l[29].length, 140);
    });
  });
}
```

- [ ] **Step 2: Test ausführen, Fehlschlag bestätigen**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test test/swiss_qr_bill_test.dart`
Expected: FAIL (undefined).

- [ ] **Step 3: Implementieren** (`lib/core/util/swiss_qr_bill.dart`):

```dart
/// Baut den Swiss-QR-Bill-Payload (SPC, Version 0200) als `\n`-getrennten String.
///
/// - [betrag] null oder <= 0 -> leere Betragszeile (offener Betrag).
/// - [referenz] gesetzt -> Referenztyp `SCOR`, sonst `NON`.
/// - [mitteilung] wird auf 140 Zeichen gekürzt (Swiss-QR-Standard).
/// Reihenfolge/Struktur ist identisch zur bisherigen Rechnungs-QR-Erzeugung.
String swissQrPayload({
  required String iban,
  required String creditorName,
  required String creditorStreet,
  required String creditorNr,
  required String creditorPlz,
  required String creditorOrt,
  String creditorLand = 'CH',
  double? betrag,
  String debtorName = '',
  String debtorStreet = '',
  String debtorNr = '',
  String debtorPlz = '',
  String debtorOrt = '',
  String? referenz,
  String? mitteilung,
}) {
  final info = (mitteilung != null && mitteilung.isNotEmpty)
      ? (mitteilung.length > 140 ? mitteilung.substring(0, 140) : mitteilung)
      : '';
  final betragStr = (betrag != null && betrag > 0) ? betrag.toStringAsFixed(2) : '';
  final hatDebitor = debtorName.isNotEmpty;

  final lines = <String>[
    'SPC', // QR Type
    '0200', // Version
    '1', // Coding Type (UTF-8)
    iban, // IBAN
    'S', // Creditor Address Type (structured)
    creditorName,
    creditorStreet,
    creditorNr,
    creditorPlz,
    creditorOrt,
    creditorLand,
    '', '', '', '', '', '', '', // Ultimate Creditor (7 leer)
    betragStr, // Amount
    'CHF', // Currency
    hatDebitor ? 'S' : '', // Debtor Address Type
    debtorName,
    debtorStreet,
    debtorNr,
    debtorPlz,
    debtorOrt,
    hatDebitor ? creditorLand : '', // Debtor Country
    (referenz != null && referenz.isNotEmpty) ? 'SCOR' : 'NON', // Reference Type
    referenz ?? '', // Reference
    info, // Unstructured Message
    'EPD', // Trailer
  ];
  return lines.join('\n');
}
```

- [ ] **Step 4: Test ausführen, Erfolg bestätigen**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test test/swiss_qr_bill_test.dart`
Expected: PASS (5 Tests).

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/core/util/swiss_qr_bill.dart sbs_projer_app/test/swiss_qr_bill_test.dart
git commit -m "feat(qr): reine Funktion swissQrPayload (TDD)"
```

---

## Task 2: Rechnungs-QR auf `swissQrPayload` umstellen (byte-identisch)

**Files:**
- Modify: `sbs_projer_app/lib/services/pdf/rechnung_pdf_service.dart`

- [ ] **Step 1: Import ergänzen** (oben bei den Imports):

```dart
import 'package:sbs_projer_app/core/util/swiss_qr_bill.dart';
```

- [ ] **Step 2: `_buildQrData` als dünnen Wrapper** — den bestehenden Methodenkörper (die manuelle
`lines`-Liste) ersetzen durch den Aufruf der reinen Funktion mit denselben Konstanten + Kunde als
Debitor:

```dart
  static String _buildQrData(double betrag, _KundeAdresse kunde,
      {String? mitteilung, String? referenz}) {
    return swissQrPayload(
      iban: _iban,
      creditorName: _firmaName,
      creditorStreet: _firmaStrasse,
      creditorNr: _firmaNr,
      creditorPlz: _firmaPlz,
      creditorOrt: _firmaOrt,
      creditorLand: _firmaLand,
      betrag: betrag,
      debtorName: kunde.name,
      debtorStreet: kunde.strasseOnly,
      debtorNr: kunde.nrOnly,
      debtorPlz: kunde.plzOnly,
      debtorOrt: kunde.ortOnly,
      referenz: referenz,
      mitteilung: mitteilung,
    );
  }
```

- [ ] **Step 3: Regression prüfen** — bestehende QR-/Rechnungs-Tests müssen grün bleiben:

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test test/swiss_qr_test.dart test/swiss_qr_cdtr_test.dart`
Expected: PASS (unverändert).

- [ ] **Step 4: Analyze**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze lib/services/pdf/rechnung_pdf_service.dart`
Expected: keine neuen Findings.

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/services/pdf/rechnung_pdf_service.dart
git commit -m "refactor(qr): Rechnungs-QR nutzt swissQrPayload (byte-identisch)"
```

---

## Task 3: On-Screen-QR-Widget `SwissQrAnsicht`

**Files:**
- Create: `sbs_projer_app/lib/presentation/widgets/swiss_qr_ansicht.dart`

- [ ] **Step 1: Widget implementieren**

```dart
import 'package:barcode/barcode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Zeigt einen Swiss-QR-Bill-Code (aus dem Payload) mit zwingendem
/// Schweizerkreuz in der Mitte — zum Scannen mit der Banking-App.
class SwissQrAnsicht extends StatelessWidget {
  final String payload;
  final double size;
  const SwissQrAnsicht({super.key, required this.payload, this.size = 240});

  @override
  Widget build(BuildContext context) {
    final svg = Barcode.qrCode(errorCorrectLevel: BarcodeQRCorrectionLevel.medium)
        .toSvg(payload, width: size, height: size, drawText: false);
    final k = size / 6; // Schweizerkreuz-Grösse

    return Container(
      width: size,
      height: size,
      color: Colors.white,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SvgPicture.string(svg, width: size, height: size),
          // Schweizerkreuz: schwarzes Quadrat, weisser Rand, weisses Kreuz.
          Container(
            width: k,
            height: k,
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border.all(color: Colors.white, width: k * 0.07),
            ),
            child: Center(
              child: SizedBox(
                width: k * 0.6,
                height: k * 0.6,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(width: k * 0.6, height: k * 0.2, color: Colors.white),
                    Container(width: k * 0.2, height: k * 0.6, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Analyze**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze lib/presentation/widgets/swiss_qr_ansicht.dart`
Expected: keine Findings.

- [ ] **Step 3: Commit**

```bash
git add sbs_projer_app/lib/presentation/widgets/swiss_qr_ansicht.dart
git commit -m "feat(qr): On-Screen-Swiss-QR-Widget mit Schweizerkreuz"
```

---

## Task 4: QR-Dialog + Button im Reinigungs-Formular

**Files:**
- Create: `sbs_projer_app/lib/presentation/screens/reinigungen/reinigung_qr_dialog.dart`
- Modify: `sbs_projer_app/lib/presentation/screens/reinigungen/reinigung_form_screen.dart`

- [ ] **Step 1: Dialog implementieren** (`reinigung_qr_dialog.dart`):

```dart
import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/swiss_qr_bill.dart';
import 'package:sbs_projer_app/data/models/geschaeft_einstellungen.dart';
import 'package:sbs_projer_app/presentation/widgets/swiss_qr_ansicht.dart';

/// Dialog: Swiss-QR aufs Firmenkonto zum Scannen (Betrag editierbar).
class ReinigungQrDialog extends StatefulWidget {
  final GeschaeftEinstellungen firma;
  final String betriebName;
  final DateTime datum;
  final double? initialBetrag;

  const ReinigungQrDialog({
    super.key,
    required this.firma,
    required this.betriebName,
    required this.datum,
    this.initialBetrag,
  });

  @override
  State<ReinigungQrDialog> createState() => _ReinigungQrDialogState();
}

class _ReinigungQrDialogState extends State<ReinigungQrDialog> {
  late final TextEditingController _betragCtrl;

  @override
  void initState() {
    super.initState();
    final b = widget.initialBetrag;
    _betragCtrl = TextEditingController(
        text: (b != null && b > 0) ? b.toStringAsFixed(2) : '');
  }

  @override
  void dispose() {
    _betragCtrl.dispose();
    super.dispose();
  }

  // "Via Rezia 8" -> ("Via Rezia", "8")
  (String, String) _splitStrasse(String s) {
    final i = s.trimRight().lastIndexOf(' ');
    if (i <= 0) return (s.trim(), '');
    return (s.substring(0, i).trim(), s.substring(i + 1).trim());
  }

  // "7013 Domat/Ems" -> ("7013", "Domat/Ems")
  (String, String) _splitPlzOrt(String s) {
    final i = s.trim().indexOf(' ');
    if (i <= 0) return ('', s.trim());
    return (s.substring(0, i).trim(), s.substring(i + 1).trim());
  }

  @override
  Widget build(BuildContext context) {
    final iban = (widget.firma.firmenIban ?? '').replaceAll(' ', '');
    final betrag = double.tryParse(_betragCtrl.text.replaceAll(',', '.'));
    final (strasse, nr) = _splitStrasse(widget.firma.adresseStrasse);
    final (plz, ort) = _splitPlzOrt(widget.firma.adressePlzOrt);
    final datumStr =
        '${widget.datum.day.toString().padLeft(2, '0')}.${widget.datum.month.toString().padLeft(2, '0')}.${widget.datum.year}';

    final payload = iban.isEmpty
        ? null
        : swissQrPayload(
            iban: iban,
            creditorName: widget.firma.firma,
            creditorStreet: strasse,
            creditorNr: nr,
            creditorPlz: plz,
            creditorOrt: ort,
            betrag: betrag,
            mitteilung: 'Reinigung · ${widget.betriebName} · $datumStr',
          );

    return AlertDialog(
      title: const Text('QR-Zahlung'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iban.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Keine Firmen-IBAN hinterlegt.\nBitte in den Einstellungen eintragen.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.error),
                ),
              )
            else ...[
              SwissQrAnsicht(payload: payload!),
              const SizedBox(height: 12),
              TextField(
                controller: _betragCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Betrag (CHF, leer = offen)',
                  isDense: true,
                  prefixIcon: Icon(Icons.payments_outlined, size: 18),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${widget.firma.firma}\n${widget.firma.firmenIban}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Schliessen')),
      ],
    );
  }
}
```

- [ ] **Step 2: Import + Button im Formular** (`reinigung_form_screen.dart`).

Imports:
```dart
import 'package:sbs_projer_app/data/repositories/geschaeft_repository.dart';
import 'package:sbs_projer_app/presentation/screens/reinigungen/reinigung_qr_dialog.dart';
```

Button (OutlinedButton) im Preis-/Rechnungsbereich einfügen — z. B. direkt nach dem Preis-Block
(dort wo `if (_preisliste != null && _serviceTyp != null) ...[ ... ]` endet), sinnvoll immer sichtbar:
```dart
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _zeigeQrZahlung,
              icon: const Icon(Icons.qr_code_2),
              label: const Text('QR-Zahlung'),
            ),
```

- [ ] **Step 3: `_zeigeQrZahlung`-Methode** im State ergänzen:

```dart
  Future<void> _zeigeQrZahlung() async {
    final betriebName = _betrieb?.name ??
        (widget.betriebId != null
            ? (await BetriebRepository.getByServerId(widget.betriebId!))?.name ?? ''
            : '');
    final firma = await GeschaeftRepository.get();
    final brutto = _calculatePreis()['brutto'];
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => ReinigungQrDialog(
        firma: firma,
        betriebName: betriebName,
        datum: _datum,
        initialBetrag: brutto,
      ),
    );
  }
```

(`BetriebRepository` ist im Formular bereits importiert.)

- [ ] **Step 4: Analyze**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze lib/presentation/screens/reinigungen/reinigung_qr_dialog.dart lib/presentation/screens/reinigungen/reinigung_form_screen.dart`
Expected: keine neuen Findings.

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/reinigungen/reinigung_qr_dialog.dart sbs_projer_app/lib/presentation/screens/reinigungen/reinigung_form_screen.dart
git commit -m "feat(reinigung): QR-Zahlung-Button + Dialog (Firmenkonto-QR, Betrag aus preisBrutto)"
```

---

## Task 5: Verifikation + Deploy v0.28.0

**Files:**
- Modify: `sbs_projer_app/pubspec.yaml`

- [ ] **Step 1: Version bumpen** — `pubspec.yaml` Zeile 4: `version: 0.27.6+506` → `version: 0.28.0+507`.

- [ ] **Step 2: Volle Analyse + alle Tests**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze && flutter test`
Expected: keine neuen Analyze-Findings; alle Tests grün (inkl. `swiss_qr_bill_test`, unveränderte `swiss_qr_test`).

- [ ] **Step 3: Web-Build**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && export MSYS_NO_PATHCONV=1 && flutter build web --base-href "/sbs-projer-dev/" --pwa-strategy=none`
Expected: `√ Built build\web`.

- [ ] **Step 4: Visueller Browser-Test (Pflicht)**
  - Neue Reinigung (Betrieb mit Preisliste) → Button **„QR-Zahlung"** → Dialog zeigt scanbaren QR
    (Schweizerkreuz), Betrag vorbefüllt aus Brutto-Preis + editierbar; Empfänger/IBAN korrekt.
  - Betrag ändern → QR aktualisiert sich; Feld leeren → offener Betrag.
  - **Realer Scan-Test** mit einer Banking-App: QR wird erkannt, Empfänger = SBS Projer GmbH, IBAN +
    Betrag stimmen.

- [ ] **Step 5: Version-Commit**

```bash
git add sbs_projer_app/pubspec.yaml
git commit -m "chore: Version 0.28.0+507 (Reinigung-QR)"
```

- [ ] **Step 6: Deploy nach gh-pages** (Workflow CLAUDE.md; vorher `main` pushen; **kein** `git stash`)

```bash
cd sbs_projer_app && export MSYS_NO_PATHCONV=1 && flutter build web --base-href "/sbs-projer-dev/" --pwa-strategy=none
cd .. && VER=$(grep -o '"version":"[^"]*"' sbs_projer_app/build/web/version.json | cut -d'"' -f4) \
  && sed -i "s/\"mainJsPath\":\"main.dart.js\"/\"mainJsPath\":\"main.dart.js?v=$VER\"/g" \
       sbs_projer_app/build/web/flutter_bootstrap.js \
  && rm -f sbs_projer_app/build/web/flutter_service_worker.js
git checkout gh-pages
rm -rf assets canvaskit icons main.dart.js* flutter*.js index.html manifest.json favicon.png version.json docs
cp -r sbs_projer_app/build/web/* .
touch .nojekyll
git add index.html main.dart.js* flutter*.js manifest.json favicon.png version.json .nojekyll assets/ canvaskit/ icons/
git commit -m "deploy v0.28.0 — Reinigung-QR (Firmenkonto-QR im Formular)"
git push origin gh-pages
git checkout main
git push origin main
```

---

## Ausführungsreihenfolge

Task 1 → 2 → 3 → 4 → 5. Jede Task ist eigenständig committbar; die UI-Tasks (3, 4) werden im Abschluss-Task 5 einmal gesammelt visuell verifiziert (inkl. realem Scan-Test) und deployt.

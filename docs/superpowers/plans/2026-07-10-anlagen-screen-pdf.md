# Anlagen-Screen + Steckbrief-PDF Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Anlagen als Bereich sichtbar machen (Dashboard-Kachel + Kennzahlen) und pro Anlage einen professionellen Steckbrief als PDF erzeugen, den man teilen oder per Mail an den RSL senden kann.

**Architecture:** Flutter + Supabase + Riverpod. Der globale `/anlagen`-Screen existiert bereits — es kommen Dashboard-Kachel, Kennzahlen-Kopf, ein reiner PDF-Service (`pdf`/`printing`), eine neue Heineken-Zuweisung `rsl` und ein Versand-Sheet (bestehendes `send-pdf-mail` via `BerichtMailService`) dazu. Reine Funktionen (Kennzahlen, Dateiname, Betreff) sind TDD-getestet. Keine DB-Migration.

**Tech Stack:** Dart/Flutter, `pdf` + `printing`, Supabase Storage (`anlagen-fotos`), flutter_test.

**Referenz-Spec:** `docs/superpowers/specs/2026-07-10-anlagen-screen-pdf-design.md`

**Reihenfolge:** reine Funktionen (TDD) → Dashboard/Kennzahlen → PDF-Service → RSL-Zuweisung+MailConfig → Detail-Aktionen → Verifikation+Deploy. **Deploy v0.27.0. Keine Migration.**

**Vorab verifizierte Fakten:**
- **AnlageLocal** (`anlage_local.dart`/web-Stub) Felder u.a.: `serverId`, `betriebId`, `bezeichnung`, `seriennummer`, `typAnlage`, `typSaeule`, `anzahlHaehne`, `backpython`, `booster`, `vorkuehler`, `durchlaufkuehler`, `letzterWasserwechsel`, `gasTyp1`, `gasTyp2`, `hauptdruckBar`, `hatNiederdruck`, `reinigungRhythmus`, `letzteReinigung`, `naechsteReinigung`, `status`, `notizen`.
- **AnlageFoto** (`data/models/anlage_foto.dart`): `fotoNummer` (1–4), `fotoUrl` (Storage-Pfad), `beschreibung`. `AnlageFotoRepository.getByAnlage(anlageServerId)` → `List<AnlageFoto>` (sortiert nach foto_nummer). Bytes: `SupabaseService.client.storage.from('anlagen-fotos').download(foto.fotoUrl)` → `Uint8List`.
- **BierleitungLocal** (`bierleitung_local_web.dart`): `leitungsNummer` (int), `biersorte` (String?), `hahnTyp` (String?), `niederdruckBar` (double?), `hatFobStop` (bool), `istGekoppelt` (bool), `istAktiv` (bool). `BierleitungRepository.getByAnlage(anlageServerId)` → `List<BierleitungLocal>`.
- **BetriebRepository.getByServerId(serverId)** → `BetriebLocal?` (Name/Adresse via `vollstaendigeAdresse`-Getter existiert nicht auf Local; nutze `strasse/nr/plz/ort`).
- **Dashboard** (`presentation/screens/home_screen.dart`): Kachel-Widget `_MenuListTile(icon:, label:, onTap:)`; „Bergkundenpauschalen" bei Zeile ~197–201 (`context.push('/bergkundenpauschalen')`).
- **AnlagenListScreen** (`presentation/screens/anlagen/anlagen_list_screen.dart`): `ConsumerStatefulWidget`, `anlagen = ref.watch(anlagenProvider)`, `betriebe = ref.watch(betriebeProvider)`, `filtered`-Liste, `body: Scaffold(appBar…, body: …)`. Route `/anlagen` existiert (`router.dart`).
- **Anlage-Detail** (`presentation/screens/anlagen/anlage_detail_screen.dart`): `AnlageDetailScreen(anlageId)`, lädt `anlage` via `AnlageRepository`; hat AppBar. `_FotosSection` (max 4) existiert. Importiert `anlage_foto_repository.dart`.
- **Mail-Versand**: `BerichtMailService.send({required String to, required String subject, required String bodyText, required String filename, required Uint8List pdf})` (nutzt `send-pdf-mail`). Muster-Sheet: `event_abschluss_sheet.dart`.
- **Heineken-Zuweisungen** (generische Tabelle, **keine Migration**): `HeinekenZuweisungenScreen._funktionen` (Liste von `(funktion, label, icon)`, aktuell monatsrechnung/raster/heigenie_service/materialbestellung); `KontaktRepository.getAllHeinekenZuweisungen()` Default-Map; `KontaktRepository.getHeinekenZuweisung(funktion)` → `KontaktLocal?`; `KontaktRepository.setHeinekenZuweisung(funktion, kontaktId)`.
- **MailConfig** (`core/config/mail_config.dart`): Bereiche als `xxxScharf`-Konstanten + `switch`-Zweige in `empfaenger(...)` und `istScharf(...)`. Muster wie `event`.
- **PDF-Muster**: `services/pdf/event_abschluss_pdf_service.dart` (professionell, ASCII-Sanitizer `_s`). `printing`: `Printing.sharePdf(bytes:, filename:)`, `Printing.layoutPdf(onLayout:)`.
- Flutter-PATH in Bash: `export PATH="$PATH:/c/flutter/bin"`.

---

## File Structure

**Neu:**
- `sbs_projer_app/lib/core/util/anlage_pdf_util.dart` — reine Funktionen (Kennzahlen, Dateiname, Betreff).
- `sbs_projer_app/test/anlage_pdf_util_test.dart` — Tests.
- `sbs_projer_app/lib/services/pdf/anlage_pdf_service.dart` — Steckbrief-PDF.
- `sbs_projer_app/test/services/pdf/anlage_pdf_service_test.dart` — Smoke-Test.
- `sbs_projer_app/lib/presentation/screens/anlagen/anlage_steckbrief_sheet.dart` — Versand-Sheet (Teilen + Mail an RSL).

**Geändert:**
- `home_screen.dart` — Dashboard-Kachel „Anlagen".
- `anlagen_list_screen.dart` — Kennzahlen-Kopf.
- `anlage_detail_screen.dart` — Menüpunkte „Steckbrief teilen"/„… an RSL".
- `heineken_zuweisungen_screen.dart` + `kontakt_repository.dart` — Funktion `rsl`.
- `mail_config.dart` — Bereich `anlage`.
- `pubspec.yaml` — v0.27.0.

---

## Task 1: Reine Funktionen (TDD)

**Files:**
- Create: `sbs_projer_app/lib/core/util/anlage_pdf_util.dart`
- Test: `sbs_projer_app/test/anlage_pdf_util_test.dart`

- [ ] **Step 1: Failing test** (`test/anlage_pdf_util_test.dart`):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/anlage_pdf_util.dart';
import 'package:sbs_projer_app/data/local/anlage_local_export.dart';

AnlageLocal _a(String typ, String status, {DateTime? naechste, String rhythmus = '4-Wochen'}) {
  final a = AnlageLocal();
  a.typAnlage = typ;
  a.status = status;
  a.naechsteReinigung = naechste;
  a.reinigungRhythmus = rhythmus;
  return a;
}

void main() {
  final jetzt = DateTime(2026, 7, 10);

  group('anlagenKennzahlen', () {
    test('zaehlt nur aktive, gruppiert nach Typ', () {
      final k = anlagenKennzahlen([
        _a('Warmanstich', 'aktiv'),
        _a('Warmanstich', 'aktiv'),
        _a('Orion', 'aktiv'),
        _a('Warmanstich', 'inaktiv'), // zaehlt nicht
      ], jetzt);
      expect(k.gesamt, 3);
      expect(k.nachTyp['Warmanstich'], 2);
      expect(k.nachTyp['Orion'], 1);
    });

    test('unbekannter Typ -> Sonstige', () {
      final k = anlagenKennzahlen([_a('Exotic', 'aktiv')], jetzt);
      expect(k.nachTyp['Sonstige'], 1);
    });

    test('ueberfaellig = naechste Reinigung vor jetzt (nur aktive)', () {
      final k = anlagenKennzahlen([
        _a('Warmanstich', 'aktiv', naechste: DateTime(2026, 7, 1)), // ueberfaellig
        _a('Warmanstich', 'aktiv', naechste: DateTime(2026, 8, 1)), // nicht
        _a('Warmanstich', 'inaktiv', naechste: DateTime(2026, 1, 1)), // inaktiv -> nicht
      ], jetzt);
      expect(k.ueberfaellig, 1);
    });

    test('ohneRhythmus zaehlt leer/keiner', () {
      final k = anlagenKennzahlen([
        _a('Warmanstich', 'aktiv', rhythmus: ''),
        _a('Warmanstich', 'aktiv', rhythmus: 'keiner'),
        _a('Warmanstich', 'aktiv', rhythmus: '4-Wochen'),
      ], jetzt);
      expect(k.ohneRhythmus, 2);
    });
  });

  group('Dateiname/Betreff', () {
    test('Dateiname ersetzt Sonderzeichen/Slashes', () {
      expect(anlageSteckbriefDateiname('Sonne/Bar', 'Warm 1'),
          'Steckbrief_Sonne-Bar_Warm-1.pdf');
    });
    test('Dateiname faellt auf Anlage zurueck wenn Bezeichnung leer', () {
      expect(anlageSteckbriefDateiname('Sonne', ''), 'Steckbrief_Sonne_Anlage.pdf');
    });
    test('Betreff enthaelt Betrieb + Anlage', () {
      expect(anlageMailBetreff('Sonne', 'Warm 1'), 'Anlagen-Steckbrief: Sonne — Warm 1');
    });
  });
}
```

- [ ] **Step 2: Test ausführen, Fehlschlag bestätigen**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test test/anlage_pdf_util_test.dart`
Expected: FAIL (undefined).

- [ ] **Step 3: Implementieren** (`lib/core/util/anlage_pdf_util.dart`):

```dart
import 'package:sbs_projer_app/data/local/anlage_local_export.dart';

/// Kennzahlen über eine Anlagenliste (nur aktive Anlagen zählen).
class AnlagenKennzahlen {
  final int gesamt;
  final Map<String, int> nachTyp;
  final int ueberfaellig;
  final int ohneRhythmus;
  AnlagenKennzahlen({
    required this.gesamt,
    required this.nachTyp,
    required this.ueberfaellig,
    required this.ohneRhythmus,
  });
}

const _bekannteTypen = {'Warmanstich', 'Kaltanstich', 'Buffetanstich', 'Orion'};

AnlagenKennzahlen anlagenKennzahlen(List<AnlageLocal> anlagen, DateTime jetzt) {
  final aktive = anlagen.where((a) => a.status == 'aktiv').toList();
  final nachTyp = <String, int>{};
  var ueberfaellig = 0;
  var ohneRhythmus = 0;
  for (final a in aktive) {
    final typ = _bekannteTypen.contains(a.typAnlage) ? a.typAnlage : 'Sonstige';
    nachTyp[typ] = (nachTyp[typ] ?? 0) + 1;
    final n = a.naechsteReinigung;
    if (n != null && n.isBefore(jetzt)) ueberfaellig++;
    final r = a.reinigungRhythmus.trim().toLowerCase();
    if (r.isEmpty || r == 'keiner') ohneRhythmus++;
  }
  return AnlagenKennzahlen(
    gesamt: aktive.length,
    nachTyp: nachTyp,
    ueberfaellig: ueberfaellig,
    ohneRhythmus: ohneRhythmus,
  );
}

String _safe(String s) => s
    .trim()
    .replaceAll(RegExp(r'[\\/:*?"<>|]'), '-')
    .replaceAll(' ', '-')
    .replaceAll(RegExp('-+'), '-');

/// Dateiname für den Steckbrief (z. B. `Steckbrief_Sonne_Warm-1.pdf`).
String anlageSteckbriefDateiname(String betriebName, String anlageBezeichnung) {
  final b = _safe(betriebName.isEmpty ? 'Betrieb' : betriebName);
  final a = _safe(anlageBezeichnung.isEmpty ? 'Anlage' : anlageBezeichnung);
  return 'Steckbrief_${b}_$a.pdf';
}

/// Mail-Betreff für den Steckbrief.
String anlageMailBetreff(String betriebName, String anlageBezeichnung) {
  final a = anlageBezeichnung.isEmpty ? 'Anlage' : anlageBezeichnung;
  return 'Anlagen-Steckbrief: $betriebName — $a';
}
```

- [ ] **Step 4: Test ausführen, Erfolg bestätigen**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test test/anlage_pdf_util_test.dart`
Expected: PASS (7 Tests).

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/core/util/anlage_pdf_util.dart sbs_projer_app/test/anlage_pdf_util_test.dart
git commit -m "feat(anlagen): reine Funktionen Kennzahlen/Dateiname/Betreff (TDD)"
```

---

## Task 2: Dashboard-Kachel + Kennzahlen-Kopf

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/home_screen.dart`
- Modify: `sbs_projer_app/lib/presentation/screens/anlagen/anlagen_list_screen.dart`

- [ ] **Step 1: Dashboard-Kachel** in `home_screen.dart` direkt VOR der Bergkundenpauschalen-Kachel einfügen:

```dart
        _MenuListTile(
          icon: Icons.propane_tank_outlined,
          label: 'Anlagen',
          onTap: () => context.push('/anlagen'),
        ),
```

- [ ] **Step 2: Import** in `anlagen_list_screen.dart`:

```dart
import 'package:sbs_projer_app/core/util/anlage_pdf_util.dart';
```

- [ ] **Step 3: Kennzahlen-Kopf** — im `build`, direkt über der Liste (im `body`, vor der Such-/Listen-Sektion). Die Kennzahlen aus ALLEN Anlagen (nicht der gefilterten Liste) rechnen:

```dart
    final kennzahlen = anlagenKennzahlen(anlagen, DateTime.now());
```

Und ein Kopf-Widget einfügen (z. B. als erstes Kind der `body`-Column, vor der Suchleiste):

```dart
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _KennzahlChip('${kennzahlen.gesamt} aktiv', Icons.propane_tank_outlined),
                for (final e in kennzahlen.nachTyp.entries)
                  _KennzahlChip('${e.value}× ${e.key}', Icons.category_outlined),
                if (kennzahlen.ueberfaellig > 0)
                  _KennzahlChip('${kennzahlen.ueberfaellig} überfällig',
                      Icons.warning_amber, color: AppColors.error),
              ],
            ),
          ),
```

- [ ] **Step 4: `_KennzahlChip`-Widget** am Datei-Ende ergänzen:

```dart
class _KennzahlChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;
  const _KennzahlChip(this.label, this.icon, {this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
```

Hinweis: Falls `AppColors` in `anlagen_list_screen.dart` noch nicht importiert ist, `import 'package:sbs_projer_app/core/theme/app_theme.dart';` ergänzen.

- [ ] **Step 5: Analyze**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze lib/presentation/screens/home_screen.dart lib/presentation/screens/anlagen/anlagen_list_screen.dart`
Expected: keine neuen Findings.

- [ ] **Step 6: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/home_screen.dart sbs_projer_app/lib/presentation/screens/anlagen/anlagen_list_screen.dart
git commit -m "feat(anlagen): Dashboard-Kachel + Kennzahlen-Kopf"
```

---

## Task 3: Steckbrief-PDF-Service + Smoke-Test

**Files:**
- Create: `sbs_projer_app/lib/services/pdf/anlage_pdf_service.dart`
- Test: `sbs_projer_app/test/services/pdf/anlage_pdf_service_test.dart`

- [ ] **Step 1: PDF-Service implementieren** (self-contained mit `pdf`/`printing`, Muster wie `event_abschluss_pdf_service.dart`):

```dart
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sbs_projer_app/data/local/anlage_local_export.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/bierleitung_local_export.dart';

/// Erzeugt den Anlagen-Steckbrief als PDF (Grunddaten + bis 4 Fotos + Bierleitungen).
class AnlagePdfService {
  /// [fotos] = bereits geladene JPEG-Bytes (max 4), Reihenfolge = Anzeige.
  static Future<Uint8List> steckbrief({
    required AnlageLocal anlage,
    BetriebLocal? betrieb,
    List<Uint8List> fotos = const [],
    List<BierleitungLocal> bierleitungen = const [],
  }) async {
    final doc = pw.Document();
    final gruen = PdfColor.fromInt(0xFF008200);

    String s(String? v) => (v == null || v.trim().isEmpty)
        ? '-'
        : v.replaceAll('✓', 'OK').replaceAll('–', '-').replaceAll('—', '-');
    String d(DateTime? x) =>
        x == null ? '-' : '${x.day.toString().padLeft(2, '0')}.${x.month.toString().padLeft(2, '0')}.${x.year}';
    String jn(bool b) => b ? 'Ja' : 'Nein';

    final adresse = betrieb == null
        ? ''
        : [
            [betrieb.strasse, betrieb.nr].where((e) => e != null && e.isNotEmpty).join(' '),
            [betrieb.plz, betrieb.ort].where((e) => e != null && e.isNotEmpty).join(' '),
          ].where((e) => e.isNotEmpty).join(', ');

    pw.Widget zeile(String label, String wert) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(children: [
            pw.SizedBox(
                width: 150,
                child: pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700))),
            pw.Expanded(child: pw.Text(wert, style: const pw.TextStyle(fontSize: 10))),
          ]),
        );

    pw.Widget header(String t) => pw.Container(
          width: double.infinity,
          margin: const pw.EdgeInsets.only(top: 14, bottom: 6),
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: gruen,
          child: pw.Text(t,
              style: pw.TextStyle(color: PdfColors.white, fontSize: 11, fontWeight: pw.FontWeight.bold)),
        );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('SBS Projer GmbH', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
          pw.Text('${ctx.pageNumber}/${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
        ],
      ),
      build: (ctx) => [
        // Kopf
        pw.Text('Anlagen-Steckbrief',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: gruen)),
        pw.SizedBox(height: 2),
        pw.Text(s(betrieb?.name), style: const pw.TextStyle(fontSize: 12)),
        if (adresse.isNotEmpty)
          pw.Text(adresse, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.SizedBox(height: 2),
        pw.Text('Erstellt: ${d(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),

        header('Grunddaten'),
        zeile('Bezeichnung', s(anlage.bezeichnung)),
        zeile('Typ Anlage', s(anlage.typAnlage)),
        zeile('Typ Säule', s(anlage.typSaeule)),
        zeile('Seriennummer', s(anlage.seriennummer)),
        zeile('Anzahl Hähne', anlage.anzahlHaehne.toString()),
        zeile('Gas-Typ 1 / 2', '${s(anlage.gasTyp1)} / ${s(anlage.gasTyp2)}'),
        zeile('Vorkühler', s(anlage.vorkuehler)),
        zeile('Durchlaufkühler', s(anlage.durchlaufkuehler)),
        zeile('Booster / Backpython', '${jn(anlage.booster)} / ${jn(anlage.backpython)}'),
        zeile('Hauptdruck (bar)', anlage.hauptdruckBar?.toString() ?? '-'),
        zeile('Niederdruck', jn(anlage.hatNiederdruck)),
        zeile('Reinigungsrhythmus', s(anlage.reinigungRhythmus)),
        zeile('Letzte / nächste Reinigung', '${d(anlage.letzteReinigung)} / ${d(anlage.naechsteReinigung)}'),
        zeile('Status', s(anlage.status)),
        if ((anlage.notizen ?? '').trim().isNotEmpty) zeile('Notizen', s(anlage.notizen)),

        if (bierleitungen.isNotEmpty) ...[
          header('Bierleitungen'),
          pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: gruen),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
            headers: ['Nr.', 'Biersorte', 'Hahn', 'Niederdruck', 'FOB', 'Gekoppelt'],
            data: [
              for (final b in bierleitungen)
                [
                  b.leitungsNummer.toString(),
                  s(b.biersorte),
                  s(b.hahnTyp),
                  b.niederdruckBar?.toString() ?? '-',
                  jn(b.hatFobStop),
                  jn(b.istGekoppelt),
                ],
            ],
          ),
        ],

        if (fotos.isNotEmpty) ...[
          header('Fotos'),
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in fotos)
                pw.Container(
                  width: 240,
                  height: 180,
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
                  child: pw.Image(pw.MemoryImage(f), fit: pw.BoxFit.cover),
                ),
            ],
          ),
        ],
      ],
    ));

    return doc.save();
  }
}
```

- [ ] **Step 2: Smoke-Test** (`test/services/pdf/anlage_pdf_service_test.dart`):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/local/anlage_local_export.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/services/pdf/anlage_pdf_service.dart';

void main() {
  test('steckbrief baut ein PDF ohne Fotos', () async {
    final a = AnlageLocal()
      ..bezeichnung = 'Warm 1'
      ..typAnlage = 'Warmanstich'
      ..anzahlHaehne = 4;
    final b = BetriebLocal()
      ..name = 'Restaurant Sonne'
      ..ort = 'Chur';
    final bytes = await AnlagePdfService.steckbrief(anlage: a, betrieb: b);
    expect(bytes.lengthInBytes, greaterThan(1000));
  });
}
```

- [ ] **Step 3: Test ausführen**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter test test/services/pdf/anlage_pdf_service_test.dart`
Expected: PASS.

- [ ] **Step 4: Analyze**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze lib/services/pdf/anlage_pdf_service.dart`
Expected: keine Findings.

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/services/pdf/anlage_pdf_service.dart sbs_projer_app/test/services/pdf/anlage_pdf_service_test.dart
git commit -m "feat(anlagen): Steckbrief-PDF-Service + Smoke-Test"
```

---

## Task 4: RSL-Zuweisung + MailConfig-Bereich `anlage`

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/heineken/heineken_zuweisungen_screen.dart`
- Modify: `sbs_projer_app/lib/data/repositories/kontakt_repository.dart`
- Modify: `sbs_projer_app/lib/core/config/mail_config.dart`

- [ ] **Step 1: Funktion `rsl` im Zuweisungen-Screen** — die `_funktionen`-Liste ergänzen:

```dart
  static const _funktionen = [
    ('monatsrechnung', 'Monatsrechnung', Icons.receipt_long),
    ('raster', 'Raster', Icons.grid_on),
    ('heigenie_service', 'Heigenie Service', Icons.build),
    ('materialbestellung', 'Materialbestellung', Icons.inventory),
    ('rsl', 'RSL (Anlagen-Steckbrief)', Icons.person_pin),
  ];
```

- [ ] **Step 2: Default-Map** in `KontaktRepository.getAllHeinekenZuweisungen` ergänzen:

```dart
    final result = <String, KontaktLocal?>{
      'monatsrechnung': null,
      'raster': null,
      'heigenie_service': null,
      'materialbestellung': null,
      'rsl': null,
    };
```

- [ ] **Step 3: MailConfig-Bereich `anlage`** — in `mail_config.dart`:

Konstante (bei den anderen `xxxScharf`):
```dart
  // Anlagen-Steckbrief an RSL: erst Test (an dich), dann scharfstellen.
  static const anlageScharf = false;
```
`switch` in `empfaenger(...)` ergänzen (bei den anderen `case`):
```dart
      case 'anlage':
        if (!anlageScharf) return bereinige(testEmpfaenger);
```
`switch` in `istScharf(...)` ergänzen:
```dart
      case 'anlage':
        return anlageScharf;
```

- [ ] **Step 4: Analyze**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze lib/presentation/screens/heineken/heineken_zuweisungen_screen.dart lib/data/repositories/kontakt_repository.dart lib/core/config/mail_config.dart`
Expected: keine neuen Findings.

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/heineken/heineken_zuweisungen_screen.dart sbs_projer_app/lib/data/repositories/kontakt_repository.dart sbs_projer_app/lib/core/config/mail_config.dart
git commit -m "feat(anlagen): Heineken-Zuweisung RSL + MailConfig-Bereich anlage"
```

---

## Task 5: Anlage-Detail — Steckbrief teilen + an RSL

**Files:**
- Create: `sbs_projer_app/lib/presentation/screens/anlagen/anlage_steckbrief_sheet.dart`
- Modify: `sbs_projer_app/lib/presentation/screens/anlagen/anlage_detail_screen.dart`

- [ ] **Step 1: Versand-Sheet** (`anlage_steckbrief_sheet.dart`) — vorausgefüllte, editierbare RSL-Adresse + Senden:

```dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/config/mail_config.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/services/mail/bericht_mail_service.dart';

/// Bottom-Sheet: Steckbrief-PDF an den RSL senden (Adresse vorausgefüllt + editierbar).
class AnlageSteckbriefSheet extends StatefulWidget {
  final String betriebName;
  final String anlageBezeichnung;
  final String? rslMail; // aus Heineken-Zuweisung 'rsl'
  final String betreff;
  final String dateiname;
  final Uint8List pdf;

  const AnlageSteckbriefSheet({
    super.key,
    required this.betriebName,
    required this.anlageBezeichnung,
    required this.rslMail,
    required this.betreff,
    required this.dateiname,
    required this.pdf,
  });

  @override
  State<AnlageSteckbriefSheet> createState() => _AnlageSteckbriefSheetState();
}

class _AnlageSteckbriefSheetState extends State<AnlageSteckbriefSheet> {
  late final _mailController = TextEditingController(text: widget.rslMail ?? '');
  bool _sending = false;

  bool get _scharf => MailConfig.istScharf('anlage');

  @override
  void dispose() {
    _mailController.dispose();
    super.dispose();
  }

  Future<void> _senden() async {
    final ziel = MailConfig.bereinige(_mailController.text);
    if (_scharf && !ziel.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte eine gültige RSL-Adresse eingeben.')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      final to = _scharf ? ziel : MailConfig.testEmpfaenger;
      await BerichtMailService.send(
        to: to,
        subject: widget.betreff,
        bodyText: 'Guten Tag\n\n'
            'Im Anhang der Anlagen-Steckbrief zu «${widget.betriebName}» '
            '(${widget.anlageBezeichnung}).\n\n'
            'Freundliche Grüsse\nSBS Projer GmbH',
        filename: widget.dateiname,
        pdf: widget.pdf,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_scharf
              ? 'Steckbrief an RSL gesendet'
              : 'Steckbrief gesendet (Testmodus → an dich)')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Senden: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Steckbrief an RSL senden',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('${widget.betriebName} — ${widget.anlageBezeichnung}',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          if (!_scharf)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AppColors.surface, borderRadius: BorderRadius.circular(6)),
              child: Text('Testmodus – Versand geht an dich (${MailConfig.testEmpfaenger}).',
                  style: const TextStyle(fontSize: 12)),
            ),
          if (widget.rslMail == null || widget.rslMail!.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Kein RSL hinterlegt — in „Heineken-Zuweisungen" festlegen oder unten eintragen.',
                  style: TextStyle(fontSize: 12, color: AppColors.error)),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _mailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'RSL E-Mail',
              isDense: true,
              prefixIcon: Icon(Icons.alternate_email, size: 18),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _sending ? null : _senden,
              icon: _sending
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
              label: Text(_sending ? 'Sende …' : 'Senden'),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Detail-Screen — Imports** in `anlage_detail_screen.dart` ergänzen:

```dart
import 'dart:typed_data';
import 'package:printing/printing.dart';
import 'package:sbs_projer_app/core/util/anlage_pdf_util.dart';
import 'package:sbs_projer_app/data/repositories/bierleitung_repository.dart';
import 'package:sbs_projer_app/data/repositories/kontakt_repository.dart';
import 'package:sbs_projer_app/services/pdf/anlage_pdf_service.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';
import 'package:sbs_projer_app/presentation/screens/anlagen/anlage_steckbrief_sheet.dart';
```
(`anlage_foto_repository.dart` + `betrieb_repository.dart` sind bereits importiert.)

- [ ] **Step 3: AppBar-Menü** — im `AnlageDetailScreen` (bzw. dem Content-Widget mit `anlage`) in den AppBar-`actions` ein `PopupMenuButton` mit zwei Einträgen ergänzen. Beide brauchen `anlage` + `context`:

```dart
          PopupMenuButton<String>(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Steckbrief',
            onSelected: (v) {
              if (v == 'teilen') _steckbriefTeilen(context, anlage);
              if (v == 'rsl') _steckbriefAnRsl(context, anlage);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'teilen', child: Text('Steckbrief teilen')),
              PopupMenuItem(value: 'rsl', child: Text('Steckbrief an RSL')),
            ],
          ),
```

- [ ] **Step 4: Hilfsmethoden** — im selben Widget (State/Widget mit Zugriff auf `context`). Gemeinsame PDF-Erzeugung + die zwei Aktionen:

```dart
  Future<Uint8List> _buildSteckbrief(AnlageLocal anlage) async {
    final sid = anlage.serverId;
    final betrieb = await BetriebRepository.getByServerId(anlage.betriebId);
    final bierleitungen =
        sid == null ? <BierleitungLocal>[] : await BierleitungRepository.getByAnlage(sid);
    final fotoBytes = <Uint8List>[];
    if (sid != null) {
      final fotos = await AnlageFotoRepository.getByAnlage(sid);
      for (final f in fotos) {
        try {
          final bytes = await SupabaseService.client.storage
              .from('anlagen-fotos')
              .download(f.fotoUrl);
          fotoBytes.add(bytes);
        } catch (_) {/* Foto fehlt -> überspringen */}
      }
    }
    return AnlagePdfService.steckbrief(
      anlage: anlage,
      betrieb: betrieb,
      fotos: fotoBytes,
      bierleitungen: bierleitungen,
    );
  }

  Future<void> _steckbriefTeilen(BuildContext context, AnlageLocal anlage) async {
    try {
      final pdf = await _buildSteckbrief(anlage);
      await Printing.sharePdf(
        bytes: pdf,
        filename: anlageSteckbriefDateiname(
            (await BetriebRepository.getByServerId(anlage.betriebId))?.name ?? '',
            anlage.bezeichnung ?? ''),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('PDF fehlgeschlagen: $e')));
      }
    }
  }

  Future<void> _steckbriefAnRsl(BuildContext context, AnlageLocal anlage) async {
    try {
      final betrieb = await BetriebRepository.getByServerId(anlage.betriebId);
      final rsl = await KontaktRepository.getHeinekenZuweisung('rsl');
      final pdf = await _buildSteckbrief(anlage);
      if (!context.mounted) return;
      final betriebName = betrieb?.name ?? '';
      final bez = anlage.bezeichnung ?? (anlage.typAnlage.isEmpty ? 'Anlage' : anlage.typAnlage);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => AnlageSteckbriefSheet(
          betriebName: betriebName,
          anlageBezeichnung: bez,
          rslMail: rsl?.email,
          betreff: anlageMailBetreff(betriebName, bez),
          dateiname: anlageSteckbriefDateiname(betriebName, bez),
          pdf: pdf,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('PDF fehlgeschlagen: $e')));
      }
    }
  }
```

Hinweis: `AnlageDetailScreen` ist ggf. ein `ConsumerWidget`/`StatelessWidget` mit einem inneren Content-Widget, das `anlage` hält (analog `betrieb_detail_screen.dart` mit `_BetriebDetailContent`). Die Methoden dort platzieren, wo `anlage` verfügbar ist. Falls das Widget kein `State` ist, die Methoden als normale Methoden am Widget definieren (sie brauchen nur `context` + `anlage`, kein `setState`).

- [ ] **Step 5: Analyze**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze lib/presentation/screens/anlagen/anlage_steckbrief_sheet.dart lib/presentation/screens/anlagen/anlage_detail_screen.dart`
Expected: keine neuen Findings.

- [ ] **Step 6: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/anlagen/anlage_steckbrief_sheet.dart sbs_projer_app/lib/presentation/screens/anlagen/anlage_detail_screen.dart
git commit -m "feat(anlagen): Steckbrief teilen + an RSL senden im Anlage-Detail"
```

---

## Task 6: Verifikation + Deploy v0.27.0

**Files:**
- Modify: `sbs_projer_app/pubspec.yaml`

- [ ] **Step 1: Version bumpen** — `pubspec.yaml` Zeile 4: `version: 0.26.4+499` → `version: 0.27.0+500`.

- [ ] **Step 2: Volle Analyse + alle Tests**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && flutter analyze && flutter test`
Expected: keine neuen Analyze-Findings; alle Tests grün (inkl. `anlage_pdf_util_test`, `anlage_pdf_service_test`).

- [ ] **Step 3: Web-Build**

Run: `cd sbs_projer_app && export PATH="$PATH:/c/flutter/bin" && export MSYS_NO_PATHCONV=1 && flutter build web --base-href "/sbs-projer-dev/" --pwa-strategy=none`
Expected: `√ Built build\web`.

- [ ] **Step 4: Visueller Browser-Test (Pflicht)**
  - Dashboard: Kachel „Anlagen" → Liste mit **Kennzahlen-Kopf** (aktiv, nach Typ, überfällig).
  - Anlage-Detail: PDF-Menü → **„Steckbrief teilen"** (Share/Vorschau, Grunddaten + Fotos), **„Steckbrief an RSL"** (Sheet mit vorausgefüllter Adresse falls Zuweisung gesetzt; Testmodus-Hinweis).
  - „Heineken-Zuweisungen"-Screen zeigt neue Zeile **„RSL (Anlagen-Steckbrief)"**, Kontakt zuweisbar.

- [ ] **Step 5: Version-Commit**

```bash
git add sbs_projer_app/pubspec.yaml
git commit -m "chore: Version 0.27.0+500 (Anlagen-Screen + Steckbrief-PDF)"
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
git commit -m "deploy v0.27.0 — Anlagen-Screen + Steckbrief-PDF (Teilen + Mail an RSL)"
git push origin gh-pages
git checkout main
git push origin main
```

---

## Ausführungsreihenfolge

Task 1 → 2 → 3 → 4 → 5 → 6. Jede Task ist eigenständig committbar; die UI-/Versand-Tasks (2, 5) werden im Abschluss-Task 6 einmal gesammelt visuell verifiziert und deployt.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/dokument.dart';
import 'package:sbs_projer_app/data/models/dokument_scan_ergebnis.dart';
import 'package:sbs_projer_app/presentation/widgets/dokumente/dokument_upload_dialog.dart';
import 'package:sbs_projer_app/services/dokumente/dokument_scan_service.dart';

/// Upload-Dialog mit Dokument-Erkennung (parse-dokument, 29.09.2026) — am
/// Handy (360 px). Erkenner, Dateiauswahl und Upload sind eingespeist, es
/// braucht kein Supabase.

final DokumentDatei _pdf = (
  bytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
  name: 'scan 0042.pdf',
  mime: 'application/pdf',
);

final _zinsausweis = DokumentScanErgebnis(
  bereich: 'steuern',
  typ: 'zinsausweis',
  jahr: 2025,
  dokumentDatum: DateTime(2025, 12, 31),
  titel: 'Zins- und Kapitalausweis GKB per 31.12.2025',
  dateiname: '2025_GKB_Zins-Kapitalausweis.pdf',
  zuversicht: 0.92,
  felder: const {
    'saldo_31_12': 10869.26,
    'zins_brutto': 0,
    'verrechnungssteuer': 0,
    'zins_netto': 0,
    'konto': '…0601',
  },
);

/// Zählt die Aufrufe und liefert der Reihe nach [antworten] (die letzte
/// wiederholt sich).
class _Erkenner {
  final List<Future<DokumentScanErgebnis?> Function()> antworten;
  final vorgaben = <String>[];
  _Erkenner(this.antworten);

  factory _Erkenner.fest(DokumentScanErgebnis? e) => _Erkenner([() async => e]);

  int get aufrufe => vorgaben.length;

  Future<DokumentScanErgebnis?> call({
    required Uint8List bytes,
    required String mediaType,
    required String bereichVorgabe,
  }) {
    vorgaben.add(bereichVorgabe);
    final i = (vorgaben.length - 1).clamp(0, antworten.length - 1);
    return antworten[i]();
  }
}

/// Hält fest, was hochgeladen würde; mit [scheitert] wirft der Upload.
class _Upload {
  Map<String, Object?>? werte;
  bool scheitert;
  _Upload({this.scheitert = false});

  Future<Dokument> call({
    required String bereich,
    required String typ,
    String? kategorie,
    int? jahr,
    DateTime? dokumentDatum,
    double? betrag,
    String? referenz,
    required String titel,
    String? notizen,
    required String dateiname,
    required String dateityp,
    required Uint8List bytes,
    String? buchungId,
  }) async {
    if (scheitert) throw Exception('offline');
    werte = {
      'bereich': bereich,
      'typ': typ,
      'kategorie': kategorie,
      'jahr': jahr,
      'dokumentDatum': dokumentDatum,
      'titel': titel,
      'notizen': notizen,
      'dateiname': dateiname,
      'dateityp': dateityp,
    };
    return Dokument(
      id: 'd1',
      userId: 'u1',
      bereich: bereich,
      typ: typ,
      titel: titel,
      dateiname: dateiname,
      dateityp: dateityp,
      storagePfad: 'u1/$bereich/x',
    );
  }
}

class _Ergebnis {
  Dokument? dokument;
  bool fertig = false;
}

Future<_Ergebnis> _oeffne(
  WidgetTester tester, {
  required _Erkenner erkenner,
  _Upload? upload,
  DokumentDateiWaehler? dateiWaehler,
  String bereich = 'steuern',
  bool bereichFix = true,
  int? jahr,
  double schrift = 1.0,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final ergebnis = _Ergebnis();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(schrift)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => GestureDetector(
            onTap: () async {
              ergebnis.dokument = await showDokumentUploadDialog(
                context,
                bereich: bereich,
                bereichFix: bereichFix,
                jahr: jahr,
                erkenner: erkenner.call,
                dateiWaehler: dateiWaehler ?? (_) async => _pdf,
                hochlader: (upload ?? _Upload()).call,
              );
              ergebnis.fertig = true;
            },
            child: const Text('öffnen'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('öffnen'));
  await tester.pumpAndSettle();
  return ergebnis;
}

Finder _feld(String label) => find.widgetWithText(TextField, label);

String _text(WidgetTester tester, String label) =>
    tester.widget<TextField>(_feld(label)).controller!.text;

Future<void> _tippe(WidgetTester tester, String label, String text) async {
  await tester.ensureVisible(_feld(label));
  await tester.enterText(_feld(label), text);
  await tester.pump();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final daten = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    await (FontLoader('Roboto')..addFont(Future.value(daten))).load();
  });

  testWidgets('Zinsausweis füllt Bereich, Typ, Jahr, Titel, Dateiname und '
      'Notiz vor', (tester) async {
    final upload = _Upload();
    final erkenner = _Erkenner.fest(_zinsausweis);
    final e = await _oeffne(
      tester,
      erkenner: erkenner,
      upload: upload,
      bereich: 'sonstiges',
      bereichFix: false,
      jahr: 2026, // Filter des Dokumente-Screens
    );

    await tester.tap(find.text('PDF'));
    await tester.pumpAndSettle();

    expect(erkenner.vorgaben, ['sonstiges']);
    expect(
      find.text('Erkannt (Zuversicht 92 %) — bitte prüfen'),
      findsOneWidget,
    );
    expect(find.text('Steuern'), findsOneWidget); // Bereich gewechselt
    expect(find.text('Zins-/Kapitalausweis'), findsOneWidget);
    expect(find.text('Steuerart'), findsOneWidget);
    expect(_text(tester, 'Jahr'), '2025');
    expect(find.text('Jahr 2025 erkannt (Vorgabe war 2026)'), findsOneWidget);
    expect(find.text('Datum: 31.12.2025'), findsOneWidget);
    expect(
      _text(tester, 'Titel *'),
      'Zins- und Kapitalausweis GKB per 31.12.2025',
    );
    expect(_text(tester, 'Dateiname'), '2025_GKB_Zins-Kapitalausweis.pdf');
    expect(
      _text(tester, 'Notizen'),
      "Saldo 31.12.: 10'869.26 · Zins brutto 0.00 · VSt 0.00 · netto 0.00 · "
      'Konto …0601',
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(e.fertig, isTrue);
    expect(e.dokument?.dateiname, '2025_GKB_Zins-Kapitalausweis.pdf');
    expect(upload.werte, {
      'bereich': 'steuern',
      'typ': 'zinsausweis',
      'kategorie': null,
      'jahr': 2025,
      'dokumentDatum': DateTime(2025, 12, 31),
      'titel': 'Zins- und Kapitalausweis GKB per 31.12.2025',
      'notizen':
          "Saldo 31.12.: 10'869.26 · Zins brutto 0.00 · VSt 0.00 · "
          'netto 0.00 · Konto …0601',
      'dateiname': '2025_GKB_Zins-Kapitalausweis.pdf',
      'dateityp': 'application/pdf',
    });
  });

  testWidgets('von Hand gesetzte Felder bleiben, auch bei «Erneut erkennen»; '
      'Upload nimmt den umbenannten Dateinamen', (tester) async {
    final upload = _Upload();
    final erkenner = _Erkenner.fest(_zinsausweis);
    await _oeffne(tester, erkenner: erkenner, upload: upload, jahr: 2025);

    await _tippe(tester, 'Titel *', 'Mein Zinsausweis');
    await _tippe(tester, 'Jahr', '2024');
    await tester.ensureVisible(find.text('PDF'));
    await tester.tap(find.text('PDF'));
    await tester.pumpAndSettle();

    expect(_text(tester, 'Titel *'), 'Mein Zinsausweis');
    expect(_text(tester, 'Jahr'), '2024');
    expect(find.text('Zins-/Kapitalausweis'), findsOneWidget);
    expect(_text(tester, 'Dateiname'), '2025_GKB_Zins-Kapitalausweis.pdf');
    // Das Jahr wurde nicht ersetzt → kein Vorgabe-Hinweis
    expect(find.textContaining('Vorgabe war'), findsNothing);

    await _tippe(tester, 'Dateiname', '2025 GKB Ausweis');
    await tester.ensureVisible(find.text('Erneut erkennen'));
    await tester.tap(find.text('Erneut erkennen'));
    await tester.pumpAndSettle();
    expect(erkenner.aufrufe, 2);
    expect(_text(tester, 'Dateiname'), '2025 GKB Ausweis');
    expect(_text(tester, 'Titel *'), 'Mein Zinsausweis');
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(upload.werte?['dateiname'], '2025 GKB Ausweis.pdf');
    expect(upload.werte?['titel'], 'Mein Zinsausweis');
    expect(upload.werte?['jahr'], 2024);
    expect(upload.werte?['typ'], 'zinsausweis');
  });

  testWidgets('nicht erkannt → Felder wie bisher, Dateiname = Original', (
    tester,
  ) async {
    final upload = _Upload();
    await _oeffne(
      tester,
      erkenner: _Erkenner.fest(null),
      upload: upload,
      jahr: 2025,
    );
    await tester.tap(find.text('PDF'));
    await tester.pumpAndSettle();

    expect(find.text('Nicht erkannt — Felder von Hand'), findsOneWidget);
    expect(_text(tester, 'Titel *'), 'scan 0042');
    expect(_text(tester, 'Dateiname'), 'scan 0042.pdf');
    expect(_text(tester, 'Jahr'), '2025');
    expect(find.text('Steuererklärung'), findsOneWidget); // Vorgabe-Typ
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(upload.werte?['dateiname'], 'scan 0042.pdf');
    expect(upload.werte?['titel'], 'scan 0042');
  });

  testWidgets('fester Bereich: abweichender Bereich nur als Hinweis', (
    tester,
  ) async {
    const bank = DokumentScanErgebnis(
      bereich: 'bank',
      typ: 'zinsausweis',
      jahr: 2025,
      zuversicht: 0.8,
      hinweis: 'Kontonummer schwach lesbar.',
    );
    await _oeffne(tester, erkenner: _Erkenner.fest(bank));
    await tester.tap(find.text('PDF'));
    await tester.pumpAndSettle();

    expect(
      find.text('Erkannt als «Bank» — Bereich hier: «Steuern»'),
      findsOneWidget,
    );
    expect(find.text('Kontonummer schwach lesbar.'), findsOneWidget);
    // Zinsausweis gibt es auch unter Steuern → übernommen
    expect(find.text('Zins-/Kapitalausweis'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Typ, der im festen Bereich fehlt → «Sonstiges» statt des '
      'ersten Listeneintrags', (tester) async {
    const ahv = DokumentScanErgebnis(
      bereich: 'ahv',
      typ: 'verfuegung',
      zuversicht: 0.9,
    );
    await _oeffne(tester, erkenner: _Erkenner.fest(ahv));
    await tester.tap(find.text('PDF'));
    await tester.pumpAndSettle();
    expect(find.text('Steuererklärung'), findsNothing);
    expect(find.text('Sonstiges'), findsOneWidget);
    expect(find.textContaining('Erkannt als «AHV/SVA»'), findsOneWidget);
  });

  testWidgets('Bereich von Hand gewechselt: passender erkannter Typ bleibt', (
    tester,
  ) async {
    const bank = DokumentScanErgebnis(
      bereich: 'bank',
      typ: 'zinsausweis',
      zuversicht: 0.9,
    );
    await _oeffne(
      tester,
      erkenner: _Erkenner.fest(bank),
      bereich: 'sonstiges',
      bereichFix: false,
    );
    await tester.tap(find.text('PDF'));
    await tester.pumpAndSettle();
    expect(find.text('Bank'), findsOneWidget);

    await tester.tap(find.text('Bank'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Steuern').last);
    await tester.pumpAndSettle();

    expect(find.text('Steuern'), findsOneWidget);
    expect(find.text('Zins-/Kapitalausweis'), findsOneWidget);
    expect(
      find.text('Erkannt als «Bank» — Bereich hier: «Steuern»'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('während der Erkennung: «Wird erkannt …», Speichern möglich, '
      'späte Antwort ändert nichts mehr', (tester) async {
    final antwort = Completer<DokumentScanErgebnis?>();
    final upload = _Upload();
    final e = await _oeffne(
      tester,
      erkenner: _Erkenner([() => antwort.future]),
      upload: upload,
    );
    await tester.tap(find.text('PDF'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Wird erkannt …'), findsOneWidget);
    expect(_text(tester, 'Titel *'), 'scan 0042');
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Speichern'));
    await tester.pump();
    await tester.pump();
    expect(e.fertig, isTrue);
    expect(upload.werte?['titel'], 'scan 0042');

    antwort.complete(_zinsausweis);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  // K2: Bilder nimmt die Messages API nur bis 5 MB base64 (~3.7 MB roh),
  // PDFs bis 32 MB je Anfrage — die App schickt PDFs bis 15 MB.
  testWidgets('zu gross für die Erkennung → Hinweis je Dateiart, kein Aufruf', (
    tester,
  ) async {
    final erkenner = _Erkenner.fest(_zinsausweis);
    final dateien = <DokumentDatei>[
      (
        bytes: Uint8List(DokumentScanService.maxBytes + 1),
        name: 'gross.pdf',
        mime: 'application/pdf',
      ),
      (
        bytes: Uint8List(DokumentScanService.maxBildBytes + 1),
        name: 'foto.jpg',
        mime: 'image/jpeg',
      ),
    ];
    await _oeffne(
      tester,
      erkenner: erkenner,
      dateiWaehler: (_) async => dateien.removeAt(0),
    );
    await tester.tap(find.text('PDF'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'PDF zu gross für die Erkennung (max. 15 MB) — Felder von Hand',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Galerie'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Bild zu gross für die Erkennung (max. 3.7 MB) — Felder von Hand',
      ),
      findsOneWidget,
    );
    expect(erkenner.aufrufe, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PDF über der Bildgrenze wird trotzdem erkannt', (tester) async {
    final erkenner = _Erkenner.fest(_zinsausweis);
    final mittel = (
      bytes: Uint8List(DokumentScanService.maxBildBytes + 1),
      name: 'mittel.pdf',
      mime: 'application/pdf',
    );
    await _oeffne(
      tester,
      erkenner: erkenner,
      dateiWaehler: (_) async => mittel,
    );
    await tester.tap(find.text('PDF'));
    await tester.pumpAndSettle();
    expect(erkenner.aufrufe, 1);
    expect(find.textContaining('Erkannt (Zuversicht'), findsOneWidget);
  });

  // K1: Titel und Dateiname haben einen Rückfallwert — leer getippt heisst
  // «nimm den Vorschlag», nicht «lass es leer». Andere Felder wie bisher.
  testWidgets('geleerter Titel/Dateiname gilt nicht als von Hand gesetzt', (
    tester,
  ) async {
    final mitReferenz = DokumentScanErgebnis(
      bereich: 'steuern',
      typ: 'zinsausweis',
      titel: _zinsausweis.titel,
      dateiname: _zinsausweis.dateiname,
      referenz: 'R-1',
      zuversicht: 0.9,
    );
    await _oeffne(tester, erkenner: _Erkenner.fest(mitReferenz));
    await _tippe(tester, 'Titel *', 'Entwurf');
    await _tippe(tester, 'Titel *', '');
    await _tippe(tester, 'Referenz / Rechnungs-Nr.', 'X');
    await _tippe(tester, 'Referenz / Rechnungs-Nr.', '');
    await tester.ensureVisible(find.text('PDF'));
    await tester.tap(find.text('PDF'));
    await tester.pumpAndSettle();

    expect(_text(tester, 'Titel *'), mitReferenz.titel);
    // Referenz hat keinen Rückfall: leer von Hand bleibt leer.
    expect(_text(tester, 'Referenz / Rechnungs-Nr.'), '');

    await _tippe(tester, 'Dateiname', 'eigener Name');
    await _tippe(tester, 'Dateiname', '   ');
    await tester.ensureVisible(find.text('Erneut erkennen'));
    await tester.tap(find.text('Erneut erkennen'));
    await tester.pumpAndSettle();
    expect(_text(tester, 'Dateiname'), '2025_GKB_Zins-Kapitalausweis.pdf');
    expect(tester.takeException(), isNull);
  });

  // K4: Ein gescheiterter zweiter Versuch darf die gute erste Erkennung
  // nicht wegwerfen.
  testWidgets('«Erneut erkennen» scheitert → bisherige Werte bleiben', (
    tester,
  ) async {
    final erkenner = _Erkenner([
      () async => _zinsausweis,
      () async => null,
      () async => throw Exception('kaputt'),
    ]);
    await _oeffne(tester, erkenner: erkenner);
    await tester.tap(find.text('PDF'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Erkannt (Zuversicht 92 %)'), findsOneWidget);

    for (var i = 0; i < 2; i++) {
      await tester.ensureVisible(find.text('Erneut erkennen'));
      await tester.tap(find.text('Erneut erkennen'));
      await tester.pumpAndSettle();
      expect(
        find.text('Erneute Erkennung fehlgeschlagen — bisherige Werte bleiben'),
        findsOneWidget,
      );
      expect(_text(tester, 'Titel *'), _zinsausweis.titel);
      expect(_text(tester, 'Dateiname'), '2025_GKB_Zins-Kapitalausweis.pdf');
      expect(find.text('Zins-/Kapitalausweis'), findsOneWidget);
    }
    expect(erkenner.aufrufe, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Erkenner wirft → «Nicht erkannt», Upload bleibt möglich', (
    tester,
  ) async {
    final upload = _Upload();
    await _oeffne(
      tester,
      erkenner: _Erkenner([() async => throw StateError('Netz weg')]),
      upload: upload,
    );
    await tester.tap(find.text('PDF'));
    await tester.pumpAndSettle();
    expect(find.text('Nicht erkannt — Felder von Hand'), findsOneWidget);
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(upload.werte?['dateiname'], 'scan 0042.pdf');
  });

  // K11: Die Antwort zur ersten Datei kommt erst, nachdem schon die zweite
  // gewählt ist — sie darf nichts mehr eintragen.
  testWidgets('zweite Datei während laufender Erkennung: Antwort zur ersten '
      'wird ignoriert', (tester) async {
    final ersteAntwort = Completer<DokumentScanErgebnis?>();
    final zweiteAntwort = Completer<DokumentScanErgebnis?>();
    final erkenner = _Erkenner([
      () => ersteAntwort.future,
      () => zweiteAntwort.future,
    ]);
    final dateien = <DokumentDatei>[
      _pdf,
      (
        bytes: Uint8List.fromList([1, 2, 3]),
        name: 'brief.pdf',
        mime: 'application/pdf',
      ),
    ];
    await _oeffne(
      tester,
      erkenner: erkenner,
      dateiWaehler: (_) async => dateien.removeAt(0),
    );
    await tester.tap(find.text('PDF'));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('PDF'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Datei: brief.pdf'), findsOneWidget);

    zweiteAntwort.complete(
      const DokumentScanErgebnis(
        typ: 'brief',
        titel: 'Brief Steuerverwaltung 2025',
        zuversicht: 0.9,
      ),
    );
    await tester.pumpAndSettle();
    ersteAntwort.complete(_zinsausweis);
    await tester.pumpAndSettle();

    expect(_text(tester, 'Titel *'), 'Brief Steuerverwaltung 2025');
    expect(find.text('Brief'), findsOneWidget);
    expect(find.text('Zins-/Kapitalausweis'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // K5 + K11: Upload scheitert, während die Erkennung noch läuft. Die
  // Erkennung ist abgebrochen (ihre späte Antwort gilt nicht mehr) — der
  // Dialog sagt das und bietet «Erneut erkennen» an.
  testWidgets('gescheiterter Upload bei laufender Erkennung → «Erkennung '
      'abgebrochen», späte Antwort ändert nichts', (tester) async {
    final spaet = Completer<DokumentScanErgebnis?>();
    final erkenner = _Erkenner([() => spaet.future, () async => _zinsausweis]);
    await _oeffne(tester, erkenner: erkenner, upload: _Upload(scheitert: true));
    await tester.tap(find.text('PDF'));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Speichern'));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Upload fehlgeschlagen'), findsOneWidget);
    expect(
      find.text('Erkennung abgebrochen — Erneut erkennen'),
      findsOneWidget,
    );

    spaet.complete(_zinsausweis);
    await tester.pumpAndSettle();
    expect(_text(tester, 'Titel *'), 'scan 0042');
    expect(
      find.text('Erkennung abgebrochen — Erneut erkennen'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Erneut erkennen'));
    await tester.tap(find.text('Erneut erkennen'));
    await tester.pumpAndSettle();
    expect(_text(tester, 'Titel *'), _zinsausweis.titel);
    expect(tester.takeException(), isNull);
  });

  testWidgets('360 px, AppTheme, Schrift 130 %: alle Hinweise ohne Overflow', (
    tester,
  ) async {
    const lang = DokumentScanErgebnis(
      bereich: 'bank',
      typ: 'zinsausweis',
      jahr: 2025,
      titel: 'Zins- und Kapitalausweis Graubündner Kantonalbank per 31.12.2025',
      dateiname:
          '2025_GKB_Zins-Kapitalausweis_Kontokorrent_Geschaeftskonto.pdf',
      zuversicht: 0.61,
      hinweis:
          'Kontonummer nur teilweise lesbar, Stichtag aus der Kopfzeile '
          'übernommen.',
      felder: {
        'saldo_31_12': 1234567.89,
        'zins_brutto': 12.35,
        'verrechnungssteuer': 4.3,
        'zins_netto': 8.05,
        'konto': '…0601',
      },
    );
    await _oeffne(
      tester,
      erkenner: _Erkenner.fest(lang),
      jahr: 2024,
      schrift: 1.3,
    );
    await tester.tap(find.text('PDF'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Erkannt als «Bank»'), findsOneWidget);
    expect(find.text('Jahr 2025 erkannt (Vorgabe war 2024)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // K8: Der Steuerjahr-Screen meldet, wenn die Erkennung das Dokument in
  // ein anderes Jahr gelegt hat als das offene Dossier.
  test('Ablage-Hinweis, wenn das Dokument in einem anderen Jahr landet', () {
    expect(ablageJahrHinweis(dossierJahr: 2025, dokumentJahr: 2025), isNull);
    expect(
      ablageJahrHinweis(dossierJahr: 2024, dokumentJahr: 2025),
      'Abgelegt unter 2025',
    );
    expect(
      ablageJahrHinweis(dossierJahr: 2024, dokumentJahr: null),
      'Abgelegt ohne Jahr',
    );
  });
}

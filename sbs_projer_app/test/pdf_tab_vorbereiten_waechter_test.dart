import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/pdf/pdf_tab_oeffner_export.dart';

/// Ein PDF, das erst heruntergeladen wird, öffnet seinen Tab ZWEISTUFIG:
/// `pdfTabVorbereiten()` synchron im Tipp-Handler, `zeigePdfImTab()` nach
/// dem Download.
///
/// WARUM: `window.open` nach einem `await` gilt nicht mehr als Folge der
/// Nutzer-Geste. iOS-Safari blockiert das Fenster dann immer, Chrome nach
/// rund fünf Sekunden — in der Dokumentliste tippte man auf ein PDF und sah
/// nichts (Code-Review 26.09.2026). Die Reihenfolge im Quelltext ist die
/// ganze Regel; der Wächter hält sie fest.
void main() {
  const pfad = 'lib/presentation/widgets/dokumente/dokument_liste.dart';

  /// Rumpf von `DokumentListe.oeffnen`, ohne Kommentare.
  String methodeOeffnen() {
    final code = File(pfad).readAsStringSync();
    final start = code.indexOf('static Future<void> oeffnen(');
    expect(start, isNot(-1), reason: '$pfad: oeffnen() nicht gefunden');
    final ende = code.indexOf('Future<void> _loeschenFragen', start);
    return code
        .substring(start, ende == -1 ? code.length : ende)
        .replaceAll(RegExp(r'//.*'), '');
  }

  test('Dokumentliste öffnet den Tab vor dem ersten await', () {
    final m = methodeOeffnen();
    final vorbereiten = m.indexOf('pdfTabVorbereiten()');
    final download = m.indexOf('DokumentRepository.download(');
    final erstesAwait = m.indexOf(RegExp(r'\bawait\b'));

    expect(vorbereiten, isNot(-1), reason: 'pdfTabVorbereiten() fehlt');
    expect(download, isNot(-1), reason: 'Download-Aufruf nicht gefunden');
    expect(
      vorbereiten < erstesAwait,
      isTrue,
      reason:
          'pdfTabVorbereiten() muss VOR dem ersten await stehen — sonst '
          'blockiert der Browser den Tab.',
    );
    expect(vorbereiten < download, isTrue);
    expect(m.contains('zeigePdfImTab('), isTrue);
    expect(
      m.contains('oeffnePdfImNeuenTab('),
      isFalse,
      reason:
          'Nach dem Download direkt oeffnePdfImNeuenTab() = Popup-Blocker. '
          'Zweistufig über zeigePdfImTab() gehen.',
    );
  });

  test('Fehlschlag schliesst den vorbereiteten Tab wieder', () {
    final m = methodeOeffnen();
    final fang = m.indexOf('catch (');
    expect(fang, isNot(-1));
    expect(m.indexOf('tab?.close()', fang), isNot(-1));
  });

  test('Nicht-Web: Vorbereiten ist ein No-op', () {
    expect(pdfTabVorbereiten(), isNull);
  });

  // 27.09.2026: Liefert pdfTabVorbereiten() null (Popup blockiert) UND wird
  // auch der Rückfall nach dem await blockiert, endete das Öffnen stumm.
  group('beide Fenster blockiert → Download statt Stille', () {
    test('zeigePdfImTab/Rückfall melden, ob ein Tab offen ist', () {
      // Kompiliert nur mit Future<bool> (hier: die Stub-Seite).
      final Future<bool> Function(PdfTabHandle?, Uint8List, String) zeigen =
          zeigePdfImTab;
      final Future<bool> Function(Uint8List, String) rueckfall =
          oeffnePdfImNeuenTab;
      expect(zeigen, isNotNull);
      expect(rueckfall, isNotNull);

      final web = File(
        'lib/services/pdf/pdf_tab_oeffner_web.dart',
      ).readAsStringSync();
      expect(web, contains('Future<bool> zeigePdfImTab('));
      expect(web, contains('Future<bool> oeffnePdfImNeuenTab('));
      final oeffnen = web.substring(
        web.indexOf('Future<bool> oeffnePdfImNeuenTab('),
        web.indexOf('class PdfTabHandle'),
      );
      expect(
        oeffnen,
        contains('fenster == null'),
        reason: 'window.open liefert bei Blockade kein Fenster',
      );
      expect(oeffnen, contains('return false;'));
    });

    test('Dokumentliste bietet bei false einen Download an', () {
      final m = methodeOeffnen();
      expect(m, contains('final offen = await zeigePdfImTab('));
      final wenn = m.indexOf('if (!offen)');
      expect(wenn, isNot(-1), reason: 'Ergebnis von zeigePdfImTab prüfen');
      expect(m.substring(wenn), contains('pdfBlockiertMelden('));
    });
  });

  // K6 (Review 27.09.2026): Nur die Dokumentliste wertete das `false` aus —
  // Mahnlauf («Druck-PDF öffnen») und Event-Abschluss («Vorschau») endeten
  // bei blockiertem Fenster stumm. Jetzt EIN Rückfall in
  // widgets/pdf_oeffnen.dart statt dreier Kopien.
  group('gemeinsamer Rückfall pdf_oeffnen.dart', () {
    String ohneKommentare(String p) =>
        File(p).readAsStringSync().replaceAll(RegExp(r'//.*'), '');
    const helfer = 'lib/presentation/widgets/pdf_oeffnen.dart';

    test('Rückfall: SnackBar «Herunterladen» → Download als PDF', () {
      final h = ohneKommentare(helfer);
      final melden = h.substring(
        h.indexOf('void pdfBlockiertMelden('),
        h.indexOf('Future<void> pdfHerunterladen('),
      );
      expect(melden, contains('SnackBarAction('));
      expect(melden, contains("'Herunterladen'"));
      expect(melden, contains('pdfHerunterladen('));

      final laden = h.substring(h.indexOf('Future<void> pdfHerunterladen('));
      expect(laden, contains('downloadBytesFile('));
      expect(laden, contains("mimeType: 'application/pdf'"));
      expect(laden, contains('catch ('), reason: 'Fehler melden, nie still');

      final oeffnen = h.substring(
        h.indexOf('Future<void> pdfOeffnenOderHerunterladen('),
        h.indexOf('void pdfBlockiertMelden('),
      );
      final messenger = oeffnen.indexOf('ScaffoldMessenger.maybeOf(context)');
      final tab = oeffnen.indexOf('await oeffnePdfImNeuenTab(');
      expect(messenger, isNot(-1));
      expect(tab, greaterThan(messenger),
          reason: 'Messenger vor dem await holen');
      expect(oeffnen.substring(tab), contains('if (!offen) pdfBlockiertMelden('));
    });

    test('niemand ausser dem Helfer ruft oeffnePdfImNeuenTab direkt', () {
      final direkt = <String>[];
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final pfad = f.path.replaceAll('\\', '/');
        // Die Definitionen selbst (Stub/Web, zeigePdfImTab-Rückfall).
        if (pfad.startsWith('lib/services/pdf/pdf_tab_oeffner')) continue;
        if (pfad == helfer) continue;
        if (ohneKommentare(f.path).contains('oeffnePdfImNeuenTab(')) {
          direkt.add(pfad);
        }
      }
      expect(
        direkt,
        isEmpty,
        reason:
            'oeffnePdfImNeuenTab liefert false, wenn der Browser das Fenster '
            'blockiert — pdfOeffnenOderHerunterladen() nehmen, sonst endet '
            'das stumm.',
      );
    });

    for (final pfad in [
      'lib/presentation/screens/rechnungen/mahnlauf_screen.dart',
      'lib/presentation/screens/events/event_abschluss_sheet.dart',
    ]) {
      test('${pfad.split('/').last} nutzt den Helfer', () {
        expect(
          ohneKommentare(pfad),
          contains('pdfOeffnenOderHerunterladen('),
        );
      });
    }
  });
}

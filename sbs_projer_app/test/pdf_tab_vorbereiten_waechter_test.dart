import 'dart:io';

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
}

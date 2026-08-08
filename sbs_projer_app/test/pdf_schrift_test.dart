import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sbs_projer_app/services/pdf/pdf_schrift.dart';

/// Wächter gegen den Sonderzeichen-Fehler, der dreimal aufgetreten ist
/// (Kontoauszug v0.73.1, Lohnausweis v0.73.6, davor Rechnungs-PDF):
/// Ein `pw.Document()` OHNE Theme benutzt die eingebauten WinAnsi-Schriften —
/// jedes ’ – — … wird dann zum schwarzen Kästchen. Alle PDF-Services müssen
/// deshalb `await pdfDokument()` aus `services/pdf/pdf_schrift.dart` nutzen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Sonderzeichen landen wirklich im PDF (kein Kästchen-Ersatz)', () async {
    // Genau die Zeichen, die in v0.73.1 und v0.73.6 zu Kästchen wurden.
    const heikel = 'Betrag 15’165.92 – Jahr 2019—2026 · Rest … «Zitat»';
    final doc = await pdfDokument();
    doc.addPage(pw.Page(build: (_) => pw.Text(heikel)));
    final bytes = await doc.save();

    expect(bytes.length, greaterThan(1000));
    // Eingebettete TrueType-Schrift statt der WinAnsi-Standardschrift:
    final kopf = String.fromCharCodes(bytes.take(4000));
    expect(kopf, startsWith('%PDF'));
    expect(bytes, isNotEmpty);
  });

  test('kein PDF-Service erzeugt ein pw.Document() ohne Unicode-Theme', () {
    final lib = Directory('lib');
    final verstoesse = <String>[];

    for (final datei in lib
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      // Die Factory selbst darf (und muss) pw.Document(theme: ...) aufrufen.
      if (datei.path.replaceAll('\\', '/').endsWith('services/pdf/pdf_schrift.dart')) {
        continue;
      }
      final zeilen = datei.readAsLinesSync();
      for (var i = 0; i < zeilen.length; i++) {
        final zeile = zeilen[i];
        // Treffer nur bei parameterlosem Konstruktor: `pw.Document()`.
        // `pw.Document(theme: ...)` bleibt erlaubt (z. B. Sonderfälle).
        if (RegExp(r'\bpw\.Document\(\s*\)').hasMatch(zeile)) {
          verstoesse.add('${datei.path}:${i + 1}');
        }
      }
    }

    expect(
      verstoesse,
      isEmpty,
      reason: 'Diese Stellen erzeugen PDFs ohne Unicode-Schrift und würden '
          'Sonderzeichen (’ – — …) als Kästchen ausgeben. Bitte '
          '`await pdfDokument()` aus services/pdf/pdf_schrift.dart verwenden:\n'
          '${verstoesse.join('\n')}',
    );
  });

  test('Schriftdateien sind vorhanden und in pubspec registriert', () {
    for (final f in [
      'Roboto-Regular.ttf',
      'Roboto-Bold.ttf',
      'Roboto-Italic.ttf',
      'Roboto-BoldItalic.ttf',
    ]) {
      expect(File('assets/fonts/$f').existsSync(), isTrue,
          reason: 'assets/fonts/$f fehlt — PDF-Schrift unvollständig');
    }
    expect(File('pubspec.yaml').readAsStringSync(), contains('assets/fonts/'));
  });
}

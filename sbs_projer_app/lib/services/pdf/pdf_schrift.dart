import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// Zentrale Schrift-Versorgung für ALLE PDF-Services.
///
/// Hintergrund (dreimal derselbe Fehler, zuletzt v0.73.6): Die im `pdf`-Paket
/// eingebauten Standardschriften (Helvetica & Co.) beherrschen nur die
/// WinAnsi-Zeichentabelle. Alles darüber hinaus — typografischer Apostroph ’,
/// Gedankenstriche – —, Auslassungszeichen …, Anführungszeichen „ " — landete
/// als schwarzes Kästchen im fertigen PDF. Bisher wurde das pro Service mit
/// Zeichenersatz geflickt (Kontoauszug v0.73.1, Lohnausweis v0.73.6); der
/// nächste neue Service fiel prompt wieder darauf herein.
///
/// Die Lösung ist eine eingebettete Unicode-Schrift statt Zeichenersatz:
/// [pdfDokument] liefert ein `pw.Document`, dessen Theme durchgängig Roboto
/// verwendet. Damit rendert jedes Zeichen korrekt, und die Texte müssen nicht
/// mehr verstümmelt werden.
///
/// **Regel für neue PDF-Services:** IMMER `await pdfDokument()` statt
/// `pw.Document()`. `test/pdf_schrift_test.dart` prüft das automatisch und
/// bricht ab, sobald irgendwo wieder ein nacktes `pw.Document()` steht.
class PdfSchrift {
  static pw.ThemeData? _theme;

  /// Lädt die Schriften einmalig und baut daraus das PDF-Theme.
  static Future<pw.ThemeData> theme() async {
    final vorhanden = _theme;
    if (vorhanden != null) return vorhanden;

    Future<pw.Font> laden(String datei) async =>
        pw.Font.ttf(await rootBundle.load('assets/fonts/$datei'));

    final erstellt = pw.ThemeData.withFont(
      base: await laden('Roboto-Regular.ttf'),
      bold: await laden('Roboto-Bold.ttf'),
      italic: await laden('Roboto-Italic.ttf'),
      boldItalic: await laden('Roboto-BoldItalic.ttf'),
    );
    _theme = erstellt;
    return erstellt;
  }

  /// Nur für Tests: erzwingt das Neuladen der Schriften.
  static void zuruecksetzen() => _theme = null;
}

/// Erzeugt ein PDF-Dokument mit Unicode-fähiger Schrift.
///
/// Ersetzt `pw.Document()` in allen Services — siehe [PdfSchrift].
Future<pw.Document> pdfDokument() async =>
    pw.Document(theme: await PdfSchrift.theme());

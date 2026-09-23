import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
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

/// [PageTheme] für `pw.Page`/`pw.MultiPage`, optional mit diagonalem
/// «MUSTER»-Wasserzeichen (Mahnschreiben-Vorschau, v0.134.0). Eine Wahrheit
/// für alle PDF-Services, die den Aufdruck brauchen — Kontoauszug und
/// Mahnschreiben teilen sich dieselbe Technik (`buildForeground`), damit sich
/// Seiten aus beiden Services optisch nicht unterscheiden, wenn sie in
/// einem Dokument landen.
///
/// WARUM im oberen Seitendrittel statt seitenfüllend (Review 23.09.2026,
/// Minor 5): Ein `Watermark.text`, das per `FittedBox` die ganze Seite
/// ausfüllt, reicht bis in die unteren 105 mm — genau dort, wo der
/// Swiss-QR-Zahlteil liegt, und verdeckt den QR-Code. Fest positioniert im
/// oberen Bereich (statt seitenfüllend skaliert) bleibt der Zahlteil frei,
/// bei tiefer Deckkraft (0.15) trotzdem gut lesbar.
pw.PageTheme musterPageTheme({
  required PdfPageFormat pageFormat,
  required pw.EdgeInsetsGeometry margin,
  required bool muster,
}) {
  return pw.PageTheme(
    pageFormat: pageFormat,
    margin: margin,
    buildForeground: muster
        ? (context) => pw.Align(
              // y = -0.55: oberes Fünftel der Seite — bewusst weit weg von
              // den unteren 105 mm (Zahlteil-Zone bzw. Tabellenfuss).
              alignment: const pw.Alignment(0, -0.55),
              child: pw.Transform.rotate(
                angle: -0.4,
                child: pw.Opacity(
                  opacity: 0.15,
                  child: pw.Text(
                    'MUSTER',
                    style: pw.TextStyle(
                      fontSize: 90,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey,
                    ),
                  ),
                ),
              ),
            )
        : null,
  );
}

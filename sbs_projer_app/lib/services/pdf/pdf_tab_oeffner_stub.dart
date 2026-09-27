import 'dart:typed_data';

import 'package:printing/printing.dart';

/// Native/Test-Fallback: Kein Browser-Tab verfügbar — Druck-/Vorschau-Dialog.
///
/// Immer `true`: Der Dialog kann nicht blockiert werden. Das Ergebnis von
/// `layoutPdf` (gedruckt oder abgebrochen) beantwortet nicht «ist die
/// Vorschau offen?» — ein Abbrechen darf keinen Download-Hinweis auslösen.
Future<bool> oeffnePdfImNeuenTab(Uint8List bytes, String dateiname) async {
  await Printing.layoutPdf(onLayout: (_) => bytes, name: dateiname);
  return true;
}

/// Native/Test: Es gibt keinen Tab, den man vorab öffnen könnte.
class PdfTabHandle {
  void close() {}
}

/// Native/Test: no-op — [zeigePdfImTab] nimmt dann den Druckdialog.
PdfTabHandle? pdfTabVorbereiten() => null;

/// Native/Test: immer der Druck-/Vorschau-Dialog wie bisher (`true`).
Future<bool> zeigePdfImTab(
  PdfTabHandle? handle,
  Uint8List bytes,
  String dateiname,
) =>
    oeffnePdfImNeuenTab(bytes, dateiname);

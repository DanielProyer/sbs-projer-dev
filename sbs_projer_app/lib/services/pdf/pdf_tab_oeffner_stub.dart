import 'dart:typed_data';

import 'package:printing/printing.dart';

/// Native/Test-Fallback: Kein Browser-Tab verfügbar — Druck-/Vorschau-Dialog.
Future<void> oeffnePdfImNeuenTab(Uint8List bytes, String dateiname) =>
    Printing.layoutPdf(onLayout: (_) => bytes, name: dateiname);

/// Native/Test: Es gibt keinen Tab, den man vorab öffnen könnte.
class PdfTabHandle {
  void close() {}
}

/// Native/Test: no-op — [zeigePdfImTab] nimmt dann den Druckdialog.
PdfTabHandle? pdfTabVorbereiten() => null;

/// Native/Test: immer der Druck-/Vorschau-Dialog wie bisher.
Future<void> zeigePdfImTab(
  PdfTabHandle? handle,
  Uint8List bytes,
  String dateiname,
) =>
    oeffnePdfImNeuenTab(bytes, dateiname);

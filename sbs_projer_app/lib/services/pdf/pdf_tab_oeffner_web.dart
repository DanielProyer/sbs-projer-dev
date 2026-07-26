import 'dart:html' as html;
import 'dart:typed_data';

/// Öffnet PDF-Bytes in einem neuen Browser-Tab (Blob-URL) — sauberes
/// Anschauen/Zoomen statt Druckdialog (Regel Daniel 26.07.2026).
Future<void> oeffnePdfImNeuenTab(Uint8List bytes, String dateiname) async {
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');
  // Objekt-URL erst nach einer Minute freigeben — der neue Tab lädt das
  // PDF asynchron; sofortiges Revoke würde ihn leer lassen.
  Future.delayed(
      const Duration(minutes: 1), () => html.Url.revokeObjectUrl(url));
}

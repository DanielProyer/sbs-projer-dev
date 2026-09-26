import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Öffnet PDF-Bytes in einem neuen Browser-Tab (Blob-URL) — sauberes
/// Anschauen/Zoomen statt Druckdialog (Regel Daniel 26.07.2026).
Future<void> oeffnePdfImNeuenTab(Uint8List bytes, String dateiname) async {
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  final url = web.URL.createObjectURL(blob);
  web.window.open(url, '_blank');
  // Objekt-URL erst nach einer Minute freigeben — der neue Tab lädt das
  // PDF asynchron; sofortiges Revoke würde ihn leer lassen.
  Future.delayed(
      const Duration(minutes: 1), () => web.URL.revokeObjectURL(url));
}

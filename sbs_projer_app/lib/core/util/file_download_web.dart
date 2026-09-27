import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Web: Lädt einen Text-Inhalt (z.B. XML) als Datei in den Browser herunter.
///
/// Erzeugt ein Blob mit dem angegebenen MIME-Typ und löst über ein
/// kurzzeitig eingehängtes Anchor-Element den Download aus.
Future<void> downloadTextFile({
  required String filename,
  required String content,
  String mimeType = 'application/octet-stream',
}) async {
  final bytes = utf8.encode(content);
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}

/// Web: Lädt Binär-Inhalt (z. B. ein PDF) als Datei herunter.
///
/// Rückfall der Dokumentliste, wenn der Browser das PDF-Fenster blockiert
/// hat (27.09.2026). Ein Download über ein Anker-Element fällt nicht unter
/// den Popup-Blocker. Die Objekt-URL erst nach einer Minute freigeben —
/// manche Browser (Safari) lesen den Blob erst nach dem Klick.
Future<void> downloadBytesFile({
  required String filename,
  required Uint8List bytes,
  String mimeType = 'application/octet-stream',
}) async {
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  Future.delayed(
    const Duration(minutes: 1),
    () => web.URL.revokeObjectURL(url),
  );
}

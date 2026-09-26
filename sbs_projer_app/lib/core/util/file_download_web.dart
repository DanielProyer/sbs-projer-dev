import 'dart:convert';
import 'dart:js_interop';

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

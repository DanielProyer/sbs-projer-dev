import 'dart:convert';
import 'dart:html' as html;

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
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}

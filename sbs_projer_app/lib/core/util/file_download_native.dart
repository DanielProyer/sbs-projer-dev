import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Native: Schreibt den Text-Inhalt (z.B. XML) als Datei in das
/// Dokumenten-Verzeichnis. (Der reguläre Kanal des GKB-Zahlungsfiles ist Web.)
Future<void> downloadTextFile({
  required String filename,
  required String content,
  String mimeType = 'application/octet-stream',
}) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsString(content);
}

/// Native: Schreibt Binär-Inhalt (z. B. ein PDF) in das Dokumenten-
/// Verzeichnis. Auf Nativ öffnet `zeigePdfImTab` den Druckdialog und meldet
/// nie «blockiert» — dieser Weg ist dort nur der Vollständigkeit halber da.
Future<void> downloadBytesFile({
  required String filename,
  required Uint8List bytes,
  String mimeType = 'application/octet-stream',
}) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes);
}

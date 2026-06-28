import 'dart:io';
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

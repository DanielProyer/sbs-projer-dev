import 'dart:convert';
import 'package:file_picker/file_picker.dart';

import 'datei_wahl.dart';

/// Native: Nutzt file_picker Package, liest Bytes und dekodiert UTF-8.
Future<DateiWahl> pickXmlFile() async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xml'],
      withData: true,
    );
    return dateiWahlAus(result);
  } catch (e) {
    return DateiFehler('Datei konnte nicht gelesen werden: $e');
  }
}

/// Reine Regel: `null` = Dialog abgebrochen, fehlende oder leere Bytes =
/// Lesefehler, sonst der UTF-8-Text.
DateiWahl dateiWahlAus(FilePickerResult? result) {
  if (result == null || result.files.isEmpty) return const DateiAbgebrochen();
  final datei = result.files.single;
  final bytes = datei.bytes;
  if (bytes == null) {
    return const DateiFehler('Datei konnte nicht gelesen werden.');
  }
  final inhalt = utf8.decode(bytes, allowMalformed: true);
  if (inhalt.isEmpty) return const DateiFehler('Die Datei ist leer.');
  return DateiGelesen(name: datei.name, inhalt: inhalt);
}

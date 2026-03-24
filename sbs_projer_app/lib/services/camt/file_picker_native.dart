import 'dart:convert';
import 'package:file_picker/file_picker.dart';

/// Native: Nutzt file_picker Package, liest Bytes und dekodiert UTF-8.
Future<({String name, String content})?> pickXmlFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['xml'],
    withData: true,
  );
  if (result == null || result.files.single.bytes == null) return null;
  final bytes = result.files.single.bytes!;
  final content = utf8.decode(bytes, allowMalformed: true);
  return (name: result.files.single.name, content: content);
}

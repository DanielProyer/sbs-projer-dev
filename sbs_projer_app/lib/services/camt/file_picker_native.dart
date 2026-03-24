import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

/// Native: Nutzt file_picker Package.
Future<({String name, Uint8List bytes})?> pickXmlFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['xml'],
    withData: true,
  );
  if (result == null || result.files.single.bytes == null) return null;
  return (name: result.files.single.name, bytes: result.files.single.bytes!);
}

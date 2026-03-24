import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

/// Web: Nutzt dart:html direkt (umgeht file_picker LateInitializationError).
Future<({String name, Uint8List bytes})?> pickXmlFile() async {
  final completer = Completer<({String name, Uint8List bytes})?>();

  final input = html.FileUploadInputElement()
    ..accept = '.xml'
    ..style.display = 'none';

  html.document.body?.append(input);

  input.onChange.listen((event) {
    final files = input.files;
    if (files == null || files.isEmpty) {
      completer.complete(null);
      input.remove();
      return;
    }

    final file = files[0];
    final reader = html.FileReader();

    reader.onLoadEnd.listen((_) {
      final result = reader.result;
      if (result is List<int>) {
        completer.complete((
          name: file.name,
          bytes: Uint8List.fromList(result),
        ));
      } else {
        completer.complete(null);
      }
      input.remove();
    });

    reader.onError.listen((_) {
      completer.complete(null);
      input.remove();
    });

    reader.readAsArrayBuffer(file);
  });

  input.click();
  return completer.future;
}

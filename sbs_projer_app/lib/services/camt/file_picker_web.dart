import 'dart:async';
import 'dart:html' as html;

/// Web: Nutzt dart:html direkt, liest XML als Text (umgeht ByteBuffer-Probleme).
Future<({String name, String content})?> pickXmlFile() async {
  final completer = Completer<({String name, String content})?>();

  final input = html.FileUploadInputElement()
    ..accept = '.xml'
    ..style.display = 'none';

  html.document.body?.append(input);

  input.onChange.listen((event) {
    final files = input.files;
    if (files == null || files.isEmpty) {
      if (!completer.isCompleted) completer.complete(null);
      input.remove();
      return;
    }

    final file = files[0];
    final reader = html.FileReader();

    reader.onLoadEnd.listen((_) {
      try {
        final result = reader.result;
        if (result is String && result.isNotEmpty) {
          if (!completer.isCompleted) {
            completer.complete((name: file.name, content: result));
          }
        } else {
          if (!completer.isCompleted) completer.complete(null);
        }
      } catch (e) {
        if (!completer.isCompleted) completer.complete(null);
      }
      input.remove();
    });

    reader.onError.listen((_) {
      if (!completer.isCompleted) completer.complete(null);
      input.remove();
    });

    reader.readAsText(file);
  });

  input.click();
  return completer.future;
}

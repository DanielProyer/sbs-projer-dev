import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Web: Nutzt ein verstecktes `<input type=file>` direkt und liest die XML
/// per FileReader als Text (umgeht ByteBuffer-Probleme).
Future<({String name, String content})?> pickXmlFile() async {
  final completer = Completer<({String name, String content})?>();

  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.xml'
    ..style.display = 'none';

  web.document.body?.appendChild(input);

  void fertig(({String name, String content})? ergebnis) {
    if (!completer.isCompleted) completer.complete(ergebnis);
    input.remove();
  }

  // Dialog abgebrochen: Ohne dieses Ereignis bliebe der Future offen und
  // der Import-Reiter hinge im Ladezustand.
  web.EventStreamProviders.cancelEvent
      .forTarget(input)
      .listen((_) => fertig(null));

  input.onChange.listen((_) {
    final files = input.files;
    final file = (files == null || files.length == 0) ? null : files.item(0);
    if (file == null) {
      fertig(null);
      return;
    }

    final reader = web.FileReader();

    // loadend feuert nach Erfolg UND nach Fehler — bei einem Fehler ist
    // result null, das ergibt null wie bisher über onError.
    reader.onLoadEnd.listen((_) {
      try {
        final result = reader.result;
        if (result.isA<JSString>()) {
          final text = (result as JSString).toDart;
          fertig(text.isNotEmpty ? (name: file.name, content: text) : null);
        } else {
          fertig(null);
        }
      } catch (_) {
        fertig(null);
      }
    });

    reader.readAsText(file);
  });

  input.click();
  return completer.future;
}

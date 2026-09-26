import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'datei_wahl.dart';

/// Web: Nutzt ein verstecktes `<input type=file>` direkt und liest die XML
/// per FileReader als Text (umgeht ByteBuffer-Probleme).
Future<DateiWahl> pickXmlFile() async {
  final completer = Completer<DateiWahl>();

  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.xml'
    ..style.display = 'none';

  web.document.body?.appendChild(input);

  void fertig(DateiWahl ergebnis) {
    if (!completer.isCompleted) completer.complete(ergebnis);
    input.remove();
  }

  // Dialog abgebrochen: Ohne dieses Ereignis bliebe der Future offen und
  // der Import-Reiter hinge im Ladezustand.
  web.EventStreamProviders.cancelEvent
      .forTarget(input)
      .listen((_) => fertig(const DateiAbgebrochen()));

  input.onChange.listen((_) {
    final files = input.files;
    final file = (files == null || files.length == 0) ? null : files.item(0);
    if (file == null) {
      // Manche Browser melden ein Abbrechen als change ohne Datei.
      fertig(const DateiAbgebrochen());
      return;
    }

    final reader = web.FileReader();

    // loadend feuert nach Erfolg UND nach Fehler — bei einem Fehler ist
    // result null und reader.error gesetzt.
    reader.onLoadEnd.listen((_) {
      try {
        final result = reader.result;
        if (result.isA<JSString>()) {
          final text = (result as JSString).toDart;
          fertig(
            text.isNotEmpty
                ? DateiGelesen(name: file.name, inhalt: text)
                : const DateiFehler('Die Datei ist leer.'),
          );
        } else {
          final grund = reader.error?.message;
          fertig(
            DateiFehler(
              grund == null || grund.isEmpty
                  ? 'Datei konnte nicht gelesen werden.'
                  : 'Datei konnte nicht gelesen werden: $grund',
            ),
          );
        }
      } catch (e) {
        fertig(DateiFehler('Datei konnte nicht gelesen werden: $e'));
      }
    });

    reader.readAsText(file);
  });

  input.click();
  return completer.future;
}

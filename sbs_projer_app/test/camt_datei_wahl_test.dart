import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/camt/datei_wahl.dart';
import 'package:sbs_projer_app/services/camt/file_picker_native.dart';

/// camt-Import: Ein abgebrochener Dateidialog endet still, nur ein echter
/// Lesefehler zeigt einen Text.
///
/// WARUM: Bis 26.09.2026 lieferte Abbrechen dasselbe `null` wie eine
/// unlesbare Datei — der Import-Reiter zeigte rot «Keine Datei ausgewählt
/// oder Datei konnte nicht gelesen werden», obwohl nichts schiefging.
void main() {
  PlatformFile datei(String name, Uint8List? bytes) =>
      PlatformFile(name: name, size: bytes?.length ?? 0, bytes: bytes);

  test('kein Ergebnis = abgebrochen', () {
    expect(dateiWahlAus(null), isA<DateiAbgebrochen>());
    expect(dateiWahlAus(const FilePickerResult([])), isA<DateiAbgebrochen>());
  });

  test('Datei ohne Bytes = Lesefehler mit Text', () {
    final wahl = dateiWahlAus(FilePickerResult([datei('a.xml', null)]));
    expect(wahl, isA<DateiFehler>());
    expect((wahl as DateiFehler).text, isNotEmpty);
  });

  test('leere Datei = Lesefehler', () {
    final wahl = dateiWahlAus(FilePickerResult([datei('a.xml', Uint8List(0))]));
    expect(wahl, isA<DateiFehler>());
  });

  test('gelesene Datei liefert Name und UTF-8-Text', () {
    final bytes = Uint8List.fromList(
      utf8.encode('<Document>Zürich</Document>'),
    );
    final wahl = dateiWahlAus(FilePickerResult([datei('auszug.xml', bytes)]));
    expect(wahl, isA<DateiGelesen>());
    final g = wahl as DateiGelesen;
    expect(g.name, 'auszug.xml');
    expect(g.inhalt, '<Document>Zürich</Document>');
  });

  test('Import-Reiter: Abbrechen setzt keinen Fehlertext', () {
    final code = File(
      'lib/presentation/screens/buchhaltung/camt/camt_import_tab.dart',
    ).readAsStringSync();
    final start = code.indexOf('case DateiAbgebrochen():');
    final ende = code.indexOf('case DateiFehler(', start);
    expect(start, isNot(-1), reason: 'Abbrechen-Zweig fehlt');
    expect(ende, isNot(-1));
    final zweig = code.substring(start, ende);
    expect(zweig.contains('_error'), isFalse);
    expect(zweig.contains('return;'), isTrue);
    // Der alte Sammeltext darf nicht zurückkommen.
    expect(code.contains('Keine Datei ausgewählt'), isFalse);
  });
}

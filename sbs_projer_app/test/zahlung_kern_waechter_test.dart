import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Runde 3: «bezahlt» wird nur noch von der DB-Funktion zahlung_erfassen
/// gesetzt (über ZahlungKern). Kein Dart-Code schreibt den Wert direkt.
void main() {
  test("'zahlungsstatus': 'bezahlt' steht in keiner Dart-Datei mehr", () {
    final treffer = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      if (f.readAsStringSync().contains("'zahlungsstatus': 'bezahlt'")) treffer.add(f.path);
    }
    expect(treffer, isEmpty, reason: treffer.join('\n'));
  });
  test('tote Zahlungspfade sind weg', () {
    expect(File('lib/services/camt/camt_auto_booker.dart').readAsStringSync().contains('static Future<AutoBookerResult> run('), isFalse);
    final z = File('lib/services/buchhaltung/zahlungsdifferenz_service.dart').readAsStringSync();
    expect(z.contains('verbuchenSammel('), isFalse);
    expect(z.contains('static Future<List<Buchung>> verbuchen('), isFalse);
  });
  test('alle Erfassungswege gehen ueber ZahlungKern.erfassen', () {
    for (final p in [
      'lib/services/camt/forderungs_abgleich_service.dart',
      'lib/services/rechnung/barzahlung_service.dart',
      'lib/services/rechnung/rechnung_service.dart',
      'lib/services/buchhaltung/heineken_buchung_service.dart',
    ]) {
      expect(File(p).readAsStringSync().contains('ZahlungKern.erfassen('), isTrue, reason: p);
    }
  });
  test('Ruecknahme nur ueber ZahlungKern.zuruecknehmen', () {
    final d = File('lib/presentation/screens/rechnungen/rechnung_detail_screen.dart').readAsStringSync();
    expect(d.contains('ZahlungKern.zuruecknehmen('), isTrue);
    expect(d.contains('zahlungRueckgaengig('), isFalse);
    expect(d.contains('BarzahlungService.rueckgaengig('), isFalse);
    expect(File('lib/services/camt/forderungs_abgleich_service.dart').readAsStringSync().contains('zahlungRueckgaengig'), isFalse);
  });
}

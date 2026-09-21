import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/rechnung_zustellung.dart';

/// Zustellungstext einer Rechnung: «Übergeben …» / «Versendet …».
///
/// WARUM getestet: Der Helfer war bis zum 21.09.2026 ohne Test. Er beantwortet
/// beim Durchgehen der offenen Rechnungen die Frage «ist die überhaupt beim
/// Kunden angekommen?» — eine offene Rechnung ohne jede Zustellung ist kein
/// Zahlungsverzug, sondern eine nie gestellte Rechnung. Genau diese
/// Verwechslung hat bei Blue Cinema vier Jahre lang zu einer falschen
/// Mahn-Einschätzung geführt (32 Rechnungen, alle ohne Versanddatum).
void main() {
  final uebergeben = DateTime(2026, 7, 7);
  final versendet = DateTime(2026, 8, 4);

  test('beide Zeitpunkte stehen nebeneinander', () {
    // Eine Tresen-Übergabe schliesst einen späteren Mailversand nicht aus.
    expect(
      zustellungsText(uebergebenAm: uebergeben, versendetAm: versendet),
      'Übergeben 07.07.2026 · Versendet 04.08.2026',
    );
  });

  test('nur übergeben', () {
    expect(
      zustellungsText(uebergebenAm: uebergeben, versendetAm: null),
      'Übergeben 07.07.2026',
    );
  });

  test('nur versendet', () {
    expect(
      zustellungsText(uebergebenAm: null, versendetAm: versendet),
      'Versendet 04.08.2026',
    );
  });

  test('keines gesetzt ergibt einen Gedankenstrich, keinen leeren Text', () {
    // Wichtig für die Liste: Eine leere Zelle liest sich wie «noch nicht
    // geladen», ein «—» wie «nachweislich nichts hinterlegt».
    expect(zustellungsText(uebergebenAm: null, versendetAm: null), '—');
  });

  test('Tag und Monat sind zweistellig', () {
    expect(
      zustellungsText(uebergebenAm: DateTime(2026, 1, 8), versendetAm: null),
      'Übergeben 08.01.2026',
    );
  });
}

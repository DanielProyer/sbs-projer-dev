import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/rechnung/rechnung_service.dart';

/// Eine Rechnung darf nie am Kundenguthaben scheitern.
void main() {
  test('ohne Betrieb oder ohne Betrag: nichts verrechnen', () async {
    expect(await RechnungService.guthabenFuerNeueRechnung(null, 143.75), 0);
    expect(await RechnungService.guthabenFuerNeueRechnung('', 143.75), 0);
    expect(await RechnungService.guthabenFuerNeueRechnung('b1', 0), 0);
  });

  test('Laden scheitert (kein Supabase): 0 statt Exception', () async {
    expect(await RechnungService.guthabenFuerNeueRechnung('b1', 143.75), 0);
  });
}

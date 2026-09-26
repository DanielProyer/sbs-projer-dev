import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/presentation/screens/rechnungen/rechnungen_list_screen.dart';

/// `/rechnungen?status=` setzt den Start-Filter der Rechnungsliste
/// (Geld-Block der Betriebsseite, Review Runde 5).
void main() {
  test('bekannter Status wird übernommen', () {
    expect(rechnungStartStatus('offen'), 'offen');
    expect(rechnungStartStatus('mahnung_1'), 'mahnung_1');
    expect(rechnungStartStatus('unbezahlt'), 'unbezahlt');
  });

  test('fehlend oder unbekannt -> alle', () {
    expect(rechnungStartStatus(null), 'alle');
    expect(rechnungStartStatus(''), 'alle');
    expect(rechnungStartStatus('entwurf'), 'alle');
  });
}

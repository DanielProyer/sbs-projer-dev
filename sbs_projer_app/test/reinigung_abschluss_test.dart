import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/rechnung/reinigung_abschluss_service.dart';

void main() {
  group('abschlussSnackbarText', () {
    test('Buchung + Nachholen', () {
      const e = AbschlussErgebnis(
        rechnungErstellt: true, buchungVerbucht: true, buchungTypLabel: 'Rechnung',
        nachgeholt: 2, meldungen: [],
      );
      expect(abschlussSnackbarText(e),
          'Reinigung abgeschlossen – Rechnung verbucht · 2 frühere Buchungen nachgeholt');
    });
    test('ohne Buchung', () {
      const e = AbschlussErgebnis(
        rechnungErstellt: false, buchungVerbucht: false, buchungTypLabel: null,
        nachgeholt: 0, meldungen: [],
      );
      expect(abschlussSnackbarText(e), 'Reinigung abgeschlossen');
    });
    test('eine nachgeholte Buchung im Singular', () {
      const e = AbschlussErgebnis(
        rechnungErstellt: true, buchungVerbucht: true, buchungTypLabel: 'Barzahlung',
        nachgeholt: 1, meldungen: [],
      );
      expect(abschlussSnackbarText(e), contains('1 frühere Buchung nachgeholt'));
    });
  });
  test('AbschlussMeldung: Stufe bestimmt Dauer', () {
    expect(const AbschlussMeldung('x', AbschlussStufe.fehler).dauer.inSeconds, 12);
    expect(const AbschlussMeldung('y', AbschlussStufe.info).dauer.inSeconds, 4);
  });
}

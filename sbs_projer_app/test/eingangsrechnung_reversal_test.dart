import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/eingangsrechnung.dart';
import 'package:sbs_projer_app/services/eingangsrechnung/eingangsrechnung_reversal_service.dart';

Eingangsrechnung _er({DateTime? exportiertAm}) => Eingangsrechnung(
      id: 'e1',
      userId: 'u',
      status: 'bezahlt',
      betragBrutto: 100,
      bezahltAm: DateTime(2026, 6, 20),
      buchungStufe2Id: 'b2',
      camtTxKey: 'K1',
      exportiertAm: exportiertAm,
    );

void main() {
  test('zielStatus: exportiert wenn Zahlungsfile erzeugt', () {
    expect(
        EingangsrechnungReversalService.zielStatus(
            _er(exportiertAm: DateTime(2026, 6, 18))),
        'exportiert');
  });

  test('zielStatus: gebucht ohne Export', () {
    expect(EingangsrechnungReversalService.zielStatus(_er()), 'gebucht');
  });

  test('resetFelder leert alle Stufe-2-Felder + setzt Zielstatus', () {
    final f = EingangsrechnungReversalService.resetFelder(
        _er(exportiertAm: DateTime(2026, 6, 18)));
    expect(f['status'], 'exportiert');
    expect(f['bezahlt_am'], isNull);
    expect(f['buchung_stufe2_id'], isNull);
    expect(f['camt_tx_key'], isNull);
  });
}

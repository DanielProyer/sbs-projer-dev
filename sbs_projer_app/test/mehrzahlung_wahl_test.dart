import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/zahlung_kern_plan.dart';
import 'package:sbs_projer_app/core/util/zahlungsdifferenz_text.dart';
import 'package:sbs_projer_app/presentation/widgets/mehrzahlung_wahl.dart';

void main() {
  test('mehrzahlungText', () {
    expect(mehrzahlungText(MehrzahlungZiel.aoErtrag), contains('8000'));
    expect(mehrzahlungText(MehrzahlungZiel.aoErtrag), contains('Trinkgeld'));
    expect(mehrzahlungText(MehrzahlungZiel.guthaben), contains('2030'));
    expect(
      mehrzahlungText(MehrzahlungZiel.guthaben),
      contains('nächsten Rechnung'),
    );
  });
  test('mehrzahlungHinweis nennt Betrag und Standardgrenze', () {
    final h = mehrzahlungHinweis(6.25);
    expect(h, contains('6.25'));
    expect(h, contains('5.00'));
  });
  test('differenzTextMitWahl folgt der Wahl, nicht dem Standard', () {
    final info = bewerteDifferenz(106.25, 100); // 6.25 → Standard Guthaben
    expect(info.mehrzahlungZiel, MehrzahlungZiel.guthaben);
    expect(differenzTextMitWahl(info, null), contains('2030'));
    expect(
      differenzTextMitWahl(info, MehrzahlungZiel.aoErtrag),
      contains('8000'),
    );
    expect(
      differenzTextMitWahl(info, MehrzahlungZiel.aoErtrag),
      isNot(contains('2030')),
    );
    final minder = bewerteDifferenz(90, 100);
    expect(differenzTextMitWahl(minder, MehrzahlungZiel.guthaben), minder.text);
  });
}

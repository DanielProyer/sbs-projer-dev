import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/rechnung_mail_text.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';

Rechnung _r({double guthaben = 0}) => Rechnung(
  id: 'r1',
  userId: 'u1',
  rechnungstyp: 'kundenrechnung',
  rechnungsdatum: DateTime(2026, 11, 28),
  faelligkeitsdatum: DateTime(2026, 12, 28),
  betragBrutto: 143.75,
  guthabenVerrechnet: guthaben,
);

void main() {
  test('ohne Guthaben: Brutto, kein Zusatz — Wortlaut wie bisher', () {
    expect(
      zahlungsSatzMail(_r()),
      'Ich bitte Sie den offenen Betrag von CHF 143.75 innerhalb von 30 Tagen '
      'mit dem beiliegenden Einzahlungsschein zu begleichen.',
    );
  });

  test('mit Guthaben 30: zu zahlen und Hinweis auf die Verrechnung', () {
    expect(
      zahlungsSatzMail(_r(guthaben: 30)),
      'Ich bitte Sie den offenen Betrag von CHF 113.75 (nach Verrechnung '
      'Ihres Guthabens von CHF 30.00) innerhalb von 30 Tagen '
      'mit dem beiliegenden Einzahlungsschein zu begleichen.',
    );
  });

  test('ganz mit Guthaben gedeckt: nichts zu zahlen, kein Einzahlungsschein', () {
    expect(
      zahlungsSatzMail(_r(guthaben: 143.75)),
      'Der Betrag wurde vollständig mit Ihrem Guthaben verrechnet — '
      'es ist nichts zu zahlen.',
    );
  });
}

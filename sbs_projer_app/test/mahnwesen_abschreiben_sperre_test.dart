import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/einzel_abschreibung.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';

/// Runde 3 Aufräumen (B): Die Einzelabschreibung darf keine Rechnung
/// abschreiben, auf die schon eine Zahlung gebucht oder vermerkt ist —
/// sonst steht der Eingang UND die Abschreibung im Journal.
Rechnung _r({
  String status = 'offen',
  DateTime? eingang,
  double? betrag,
}) => Rechnung(
  id: 'r1',
  userId: 'u',
  rechnungstyp: 'kundenrechnung',
  rechnungsdatum: DateTime(2026, 3, 1),
  faelligkeitsdatum: DateTime(2026, 3, 31),
  betragBrutto: 100,
  zahlungsstatus: status,
  zahlungEingegangenAm: eingang,
  zahlungBetrag: betrag,
);

void main() {
  test('offene Rechnung ohne Zahlung: frei', () {
    expect(abschreibSperre(_r(status: 'mahnung_2'), hatZahlung: false), isNull);
  });

  test('bezahlt oder abgeschrieben: bereits erledigt', () {
    expect(abschreibSperre(_r(status: 'bezahlt'), hatZahlung: false),
        contains('bereits'));
    expect(abschreibSperre(_r(status: 'abgeschrieben'), hatZahlung: false),
        contains('bereits'));
  });

  test('Zahlung im Journal gebucht: gesperrt', () {
    expect(abschreibSperre(_r(), hatZahlung: true),
        contains('Zahlung gebucht'));
  });

  test('Zahlungsfelder gesetzt: gesperrt', () {
    expect(abschreibSperre(_r(eingang: DateTime(2026, 4, 1)), hatZahlung: false),
        contains('Zahlung gebucht'));
    expect(abschreibSperre(_r(betrag: 20), hatZahlung: false),
        contains('Zahlung gebucht'));
  });
}

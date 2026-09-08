import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/servicezeit_vorschlag.dart';

Besuchszeit _b(String start, String ende) =>
    Besuchszeit(startMinuten: _m(start), endeMinuten: _m(ende));

int _m(String hhmm) {
  final t = hhmm.split(':');
  return int.parse(t[0]) * 60 + int.parse(t[1]);
}

/// Kopfzeile über der Besuchsliste: die volle Spanne und die Stunde, in der
/// die meisten Besuche begannen. Beides beantwortet beim Durchgehen die
/// Frage «passt der Vorschlag zu dem, was ich tatsächlich gemacht habe?».
void main() {
  test('Spanne geht vom frühesten Start bis zum spätesten Ende', () {
    final u = besuchsUebersicht([
      _b('08:24', '09:30'),
      _b('07:34', '08:30'),
      _b('10:00', '12:05'),
    ]);
    expect(u!.spanneVon, '07:34');
    expect(u.spanneBis, '12:05');
  });

  test('häufigste Startstunde mit Anzahl', () {
    final u = besuchsUebersicht([
      _b('08:10', '09:00'),
      _b('08:40', '09:30'),
      _b('08:55', '09:45'),
      _b('09:20', '10:00'),
      _b('14:00', '15:00'),
    ]);
    expect(u!.haeufigsteStunde, 8);
    expect(u.haeufigkeit, 3);
    expect(u.stundenText, '08–09 Uhr');
  });

  test('bei Gleichstand gewinnt die frühere Stunde', () {
    final u = besuchsUebersicht([
      _b('08:10', '09:00'),
      _b('14:00', '15:00'),
    ]);
    expect(u!.haeufigsteStunde, 8);
  });

  test('leere Liste ergibt keine Übersicht', () {
    expect(besuchsUebersicht([]), isNull);
  });

  test('ein einzelner Besuch reicht', () {
    final u = besuchsUebersicht([_b('09:15', '10:05')]);
    expect(u!.spanneVon, '09:15');
    expect(u.spanneBis, '10:05');
    expect(u.haeufigkeit, 1);
  });
}

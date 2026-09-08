import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/servicezeit_vorschlag.dart';

Besuchszeit _b(String start, String ende) => Besuchszeit(
  startMinuten: _min(start),
  endeMinuten: _min(ende),
);

int _min(String hhmm) {
  final t = hhmm.split(':');
  return int.parse(t[0]) * 60 + int.parse(t[1]);
}

/// Leitet aus den tatsächlichen Besuchszeiten ein Servicefenster ab.
/// Robust gegen Ausreisser: Das früheste und späteste Zehntel fällt weg —
/// ein einzelner Abendeinsatz (Hürtel Küssnacht, 19:16) würde das Fenster
/// sonst unbrauchbar weit machen. Gerundet wird nach aussen auf viertel
/// Stunden, damit die Werte wie von Hand gesetzt aussehen.
void main() {
  test('Ausreisser am Rand fallen weg, Rest wird nach aussen gerundet', () {
    // Nachbau Rätia Ilanz: Kern um 08:24–11:33, dazu je ein Ausreisser
    // (einmal 06:00 losgelegt, einmal bis 13:00 geblieben).
    final v = servicezeitVorschlag([
      _b('06:00', '07:00'), // zu früh — soll wegfallen
      for (var i = 0; i < 18; i++) _b('08:24', '11:33'),
      _b('11:00', '13:00'), // zu spät — soll wegfallen
    ]);
    expect(v.morgenAb, '08:15');
    expect(v.morgenBis, '11:45');
    expect(v.morgenBesuche, 20);
  });

  test('bei wenigen Besuchen zählt jeder Wert (kein Filter möglich)', () {
    // Fünf Besuche: 10 % davon ist weniger als ein Wert — der früheste bleibt
    // also drin. Das ist gewollt, bei so wenig Daten gibt es keine Ausreisser.
    final v = servicezeitVorschlag([
      _b('07:34', '08:30'),
      _b('08:24', '09:30'),
      _b('08:40', '10:00'),
      _b('09:00', '11:33'),
      _b('10:00', '12:05'),
    ]);
    expect(v.morgenAb, '07:30');
    expect(v.morgenBis, '12:15');
    expect(v.morgenBesuche, 5);
  });

  test('trennt Morgen und Nachmittag an der 12-Uhr-Grenze', () {
    final v = servicezeitVorschlag([
      _b('07:00', '08:00'),
      _b('08:00', '09:00'),
      _b('09:00', '10:00'),
      _b('13:00', '14:00'),
      _b('14:00', '15:00'),
      _b('15:00', '16:00'),
    ]);
    expect(v.morgenAb, '07:00');
    expect(v.morgenBis, '10:00');
    expect(v.nachmittagAb, '13:00');
    expect(v.nachmittagBis, '16:00');
  });

  test('Block mit weniger als drei Besuchen wird verworfen', () {
    // Hürtel Küssnacht: 8 Vormittage, 2 Abendeinsätze → nur der Morgen zählt.
    final v = servicezeitVorschlag([
      for (var i = 0; i < 8; i++) _b('08:00', '11:00'),
      _b('19:16', '20:00'),
      _b('20:00', '20:58'),
    ]);
    expect(v.morgenAb, isNotNull);
    expect(v.nachmittagAb, isNull);
    expect(v.nachmittagBis, isNull);
    expect(v.nachmittagBesuche, 2);
  });

  test('ohne Besuche kein Vorschlag', () {
    final v = servicezeitVorschlag([]);
    expect(v.morgenAb, isNull);
    expect(v.nachmittagAb, isNull);
    expect(v.hatVorschlag, isFalse);
  });

  test('genau drei Besuche reichen', () {
    final v = servicezeitVorschlag([
      _b('08:00', '09:00'),
      _b('08:30', '09:30'),
      _b('09:00', '10:00'),
    ]);
    expect(v.morgenAb, '08:00');
    expect(v.morgenBis, '10:00');
    expect(v.hatVorschlag, isTrue);
  });

  test('bereits runde Zeiten bleiben unverändert', () {
    final v = servicezeitVorschlag([
      _b('08:00', '11:00'),
      _b('08:00', '11:00'),
      _b('08:00', '11:00'),
    ]);
    expect(v.morgenAb, '08:00');
    expect(v.morgenBis, '11:00');
  });

  test('Mitternacht als Grenze: 00:xx zählt zum Morgen, 23:xx zum Nachmittag', () {
    final v = servicezeitVorschlag([
      _b('23:00', '23:30'),
      _b('23:15', '23:45'),
      _b('23:30', '23:50'),
    ]);
    expect(v.nachmittagAb, '23:00');
    expect(v.morgenAb, isNull);
  });
}

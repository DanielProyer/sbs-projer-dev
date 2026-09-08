import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/oeffnungszeiten_text.dart';

Map<String, dynamic> _z(Map<String, String?> tage) => {
  for (final e in tage.entries)
    e.key: e.value == null
        ? <Map<String, String>>[]
        : [
            {
              'von': e.value!.split('-')[0],
              'bis': e.value!.split('-')[1],
            },
          ],
};

/// Öffnungszeiten für eine Zeile auf der Karte: gleiche Tage werden
/// zusammengefasst, sonst stünden dort sieben Einzeleinträge.
void main() {
  test('durchgehend gleiche Zeiten werden zu einer Spanne', () {
    final t = oeffnungszeitenKompakt(
      _z({
        'Mo': '08:30-18:00',
        'Di': '08:30-18:00',
        'Mi': '08:30-18:00',
        'Do': '08:30-18:00',
        'Fr': '08:30-18:00',
        'Sa': '08:30-18:00',
        'So': '08:30-18:00',
      }),
    );
    expect(t, 'Mo–So 08:30–18:00');
  });

  test('geschlossene Tage werden benannt', () {
    final t = oeffnungszeitenKompakt(
      _z({
        'Mo': null,
        'Di': null,
        'Mi': null,
        'Do': null,
        'Fr': '14:00-20:00',
        'Sa': '14:00-20:00',
        'So': '14:00-20:00',
      }),
    );
    expect(t, 'Mo–Do geschlossen · Fr–So 14:00–20:00');
  });

  test('zwei gleiche Tage mit Schrägstrich, einzelner Tag allein', () {
    final t = oeffnungszeitenKompakt(
      _z({
        'Mo': '09:00-12:00',
        'Di': '09:00-12:00',
        'Mi': '14:00-18:00',
        'Do': '09:00-12:00',
        'Fr': '09:00-12:00',
        'Sa': '09:00-12:00',
        'So': '09:00-12:00',
      }),
    );
    expect(t, 'Mo/Di 09:00–12:00 · Mi 14:00–18:00 · Do–So 09:00–12:00');
  });

  test('mehrere Fenster am selben Tag', () {
    final t = oeffnungszeitenKompakt({
      'Mo': [
        {'von': '12:00', 'bis': '13:30'},
        {'von': '18:00', 'bis': '21:00'},
      ],
    });
    expect(t, 'Mo 12:00–13:30, 18:00–21:00');
  });

  test('nichts hinterlegt ergibt null', () {
    expect(oeffnungszeitenKompakt(null), isNull);
    expect(oeffnungszeitenKompakt(<String, dynamic>{}), isNull);
    expect(
      oeffnungszeitenKompakt(_z({'Mo': null, 'Di': null})),
      isNull,
    );
  });
}

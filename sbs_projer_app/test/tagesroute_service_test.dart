import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/routing/tagesroute_service.dart';

void main() {
  group('TagesrouteService.stuetzpunkte', () {
    Map<String, dynamic> antwortMit(List<List<double>> coords) => {
      'code': 'Ok',
      'routes': [
        {
          'geometry': {'type': 'LineString', 'coordinates': coords},
        },
      ],
    };

    test('dreht GeoJSON [lng, lat] auf LatLng um', () {
      final punkte = TagesrouteService.stuetzpunkte(
        antwortMit([
          [9.4522, 46.8362],
          [9.5321, 46.8499],
        ]),
      );
      expect(punkte, isNotNull);
      expect(punkte!.length, 2);
      expect(punkte.first.latitude, closeTo(46.8362, 0.0001));
      expect(punkte.first.longitude, closeTo(9.4522, 0.0001));
      expect(punkte.last.latitude, closeTo(46.8499, 0.0001));
    });

    test('ganze Zahlen im GeoJSON werden akzeptiert', () {
      final punkte = TagesrouteService.stuetzpunkte({
        'code': 'Ok',
        'routes': [
          {
            'geometry': {
              'coordinates': [
                [9, 46],
                [10, 47],
              ],
            },
          },
        ],
      });
      expect(punkte!.first.latitude, 46.0);
      expect(punkte.first.longitude, 9.0);
    });

    test('null bei fehlender Antwort', () {
      expect(TagesrouteService.stuetzpunkte(null), isNull);
    });

    test('null wenn OSRM keine Route findet', () {
      expect(
        TagesrouteService.stuetzpunkte({
          'code': 'NoRoute',
          'message': 'Impossible route',
        }),
        isNull,
      );
    });

    test('null bei leerer Routen-Liste', () {
      expect(
        TagesrouteService.stuetzpunkte({'code': 'Ok', 'routes': []}),
        isNull,
      );
    });

    test('null wenn die Geometrie fehlt', () {
      expect(
        TagesrouteService.stuetzpunkte({
          'code': 'Ok',
          'routes': [
            {'distance': 1200.0},
          ],
        }),
        isNull,
      );
    });

    test('null bei nur einem Stützpunkt — daraus wird keine Linie', () {
      expect(
        TagesrouteService.stuetzpunkte(
          antwortMit([
            [9.4522, 46.8362],
          ]),
        ),
        isNull,
      );
    });

    test('null bei unbrauchbaren Koordinaten statt halber Route', () {
      expect(
        TagesrouteService.stuetzpunkte({
          'code': 'Ok',
          'routes': [
            {
              'geometry': {
                'coordinates': [
                  [9.4522, 46.8362],
                  ['x', 'y'],
                ],
              },
            },
          ],
        }),
        isNull,
      );
    });
  });

  group('TagesrouteService.verlauf', () {
    test('null ohne Netzabfrage bei weniger als zwei Punkten', () async {
      expect(await TagesrouteService.verlauf(const []), isNull);
    });
  });
}

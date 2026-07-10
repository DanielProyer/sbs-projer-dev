import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/google_betrieb_daten.dart';

void main() {
  group('betriebAusGooglePlace', () {
    test('parst Adresse, Telefon (national bevorzugt), Website, Koordinaten', () {
      final place = {
        'displayName': {'text': 'Restaurant Sonne'},
        'formattedAddress': 'Dorfstrasse 12, 7000 Chur, Schweiz',
        'addressComponents': [
          {'types': ['route'], 'longText': 'Dorfstrasse'},
          {'types': ['street_number'], 'longText': '12'},
          {'types': ['postal_code'], 'longText': '7000'},
          {'types': ['locality'], 'longText': 'Chur'},
        ],
        'nationalPhoneNumber': '081 123 45 67',
        'internationalPhoneNumber': '+41 81 123 45 67',
        'websiteUri': 'https://sonne-chur.ch',
        'location': {'latitude': 46.85, 'longitude': 9.53},
        'googleMapsUri': 'https://maps.google.com/?cid=123',
      };

      final d = betriebAusGooglePlace(place);

      expect(d.name, 'Restaurant Sonne');
      expect(d.strasse, 'Dorfstrasse');
      expect(d.nr, '12');
      expect(d.plz, '7000');
      expect(d.ort, 'Chur');
      expect(d.telefon, '081 123 45 67');
      expect(d.website, 'https://sonne-chur.ch');
      expect(d.latitude, 46.85);
      expect(d.longitude, 9.53);
      expect(d.mapsUri, 'https://maps.google.com/?cid=123');
    });

    test('faellt auf internationale Telefonnummer zurueck', () {
      final d = betriebAusGooglePlace({
        'internationalPhoneNumber': '+41 81 999 00 11',
      });
      expect(d.telefon, '+41 81 999 00 11');
    });

    test('mappt regularOpeningHours auf oeffnungszeiten und ruhetage', () {
      final place = {
        'regularOpeningHours': {
          'periods': [
            {
              'open': {'day': 1, 'hour': 8, 'minute': 0},
              'close': {'day': 1, 'hour': 12, 'minute': 0},
            },
            {
              'open': {'day': 1, 'hour': 13, 'minute': 30},
              'close': {'day': 1, 'hour': 18, 'minute': 0},
            },
          ],
        },
      };

      final d = betriebAusGooglePlace(place);

      expect(d.oeffnungszeiten['Mo'], [
        {'von': '08:00', 'bis': '12:00'},
        {'von': '13:30', 'bis': '18:00'},
      ]);
      expect(d.ruhetage, containsAll(['Di', 'Mi', 'Do', 'Fr', 'Sa', 'So']));
      expect(d.ruhetage, isNot(contains('Mo')));
    });

    test('ohne regularOpeningHours: leere Oeffnungszeiten, keine Ruhetage', () {
      final d = betriebAusGooglePlace({'displayName': {'text': 'X'}});
      expect(d.oeffnungszeiten.values.every((l) => l.isEmpty), isTrue);
      expect(d.ruhetage, isEmpty);
    });

    test('fehlende Adressteile bleiben null', () {
      final d = betriebAusGooglePlace({
        'addressComponents': [
          {'types': ['locality'], 'longText': 'Chur'},
        ],
      });
      expect(d.strasse, isNull);
      expect(d.nr, isNull);
      expect(d.plz, isNull);
      expect(d.ort, 'Chur');
    });
  });
}

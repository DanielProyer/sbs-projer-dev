import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/google_maps_route.dart';

void main() {
  group('googleMapsRouteUrl', () {
    test('Koordinaten haben Vorrang', () {
      final url = googleMapsRouteUrl(
          latitude: 46.85, longitude: 9.53, adresse: 'Dorfstrasse 12 Chur');
      expect(url,
          'https://www.google.com/maps/dir/?api=1&destination=46.85%2C9.53');
    });

    test('ohne Koordinaten: URL-kodierte Adresse', () {
      final url = googleMapsRouteUrl(
          latitude: null, longitude: null, adresse: 'Dorfstrasse 12, 7000 Chur');
      expect(url,
          'https://www.google.com/maps/dir/?api=1&destination=Dorfstrasse+12%2C+7000+Chur');
    });

    test('ohne Koordinaten und ohne Adresse -> null', () {
      expect(googleMapsRouteUrl(latitude: null, longitude: null, adresse: ''),
          isNull);
    });

    test('nur Longitude fehlt -> Fallback Adresse', () {
      final url = googleMapsRouteUrl(
          latitude: 46.85, longitude: null, adresse: 'Chur');
      expect(url, 'https://www.google.com/maps/dir/?api=1&destination=Chur');
    });
  });
}

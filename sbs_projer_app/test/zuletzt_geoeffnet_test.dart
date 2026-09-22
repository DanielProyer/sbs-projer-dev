import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sbs_projer_app/services/suche/zuletzt_geoeffnet.dart';

ZuletztEintrag _e(String route) =>
    ZuletztEintrag(titel: 'T $route', untertitel: null, route: route);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('leer am Anfang', () async {
    expect(await ZuletztGeoeffnet.lade(), isEmpty);
  });

  test('neueste zuerst, hoechstens 5', () async {
    for (var i = 1; i <= 7; i++) {
      await ZuletztGeoeffnet.merke(_e('/r$i'));
    }
    final l = await ZuletztGeoeffnet.lade();
    expect(l.map((e) => e.route), ['/r7', '/r6', '/r5', '/r4', '/r3']);
  });

  test('kein Duplikat: erneut geoeffnet rueckt nach vorn', () async {
    await ZuletztGeoeffnet.merke(_e('/a'));
    await ZuletztGeoeffnet.merke(_e('/b'));
    await ZuletztGeoeffnet.merke(_e('/a'));
    final l = await ZuletztGeoeffnet.lade();
    expect(l.map((e) => e.route), ['/a', '/b']);
  });

  test('kaputter Speicherinhalt ergibt leere Liste statt Absturz', () async {
    SharedPreferences.setMockInitialValues({'suche_zuletzt': 'kein json'});
    expect(await ZuletztGeoeffnet.lade(), isEmpty);
  });
}

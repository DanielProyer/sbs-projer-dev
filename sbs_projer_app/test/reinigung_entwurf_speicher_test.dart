import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/reinigung_entwurf.dart';
import 'package:sbs_projer_app/services/storage/reinigung_entwurf_speicher.dart';
import 'package:shared_preferences/shared_preferences.dart';

ReinigungEntwurf _entwurf(String betriebId, DateTime am) => ReinigungEntwurf(
  betriebId: betriebId,
  anlageIds: const ['a-1'],
  datum: DateTime(am.year, am.month, am.day),
  uhrzeitStart: '08:00',
  serviceArt: 'standardservice',
  notizen: 'n',
  gespeichertAm: am,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('speichern → laden → loeschen', () async {
    final jetzt = DateTime.now();
    await ReinigungEntwurfSpeicher.speichern(_entwurf('b-1', jetzt));
    final e = await ReinigungEntwurfSpeicher.laden('b-1');
    expect(e, isNotNull);
    expect(e!.notizen, 'n');
    expect(await ReinigungEntwurfSpeicher.laden('b-2'), isNull);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('entwurf_reinigung_b-1'), isNotNull);

    await ReinigungEntwurfSpeicher.loeschen('b-1');
    expect(await ReinigungEntwurfSpeicher.laden('b-1'), isNull);
  });

  test('laden: abgelaufener Entwurf zählt nicht und wird entfernt', () async {
    await ReinigungEntwurfSpeicher.speichern(
      _entwurf('b-1', DateTime.now().subtract(const Duration(days: 3))),
    );
    expect(await ReinigungEntwurfSpeicher.laden('b-1'), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('entwurf_reinigung_b-1'), isNull);
  });

  test('laden: kaputter Eintrag → kein Entwurf, kein Fehler', () async {
    SharedPreferences.setMockInitialValues({
      'entwurf_reinigung_b-1': '{kaputt',
    });
    expect(await ReinigungEntwurfSpeicher.laden('b-1'), isNull);
  });

  test('alleOffen: nur frische Entwürfe, abgelaufene werden gelöscht',
      () async {
    final jetzt = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'anderer_schluessel': 'x',
      'entwurf_reinigung_kaputt': 'nicht json',
    });
    await ReinigungEntwurfSpeicher.speichern(_entwurf('b-1', jetzt));
    await ReinigungEntwurfSpeicher.speichern(
      _entwurf('b-alt', jetzt.subtract(const Duration(days: 5))),
    );
    final offen = await ReinigungEntwurfSpeicher.alleOffen();
    expect(offen.map((e) => e.betriebId), ['b-1']);
    expect(offen.single.gespeichertAm, jetzt);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('entwurf_reinigung_b-alt'), isNull);
    expect(prefs.getString('entwurf_reinigung_kaputt'), isNull);
    expect(prefs.getString('anderer_schluessel'), 'x');
  });

  test('speichern ohne betriebId wird ignoriert', () async {
    await ReinigungEntwurfSpeicher.speichern(_entwurf('', DateTime.now()));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty);
  });
}

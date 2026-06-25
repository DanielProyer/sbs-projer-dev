import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';

BetriebLocal _b(String sid, List<String> aliase) =>
    BetriebLocal()
      ..serverId = sid
      ..name = sid
      ..zahlerAliase = aliase;

void main() {
  test('neuer Alias → gelernt', () {
    final res = BetriebRepository.entscheideAlias(
      betriebServerId: 'b1', zahlername: 'Hotel Alpina AG',
      alleBetriebe: [_b('b1', []), _b('b2', [])],
    );
    expect(res, AliasLernResultat.gelernt);
  });

  test('schon vorhanden → schonVorhanden', () {
    final res = BetriebRepository.entscheideAlias(
      betriebServerId: 'b1', zahlername: 'Hotel  Alpina  AG',
      alleBetriebe: [_b('b1', ['hotel alpina ag'])],
    );
    expect(res, AliasLernResultat.schonVorhanden);
  });

  test('Alias bei anderem Betrieb → konflikt', () {
    final res = BetriebRepository.entscheideAlias(
      betriebServerId: 'b1', zahlername: 'Hotel Alpina AG',
      alleBetriebe: [_b('b1', []), _b('b2', ['hotel alpina ag'])],
    );
    expect(res, AliasLernResultat.konflikt);
  });

  test('leerer Name → schonVorhanden (No-Op)', () {
    final res = BetriebRepository.entscheideAlias(
      betriebServerId: 'b1', zahlername: '   ',
      alleBetriebe: [_b('b1', [])],
    );
    expect(res, AliasLernResultat.schonVorhanden);
  });
}

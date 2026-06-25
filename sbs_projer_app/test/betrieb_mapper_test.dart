import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/betrieb.dart';
import 'package:sbs_projer_app/data/mappers/betrieb_mapper.dart';

void main() {
  test('zahlerAliase überlebt DTO→Local→JSON', () {
    final dto = Betrieb(
      id: 'b1',
      userId: 'u1',
      name: 'Hotel Alpina',
      zahlerAliase: const ['hotel alpina ag', 'alpina gastro'],
    );
    final local = BetriebMapper.fromDto(dto);
    expect(local.zahlerAliase, ['hotel alpina ag', 'alpina gastro']);

    final json = BetriebMapper.toJson(local);
    expect(json['zahler_aliase'], ['hotel alpina ag', 'alpina gastro']);
  });

  test('fromJson liest zahler_aliase (oder leer wenn fehlt)', () {
    final mit = Betrieb.fromJson({
      'id': 'b1', 'user_id': 'u1', 'name': 'X',
      'zahler_aliase': ['a', 'b'],
    });
    expect(mit.zahlerAliase, ['a', 'b']);

    final ohne = Betrieb.fromJson({'id': 'b2', 'user_id': 'u1', 'name': 'Y'});
    expect(ohne.zahlerAliase, isEmpty);
  });
}

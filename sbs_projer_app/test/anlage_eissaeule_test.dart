import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/mappers/anlage_mapper.dart';
import 'package:sbs_projer_app/data/models/anlage.dart';

void main() {
  test('eissaeule überlebt fromJson/toJson', () {
    final a = Anlage.fromJson({
      'id': 'a1',
      'user_id': 'u1',
      'betrieb_id': 'b1',
      'typ_anlage': 'Warmanstich',
      'eissaeule': true,
    });
    expect(a.eissaeule, isTrue);
    expect(a.toJson()['eissaeule'], isTrue);
  });

  test('eissaeule ist ohne Angabe false', () {
    final a = Anlage.fromJson({
      'id': 'a1',
      'user_id': 'u1',
      'betrieb_id': 'b1',
      'typ_anlage': 'Warmanstich',
    });
    expect(a.eissaeule, isFalse);
  });

  test('eissaeule überlebt den Weg DTO -> lokal -> Supabase-JSON', () {
    final dto = Anlage(
      id: 'a1',
      userId: 'u1',
      betriebId: 'b1',
      typAnlage: 'Warmanstich',
      eissaeule: true,
    );
    final local = AnlageMapper.fromDto(dto);
    expect(local.eissaeule, isTrue);
    expect(AnlageMapper.toJson(local)['eissaeule'], isTrue);
  });
}

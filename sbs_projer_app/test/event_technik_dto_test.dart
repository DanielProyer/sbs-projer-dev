import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/event_geraet.dart';
import 'package:sbs_projer_app/data/models/event_leitung.dart';

void main() {
  test('EventGeraet: fromJson liest alle Felder, toJson spiegelt sie', () {
    final json = {
      'id': 'g1',
      'user_id': 'u1',
      'event_id': 'e1',
      'typ': 'mehrfachanstich',
      'bezeichnung': 'Kühlzelt Nord',
      'anzahl_tanks': 4,
      'standort_notiz': 'hinter Bühne',
      'latitude': 46.3,
      'longitude': 7.7,
      'position_quelle': 'karte',
      'position_genauigkeit': 'mittel',
      'in_betrieb': true,
      'in_betrieb_am': '2026-08-17T10:00:00Z',
      'sortierung': 2,
      'notizen': 'CO2 separat',
      'created_at': '2026-08-14T08:00:00Z',
      'updated_at': '2026-08-14T09:00:00Z',
    };
    final g = EventGeraet.fromJson(json);
    expect(g.typ, 'mehrfachanstich');
    expect(g.anzahlTanks, 4);
    expect(g.inBetrieb, isTrue);
    final back = g.toJson();
    expect(back['event_id'], 'e1');
    expect(back['anzahl_tanks'], 4);
    expect(back['in_betrieb_am'], isNotNull);
  });

  test('EventGeraet: Defaults bei fehlenden Feldern', () {
    final g = EventGeraet.fromJson({
      'id': 'g1', 'user_id': 'u1', 'event_id': 'e1',
      'typ': 'orion_500', 'bezeichnung': 'Tank A',
    });
    expect(g.anzahlTanks, isNull);
    expect(g.inBetrieb, isFalse);
    expect(g.sortierung, 0);
  });

  test('EventGeraet: typLabel und istAnstich', () {
    expect(EventGeraet.typLabel('orion_1000'), 'Orion 1000 l');
    expect(EventGeraet.typLabel('durchlaufkuehler'), 'Durchlaufkühler');
    expect(EventGeraet.istAnstich('orion_500'), isTrue);
    expect(EventGeraet.istAnstich('durchlaufkuehler'), isFalse);
  });

  test('EventLeitung: Roundtrip inkl. Null-Zielen', () {
    final l = EventLeitung.fromJson({
      'id': 'l1', 'user_id': 'u1', 'event_id': 'e1',
      'nummer': '7', 'quelle_id': 'g1',
    });
    expect(l.kuehlerId, isNull);
    expect(l.standId, isNull);
    expect(l.standAnlageId, isNull);
    expect(l.inBetrieb, isFalse);
    final back = l.toJson();
    expect(back['nummer'], '7');
    expect(back['quelle_id'], 'g1');
    expect(back.containsKey('kuehler_id'), isTrue); // explizit null mitschicken
  });
}

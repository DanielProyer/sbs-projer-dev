import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/event_geraet.dart';
import 'package:sbs_projer_app/data/models/event_leitung.dart';

void main() {
  test('EventGeraet: voller Roundtrip — jedes Feld, exakte Keys', () {
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
      'kuehler_typ': 'Lindr KONTAKT 40/K',
      'pumpe_typ': 'Flojet 2130',
      'typenschild_kuehler_pfad': 'events/e1/typenschild_kuehler.jpg',
      'typenschild_pumpe_pfad': 'events/e1/typenschild_pumpe.jpg',
      'typenschild_erkennung': {
        'hersteller': 'Lindr',
        'sicherheit': 'hoch',
      },
      'soll_min_celsius': 2.5,
      'soll_max_celsius': 4.0,
      'created_at': '2026-08-14T08:00:00Z',
      'updated_at': '2026-08-14T09:00:00Z',
    };
    final g = EventGeraet.fromJson(json);
    expect(g.typ, 'mehrfachanstich');
    expect(g.anzahlTanks, 4);
    expect(g.inBetrieb, isTrue);
    expect(g.kuehlerTyp, 'Lindr KONTAKT 40/K');
    expect(g.pumpeTyp, 'Flojet 2130');
    expect(g.typenschildKuehlerPfad, 'events/e1/typenschild_kuehler.jpg');
    expect(g.typenschildPumpePfad, 'events/e1/typenschild_pumpe.jpg');
    expect(g.typenschildErkennung, {'hersteller': 'Lindr', 'sicherheit': 'hoch'});
    expect(g.sollMinCelsius, 2.5);
    expect(g.sollMaxCelsius, 4.0);
    expect(g.createdAt, DateTime.utc(2026, 8, 14, 8, 0, 0));
    expect(g.updatedAt, DateTime.utc(2026, 8, 14, 9, 0, 0));

    final back = g.toJson();
    expect(back, {
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
      'in_betrieb_am': '2026-08-17T10:00:00.000Z',
      'sortierung': 2,
      'notizen': 'CO2 separat',
      'kuehler_typ': 'Lindr KONTAKT 40/K',
      'pumpe_typ': 'Flojet 2130',
      'typenschild_kuehler_pfad': 'events/e1/typenschild_kuehler.jpg',
      'typenschild_pumpe_pfad': 'events/e1/typenschild_pumpe.jpg',
      'typenschild_erkennung': {'hersteller': 'Lindr', 'sicherheit': 'hoch'},
      'soll_min_celsius': 2.5,
      'soll_max_celsius': 4.0,
    });
  });

  test('EventGeraet: Defaults bei fehlenden Feldern', () {
    final g = EventGeraet.fromJson({
      'id': 'g1', 'user_id': 'u1', 'event_id': 'e1',
      'typ': 'orion_500', 'bezeichnung': 'Tank A',
    });
    expect(g.anzahlTanks, isNull);
    expect(g.inBetrieb, isFalse);
    expect(g.sortierung, 0);
    expect(g.kuehlerTyp, isNull);
    expect(g.pumpeTyp, isNull);
    expect(g.typenschildErkennung, isNull);
    expect(g.sollMinCelsius, isNull);
    expect(g.sollMaxCelsius, isNull);
  });

  test('EventGeraet: typLabel und istAnstich', () {
    expect(EventGeraet.typLabel('orion_1000'), 'Orion 1000 l');
    expect(EventGeraet.typLabel('durchlaufkuehler'), 'Durchlaufkühler');
    expect(EventGeraet.istAnstich('orion_500'), isTrue);
    expect(EventGeraet.istAnstich('durchlaufkuehler'), isFalse);
  });

  test('EventLeitung: voller Roundtrip — jedes Feld, exakte Keys', () {
    final json = {
      'id': 'l1',
      'user_id': 'u1',
      'event_id': 'e1',
      'nummer': '7a',
      'quelle_id': 'q1',
      'kuehler_id': 'k1',
      'stand_id': 's1',
      'stand_anlage_id': 'sa1',
      'in_betrieb': true,
      'in_betrieb_am': '2026-08-18T11:00:00Z',
      'sortierung': 3,
      'notiz': 'links am Zelt',
      'created_at': '2026-08-14T10:00:00Z',
      'updated_at': '2026-08-14T11:00:00Z',
    };
    final l = EventLeitung.fromJson(json);
    expect(l.id, 'l1');
    expect(l.userId, 'u1');
    expect(l.eventId, 'e1');
    expect(l.nummer, '7a');
    expect(l.quelleId, 'q1');
    expect(l.kuehlerId, 'k1');
    expect(l.standId, 's1');
    expect(l.standAnlageId, 'sa1');
    expect(l.inBetrieb, isTrue);
    expect(l.inBetriebAm, DateTime.utc(2026, 8, 18, 11, 0, 0));
    expect(l.sortierung, 3);
    expect(l.notiz, 'links am Zelt');
    expect(l.createdAt, DateTime.utc(2026, 8, 14, 10, 0, 0));
    expect(l.updatedAt, DateTime.utc(2026, 8, 14, 11, 0, 0));

    final back = l.toJson();
    expect(back, {
      'id': 'l1',
      'user_id': 'u1',
      'event_id': 'e1',
      'nummer': '7a',
      'quelle_id': 'q1',
      'kuehler_id': 'k1',
      'stand_id': 's1',
      'stand_anlage_id': 'sa1',
      'in_betrieb': true,
      'in_betrieb_am': '2026-08-18T11:00:00.000Z',
      'sortierung': 3,
      'notiz': 'links am Zelt',
    });
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

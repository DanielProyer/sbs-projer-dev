import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/local/event_geraet_local_export.dart';
import 'package:sbs_projer_app/data/local/event_leitung_local_export.dart';
import 'package:sbs_projer_app/data/mappers/event_geraet_mapper.dart';
import 'package:sbs_projer_app/data/mappers/event_leitung_mapper.dart';
import 'package:sbs_projer_app/data/models/event_geraet.dart';
import 'package:sbs_projer_app/data/models/event_leitung.dart';

void main() {
  test('EventGeraetMapper: DTO -> Local -> Json Roundtrip', () {
    final dto = EventGeraet.fromJson({
      'id': 'g1', 'user_id': 'u1', 'event_id': 'e1',
      'typ': 'orion_1000', 'bezeichnung': 'Tank A',
      'anzahl_tanks': null, 'standort_notiz': 'Kühlzelt',
      'in_betrieb': true, 'in_betrieb_am': '2026-08-17T10:00:00Z',
      'sortierung': 1,
      'updated_at': '2026-08-14T09:00:00Z',
    });
    final local = EventGeraetMapper.fromDto(dto);
    expect(local.serverId, 'g1');
    expect(local.bezeichnung, 'Tank A');
    expect(local.inBetrieb, isTrue);
    expect(local.isSynced, isTrue);
    final json = EventGeraetMapper.toJson(local);
    expect(json['id'], 'g1');
    expect(json['event_id'], 'e1');
    expect(json['typ'], 'orion_1000');
    expect(json['in_betrieb'], true);
  });

  test('EventLeitungMapper: DTO -> Local -> Json Roundtrip mit Nullen', () {
    final dto = EventLeitung.fromJson({
      'id': 'l1', 'user_id': 'u1', 'event_id': 'e1',
      'nummer': '7', 'quelle_id': 'g1',
    });
    final local = EventLeitungMapper.fromDto(dto);
    expect(local.nummer, '7');
    expect(local.standId, isNull);
    final json = EventLeitungMapper.toJson(local);
    expect(json['quelle_id'], 'g1');
    expect(json['stand_id'], isNull);
    expect(json['id'], 'l1');
  });

  test('toJson ohne serverId laesst id weg (Insert-Fall)', () {
    final dto = EventLeitung.fromJson({
      'id': 'l1', 'user_id': 'u1', 'event_id': 'e1',
      'nummer': '7', 'quelle_id': 'g1',
    });
    final local = EventLeitungMapper.fromDto(dto)..serverId = null;
    expect(EventLeitungMapper.toJson(local).containsKey('id'), isFalse);
  });

  test('EventGeraetMapper: voller Roundtrip — jedes Feld', () {
    final dto = EventGeraet.fromJson({
      'id': 'g2',
      'user_id': 'u2',
      'event_id': 'e2',
      'typ': 'mehrfachanstich',
      'bezeichnung': 'Tank B',
      'anzahl_tanks': 3,
      'standort_notiz': 'Neben Bühne',
      'latitude': 47.1234,
      'longitude': 8.5678,
      'position_quelle': 'gps',
      'position_genauigkeit': 'mittel',
      'in_betrieb': true,
      'in_betrieb_am': '2026-08-17T11:00:00Z',
      'sortierung': 5,
      'notizen': 'Zweiter Anstich rechts',
      'created_at': '2026-08-01T08:00:00Z',
      'updated_at': '2026-08-14T09:30:00Z',
    });

    final local = EventGeraetMapper.fromDto(dto);

    expect(local.serverId, 'g2');
    expect(local.userId, 'u2');
    expect(local.eventId, 'e2');
    expect(local.typ, 'mehrfachanstich');
    expect(local.bezeichnung, 'Tank B');
    expect(local.anzahlTanks, 3);
    expect(local.standortNotiz, 'Neben Bühne');
    expect(local.latitude, 47.1234);
    expect(local.longitude, 8.5678);
    expect(local.positionQuelle, 'gps');
    expect(local.positionGenauigkeit, 'mittel');
    expect(local.inBetrieb, isTrue);
    expect(local.inBetriebAm, DateTime.parse('2026-08-17T11:00:00Z'));
    expect(local.sortierung, 5);
    expect(local.notizen, 'Zweiter Anstich rechts');
    expect(local.createdAt, DateTime.parse('2026-08-01T08:00:00Z'));
    expect(local.updatedAt, DateTime.parse('2026-08-14T09:30:00Z'));
    expect(local.isSynced, isTrue);

    final json = EventGeraetMapper.toJson(local);
    expect(json, {
      'id': 'g2',
      'user_id': 'u2',
      'event_id': 'e2',
      'typ': 'mehrfachanstich',
      'bezeichnung': 'Tank B',
      'anzahl_tanks': 3,
      'standort_notiz': 'Neben Bühne',
      'latitude': 47.1234,
      'longitude': 8.5678,
      'position_quelle': 'gps',
      'position_genauigkeit': 'mittel',
      'in_betrieb': true,
      'in_betrieb_am': '2026-08-17T11:00:00.000Z',
      'sortierung': 5,
      'notizen': 'Zweiter Anstich rechts',
    });
  });

  test('EventLeitungMapper: voller Roundtrip — jedes Feld', () {
    final dto = EventLeitung.fromJson({
      'id': 'l2',
      'user_id': 'u3',
      'event_id': 'e3',
      'nummer': '12',
      'quelle_id': 'g1',
      'kuehler_id': 'k1',
      'stand_id': 's1',
      'stand_anlage_id': 'sa1',
      'in_betrieb': true,
      'in_betrieb_am': '2026-08-17T12:00:00Z',
      'sortierung': 2,
      'notiz': 'Leitung führt zum Zapfhahn links',
      'created_at': '2026-08-01T08:00:00Z',
      'updated_at': '2026-08-14T09:45:00Z',
    });

    final local = EventLeitungMapper.fromDto(dto);

    expect(local.serverId, 'l2');
    expect(local.userId, 'u3');
    expect(local.eventId, 'e3');
    expect(local.nummer, '12');
    expect(local.quelleId, 'g1');
    expect(local.kuehlerId, 'k1');
    expect(local.standId, 's1');
    expect(local.standAnlageId, 'sa1');
    expect(local.inBetrieb, isTrue);
    expect(local.inBetriebAm, DateTime.parse('2026-08-17T12:00:00Z'));
    expect(local.sortierung, 2);
    expect(local.notiz, 'Leitung führt zum Zapfhahn links');
    expect(local.createdAt, DateTime.parse('2026-08-01T08:00:00Z'));
    expect(local.updatedAt, DateTime.parse('2026-08-14T09:45:00Z'));
    expect(local.isSynced, isTrue);

    final json = EventLeitungMapper.toJson(local);
    expect(json, {
      'id': 'l2',
      'user_id': 'u3',
      'event_id': 'e3',
      'nummer': '12',
      'quelle_id': 'g1',
      'kuehler_id': 'k1',
      'stand_id': 's1',
      'stand_anlage_id': 'sa1',
      'in_betrieb': true,
      'in_betrieb_am': '2026-08-17T12:00:00.000Z',
      'sortierung': 2,
      'notiz': 'Leitung führt zum Zapfhahn links',
    });
  });

  test('EventGeraetMapper: existing wird aktualisiert, Isar-Id bleibt', () {
    final dto = EventGeraet.fromJson({
      'id': 'g3',
      'user_id': 'u4',
      'event_id': 'e4',
      'typ': 'orion_500',
      'bezeichnung': 'Tank C',
      'anzahl_tanks': 2,
      'standort_notiz': 'Beim Eingang',
      'latitude': 46.9999,
      'longitude': 7.1111,
      'position_quelle': 'karte',
      'position_genauigkeit': 'genau',
      'in_betrieb': false,
      'in_betrieb_am': '2026-08-20T08:00:00Z',
      'sortierung': 9,
      'notizen': 'Neue Notiz',
      'created_at': '2026-08-02T08:00:00Z',
      'updated_at': '2026-08-15T09:00:00Z',
    });

    final vorbelegt = EventGeraetLocal()
      ..id = 42
      ..serverId = 'alt-g'
      ..userId = 'alt-u'
      ..eventId = 'alt-e'
      ..typ = 'durchlaufkuehler'
      ..bezeichnung = 'Alter Name'
      ..anzahlTanks = 1
      ..standortNotiz = 'Alte Notiz'
      ..latitude = 1.0
      ..longitude = 2.0
      ..positionQuelle = 'gps'
      ..positionGenauigkeit = 'ungefaehr'
      ..inBetrieb = true
      ..inBetriebAm = DateTime.parse('2020-01-01T00:00:00Z')
      ..sortierung = 1
      ..notizen = 'Alt'
      ..createdAt = DateTime.parse('2019-01-01T00:00:00Z')
      ..updatedAt = DateTime.parse('2019-01-02T00:00:00Z')
      ..isSynced = false;

    final result = EventGeraetMapper.fromDto(dto, existing: vorbelegt);

    expect(identical(result, vorbelegt), isTrue);
    expect(result.id, 42);
    expect(result.serverId, 'g3');
    expect(result.userId, 'u4');
    expect(result.eventId, 'e4');
    expect(result.typ, 'orion_500');
    expect(result.bezeichnung, 'Tank C');
    expect(result.anzahlTanks, 2);
    expect(result.standortNotiz, 'Beim Eingang');
    expect(result.latitude, 46.9999);
    expect(result.longitude, 7.1111);
    expect(result.positionQuelle, 'karte');
    expect(result.positionGenauigkeit, 'genau');
    expect(result.inBetrieb, isFalse);
    expect(result.inBetriebAm, DateTime.parse('2026-08-20T08:00:00Z'));
    expect(result.sortierung, 9);
    expect(result.notizen, 'Neue Notiz');
    expect(result.createdAt, DateTime.parse('2026-08-02T08:00:00Z'));
    expect(result.updatedAt, DateTime.parse('2026-08-15T09:00:00Z'));
    expect(result.isSynced, isTrue);
  });

  test('EventLeitungMapper: existing wird aktualisiert, Isar-Id bleibt', () {
    final dto = EventLeitung.fromJson({
      'id': 'l3',
      'user_id': 'u5',
      'event_id': 'e5',
      'nummer': '99',
      'quelle_id': 'g4',
      'kuehler_id': 'k4',
      'stand_id': 's4',
      'stand_anlage_id': 'sa4',
      'in_betrieb': false,
      'in_betrieb_am': '2026-08-21T08:00:00Z',
      'sortierung': 7,
      'notiz': 'Neue Leitungsnotiz',
      'created_at': '2026-08-02T08:00:00Z',
      'updated_at': '2026-08-15T09:15:00Z',
    });

    final vorbelegt = EventLeitungLocal()
      ..id = 42
      ..serverId = 'alt-l'
      ..userId = 'alt-u'
      ..eventId = 'alt-e'
      ..nummer = '1'
      ..quelleId = 'alt-g'
      ..kuehlerId = 'alt-k'
      ..standId = 'alt-s'
      ..standAnlageId = 'alt-sa'
      ..inBetrieb = true
      ..inBetriebAm = DateTime.parse('2020-01-01T00:00:00Z')
      ..sortierung = 1
      ..notiz = 'Alt'
      ..createdAt = DateTime.parse('2019-01-01T00:00:00Z')
      ..updatedAt = DateTime.parse('2019-01-02T00:00:00Z')
      ..isSynced = false;

    final result = EventLeitungMapper.fromDto(dto, existing: vorbelegt);

    expect(identical(result, vorbelegt), isTrue);
    expect(result.id, 42);
    expect(result.serverId, 'l3');
    expect(result.userId, 'u5');
    expect(result.eventId, 'e5');
    expect(result.nummer, '99');
    expect(result.quelleId, 'g4');
    expect(result.kuehlerId, 'k4');
    expect(result.standId, 's4');
    expect(result.standAnlageId, 'sa4');
    expect(result.inBetrieb, isFalse);
    expect(result.inBetriebAm, DateTime.parse('2026-08-21T08:00:00Z'));
    expect(result.sortierung, 7);
    expect(result.notiz, 'Neue Leitungsnotiz');
    expect(result.createdAt, DateTime.parse('2026-08-02T08:00:00Z'));
    expect(result.updatedAt, DateTime.parse('2026-08-15T09:15:00Z'));
    expect(result.isSynced, isTrue);
  });
}

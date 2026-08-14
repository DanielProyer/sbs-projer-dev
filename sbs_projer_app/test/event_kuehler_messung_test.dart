import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/local/event_kuehler_messung_local_export.dart';
import 'package:sbs_projer_app/data/mappers/event_kuehler_messung_mapper.dart';
import 'package:sbs_projer_app/data/models/event_kuehler_messung.dart';

void main() {
  test('EventKuehlerMessung: voller Roundtrip — jedes Feld, exakte Keys', () {
    final json = {
      'id': 'm1',
      'user_id': 'u1',
      'geraet_id': 'g1',
      'gemessen_am': '2026-08-14T10:30:00Z',
      'temperatur': 3.4,
      'notiz': 'nach Aufbau gemessen',
      'created_at': '2026-08-14T08:00:00Z',
      'updated_at': '2026-08-14T09:00:00Z',
    };
    final m = EventKuehlerMessung.fromJson(json);
    expect(m.id, 'm1');
    expect(m.userId, 'u1');
    expect(m.geraetId, 'g1');
    expect(m.gemessenAm, DateTime.utc(2026, 8, 14, 10, 30, 0));
    expect(m.temperatur, 3.4);
    expect(m.notiz, 'nach Aufbau gemessen');
    expect(m.createdAt, DateTime.utc(2026, 8, 14, 8, 0, 0));
    expect(m.updatedAt, DateTime.utc(2026, 8, 14, 9, 0, 0));

    final back = m.toJson();
    expect(back, {
      'id': 'm1',
      'user_id': 'u1',
      'geraet_id': 'g1',
      'gemessen_am': '2026-08-14T10:30:00.000Z',
      'temperatur': 3.4,
      'notiz': 'nach Aufbau gemessen',
    });
  });

  test('EventKuehlerMessung: Defaults bei fehlenden Feldern (notiz null)', () {
    final m = EventKuehlerMessung.fromJson({
      'id': 'm1',
      'user_id': 'u1',
      'geraet_id': 'g1',
      'gemessen_am': '2026-08-14T10:30:00Z',
      'temperatur': 4,
    });
    expect(m.temperatur, 4.0);
    expect(m.notiz, isNull);
    final back = m.toJson();
    expect(back.containsKey('notiz'), isTrue); // explizit null mitschicken
  });

  test('EventKuehlerMessungMapper: voller Roundtrip — jedes Feld', () {
    final dto = EventKuehlerMessung.fromJson({
      'id': 'm2',
      'user_id': 'u2',
      'geraet_id': 'g2',
      'gemessen_am': '2026-08-14T11:00:00Z',
      'temperatur': 2.8,
      'notiz': 'Kontrollmessung',
      'created_at': '2026-08-01T08:00:00Z',
      'updated_at': '2026-08-14T09:30:00Z',
    });

    final local = EventKuehlerMessungMapper.fromDto(dto);

    expect(local.serverId, 'm2');
    expect(local.userId, 'u2');
    expect(local.geraetId, 'g2');
    expect(local.gemessenAm, DateTime.parse('2026-08-14T11:00:00Z'));
    expect(local.temperatur, 2.8);
    expect(local.notiz, 'Kontrollmessung');
    expect(local.createdAt, DateTime.parse('2026-08-01T08:00:00Z'));
    expect(local.updatedAt, DateTime.parse('2026-08-14T09:30:00Z'));
    expect(local.isSynced, isTrue);

    final json = EventKuehlerMessungMapper.toJson(local);
    expect(json, {
      'id': 'm2',
      'user_id': 'u2',
      'geraet_id': 'g2',
      'gemessen_am': '2026-08-14T11:00:00.000Z',
      'temperatur': 2.8,
      'notiz': 'Kontrollmessung',
    });
  });

  test('EventKuehlerMessungMapper: existing wird aktualisiert, Isar-Id bleibt', () {
    final dto = EventKuehlerMessung.fromJson({
      'id': 'm3',
      'user_id': 'u3',
      'geraet_id': 'g3',
      'gemessen_am': '2026-08-14T12:00:00Z',
      'temperatur': 5.1,
      'notiz': 'Neue Notiz',
      'created_at': '2026-08-02T08:00:00Z',
      'updated_at': '2026-08-15T09:00:00Z',
    });

    final vorbelegt = EventKuehlerMessungLocal()
      ..id = 42
      ..serverId = 'alt-m'
      ..userId = 'alt-u'
      ..geraetId = 'alt-g'
      ..gemessenAm = DateTime.parse('2020-01-01T00:00:00Z')
      ..temperatur = 1.0
      ..notiz = 'Alt'
      ..createdAt = DateTime.parse('2019-01-01T00:00:00Z')
      ..updatedAt = DateTime.parse('2019-01-02T00:00:00Z')
      ..isSynced = false;

    final result = EventKuehlerMessungMapper.fromDto(dto, existing: vorbelegt);

    expect(identical(result, vorbelegt), isTrue);
    expect(result.id, 42);
    expect(result.serverId, 'm3');
    expect(result.userId, 'u3');
    expect(result.geraetId, 'g3');
    expect(result.gemessenAm, DateTime.parse('2026-08-14T12:00:00Z'));
    expect(result.temperatur, 5.1);
    expect(result.notiz, 'Neue Notiz');
    expect(result.createdAt, DateTime.parse('2026-08-02T08:00:00Z'));
    expect(result.updatedAt, DateTime.parse('2026-08-15T09:00:00Z'));
    expect(result.isSynced, isTrue);
  });

  test('toJson ohne serverId laesst id weg (Insert-Fall)', () {
    final dto = EventKuehlerMessung.fromJson({
      'id': 'm4',
      'user_id': 'u4',
      'geraet_id': 'g4',
      'gemessen_am': '2026-08-14T12:00:00Z',
      'temperatur': 3.0,
    });
    final local = EventKuehlerMessungMapper.fromDto(dto)..serverId = null;
    expect(EventKuehlerMessungMapper.toJson(local).containsKey('id'), isFalse);
  });

  test(
    'UTC-Pinning: lokale gemessenAm geht als Z-String raus (2h-Versatz-Falle)',
    () {
      // Isar liest DateTime in Lokalzeit zurück. Ohne toUtc() beim Push würde
      // ein lokal gespeicherter Zeitstempel ohne «Z» rausgehen und Postgres
      // würde ihn faelschlich als UTC interpretieren (2 h Versatz, wie beim
      // in_betrieb_am-Fund von heute bei EventLeitung/EventGeraet).
      final local = EventKuehlerMessungLocal()
        ..serverId = 'm5'
        ..userId = 'u5'
        ..geraetId = 'g5'
        // bewusst als Lokalzeit konstruiert, nicht UTC
        ..gemessenAm = DateTime(2026, 8, 14, 14, 0, 0)
        ..temperatur = 3.5;

      final json = EventKuehlerMessungMapper.toJson(local);
      expect(json['gemessen_am'], endsWith('Z'));
    },
  );
}

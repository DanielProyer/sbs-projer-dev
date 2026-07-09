import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uuid/uuid.dart';
import 'package:sbs_projer_app/data/local/event_kontakt_local_export.dart';
import 'package:sbs_projer_app/data/models/event_kontakt.dart';
import 'package:sbs_projer_app/data/mappers/event_kontakt_mapper.dart';
import 'package:sbs_projer_app/services/storage/isar_service_export.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class EventKontaktRepository {
  static String get _userId => SupabaseService.dataUserId;

  static Future<List<EventKontaktLocal>> getByEvent(String eventId) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('event_kontakte').select()
          .eq('user_id', _userId)
          .eq('event_id', eventId);
      return rows
          .map((r) => EventKontaktMapper.fromDto(EventKontakt.fromJson(r)))
          .toList();
    }
    return IsarService.eventKontaktFindByEvent(eventId);
  }

  static Future<void> save(EventKontaktLocal zuordnung) async {
    zuordnung.userId = _userId;
    zuordnung.serverId ??= const Uuid().v4();
    if (kIsWeb) {
      final json = EventKontaktMapper.toJson(zuordnung);
      await SupabaseService.client.from('event_kontakte').upsert(json);
      return;
    }
    zuordnung.isSynced = false;
    zuordnung.lastModifiedAt = DateTime.now().toUtc();
    await IsarService.eventKontaktPut(zuordnung);
  }

  static Future<void> delete(String id) async {
    if (kIsWeb) {
      await SupabaseService.client.from('event_kontakte').delete().eq('id', id);
      return;
    }
    await IsarService.eventKontaktDelete(int.parse(id));
  }

  /// Entfernt alle Zuordnungen eines Event-Jahres (vor dem Event-Löschen).
  static Future<void> deleteByEvent(String eventId) async {
    if (kIsWeb) {
      await SupabaseService.client
          .from('event_kontakte').delete()
          .eq('event_id', eventId);
      return;
    }
    final zuordnungen = await IsarService.eventKontaktFindByEvent(eventId);
    for (final z in zuordnungen) {
      await IsarService.eventKontaktDelete(z.id);
    }
  }

  /// Liefert die Zuordnungen aus [quelle], deren (kontaktId, rolle)-Kombination
  /// in [ziel] noch fehlt (Vorjahres-Übernahme ohne Duplikate).
  static List<EventKontaktLocal> fehlendeZuordnungen(
      List<EventKontaktLocal> quelle, List<EventKontaktLocal> ziel) {
    return quelle
        .where((q) => !ziel.any(
            (z) => z.kontaktId == q.kontaktId && z.rolle == q.rolle))
        .toList();
  }

  /// Übernimmt Kontakte aus dem Vorjahres-Event [vonEventId] in [zuEventId].
  /// Rückgabe: Anzahl übernommener Zuordnungen.
  static Future<int> uebernehmeVon(String vonEventId, String zuEventId) async {
    final quelle = await getByEvent(vonEventId);
    final ziel = await getByEvent(zuEventId);
    final neu = fehlendeZuordnungen(quelle, ziel);
    for (final q in neu) {
      final z = EventKontaktLocal()
        ..eventId = zuEventId
        ..kontaktId = q.kontaktId
        ..rolle = q.rolle
        ..bemerkung = q.bemerkung;
      await save(z);
    }
    return neu.length;
  }
}

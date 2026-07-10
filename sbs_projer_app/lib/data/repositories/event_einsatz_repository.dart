import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uuid/uuid.dart';
import 'package:sbs_projer_app/data/local/event_einsatz_local_export.dart';
import 'package:sbs_projer_app/data/models/event_einsatz.dart';
import 'package:sbs_projer_app/data/mappers/event_einsatz_mapper.dart';
import 'package:sbs_projer_app/services/storage/isar_service_export.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class EventEinsatzRepository {
  static String get _userId => SupabaseService.dataUserId;

  static Future<List<EventEinsatzLocal>> getByEvent(String eventId) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('event_einsaetze').select()
          .eq('user_id', _userId)
          .eq('event_id', eventId)
          .order('zeitpunkt', ascending: false);
      return rows
          .map((r) => EventEinsatzMapper.fromDto(EventEinsatz.fromJson(r)))
          .toList();
    }
    return IsarService.eventEinsatzFindByEvent(eventId);
  }

  static Future<void> save(EventEinsatzLocal einsatz) async {
    einsatz.userId = _userId;
    einsatz.serverId ??= const Uuid().v4();
    if (kIsWeb) {
      final json = EventEinsatzMapper.toJson(einsatz);
      await SupabaseService.client.from('event_einsaetze').upsert(json);
      return;
    }
    einsatz.isSynced = false;
    einsatz.lastModifiedAt = DateTime.now().toUtc();
    await IsarService.eventEinsatzPut(einsatz);
  }

  static Future<void> delete(String id) async {
    if (kIsWeb) {
      await SupabaseService.client.from('event_einsaetze').delete().eq('id', id);
      return;
    }
    // Native: zuerst serverseitig löschen, dann Isar aufräumen.
    final isarId = int.parse(id);
    final local = await IsarService.eventEinsatzGet(isarId);
    if (local?.serverId != null) {
      await SupabaseService.client
          .from('event_einsaetze').delete().eq('id', local!.serverId!);
    }
    await IsarService.eventEinsatzDelete(isarId);
  }
}

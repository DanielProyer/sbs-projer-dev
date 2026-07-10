import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uuid/uuid.dart';
import 'package:sbs_projer_app/data/local/event_aufwand_local_export.dart';
import 'package:sbs_projer_app/data/models/event_aufwand.dart';
import 'package:sbs_projer_app/data/mappers/event_aufwand_mapper.dart';
import 'package:sbs_projer_app/services/storage/isar_service_export.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class EventAufwandRepository {
  static String get _userId => SupabaseService.dataUserId;

  static Future<List<EventAufwandLocal>> getByEvent(String eventId) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('event_aufwand').select()
          .eq('user_id', _userId)
          .eq('event_id', eventId)
          .order('datum', ascending: true);
      return rows
          .map((r) => EventAufwandMapper.fromDto(EventAufwand.fromJson(r)))
          .toList();
    }
    return IsarService.eventAufwandFindByEvent(eventId);
  }

  static Future<void> save(EventAufwandLocal aufwand) async {
    aufwand.userId = _userId;
    aufwand.serverId ??= const Uuid().v4();
    if (kIsWeb) {
      final json = EventAufwandMapper.toJson(aufwand);
      await SupabaseService.client.from('event_aufwand').upsert(json);
      return;
    }
    aufwand.isSynced = false;
    aufwand.lastModifiedAt = DateTime.now().toUtc();
    await IsarService.eventAufwandPut(aufwand);
  }

  static Future<void> delete(String id) async {
    if (kIsWeb) {
      await SupabaseService.client.from('event_aufwand').delete().eq('id', id);
      return;
    }
    // Native: zuerst serverseitig löschen, dann Isar aufräumen.
    final isarId = int.parse(id);
    final local = await IsarService.eventAufwandGet(isarId);
    if (local?.serverId != null) {
      await SupabaseService.client
          .from('event_aufwand').delete().eq('id', local!.serverId!);
    }
    await IsarService.eventAufwandDelete(isarId);
  }
}

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uuid/uuid.dart';
import 'package:sbs_projer_app/data/local/event_stand_anlage_local_export.dart';
import 'package:sbs_projer_app/data/models/event_stand_anlage.dart';
import 'package:sbs_projer_app/data/mappers/event_stand_anlage_mapper.dart';
import 'package:sbs_projer_app/services/storage/isar_service_export.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class EventStandAnlageRepository {
  static String get _userId => SupabaseService.dataUserId;

  static Future<List<EventStandAnlageLocal>> getByStand(String standId) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('event_stand_anlagen').select()
          .eq('user_id', _userId)
          .eq('stand_id', standId)
          .order('sortierung');
      return rows
          .map((r) => EventStandAnlageMapper.fromDto(EventStandAnlage.fromJson(r)))
          .toList();
    }
    return IsarService.eventStandAnlageFindByStand(standId);
  }

  static Future<void> save(EventStandAnlageLocal anlage) async {
    anlage.userId = _userId;
    anlage.serverId ??= const Uuid().v4();
    if (kIsWeb) {
      final json = EventStandAnlageMapper.toJson(anlage);
      await SupabaseService.client.from('event_stand_anlagen').upsert(json);
      return;
    }
    anlage.isSynced = false;
    anlage.lastModifiedAt = DateTime.now().toUtc();
    await IsarService.eventStandAnlagePut(anlage);
  }

  static Future<void> delete(String id) async {
    if (kIsWeb) {
      await SupabaseService.client.from('event_stand_anlagen').delete().eq('id', id);
      return;
    }
    // Native: zuerst serverseitig löschen, dann Isar aufräumen.
    final isarId = int.parse(id);
    final local = await IsarService.eventStandAnlageGet(isarId);
    if (local?.serverId != null) {
      await SupabaseService.client
          .from('event_stand_anlagen').delete().eq('id', local!.serverId!);
    }
    await IsarService.eventStandAnlageDelete(isarId);
  }

  /// Ersetzt alle Anlagen eines Stands durch [neu] (löscht bestehende, legt neue an).
  static Future<void> replaceForStand(
      String standId, List<EventStandAnlageLocal> neu) async {
    final alt = await getByStand(standId);
    for (final a in alt) {
      await delete(a.routeId);
    }
    for (var i = 0; i < neu.length; i++) {
      final a = neu[i]
        ..standId = standId
        ..sortierung = i;
      await save(a);
    }
  }
}

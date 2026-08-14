import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uuid/uuid.dart';
import 'package:sbs_projer_app/data/local/event_kuehler_messung_local_export.dart';
import 'package:sbs_projer_app/data/models/event_kuehler_messung.dart';
import 'package:sbs_projer_app/data/mappers/event_kuehler_messung_mapper.dart';
import 'package:sbs_projer_app/services/storage/isar_service_export.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class EventKuehlerMessungRepository {
  static String get _userId => SupabaseService.dataUserId;

  static Future<List<EventKuehlerMessungLocal>> getByGeraet(
    String geraetId,
  ) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('event_kuehler_messungen').select()
          .eq('user_id', _userId)
          .eq('geraet_id', geraetId)
          .order('gemessen_am')
          .order('id');
      return rows
          .map((r) => EventKuehlerMessungMapper.fromDto(
                EventKuehlerMessung.fromJson(r),
              ))
          .toList();
    }
    return IsarService.eventKuehlerMessungFindByGeraet(geraetId);
  }

  static Future<void> save(EventKuehlerMessungLocal messung) async {
    messung.userId = _userId;
    messung.serverId ??= const Uuid().v4();
    if (kIsWeb) {
      final json = EventKuehlerMessungMapper.toJson(messung);
      await SupabaseService.client.from('event_kuehler_messungen').upsert(json);
      return;
    }
    messung.isSynced = false;
    messung.lastModifiedAt = DateTime.now().toUtc();
    await IsarService.eventKuehlerMessungPut(messung);
  }

  static Future<void> delete(String id) async {
    if (kIsWeb) {
      await SupabaseService.client
          .from('event_kuehler_messungen').delete().eq('id', id);
      return;
    }
    final isarId = int.parse(id);
    final local = await IsarService.eventKuehlerMessungGet(isarId);
    if (local?.serverId != null) {
      await SupabaseService.client
          .from('event_kuehler_messungen').delete().eq('id', local!.serverId!);
    }
    await IsarService.eventKuehlerMessungDelete(isarId);
  }
}

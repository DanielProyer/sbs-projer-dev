import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uuid/uuid.dart';
import 'package:sbs_projer_app/data/local/event_dokument_local_export.dart';
import 'package:sbs_projer_app/data/models/event_dokument.dart';
import 'package:sbs_projer_app/data/mappers/event_dokument_mapper.dart';
import 'package:sbs_projer_app/services/storage/isar_service_export.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class EventDokumentRepository {
  static String get _userId => SupabaseService.dataUserId;

  static Future<List<EventDokumentLocal>> getByEvent(String eventId) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('event_dokumente').select()
          .eq('user_id', _userId)
          .eq('event_id', eventId)
          .order('created_at');
      return rows
          .map((r) => EventDokumentMapper.fromDto(EventDokument.fromJson(r)))
          .toList();
    }
    return IsarService.eventDokumentFindByEvent(eventId);
  }

  static Future<void> save(EventDokumentLocal dokument) async {
    dokument.userId = _userId;
    dokument.serverId ??= const Uuid().v4();
    if (kIsWeb) {
      final json = EventDokumentMapper.toJson(dokument);
      await SupabaseService.client.from('event_dokumente').upsert(json);
      return;
    }
    dokument.isSynced = false;
    dokument.lastModifiedAt = DateTime.now().toUtc();
    await IsarService.eventDokumentPut(dokument);
  }

  static Future<void> delete(String id) async {
    if (kIsWeb) {
      await SupabaseService.client.from('event_dokumente').delete().eq('id', id);
      return;
    }
    // Native: zuerst serverseitig löschen, dann Isar aufräumen.
    final isarId = int.parse(id);
    final local = await IsarService.eventDokumentGet(isarId);
    if (local?.serverId != null) {
      await SupabaseService.client
          .from('event_dokumente').delete().eq('id', local!.serverId!);
    }
    await IsarService.eventDokumentDelete(isarId);
  }
}

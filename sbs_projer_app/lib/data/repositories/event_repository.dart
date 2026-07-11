import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uuid/uuid.dart';
import 'package:sbs_projer_app/data/local/event_local_export.dart';
import 'package:sbs_projer_app/data/models/event.dart';
import 'package:sbs_projer_app/data/mappers/event_mapper.dart';
import 'package:sbs_projer_app/services/google_calendar/google_calendar_sync_service.dart';
import 'package:sbs_projer_app/services/storage/isar_service_export.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class EventRepository {
  static String get _userId => SupabaseService.dataUserId;

  static Future<List<EventLocal>> getAll() async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('events').select()
          .eq('user_id', _userId)
          .order('jahr', ascending: false);
      return rows.map((r) => EventMapper.fromDto(Event.fromJson(r))).toList();
    }
    return IsarService.eventFindAll();
  }

  static Future<EventLocal?> getById(String id) async {
    if (kIsWeb) {
      final row = await SupabaseService.client
          .from('events').select().eq('id', id).maybeSingle();
      if (row == null) return null;
      return EventMapper.fromDto(Event.fromJson(row));
    }
    final byServerId = await IsarService.eventFindByServerId(id);
    if (byServerId != null) return byServerId;
    final isarId = int.tryParse(id);
    if (isarId == null) return null;
    return IsarService.eventGet(isarId);
  }

  static Future<void> save(EventLocal event) async {
    event.userId = _userId;
    // Server-UUID client-seitig generieren, damit event_kontakte.eventId
    // auch bei offline angelegten Events sofort einen gültigen Wert hat.
    event.serverId ??= const Uuid().v4();
    if (kIsWeb) {
      final json = EventMapper.toJson(event);
      await SupabaseService.client.from('events').upsert(json);
      await GoogleCalendarSyncService.push('event', event.serverId!);
      return;
    }
    event.isSynced = false;
    event.lastModifiedAt = DateTime.now().toUtc();
    await IsarService.eventPut(event);
  }

  static Future<void> delete(String id) async {
    if (kIsWeb) {
      await SupabaseService.client.from('events').delete().eq('id', id);
      await GoogleCalendarSyncService.push('event', id);
      return;
    }
    // Native: zuerst serverseitig löschen (CASCADE räumt event_kontakte ab),
    // dann Isar aufräumen — Muster stoerung_repository, verhindert Geister-Events.
    final isarId = int.parse(id);
    final local = await IsarService.eventGet(isarId);
    if (local?.serverId != null) {
      await SupabaseService.client
          .from('events').delete().eq('id', local!.serverId!);
    }
    await IsarService.eventDelete(isarId);
  }

  /// Liefert das jüngste Event des Betriebs mit Jahr < [jahr] (oder null).
  static Future<EventLocal?> getVorjahr(String betriebId, int jahr) async {
    final alle = await getAll();
    EventLocal? vorjahr;
    for (final e in alle) {
      if (e.betriebId != betriebId || e.jahr >= jahr) continue;
      if (vorjahr == null || e.jahr > vorjahr.jahr) vorjahr = e;
    }
    return vorjahr;
  }
}

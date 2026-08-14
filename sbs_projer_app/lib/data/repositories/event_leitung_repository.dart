import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uuid/uuid.dart';
import 'package:sbs_projer_app/core/util/event_technik.dart';
import 'package:sbs_projer_app/data/local/event_leitung_local_export.dart';
import 'package:sbs_projer_app/data/models/event_leitung.dart';
import 'package:sbs_projer_app/data/mappers/event_leitung_mapper.dart';
import 'package:sbs_projer_app/services/storage/isar_service_export.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class EventLeitungRepository {
  static String get _userId => SupabaseService.dataUserId;

  static Future<List<EventLeitungLocal>> getByEvent(String eventId) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('event_leitungen').select()
          .eq('user_id', _userId)
          .eq('event_id', eventId)
          .order('sortierung')
          .order('id');
      return rows
          .map((r) => EventLeitungMapper.fromDto(EventLeitung.fromJson(r)))
          .toList();
    }
    return IsarService.eventLeitungFindByEvent(eventId);
  }

  static Future<void> save(EventLeitungLocal leitung) async {
    leitung.userId = _userId;
    leitung.serverId ??= const Uuid().v4();
    if (kIsWeb) {
      final json = EventLeitungMapper.toJson(leitung);
      await SupabaseService.client.from('event_leitungen').upsert(json);
      return;
    }
    leitung.isSynced = false;
    leitung.lastModifiedAt = DateTime.now().toUtc();
    await IsarService.eventLeitungPut(leitung);
  }

  static Future<void> delete(String id) async {
    if (kIsWeb) {
      await SupabaseService.client.from('event_leitungen').delete().eq('id', id);
      return;
    }
    final isarId = int.parse(id);
    final local = await IsarService.eventLeitungGet(isarId);
    if (local?.serverId != null) {
      await SupabaseService.client
          .from('event_leitungen').delete().eq('id', local!.serverId!);
    }
    await IsarService.eventLeitungDelete(isarId);
  }

  /// Massenanlage «Leitungen erzeugen»: legt für die Quelle die Nummern
  /// [von]–[bis] an, überspringt bereits vorhandene (Unique-Index
  /// (quelle_id, nummer) bleibt sauber, die Aktion ist wiederholbar).
  /// Liefert die Anzahl neu angelegter Leitungen. Wirft [ArgumentError]
  /// bei Bereichen über 500 (Guard in [leitungsNummernBereich]).
  static Future<int> erzeugeLeitungen({
    required String eventId,
    required String quelleId,
    required int von,
    required int bis,
  }) async {
    final alle = await getByEvent(eventId);
    final bestehend = {
      for (final l in alle)
        if (l.quelleId == quelleId) l.nummer,
    };
    final neue = leitungsNummernBereich(von, bis, bestehend: bestehend);
    var sortierung = alle.where((l) => l.quelleId == quelleId).length;
    for (final nummer in neue) {
      final l = EventLeitungLocal()
        ..eventId = eventId
        ..quelleId = quelleId
        ..nummer = nummer
        ..sortierung = sortierung++;
      await save(l);
    }
    return neue.length;
  }
}

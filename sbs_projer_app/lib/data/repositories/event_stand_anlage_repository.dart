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

  /// Gleicht die Anlagen eines Stands id-basiert ab: bestehende (per serverId)
  /// werden auf Typ/Anzahl aktualisiert (inBetrieb/inBetriebAm bleiben erhalten),
  /// neue eingefügt, entfernte gelöscht. [zeilen] in gewünschter Reihenfolge.
  static Future<void> applyForStand(
      String standId, List<({String? serverId, String typ, int anzahl})> zeilen) async {
    final bestehende = await getByStand(standId);
    final beiId = {
      for (final b in bestehende)
        if (b.serverId != null) b.serverId!: b,
    };
    final behalten = <String>{};
    for (var i = 0; i < zeilen.length; i++) {
      final z = zeilen[i];
      final vorhanden = z.serverId != null ? beiId[z.serverId] : null;
      if (vorhanden != null) {
        vorhanden
          ..typ = z.typ
          ..anzahl = z.anzahl
          ..sortierung = i;
        await save(vorhanden); // inBetrieb/inBetriebAm bleiben unveraendert
        behalten.add(z.serverId!);
      } else {
        final neu = EventStandAnlageLocal()
          ..standId = standId
          ..typ = z.typ
          ..anzahl = z.anzahl
          ..sortierung = i;
        await save(neu);
      }
    }
    for (final b in bestehende) {
      if (b.serverId != null && !behalten.contains(b.serverId)) {
        await delete(b.routeId);
      }
    }
  }
}

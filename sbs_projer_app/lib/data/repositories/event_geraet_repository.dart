import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uuid/uuid.dart';
import 'package:sbs_projer_app/data/local/event_geraet_local_export.dart';
import 'package:sbs_projer_app/data/models/event_geraet.dart';
import 'package:sbs_projer_app/data/mappers/event_geraet_mapper.dart';
import 'package:sbs_projer_app/services/storage/isar_service_export.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class EventGeraetRepository {
  static String get _userId => SupabaseService.dataUserId;

  static Future<List<EventGeraetLocal>> getByEvent(String eventId) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('event_geraete').select()
          .eq('user_id', _userId)
          .eq('event_id', eventId)
          .order('sortierung')
          .order('id');
      return rows
          .map((r) => EventGeraetMapper.fromDto(EventGeraet.fromJson(r)))
          .toList();
    }
    return IsarService.eventGeraetFindByEvent(eventId);
  }

  static Future<void> save(EventGeraetLocal geraet) async {
    geraet.userId = _userId;
    geraet.serverId ??= const Uuid().v4();
    if (kIsWeb) {
      final json = EventGeraetMapper.toJson(geraet);
      await SupabaseService.client.from('event_geraete').upsert(json);
      return;
    }
    geraet.isSynced = false;
    geraet.lastModifiedAt = DateTime.now().toUtc();
    await IsarService.eventGeraetPut(geraet);
  }

  /// Löscht das Gerät. Leitungen mit diesem Gerät als QUELLE löscht die DB
  /// per ON DELETE CASCADE mit; als KÜHLER wird die Referenz genullt.
  /// Nativ werden die lokalen Kopien entsprechend nachgezogen — der Pull
  /// upsertet nur und würde die Leichen nie bereinigen.
  static Future<void> delete(String id) async {
    if (kIsWeb) {
      await SupabaseService.client.from('event_geraete').delete().eq('id', id);
      return;
    }
    final isarId = int.parse(id);
    final local = await IsarService.eventGeraetGet(isarId);
    if (local?.serverId != null) {
      await SupabaseService.client
          .from('event_geraete').delete().eq('id', local!.serverId!);
      final alsQuelle = await IsarService.eventLeitungFindByQuelle(
        local.serverId!,
      );
      for (final l in alsQuelle) {
        await IsarService.eventLeitungDelete(l.id);
      }
      // Reihenfolge tragend: erst Quelle-Leitungen löschen, DANN Kühler-
      // Referenzen nullen — umgekehrt würde put() eine soeben gelöschte
      // Leitung wieder anlegen.
      final alsKuehler = await IsarService.eventLeitungFindByKuehler(
        local.serverId!,
      );
      for (final l in alsKuehler) {
        l.kuehlerId = null;
        // bewusst ohne save(): der Server hat per ON DELETE SET NULL schon
        // genullt, isSynced bleibt true (kein Re-Push-Rauschen).
        await IsarService.eventLeitungPut(l);
      }
      // Messungen hängen per ON DELETE CASCADE am Gerät — lokale Kopien
      // ebenfalls nachziehen (der Pull upsertet nur, Leichen blieben sonst).
      final messungen = await IsarService.eventKuehlerMessungFindByGeraet(
        local.serverId!,
      );
      for (final m in messungen) {
        await IsarService.eventKuehlerMessungDelete(m.id);
      }
    }
    await IsarService.eventGeraetDelete(isarId);
  }
}

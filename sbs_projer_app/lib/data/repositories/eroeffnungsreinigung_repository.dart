import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sbs_projer_app/data/local/eroeffnungsreinigung_local_export.dart';
import 'package:sbs_projer_app/data/models/eroeffnungsreinigung.dart';
import 'package:sbs_projer_app/data/mappers/eroeffnungsreinigung_mapper.dart';
import 'package:sbs_projer_app/services/storage/isar_service_export.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class EroeffnungsreinigungRepository {
  static String get _userId => SupabaseService.currentUser!.id;

  static Future<List<EroeffnungsreinigungLocal>> getAll() async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('eroeffnungsreinigungen').select().eq('user_id', _userId);
      return rows.map((r) => EroeffnungsreinigungMapper.fromDto(Eroeffnungsreinigung.fromJson(r))).toList();
    }
    return IsarService.eroeffnungsreinigungFindAll();
  }

  static Future<EroeffnungsreinigungLocal?> getById(String id) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('eroeffnungsreinigungen').select().eq('id', id).limit(1);
      if (rows.isEmpty) return null;
      return EroeffnungsreinigungMapper.fromDto(Eroeffnungsreinigung.fromJson(rows.first));
    }
    return IsarService.eroeffnungsreinigungGet(int.parse(id));
  }

  static Stream<List<EroeffnungsreinigungLocal>> watchAll() {
    if (kIsWeb) return Stream.fromFuture(getAll());
    return IsarService.eroeffnungsreinigungWatchAll();
  }

  static Future<List<EroeffnungsreinigungLocal>> getByBetrieb(String betriebId) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('eroeffnungsreinigungen').select().eq('user_id', _userId).eq('betrieb_id', betriebId);
      return rows.map((r) => EroeffnungsreinigungMapper.fromDto(Eroeffnungsreinigung.fromJson(r))).toList();
    }
    return IsarService.eroeffnungsreinigungFilterByBetrieb(betriebId);
  }

  static Stream<List<EroeffnungsreinigungLocal>> watchByBetrieb(String betriebId) {
    if (kIsWeb) return Stream.fromFuture(getByBetrieb(betriebId));
    return IsarService.eroeffnungsreinigungWatchByBetrieb(betriebId);
  }

  static Future<int> count() async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('eroeffnungsreinigungen').select('id').eq('user_id', _userId);
      return rows.length;
    }
    return IsarService.eroeffnungsreinigungCount();
  }

  static Future<void> save(EroeffnungsreinigungLocal er) async {
    er.userId = _userId;
    if (kIsWeb) {
      final json = EroeffnungsreinigungMapper.toJson(er);
      await SupabaseService.client.from('eroeffnungsreinigungen').upsert(json);
      return;
    }
    er.isSynced = false;
    er.lastModifiedAt = DateTime.now().toUtc();
    await IsarService.eroeffnungsreinigungPut(er);
  }

  static Future<void> delete(String id) async {
    if (kIsWeb) {
      await SupabaseService.client.from('eroeffnungsreinigungen').delete().eq('id', id);
      return;
    }
    final local = await IsarService.eroeffnungsreinigungGet(int.parse(id));
    if (local?.serverId != null) {
      await SupabaseService.client.from('eroeffnungsreinigungen').delete().eq('id', local!.serverId!);
    }
    await IsarService.eroeffnungsreinigungDelete(int.parse(id));
  }
}

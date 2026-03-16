import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sbs_projer_app/data/local/stoerung_local_export.dart';
import 'package:sbs_projer_app/data/models/stoerung.dart';
import 'package:sbs_projer_app/data/mappers/stoerung_mapper.dart';
import 'package:sbs_projer_app/services/storage/isar_service_export.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class StoerungRepository {
  static String get _userId => SupabaseService.currentUser!.id;

  static Future<List<StoerungLocal>> getAll() async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('stoerungen').select().eq('user_id', _userId);
      return rows.map((r) => StoerungMapper.fromDto(Stoerung.fromJson(r))).toList();
    }
    return IsarService.stoerungFindAll();
  }

  static Future<StoerungLocal?> getById(String id) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('stoerungen').select().eq('id', id).limit(1);
      if (rows.isEmpty) return null;
      return StoerungMapper.fromDto(Stoerung.fromJson(rows.first));
    }
    return IsarService.stoerungGet(int.parse(id));
  }

  static Stream<List<StoerungLocal>> watchAll() {
    if (kIsWeb) return Stream.fromFuture(getAll());
    return IsarService.stoerungWatchAll();
  }

  static Future<List<StoerungLocal>> getByAnlage(String anlageId) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('stoerungen').select().eq('user_id', _userId).eq('anlage_id', anlageId);
      return rows.map((r) => StoerungMapper.fromDto(Stoerung.fromJson(r))).toList();
    }
    return IsarService.stoerungFilterByAnlage(anlageId);
  }

  static Future<List<StoerungLocal>> getByBetrieb(String betriebId) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('stoerungen').select().eq('user_id', _userId).eq('betrieb_id', betriebId);
      return rows.map((r) => StoerungMapper.fromDto(Stoerung.fromJson(r))).toList();
    }
    return IsarService.stoerungFilterByBetrieb(betriebId);
  }

  static Stream<List<StoerungLocal>> watchByAnlage(String anlageId) {
    if (kIsWeb) return Stream.fromFuture(getByAnlage(anlageId));
    return IsarService.stoerungWatchByAnlage(anlageId);
  }

  static Stream<List<StoerungLocal>> watchByBetrieb(String betriebId) {
    if (kIsWeb) return Stream.fromFuture(getByBetrieb(betriebId));
    return IsarService.stoerungWatchByBetrieb(betriebId);
  }

  static Future<int> count() async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('stoerungen').select('id').eq('user_id', _userId);
      return rows.length;
    }
    return IsarService.stoerungCount();
  }

  static Future<void> save(StoerungLocal stoerung) async {
    stoerung.userId = _userId;
    if (kIsWeb) {
      final json = StoerungMapper.toJson(stoerung);
      await SupabaseService.client.from('stoerungen').upsert(json);
      return;
    }
    stoerung.isSynced = false;
    stoerung.lastModifiedAt = DateTime.now().toUtc();
    await IsarService.stoerungPut(stoerung);
  }

  static Future<void> delete(String id) async {
    if (kIsWeb) {
      await SupabaseService.client.from('stoerungen').delete().eq('id', id);
      return;
    }
    // Native: Supabase löschen, dann Isar aufräumen
    final local = await IsarService.stoerungGet(int.parse(id));
    if (local?.serverId != null) {
      await SupabaseService.client.from('stoerungen').delete().eq('id', local!.serverId!);
    }
    await IsarService.stoerungDelete(int.parse(id));
  }

  static Future<String> generateStoerungsnummer() async {
    final now = DateTime.now();
    final prefix =
        'STR-${now.year}${now.month.toString().padLeft(2, '0')}-';
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('stoerungen').select('stoerungsnummer')
          .eq('user_id', _userId).like('stoerungsnummer', '$prefix%');
      final nextNum = rows.length + 1;
      return '$prefix${nextNum.toString().padLeft(3, '0')}';
    }
    final all = await IsarService.stoerungFilterByNummer(prefix);
    final nextNum = all.length + 1;
    return '$prefix${nextNum.toString().padLeft(3, '0')}';
  }
}

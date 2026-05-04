import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sbs_projer_app/data/local/bergkundenpauschale_local_export.dart';
import 'package:sbs_projer_app/data/models/bergkundenpauschale.dart';
import 'package:sbs_projer_app/data/mappers/bergkundenpauschale_mapper.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class BergkundenpauschaleRepository {
  static String get _userId => SupabaseService.currentUser!.id;
  static const _table = 'bergkundenpauschalen';

  static Future<List<BergkundenpauschaleLocal>> getAll() async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from(_table)
          .select()
          .eq('user_id', _userId)
          .order('datum', ascending: false);
      return rows
          .map((r) => BergkundenpauschaleMapper.fromDto(
              Bergkundenpauschale.fromJson(r)))
          .toList();
    }
    throw UnimplementedError('Native nicht implementiert');
  }

  static Future<BergkundenpauschaleLocal?> getById(String id) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from(_table)
          .select()
          .eq('id', id)
          .limit(1);
      if (rows.isEmpty) return null;
      return BergkundenpauschaleMapper.fromDto(
          Bergkundenpauschale.fromJson(rows.first));
    }
    throw UnimplementedError('Native nicht implementiert');
  }

  static Stream<List<BergkundenpauschaleLocal>> watchAll() {
    if (kIsWeb) return Stream.fromFuture(getAll());
    throw UnimplementedError('Native nicht implementiert');
  }

  static Future<List<BergkundenpauschaleLocal>> getByBetrieb(
      String betriebId) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from(_table)
          .select()
          .eq('user_id', _userId)
          .eq('betrieb_id', betriebId)
          .order('datum', ascending: false);
      return rows
          .map((r) => BergkundenpauschaleMapper.fromDto(
              Bergkundenpauschale.fromJson(r)))
          .toList();
    }
    throw UnimplementedError('Native nicht implementiert');
  }

  static Future<int> count() async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from(_table)
          .select('id')
          .eq('user_id', _userId);
      return rows.length;
    }
    throw UnimplementedError('Native nicht implementiert');
  }

  static Future<BergkundenpauschaleLocal> create(
      Map<String, dynamic> data) async {
    data['user_id'] = _userId;
    final rows = await SupabaseService.client
        .from(_table)
        .insert(data)
        .select();
    return BergkundenpauschaleMapper.fromDto(
        Bergkundenpauschale.fromJson(rows.first));
  }

  static Future<void> save(BergkundenpauschaleLocal entry) async {
    entry.userId = _userId;
    if (kIsWeb) {
      final json = BergkundenpauschaleMapper.toJson(entry);
      await SupabaseService.client.from(_table).upsert(json);
      return;
    }
    throw UnimplementedError('Native nicht implementiert');
  }

  static Future<void> delete(String id) async {
    if (kIsWeb) {
      await SupabaseService.client.from(_table).delete().eq('id', id);
      return;
    }
    throw UnimplementedError('Native nicht implementiert');
  }

  static Future<void> deleteByReinigungId(String reinigungId) async {
    if (kIsWeb) {
      await SupabaseService.client
          .from(_table)
          .delete()
          .eq('reinigung_id', reinigungId);
      return;
    }
    throw UnimplementedError('Native nicht implementiert');
  }
}

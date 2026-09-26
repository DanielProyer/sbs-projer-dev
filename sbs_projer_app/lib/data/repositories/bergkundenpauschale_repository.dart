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

  /// Gibt es für diesen Besuch schon eine Pauschale — zur Reinigung selbst
  /// ODER am selben Tag im selben Betrieb? Die Pauschale gilt pro Besuch
  /// (Betrieb + Tag), nicht pro Anlage. Die Abschlusskette läuft auch als
  /// Nachhol-Weg (Reinigungs-Detail) und beim erneuten Abschliessen — ohne
  /// diese Prüfung entstünde die Pauschale jedes Mal neu und würde Heineken
  /// doppelt verrechnet.
  static Future<bool> existiertFuerBesuch({
    required String reinigungId,
    required String betriebId,
    required DateTime datum,
  }) async {
    if (kIsWeb) {
      final tag = datum.toIso8601String().split('T').first;
      final rows = await SupabaseService.client
          .from(_table)
          .select('id')
          .or(
            'reinigung_id.eq.$reinigungId,'
            'and(betrieb_id.eq.$betriebId,datum.eq.$tag)',
          )
          .limit(1);
      return rows.isNotEmpty;
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

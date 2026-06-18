// lib/data/repositories/geschaeft_repository.dart
import 'package:sbs_projer_app/data/models/geschaeft_einstellungen.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class GeschaeftRepository {
  static String get _userId => SupabaseService.dataUserId;

  /// Lädt die Geschäfts-Zeile des Users. Falls keine existiert, gibt es ein
  /// leeres Model zurück (dessen Getter auf die Konstanten zurückfallen).
  static Future<GeschaeftEinstellungen> get() async {
    final rows = await SupabaseService.client
        .from('geschaeft_einstellungen')
        .select()
        .eq('user_id', _userId)
        .limit(1);
    if ((rows as List).isEmpty) return const GeschaeftEinstellungen();
    return GeschaeftEinstellungen.fromJson(rows.first);
  }

  /// Upsert auf user_id (eine Zeile pro User).
  static Future<GeschaeftEinstellungen> save(Map<String, dynamic> fields) async {
    final json = {
      ...fields,
      'user_id': _userId,
      'updated_at': DateTime.now().toIso8601String(),
    };
    final rows = await SupabaseService.client
        .from('geschaeft_einstellungen')
        .upsert(json, onConflict: 'user_id')
        .select();
    return GeschaeftEinstellungen.fromJson(rows.first);
  }
}

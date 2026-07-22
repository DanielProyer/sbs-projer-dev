import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// CRUD für die Tabelle aufgaben (Supabase only, kein Isar — Spec 22.07.).
class AufgabenRepository {
  static String get _uid => SupabaseService.currentUser!.id;

  static Future<List<Map<String, dynamic>>> alleZeilen() async =>
      List<Map<String, dynamic>>.from(
          await SupabaseService.client.from('aufgaben').select().eq('user_id', _uid));

  /// Upsert auf (user_id,typ,key). ACHTUNG: Der Unique-Index ist PARTIELL
  /// (WHERE key IS NOT NULL) — PostgREST kann den evtl. nicht als
  /// onConflict-Ziel nutzen. Deshalb robust: delete + insert (Einzel-User,
  /// kein Race relevant).
  static Future<void> _setzeKeyZeile(String typ, String key,
      Map<String, dynamic> felder) async {
    final client = SupabaseService.client;
    await client.from('aufgaben').delete()
        .eq('user_id', _uid).eq('typ', typ).eq('key', key);
    await client.from('aufgaben').insert({
      'user_id': _uid,
      'typ': typ,
      'key': key,
      ...felder,
    });
  }

  static Future<void> markerSetzen(String key) => _setzeKeyZeile(
      'marker', key,
      {'erledigt_am': DateTime.now().toUtc().toIso8601String()});

  static Future<void> markerLoeschen(String key) async =>
      SupabaseService.client.from('aufgaben').delete()
          .eq('user_id', _uid).eq('typ', 'marker').eq('key', key);

  static Future<void> snooze(String key, int tage) => _setzeKeyZeile(
      'snooze', key, {
        'snooze_bis': DateTime.now()
            .add(Duration(days: tage))
            .toIso8601String()
            .split('T')
            .first,
      });

  static Future<void> eigeneAnlegen(String titel, DateTime? faelligAm) async =>
      SupabaseService.client.from('aufgaben').insert({
        'user_id': _uid,
        'typ': 'eigene',
        'titel': titel,
        'faellig_am': faelligAm?.toIso8601String().split('T').first,
      });

  static Future<void> eigeneErledigen(String id) async =>
      SupabaseService.client.from('aufgaben')
          .update({'erledigt_am': DateTime.now().toUtc().toIso8601String()})
          .eq('id', id);
}

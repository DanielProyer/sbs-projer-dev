import 'package:flutter/foundation.dart' show debugPrint;
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Stösst den serverseitigen Push App -> Google Kalender an.
class GoogleCalendarSyncService {
  /// Ein Eintrag sofort synchronisieren. Fehler brechen NIE den Aufrufer.
  static Future<void> push(String entityType, String entityId) async {
    try {
      await SupabaseService.client.functions.invoke(
        'google-calendar-sync',
        body: {'action': 'push', 'entity_type': entityType, 'entity_id': entityId},
      );
    } catch (e) {
      debugPrint('[GCalSync] push $entityType/$entityId: $e');
    }
  }

  /// Vollabgleich (alle Einträge + Waisen löschen). Wirft bei Fehler.
  static Future<Map<String, dynamic>> reconcile() async {
    final res = await SupabaseService.client.functions
        .invoke('google-calendar-sync', body: {'action': 'reconcile'});
    final d = res.data;
    return d is Map ? Map<String, dynamic>.from(d) : {};
  }

  /// Betriebs-Reinigungen (Saison/Ferien) synchronisieren. [reinigungen] =
  /// Liste von {slot_key, art, datum (yyyy-MM-dd), aktiv}. Wirft bei Fehler.
  static Future<Map<String, dynamic>> syncBetriebReinigungen(
    String betriebId,
    String label,
    List<Map<String, dynamic>> reinigungen,
  ) async {
    final res = await SupabaseService.client.functions.invoke(
      'google-calendar-sync',
      body: {
        'action': 'sync_reinigungen',
        'betrieb_id': betriebId,
        'label': label,
        'reinigungen': reinigungen,
      },
    );
    final d = res.data;
    return d is Map ? Map<String, dynamic>.from(d) : {};
  }
}

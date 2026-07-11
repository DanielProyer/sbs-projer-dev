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

  /// K2a: Bestehende Google-Termine im Zeitraum scannen (read-only).
  /// [timeMin]/[timeMax] = RFC3339 (z.B. DateTime.toUtc().toIso8601String()).
  /// Rückgabe enthält 'events' (Liste {event_id, summary, start, is_all_day}),
  /// 'scanned', 'skipped_tagged'. Wirft bei Fehler.
  static Future<Map<String, dynamic>> scanManuelleTermine(
    String timeMin,
    String timeMax,
  ) async {
    final res = await SupabaseService.client.functions.invoke(
      'google-calendar-sync',
      body: {'action': 'scan_manual', 'time_min': timeMin, 'time_max': timeMax},
    );
    final d = res.data;
    return d is Map ? Map<String, dynamic>.from(d) : {};
  }

  /// K2b: Ausgewählte Termine taggen (Lavendel + Erinnerung + Betrieb-Tag,
  /// nur PATCH — Titel/Notizen bleiben). [items] = [{event_id, betrieb_id}].
  /// Rückgabe: {tagged, errors}. Wirft bei Fehler.
  static Future<Map<String, dynamic>> applyTags(
    List<Map<String, String>> items,
  ) async {
    final res = await SupabaseService.client.functions.invoke(
      'google-calendar-sync',
      body: {'action': 'apply_tags', 'items': items},
    );
    final d = res.data;
    return d is Map ? Map<String, dynamic>.from(d) : {};
  }

  /// K2b: K2-Tags wieder entfernen (Farbe/Erinnerung/Tag zurücksetzen).
  /// [eventIds] leer/null = alle. Rückgabe: {untagged, errors}. Wirft bei Fehler.
  static Future<Map<String, dynamic>> untagManuelle([
    List<String>? eventIds,
  ]) async {
    final res = await SupabaseService.client.functions.invoke(
      'google-calendar-sync',
      body: {
        'action': 'untag_manual',
        if (eventIds != null) 'event_ids': eventIds,
      },
    );
    final d = res.data;
    return d is Map ? Map<String, dynamic>.from(d) : {};
  }
}

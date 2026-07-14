import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:sbs_projer_app/core/util/tages_sync.dart';
import 'package:sbs_projer_app/services/google_calendar/google_calendar_sync_service.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Stösst den **täglichen** Google-Kalender-Vollabgleich automatisch an.
///
/// Prüft beim App-Start und danach stündlich, ob heute schon abgeglichen
/// wurde — deckt so auch einen tagelang offenen Browser-Tab ab (dort feuert
/// „beim Start" nie erneut). Läuft nur bei bestehender Session **und**
/// verbundenem Google-Konto. Fehler blockieren nie die App (nur Log).
class GoogleCalendarAutoSync {
  GoogleCalendarAutoSync._();

  static Timer? _timer;
  static bool _laeuft = false;

  /// Beim App-Start aufrufen: startet den stündlichen Check + prüft kurz
  /// verzögert einmal sofort.
  static void start() {
    _timer?.cancel();
    _timer = Timer.periodic(
        const Duration(hours: 1), (_) => _pruefeUndSynce());
    Future.delayed(const Duration(seconds: 5), _pruefeUndSynce);
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }

  static Future<void> _pruefeUndSynce() async {
    if (_laeuft) return;
    _laeuft = true;
    try {
      if (SupabaseService.client.auth.currentSession == null) return;
      final rows = await SupabaseService.client
          .from('google_calendar_status')
          .select('connected, last_sync_at')
          .limit(1);
      if (rows.isEmpty) return;
      final r = rows.first;
      if (r['connected'] != true) return;
      final lastRaw = r['last_sync_at'] as String?;
      final last = lastRaw != null ? DateTime.tryParse(lastRaw) : null;
      if (!brauchtTagesSync(last, DateTime.now())) return;
      debugPrint('[GCalAutoSync] Tages-Abgleich fällig → reconcile');
      await GoogleCalendarSyncService.reconcile();
    } catch (e) {
      debugPrint('[GCalAutoSync] $e');
    } finally {
      _laeuft = false;
    }
  }
}

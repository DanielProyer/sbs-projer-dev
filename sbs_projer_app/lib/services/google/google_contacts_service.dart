import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Ergebnis eines Sync-Laufs (Zähler aus der Edge-Function).
class KontakteSyncErgebnis {
  final int created, updated, deleted, total;
  final String info;
  const KontakteSyncErgebnis(
      this.created, this.updated, this.deleted, this.total, this.info);
}

/// Einseitiger Kontakte-Sync App -> Google (Edge-Function google-contacts-sync).
class GoogleContactsService {
  static Timer? _debounce;

  /// Manueller Lauf (Einstellungen-Button). Wirft bei Fehler.
  static Future<KontakteSyncErgebnis> syncJetzt() async {
    final res = await SupabaseService.client.functions
        .invoke('google-contacts-sync', body: {'action': 'reconcile'});
    final data = res.data;
    if (res.status != 200 || data is! Map || data['ok'] != true) {
      final msg = data is Map
          ? (data['error'] ?? data['skipped'] ?? 'Fehler').toString()
          : 'Fehler';
      throw Exception(msg);
    }
    return KontakteSyncErgebnis(
      (data['created'] as num?)?.toInt() ?? 0,
      (data['updated'] as num?)?.toInt() ?? 0,
      (data['deleted'] as num?)?.toInt() ?? 0,
      (data['total'] as num?)?.toInt() ?? 0,
      (data['info'] ?? '').toString(),
    );
  }

  /// Hintergrund-Lauf nach Speichern/Löschen: entprellt (5 s), Fehler still.
  /// Ohne Google-Verbindung oder Kontakte-Scope antwortet die Function mit
  /// skipped/Fehler — beides wird hier bewusst geschluckt; der nächste
  /// Reconcile holt alles nach.
  static void syncImHintergrund() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 5), () {
      syncJetzt().then((_) {}, onError: (Object e) {
        debugPrint('Kontakte-Sync (Hintergrund) übersprungen: $e');
      });
    });
  }
}

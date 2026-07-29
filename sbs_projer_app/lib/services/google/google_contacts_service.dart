import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sbs_projer_app/core/util/google_fehler.dart';
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

  /// Hintergrund-Lauf nach Speichern/Löschen, entprellt.
  ///
  /// Ist kein Google-Konto verbunden, passiert bewusst nichts. Scheitert der
  /// Lauf dagegen an der Einrichtung — API nicht freigeschaltet, fehlende
  /// Freigabe, abgelaufene Verbindung —, meldet [onFehler] das im Klartext.
  /// Vorher verschwand jeder Fehler im Log: Der Sync lief seit der fehlenden
  /// People-API-Freischaltung stumm ins Leere (29.07.2026).
  static void syncImHintergrund({void Function(GoogleFehler)? onFehler}) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () {
      syncJetzt().then((_) {}, onError: (Object e) {
        final f = googleFehler(e);
        debugPrint('Kontakte-Sync (Hintergrund) fehlgeschlagen: $e');
        if (f.istMeldenswert) onFehler?.call(f);
      });
    });
  }
}

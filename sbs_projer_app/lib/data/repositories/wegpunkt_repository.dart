import 'package:flutter/foundation.dart';
import 'package:sbs_projer_app/services/gps/gps_service.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Wegpunkte: Zeit-/Ortsstempel je Ereignis des Arbeitstags (Migration 155).
///
/// Statt Dauer-GPS-Tracking (in der Web-App nicht zuverlässig — der Browser
/// drosselt Hintergrund-Tabs, bei ausgeschaltetem Bildschirm läuft kein
/// JavaScript) stempelt die App bei jedem EREIGNIS einen Punkt: Reinigung
/// abgeschlossen, Störung/Montage erfasst, Arbeitsbeginn, Feierabend. Jeder
/// Punkt trägt Kontext (Quelle, Betrieb, Referenz) — für die spätere
/// Routen-Optimierung wertvoller als rohe 5-Minuten-Pings.
class WegpunktRepository {
  /// Stempelt einen Wegpunkt mit Ist-Zeit und (wenn möglich) GPS.
  ///
  /// Fire-and-forget gedacht: Fehler werden geloggt, nie geworfen — ein
  /// Wegpunkt darf kein Speichern stören. Ohne GPS wird trotzdem gestempelt:
  /// Die ZEIT ist für den Nachführungs-Guard das Entscheidende, die Position
  /// ist Zusatznutzen.
  static Future<void> stempeln({
    required String quelle,
    String? betriebId,
    String? referenzId,
    String? notiz,
    ({double lat, double lng})? position,
  }) async {
    try {
      var pos = position;
      if (pos == null) {
        try {
          final p = await GpsService.aktuellePosition();
          pos = (lat: p.latitude, lng: p.longitude);
        } catch (_) {
          // GPS verweigert/nicht verfügbar -> Punkt ohne Koordinaten.
        }
      }
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) return;
      await SupabaseService.client.from('wegpunkte').insert({
        'user_id': userId,
        'zeitpunkt': DateTime.now().toUtc().toIso8601String(),
        if (pos != null) 'lat': pos.lat,
        if (pos != null) 'lng': pos.lng,
        'quelle': quelle,
        if (betriebId != null) 'betrieb_id': betriebId,
        if (referenzId != null) 'referenz_id': referenzId,
        if (notiz != null && notiz.isNotEmpty) 'notiz': notiz,
      });
    } catch (e) {
      debugPrint('[Wegpunkt] Stempeln uebersprungen: $e');
    }
  }

  /// Lag zwischen [von] und [bis] (lokale Zeit) eine Störung oder Montage?
  ///
  /// Guard für die Fahrzeit-Nachführung: Wenn ja, ist die Lücke zwischen zwei
  /// Reinigungen keine reine Fahrzeit und darf nicht gelernt werden.
  static Future<bool> stoerungOderMontageZwischen(
    DateTime von,
    DateTime bis,
  ) async {
    try {
      final rows = await SupabaseService.client
          .from('wegpunkte')
          .select('id')
          .inFilter('quelle', ['stoerung', 'montage'])
          .gte('zeitpunkt', von.toUtc().toIso8601String())
          .lte('zeitpunkt', bis.toUtc().toIso8601String())
          .limit(1);
      return rows.isNotEmpty;
    } catch (e) {
      // Im Zweifel NICHT lernen — eine verpasste Beobachtung ist harmlos,
      // eine falsche verfälscht den gleitenden Median.
      debugPrint('[Wegpunkt] Guard-Abfrage fehlgeschlagen: $e');
      return true;
    }
  }
}

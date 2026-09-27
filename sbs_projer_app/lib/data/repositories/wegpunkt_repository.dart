import 'package:flutter/foundation.dart';
import 'package:sbs_projer_app/core/util/fahrten_aus_kette.dart'
    show StempelRoh;
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

  /// Einsatz-Stempel (Reinigung/Störung/Montage) und Leerfahrten
  /// (`vergeblich`, «War geschlossen») eines Monats — Zeitquelle für
  /// Einsätze ohne erfasste Arbeitszeit in «Fahrten aus der Kette»; eine
  /// Leerfahrt ist dort ein eigener Punkt-Halt.
  ///
  /// Mit Position (`lat`/`lng`): Ein Stempel zählt nur, wenn er am Betrieb
  /// gesetzt wurde (`stempelAmBetrieb`, ≤ 300 m) — Störungen/Montagen werden
  /// oft erst abends zuhause abgeschlossen.
  ///
  /// Monatsgrenzen in LOKALER Zeit (ein Stempel um 00:30 gehört zum neuen
  /// Tag), Zeitpunkte als `toLocal()` zurück — die Kette rechnet mit
  /// `hour * 60 + minute`. Rund 170 Stempel im stärksten Monat (Stand
  /// 27.09.2026), also weit unter dem PostgREST-Deckel; `.order('id')`
  /// zuletzt für eine stabile Reihenfolge (CLAUDE.md).
  ///
  /// Nur Supabase-Pfad: `wegpunkte` hat (wie der ganze Wegpunkt-Strom) kein
  /// Isar-Gegenstück. Für die Android-Vorlage nachzuziehen (lokale Tabelle
  /// oder Abfrage mit Online-Pflicht) — die Kette braucht die Stempel samt
  /// Position.
  static Future<List<StempelRoh>> getStempelImMonat(int jahr, int monat) async {
    final von = DateTime(jahr, monat, 1);
    final bis = DateTime(jahr, monat + 1, 1); // Monat 13 → Januar Folgejahr
    final rows = await SupabaseService.client
        .from('wegpunkte')
        .select('id, zeitpunkt, quelle, betrieb_id, referenz_id, lat, lng')
        // 'vergeblich' kennt der CHECK seit Migration 160.
        .inFilter('quelle', ['reinigung', 'stoerung', 'montage', 'vergeblich'])
        .gte('zeitpunkt', von.toUtc().toIso8601String())
        .lt('zeitpunkt', bis.toUtc().toIso8601String())
        .order('zeitpunkt')
        .order('id');
    return [
      for (final r in rows)
        (
          zeitpunkt: DateTime.parse(r['zeitpunkt'] as String).toLocal(),
          quelle: r['quelle'] as String,
          betriebId: r['betrieb_id'] as String?,
          referenzId: r['referenz_id'] as String?,
          lat: _zahl(r['lat']),
          lng: _zahl(r['lng']),
        ),
    ];
  }

  /// numeric kommt je nach Wert als Zahl oder als String zurück.
  static double? _zahl(Object? v) => switch (v) {
    num n => n.toDouble(),
    String s => double.tryParse(s),
    _ => null,
  };

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

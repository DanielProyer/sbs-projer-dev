import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:latlong2/latlong.dart';

/// Holt den tatsächlichen Strassenverlauf einer Tagesroute (Daniel
/// 30.07.2026: «wolltest du nicht Routen in der Karte darstellen»).
///
/// Die Tages-Karte verband die Besuche bis dahin mit Luftlinien — quer über
/// Berge und Seen. Diese Klasse fragt OSRM nach der gefahrenen Strecke und
/// liefert deren Stützpunkte zum Zeichnen.
///
/// Bewusst direkt gegen den OSRM-Demo-Server statt über eine Edge-Function:
/// Es ist eine reine Anzeige-Hilfe ohne Geheimnisse, und ein Fehlschlag ist
/// harmlos — die Karte fällt dann auf die Luftlinie zurück.
class TagesrouteService {
  /// OSRM erlaubt ~100 Wegpunkte je Anfrage; ein Arbeitstag bleibt weit
  /// darunter. Zur Sicherheit trotzdem eine Grenze, damit ein versehentlich
  /// riesiger Plan nicht in einer 414-URL endet.
  static const int _maxPunkte = 50;

  /// Strassenverlauf durch [punkte] in dieser Reihenfolge.
  ///
  /// Rückgabe `null` heisst «nicht verfügbar» (weniger als zwei Punkte,
  /// Netzfehler, keine Route) — der Aufrufer zeichnet dann die Luftlinie.
  static Future<List<LatLng>?> verlauf(List<LatLng> punkte) async {
    if (punkte.length < 2) return null;
    final ziele = punkte.length > _maxPunkte
        ? punkte.sublist(0, _maxPunkte)
        : punkte;
    try {
      final koordinaten = ziele
          .map(
            (p) =>
                '${p.longitude.toStringAsFixed(6)},'
                '${p.latitude.toStringAsFixed(6)}',
          )
          .join(';');
      final res = await Dio().get<Map<String, dynamic>>(
        'https://router.project-osrm.org/route/v1/driving/$koordinaten',
        queryParameters: const {'overview': 'full', 'geometries': 'geojson'},
        options: Options(
          receiveTimeout: const Duration(seconds: 12),
          sendTimeout: const Duration(seconds: 12),
        ),
      );
      return stuetzpunkte(res.data);
    } catch (e) {
      debugPrint('[Tagesroute] Verlauf nicht abrufbar: $e');
      return null;
    }
  }

  /// Liest die Stützpunkte aus einer OSRM-Antwort. Eigene Funktion, damit die
  /// Auswertung ohne Netz prüfbar ist. `null` bei allem, was nicht nach einer
  /// brauchbaren Route aussieht.
  static List<LatLng>? stuetzpunkte(Map<String, dynamic>? antwort) {
    if (antwort == null || antwort['code'] != 'Ok') return null;
    final routen = antwort['routes'];
    if (routen is! List || routen.isEmpty) return null;
    final erste = routen.first;
    if (erste is! Map) return null;
    final geometrie = erste['geometry'];
    if (geometrie is! Map) return null;
    final coords = geometrie['coordinates'];
    if (coords is! List || coords.length < 2) return null;
    final punkte = <LatLng>[];
    for (final c in coords) {
      if (c is! List || c.length < 2) return null;
      final lng = c[0], lat = c[1];
      if (lng is! num || lat is! num) return null;
      // GeoJSON liefert [lng, lat] — LatLng erwartet die andere Reihenfolge.
      punkte.add(LatLng(lat.toDouble(), lng.toDouble()));
    }
    return punkte;
  }
}

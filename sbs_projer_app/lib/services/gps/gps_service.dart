import 'package:geolocator/geolocator.dart';

/// Dünne Hülle um geolocator für die einmalige Standort-Erfassung.
class GpsService {
  /// Ab dieser Genauigkeit (Meter) gilt eine Messung als gut genug und die
  /// Erfassung bricht sofort ab.
  static const double _gutGenugMeter = 25;

  static const int _maxMessungen = 3;

  /// Holt die aktuelle Position; wirft mit verständlicher Meldung bei
  /// fehlender Berechtigung/deaktiviertem Dienst.
  ///
  /// Openair-Befund (Daniel 31.07.2026): Die erste Browser-Messung ist oft
  /// ein grober Netzwerk-Fix (WLAN/Funkzelle, teils mehrere 100 m daneben) —
  /// erst spätere Messungen liefern den GPS-Fix. Darum bis zu drei Messungen
  /// mit höchster Genauigkeitsstufe; die genaueste gewinnt, ab 25 m ist
  /// Schluss. Mehr als die Browser-Geolocation (fused Location des Handys)
  /// gibt es in einer Web-App nicht — Roh-GNSS bliebe einer nativen App
  /// vorbehalten.
  static Future<Position> aktuellePosition() async {
    final aktiv = await Geolocator.isLocationServiceEnabled();
    if (!aktiv) {
      throw 'Standortdienst ist deaktiviert.';
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      throw 'Kein Zugriff auf den Standort.';
    }

    Position? beste;
    for (var i = 0; i < _maxMessungen; i++) {
      try {
        final p = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            timeLimit: Duration(seconds: 6),
          ),
        );
        if (beste == null || p.accuracy < beste.accuracy) beste = p;
        // accuracy 0 heisst bei manchen Browsern «unbekannt» — dann weiter
        // messen statt die erste Messung blind zu übernehmen.
        if (beste.accuracy > 0 && beste.accuracy <= _gutGenugMeter) break;
      } on Exception {
        // Timeout: eine bereits vorhandene (schlechtere) Messung ist besser
        // als gar keine; ganz ohne Messung den Fehler weiterreichen.
        if (beste != null) break;
        if (i == _maxMessungen - 1) rethrow;
      }
    }
    return beste!;
  }
}

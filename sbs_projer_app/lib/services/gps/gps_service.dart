import 'package:geolocator/geolocator.dart';

/// Dünne Hülle um geolocator für die einmalige Standort-Erfassung.
class GpsService {
  /// Holt die aktuelle Position; wirft mit verständlicher Meldung bei
  /// fehlender Berechtigung/deaktiviertem Dienst.
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
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }
}

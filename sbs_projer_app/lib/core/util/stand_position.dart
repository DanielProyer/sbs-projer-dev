import 'package:sbs_projer_app/core/util/fahrzeit.dart';

/// Abgleich zwischen der hinterlegten und einer frisch gemessenen Standposition.
/// Reine Funktionen — testbar, ohne IO.
///
/// Regel (Daniel 11.08.2026): Es gibt **eine** Position je Stand. Am PC wird
/// sie auf der Karte geplant (`quelle = 'karte'`), im Feld per GPS gemessen.
/// Beim Messen wird nie stillschweigend überschrieben — es kommt eine
/// Rückfrage mit Kartenanzeige und Distanz. Nach der Übernahme gilt der
/// gemessene Standort als Realität und wandert auch ins Folgejahr; verschiebt
/// sich ein Stand, wird per Karte oder GPS neu erfasst.

/// Herkunft der gespeicherten Position.
const String quelleKarte = 'karte';
const String quelleGps = 'gps';

/// Verlässlichkeit der Position (Migration 169).
const String genauGenau = 'genau';
const String genauMittel = 'mittel';
const String genauUngefaehr = 'ungefaehr';

const List<String> alleGenauigkeiten = [
  genauGenau,
  genauMittel,
  genauUngefaehr,
];

/// Beschriftung für Auswahl und Anzeige.
String genauigkeitText(String? wert) => switch (wert) {
      genauGenau => 'genau',
      genauMittel => 'mittel',
      genauUngefaehr => 'ungefähr',
      _ => 'nicht angegeben',
    };

/// Genauigkeitsstufe aus der vom GPS gemeldeten Messgenauigkeit in Metern.
///
/// Die Schwellen sind bewusst grob: Ein Stand ist mehrere Meter breit, und
/// die Browser-Geolocation liefert selbst bei gutem Empfang selten unter 5 m.
String genauigkeitAusMessung(double? meter) {
  if (meter == null || meter <= 0) return genauMittel;
  if (meter <= 10) return genauGenau;
  if (meter <= 50) return genauMittel;
  return genauUngefaehr;
}

typedef PositionsAbgleich = ({
  /// Rückfrage nötig? Nur wenn schon eine vollständige Position existiert.
  bool brauchtRueckfrage,

  /// Abstand zur bisherigen Position in Metern; null, wenn es keine gab.
  double? distanzMeter,

  /// War die bisherige Position geplant (Karte) statt gemessen?
  bool bisherWarGeplant,
});

PositionsAbgleich positionsAbgleich({
  required double? bisherLat,
  required double? bisherLng,
  required String? bisherQuelle,
  required double neuLat,
  required double neuLng,
}) {
  // Halbe Koordinaten (nur lat oder nur lng) sind keine Position.
  if (bisherLat == null || bisherLng == null) {
    return (
      brauchtRueckfrage: false,
      distanzMeter: null,
      bisherWarGeplant: false,
    );
  }
  final km = haversineKm(bisherLat, bisherLng, neuLat, neuLng);
  return (
    brauchtRueckfrage: true,
    distanzMeter: km * 1000,
    bisherWarGeplant: bisherQuelle == quelleKarte,
  );
}

/// «14 m» / «2.5 km» — für Dialog und Kartenbeschriftung.
String distanzText(double meter) {
  if (meter < 1000) return '${meter.round()} m';
  return '${(meter / 1000).toStringAsFixed(1)} km';
}

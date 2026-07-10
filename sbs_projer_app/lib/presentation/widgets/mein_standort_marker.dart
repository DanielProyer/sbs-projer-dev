import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Auffällige Farbe für den eigenen Standort — kontrastiert stark mit dem vielen
/// Grün (und Wasser-Blau) auf dem swisstopo-Luftbild und ist keine der
/// Fälligkeits-Markerfarben.
const meinStandortColor = Color(0xFFE91E63); // Magenta/Pink

/// Marker (gefüllter Punkt mit weissem Ring) für die aktuelle Handy-Position.
Marker meinStandortMarker(LatLng point) {
  return Marker(
    point: point,
    width: 24,
    height: 24,
    child: Container(
      decoration: BoxDecoration(
        color: meinStandortColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(70), blurRadius: 4),
        ],
      ),
    ),
  );
}

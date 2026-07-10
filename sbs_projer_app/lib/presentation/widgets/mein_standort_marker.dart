import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Farbe für den eigenen Standort-Punkt (klassisches „My-Location"-Blau).
const meinStandortColor = Color(0xFF2196F3); // Blau

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

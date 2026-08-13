import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/stand_position.dart';
import 'package:sbs_projer_app/core/util/swisstopo.dart';

/// Rückfrage beim Erfassen einer Standposition im Feld (Daniel 11.08.2026):
/// Die bisherige und die gemessene Position nebeneinander auf der Karte, mit
/// Verbindungslinie und Abstand. Erst nach Bestätigung gilt der gemessene
/// Standort — überschrieben wird nie stillschweigend.
///
/// Gibt `true` zurück, wenn die neue Position übernommen werden soll.
Future<bool> zeigeStandPositionDialog(
  BuildContext context, {
  required String standName,
  required double bisherLat,
  required double bisherLng,
  required double neuLat,
  required double neuLng,
  required double distanzMeter,
  required bool bisherWarGeplant,
}) async {
  final alt = LatLng(bisherLat, bisherLng);
  final neu = LatLng(neuLat, neuLng);

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(standName),
      contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                bisherWarGeplant
                    ? 'Auf der Karte geplante Position liegt '
                        '${distanzText(distanzMeter)} entfernt.'
                    : 'Die bisher gemessene Position liegt '
                        '${distanzText(distanzMeter)} entfernt.',
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: FlutterMap(
                options: MapOptions(
                  initialCameraFit: CameraFit.coordinates(
                    coordinates: [alt, neu],
                    padding: const EdgeInsets.all(56),
                    maxZoom: 19,
                  ),
                  // Reine Anzeige — hier wird nichts verschoben.
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: basemapUrl(Basemap.luftbild),
                    userAgentPackageName: 'ch.sbsprojer.app',
                    maxZoom: 19,
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [alt, neu],
                        color: Colors.black54,
                        strokeWidth: 2,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: alt,
                        width: 36,
                        height: 36,
                        child: Icon(
                          bisherWarGeplant
                              ? Icons.push_pin
                              : Icons.location_on,
                          color: AppColors.info,
                          size: 36,
                        ),
                      ),
                      Marker(
                        point: neu,
                        width: 36,
                        height: 36,
                        child: const Icon(
                          Icons.gps_fixed,
                          color: Colors.red,
                          size: 32,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 10, 24, 0),
              child: Row(
                children: [
                  Icon(Icons.push_pin, size: 16, color: AppColors.info),
                  SizedBox(width: 6),
                  Text('bisher', style: TextStyle(fontSize: 12)),
                  SizedBox(width: 16),
                  Icon(Icons.gps_fixed, size: 16, color: Colors.red),
                  SizedBox(width: 6),
                  Text('jetzt gemessen', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Bisherige behalten'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Gemessene übernehmen'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

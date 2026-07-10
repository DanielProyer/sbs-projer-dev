import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:sbs_projer_app/data/local/event_stand_local_export.dart';

/// Karte mit swisstopo-Luftbild und einem Marker je Stand (mit GPS).
/// Tap auf Marker ruft [onStandTap] mit dem Stand auf.
class EventStaendeMap extends StatelessWidget {
  final List<EventStandLocal> staende;
  final void Function(EventStandLocal) onStandTap;

  const EventStaendeMap(
      {super.key, required this.staende, required this.onStandTap});

  @override
  Widget build(BuildContext context) {
    final mitGps = staende
        .where((s) => s.latitude != null && s.longitude != null)
        .toList();
    if (mitGps.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Noch keine Stand-Standorte erfasst.\n'
            'Bei einem Stand «Standort erfassen» tippen.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final punkte =
        mitGps.map((s) => LatLng(s.latitude!, s.longitude!)).toList();

    return FlutterMap(
      options: MapOptions(
        initialCameraFit: CameraFit.coordinates(
          coordinates: punkte,
          padding: const EdgeInsets.all(48),
          maxZoom: 18,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://wmts.geo.admin.ch/1.0.0/ch.swisstopo.swissimage/default/current/3857/{z}/{x}/{y}.jpeg',
          userAgentPackageName: 'ch.sbsprojer.app',
          maxZoom: 19,
        ),
        MarkerLayer(
          markers: [
            for (final s in mitGps)
              Marker(
                point: LatLng(s.latitude!, s.longitude!),
                width: 40,
                height: 40,
                child: GestureDetector(
                  onTap: () => onStandTap(s),
                  child: const Icon(Icons.location_on,
                      color: Colors.red, size: 40),
                ),
              ),
          ],
        ),
        const RichAttributionWidget(
          attributions: [TextSourceAttribution('© swisstopo')],
        ),
      ],
    );
  }
}

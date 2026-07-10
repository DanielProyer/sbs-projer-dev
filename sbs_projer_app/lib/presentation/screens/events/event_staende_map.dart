import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:sbs_projer_app/core/util/swisstopo.dart';
import 'package:sbs_projer_app/data/local/event_stand_local_export.dart';
import 'package:sbs_projer_app/presentation/widgets/basemap_umschalter.dart';

/// Karte mit swisstopo-Hintergrund (Luftbild/Karte umschaltbar) und einem
/// Marker je Stand (mit GPS). Tap auf Marker ruft [onStandTap] mit dem Stand auf.
class EventStaendeMap extends StatefulWidget {
  final List<EventStandLocal> staende;
  final void Function(EventStandLocal) onStandTap;

  const EventStaendeMap(
      {super.key, required this.staende, required this.onStandTap});

  @override
  State<EventStaendeMap> createState() => _EventStaendeMapState();
}

class _EventStaendeMapState extends State<EventStaendeMap> {
  final _controller = MapController();
  bool _luftbild = true;

  @override
  Widget build(BuildContext context) {
    final mitGps = widget.staende
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

    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCameraFit: CameraFit.coordinates(
              coordinates: punkte,
              padding: const EdgeInsets.all(48),
              maxZoom: 18,
            ),
            onMapReady: () {
              // CanvasKit zeichnet die Kacheln sonst erst nach der ersten
              // Interaktion. Ein minimaler (unsichtbarer) Kamera-Nudge nach dem
              // ersten Frame erzwingt den Repaint, sodass die Kacheln sofort da sind.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                final cam = _controller.camera;
                _controller.move(cam.center, cam.zoom + 0.02);
              });
            },
          ),
          children: [
            TileLayer(
              key: ValueKey(_luftbild),
              urlTemplate: _luftbild ? swisstopoLuftbild : swisstopoKarte,
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
                      onTap: () => widget.onStandTap(s),
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
        ),
        Positioned(
          top: 8,
          right: 8,
          child: BasemapUmschalter(
            luftbild: _luftbild,
            onChanged: (v) => setState(() => _luftbild = v),
          ),
        ),
      ],
    );
  }
}

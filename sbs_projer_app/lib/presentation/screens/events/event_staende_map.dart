import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:sbs_projer_app/core/util/swisstopo.dart';
import 'package:sbs_projer_app/data/local/event_stand_local_export.dart';
import 'package:sbs_projer_app/presentation/widgets/basemap_umschalter.dart';
import 'package:sbs_projer_app/presentation/widgets/mein_standort_marker.dart';
import 'package:sbs_projer_app/services/gps/gps_service.dart';

/// Karte mit swisstopo-Hintergrund (Luftbild/Karte umschaltbar), einem Marker je
/// Stand (mit GPS) und dem eigenen Handy-Standort. Tap auf Marker ruft
/// [onStandTap] mit dem Stand auf.
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
  LatLng? _meinStandort;
  bool _standortLaedt = false;

  @override
  void initState() {
    super.initState();
    _ladeStandort();
  }

  /// Holt die aktuelle Handy-Position und zeigt sie als Marker.
  /// Bei [zentrieren] wird die Karte zusätzlich darauf zentriert.
  Future<void> _ladeStandort({bool zentrieren = false}) async {
    setState(() => _standortLaedt = true);
    try {
      final pos = await GpsService.aktuellePosition();
      if (!mounted) return;
      setState(() => _meinStandort = LatLng(pos.latitude, pos.longitude));
      if (zentrieren) _controller.move(_meinStandort!, 15);
    } catch (e) {
      if (mounted && zentrieren) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Standort: $e')));
      }
    } finally {
      if (mounted) setState(() => _standortLaedt = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mitGps = widget.staende
        .where((s) => s.latitude != null && s.longitude != null)
        .toList();
    // Auch ohne Stand-Standorte die Karte (mit eigenem Standort) zeigen.
    final punkte =
        mitGps.map((s) => LatLng(s.latitude!, s.longitude!)).toList();
    final schweiz = LatLng(46.8, 8.23);

    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCameraFit: punkte.isEmpty
                ? null
                : CameraFit.coordinates(
                    coordinates: punkte,
                    padding: const EdgeInsets.all(48),
                    maxZoom: 18,
                  ),
            initialCenter: punkte.isEmpty ? schweiz : punkte.first,
            initialZoom: punkte.isEmpty ? 7.5 : 13,
            onMapReady: () {
              // CanvasKit zeichnet die Kacheln sonst erst nach der ersten
              // Interaktion. Ein minimaler Kamera-Nudge nach dem ersten Frame
              // erzwingt den Repaint, sodass die Kacheln sofort da sind.
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
            if (_meinStandort != null)
              MarkerLayer(markers: [meinStandortMarker(_meinStandort!)]),
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
        Positioned(
          right: 8,
          bottom: 34,
          child: FloatingActionButton.small(
            heroTag: 'event_standort',
            onPressed:
                _standortLaedt ? null : () => _ladeStandort(zentrieren: true),
            tooltip: 'Mein Standort',
            child: _standortLaedt
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }
}

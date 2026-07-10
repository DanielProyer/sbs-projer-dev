import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/swisstopo.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/basemap_umschalter.dart';
import 'package:sbs_projer_app/presentation/widgets/mein_standort_marker.dart';
import 'package:sbs_projer_app/services/gps/gps_service.dart';

/// Ein Betrieb mit seiner aggregierten Fälligkeit für die Karte.
class BetriebMarkerData {
  final BetriebLocal betrieb;
  final FaelligkeitsStatus status;
  const BetriebMarkerData(this.betrieb, this.status);
}

/// swisstopo-Karte mit einem farbigen Marker je Betrieb (mit Koordinaten).
/// Farbe nach [BetriebMarkerData.status]. Tap -> Popup mit «Öffnen».
class BetriebeMap extends StatefulWidget {
  final List<BetriebMarkerData> eintraege;
  final void Function(BetriebLocal) onOeffnen;
  final void Function(BetriebLocal) onRoute;

  const BetriebeMap({
    super.key,
    required this.eintraege,
    required this.onOeffnen,
    required this.onRoute,
  });

  @override
  State<BetriebeMap> createState() => _BetriebeMapState();
}

class _BetriebeMapState extends State<BetriebeMap> {
  final _controller = MapController();
  bool _luftbild = true;
  LatLng? _meinStandort;
  bool _standortLaedt = false;

  // Mittelpunkt Schweiz als Fallback (0 Marker).
  static final _schweiz = LatLng(46.8, 8.23);

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
      if (zentrieren) _controller.move(_meinStandort!, 14);
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
    final mitGps = widget.eintraege
        .where((e) =>
            e.betrieb.latitude != null && e.betrieb.longitude != null)
        .toList();
    final punkte = mitGps
        .map((e) => LatLng(e.betrieb.latitude!, e.betrieb.longitude!))
        .toList();

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
                    maxZoom: 16,
                  ),
            initialCenter: punkte.isEmpty ? _schweiz : punkte.first,
            initialZoom: punkte.isEmpty ? 7.5 : 12,
            onMapReady: () {
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
                for (final e in mitGps)
                  Marker(
                    point: LatLng(
                        e.betrieb.latitude!, e.betrieb.longitude!),
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () => _zeigePopup(e),
                      child: Icon(Icons.location_on,
                          color: faelligkeitFarbe(e.status), size: 40),
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
          left: 8,
          bottom: 8,
          child: _Legende(),
        ),
        Positioned(
          right: 8,
          bottom: 34,
          child: FloatingActionButton.small(
            heroTag: 'betriebe_standort',
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF2196F3),
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

  void _zeigePopup(BetriebMarkerData e) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.betrieb.name,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.circle,
                      size: 12, color: faelligkeitFarbe(e.status)),
                  const SizedBox(width: 6),
                  Text(faelligkeitLabel(e.status)),
                ],
              ),
              if (e.betrieb.ort != null) ...[
                const SizedBox(height: 4),
                Text(e.betrieb.ort!,
                    style: const TextStyle(color: AppColors.textSecondary)),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        widget.onRoute(e.betrieb);
                      },
                      icon: const Icon(Icons.directions),
                      label: const Text('Route'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        widget.onOeffnen(e.betrieb);
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Öffnen'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legende extends StatelessWidget {
  static const _eintraege = [
    (FaelligkeitsStatus.ueberfaellig, 'Überfällig'),
    (FaelligkeitsStatus.faellig, 'Fällig'),
    (FaelligkeitsStatus.baldFaellig, 'Bald'),
    (FaelligkeitsStatus.eroeffnungFaellig, 'Eröffnung'),
    (FaelligkeitsStatus.nichtFaellig, 'OK'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface.withAlpha(230),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (status, label) in _eintraege)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle,
                      size: 10, color: faelligkeitFarbe(status)),
                  const SizedBox(width: 4),
                  Text(label, style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

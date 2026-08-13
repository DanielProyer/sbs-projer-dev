import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/stand_position.dart';
import 'package:sbs_projer_app/core/util/swisstopo.dart';
import 'package:sbs_projer_app/data/local/event_stand_local_export.dart';
import 'package:sbs_projer_app/presentation/widgets/basemap_umschalter.dart';
import 'package:sbs_projer_app/presentation/widgets/mein_standort_marker.dart';
import 'package:sbs_projer_app/services/gps/gps_service.dart';

/// Karte mit swisstopo-Hintergrund (Luftbild/Karte umschaltbar), einem Marker je
/// Stand (mit Position) und dem eigenen Handy-Standort. Tap auf Marker ruft
/// [onStandTap] mit dem Stand auf.
///
/// **Positionieren am PC** (Daniel 11.08.2026): Über den Knopf «Positionieren»
/// lässt sich ein Stand auswählen und per Tap auf die Karte setzen — das ist
/// die Planung vor dem Anlass, ohne GPS und ohne vor Ort zu sein. Im Feld
/// wird die Position dann per «Standort erfassen» gemessen und nach Rückfrage
/// übernommen; Regeln siehe `core/util/stand_position.dart`.
class EventStaendeMap extends StatefulWidget {
  final List<EventStandLocal> staende;
  final void Function(EventStandLocal) onStandTap;

  /// Position eines Stands auf der Karte setzen (Planung). Fehlt der Callback,
  /// ist die Karte reine Anzeige.
  final Future<void> Function(EventStandLocal stand, LatLng punkt)?
      onPositionSetzen;

  const EventStaendeMap({
    super.key,
    required this.staende,
    required this.onStandTap,
    this.onPositionSetzen,
  });

  @override
  State<EventStaendeMap> createState() => _EventStaendeMapState();
}

class _EventStaendeMapState extends State<EventStaendeMap> {
  final _controller = MapController();
  // Stände liegen oft auf Wiesen/Plätzen ohne Strassennetz — dort bleibt das
  // Luftbild der brauchbarste Hintergrund (anders als bei den Betriebskarten).
  Basemap _basemap = Basemap.luftbild;
  LatLng? _meinStandort;
  bool _standortLaedt = false;

  /// Stand, der gerade platziert wird (null = normaler Anzeigemodus).
  EventStandLocal? _platziert;
  bool _speichert = false;

  /// Tap auf die Karte im Positionier-Modus.
  Future<void> _kartenTap(LatLng punkt) async {
    final stand = _platziert;
    if (stand == null || widget.onPositionSetzen == null || _speichert) return;
    setState(() => _speichert = true);
    try {
      await widget.onPositionSetzen!(stand, punkt);
      if (!mounted) return;
      // Nach dem Setzen gleich zum nächsten Stand ohne Position — so lässt
      // sich ein ganzer Anlass in einem Durchgang platzieren.
      final offen = widget.staende
          .where((s) => s.serverId != stand.serverId && s.latitude == null)
          .toList();
      setState(() => _platziert = offen.isEmpty ? null : offen.first);
      if (offen.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alle Stände sind positioniert.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Position nicht gespeichert: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _speichert = false);
    }
  }

  /// Auswahl, welcher Stand platziert werden soll.
  Future<void> _standWaehlen() async {
    final gewaehlt = await showModalBottomSheet<EventStandLocal>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Welchen Stand positionieren?',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'Danach auf die Karte tippen. Ohne Position erfasste Stände '
                'stehen zuoberst.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            for (final s in _nachPositionSortiert())
              ListTile(
                leading: Icon(
                  s.latitude == null
                      ? Icons.location_off_outlined
                      : (s.positionQuelle == quelleGps
                          ? Icons.gps_fixed
                          : Icons.push_pin_outlined),
                  color: s.latitude == null
                      ? AppColors.textSecondary
                      : (s.positionQuelle == quelleGps
                          ? AppColors.success
                          : AppColors.info),
                ),
                title: Text(s.name),
                subtitle: Text(
                  s.latitude == null
                      ? 'Noch keine Position'
                      : (s.positionQuelle == quelleGps
                          ? 'Im Feld gemessen'
                          : 'Auf der Karte geplant'),
                ),
                onTap: () => Navigator.pop(ctx, s),
              ),
          ],
        ),
      ),
    );
    if (gewaehlt != null && mounted) {
      setState(() => _platziert = gewaehlt);
    }
  }

  /// Stände ohne Position zuerst, dann nach Name.
  List<EventStandLocal> _nachPositionSortiert() {
    final liste = List.of(widget.staende);
    liste.sort((a, b) {
      final aOhne = a.latitude == null ? 0 : 1;
      final bOhne = b.latitude == null ? 0 : 1;
      if (aOhne != bOhne) return aOhne.compareTo(bOhne);
      return a.name.compareTo(b.name);
    });
    return liste;
  }

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Standort: $e')));
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
    final punkte = mitGps
        .map((s) => LatLng(s.latitude!, s.longitude!))
        .toList();
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
            onTap: _platziert == null ? null : (_, punkt) => _kartenTap(punkt),
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
              key: ValueKey(_basemap),
              urlTemplate: basemapUrl(_basemap),
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
                      // Im Positionier-Modus wählt ein Marker-Tap den Stand
                      // zum Verschieben aus, statt ihn zu bearbeiten.
                      onTap: () => _platziert == null
                          ? widget.onStandTap(s)
                          : setState(() => _platziert = s),
                      child: Icon(
                        Icons.location_on,
                        // Geplant (Karte) blau, im Feld gemessen rot — auf
                        // einen Blick sichtbar, was noch zu prüfen ist.
                        color: s.serverId == _platziert?.serverId
                            ? Colors.orange
                            : (s.positionQuelle == quelleGps
                                ? Colors.red
                                : AppColors.info),
                        size: 40,
                      ),
                    ),
                  ),
              ],
            ),
            if (_meinStandort != null)
              MarkerLayer(markers: [meinStandortMarker(_meinStandort!)]),
            RichAttributionWidget(
              attributions: [TextSourceAttribution(basemapQuelle(_basemap))],
            ),
          ],
        ),
        Positioned(
          top: 8,
          right: 8,
          child: BasemapUmschalter(
            aktiv: _basemap,
            onChanged: (v) => setState(() => _basemap = v),
          ),
        ),

        // Bedienleiste zum Positionieren (nur wenn der Aufrufer speichern kann).
        if (widget.onPositionSetzen != null)
          Positioned(
            left: 8,
            top: 8,
            right: 64,
            child: _PositionierLeiste(
              stand: _platziert,
              speichert: _speichert,
              ohnePosition:
                  widget.staende.where((s) => s.latitude == null).length,
              onWaehlen: _standWaehlen,
              onAbbrechen: () => setState(() => _platziert = null),
            ),
          ),
        Positioned(
          right: 8,
          bottom: 34,
          child: FloatingActionButton.small(
            heroTag: 'event_standort',
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF2196F3),
            onPressed: _standortLaedt
                ? null
                : () => _ladeStandort(zentrieren: true),
            tooltip: 'Mein Standort',
            child: _standortLaedt
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }
}

/// Leiste oben links: startet das Positionieren und zeigt, welcher Stand
/// gerade gesetzt wird. Bewusst GestureDetector statt Material-Buttons —
/// die rendern auf manchen CanvasKit-Screens nicht zuverlässig.
class _PositionierLeiste extends StatelessWidget {
  final EventStandLocal? stand;
  final bool speichert;
  final int ohnePosition;
  final VoidCallback onWaehlen;
  final VoidCallback onAbbrechen;

  const _PositionierLeiste({
    required this.stand,
    required this.speichert,
    required this.ohnePosition,
    required this.onWaehlen,
    required this.onAbbrechen,
  });

  @override
  Widget build(BuildContext context) {
    if (stand == null) {
      return Align(
        alignment: Alignment.topLeft,
        child: GestureDetector(
          onTap: onWaehlen,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_location_alt_outlined,
                    size: 18, color: AppColors.info),
                const SizedBox(width: 6),
                Text(
                  ohnePosition > 0
                      ? 'Positionieren ($ohnePosition offen)'
                      : 'Positionieren',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: Row(
        children: [
          if (speichert)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            const Icon(Icons.touch_app, size: 18, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  stand!.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                const Text(
                  'Auf die Karte tippen',
                  style: TextStyle(fontSize: 11, color: Colors.black87),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onAbbrechen,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

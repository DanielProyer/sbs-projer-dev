import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/swisstopo.dart';
import 'package:sbs_projer_app/core/util/touren_anzeige.dart';
import 'package:sbs_projer_app/presentation/providers/reinigung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/basemap_umschalter.dart';

/// Ein Punkt der Tages-Route in zeitlicher Reihenfolge.
class _TagesPunkt {
  final int zeitMin;
  final LatLng pos;
  final String label;
  final Color farbe;
  final IconData? icon;

  /// Besuchs-Nummer (nur Reinigungen), sonst null.
  final int? nummer;

  const _TagesPunkt({
    required this.zeitMin,
    required this.pos,
    required this.label,
    required this.farbe,
    this.icon,
    this.nummer,
  });
}

/// Tages-Karte (Daniel 31.07.2026): die tatsächlichen Besuche und
/// Wegpunkt-Stempel eines Tages auf der swisstopo-Karte, zeitlich als Linie
/// verbunden — inkl. Start-/Endposition des Arbeitstags (GPS der Knöpfe).
///
/// Besuchs-Marker sitzen auf den Betriebs-Koordinaten; Wegpunkte auf der
/// tatsächlich gestempelten GPS-Position. Aussagekräftig ab 31.07.2026 —
/// erst seit dann werden Wegpunkte und Arbeitstag-GPS erfasst.
class TagesKarteScreen extends ConsumerStatefulWidget {
  final DateTime datum;

  const TagesKarteScreen({super.key, required this.datum});

  @override
  ConsumerState<TagesKarteScreen> createState() => _TagesKarteScreenState();
}

class _TagesKarteScreenState extends ConsumerState<TagesKarteScreen> {
  Basemap _basemap = Basemap.osm;

  static const _schweiz = LatLng(46.8182, 9.0);

  @override
  Widget build(BuildContext context) {
    final lookup = ref.watch(betriebLookupProvider);
    final punkte = <_TagesPunkt>[];

    // ── Besuche: abgeschlossene Reinigungen des Tages (Betriebs-GPS) ──
    final reinigungenDesTages =
        [
          for (final r in ref.watch(reinigungenProvider))
            if (r.status == 'abgeschlossen' &&
                r.betriebId.isNotEmpty &&
                r.datum.year == widget.datum.year &&
                r.datum.month == widget.datum.month &&
                r.datum.day == widget.datum.day)
              r,
        ]..sort(
          (a, b) => (minutenAusHhmm(a.uhrzeitStart) ?? 1440).compareTo(
            minutenAusHhmm(b.uhrzeitStart) ?? 1440,
          ),
        );
    var nummer = 0;
    for (final r in reinigungenDesTages) {
      final b = lookup[r.betriebId];
      if (b?.latitude == null || b?.longitude == null) continue;
      nummer++;
      punkte.add(
        _TagesPunkt(
          zeitMin: minutenAusHhmm(r.uhrzeitStart) ?? 1440,
          pos: LatLng(b!.latitude!, b.longitude!),
          label:
              '${r.uhrzeitStart ?? '—'} ${b.name}'
              '${b.ort != null ? ' (${b.ort})' : ''}',
          farbe: AppColors.success,
          nummer: nummer,
        ),
      );
    }

    // ── Wegpunkt-Stempel mit GPS (Störung/Montage/Arbeitstag-Ränder) ──
    // Reinigungs-Stempel bewusst nicht doppelt — die Besuche sind schon da.
    final wegpunkte =
        ref.watch(wegpunkteFuerTagProvider(widget.datum)).valueOrNull ??
        const <WegpunktTag>[];
    for (final w in wegpunkte) {
      if (w.lat == null || w.lng == null || w.quelle == 'reinigung') continue;
      final zeit = w.zeitpunkt.hour * 60 + w.zeitpunkt.minute;
      final betrieb = w.betriebId != null ? lookup[w.betriebId!] : null;
      final (label, farbe, icon) = switch (w.quelle) {
        'arbeitsbeginn' => ('Arbeitsbeginn', AppColors.primary, Icons.flag),
        'feierabend' => ('Feierabend', AppColors.info, Icons.sports_score),
        'stoerung' => ('Störung', AppColors.error, Icons.warning_amber),
        'montage' => ('Montage', AppColors.info, Icons.construction),
        _ => ('Wegpunkt', AppColors.textSecondary, Icons.place),
      };
      punkte.add(
        _TagesPunkt(
          zeitMin: zeit,
          pos: LatLng(w.lat!, w.lng!),
          label:
              '${hhmmAusMinuten(zeit)} $label'
              '${betrieb != null ? ' ${betrieb.name}' : ''}',
          farbe: farbe,
          icon: icon,
        ),
      );
    }

    // ── Arbeitstag-Ränder aus der Plan-Zeile (falls kein Wegpunkt-GPS) ──
    final g = ref
        .watch(gespeicherterTagesplanProvider(widget.datum))
        .valueOrNull;
    final hatBeginnPunkt = punkte.any((p) => p.icon == Icons.flag);
    if (!hatBeginnPunkt && g?.startLat != null && g?.startLng != null) {
      punkte.add(
        _TagesPunkt(
          zeitMin: minutenAusHhmm(g?.arbeitsbeginn) ?? 0,
          pos: LatLng(g!.startLat!, g.startLng!),
          label: 'Arbeitsbeginn ${g.arbeitsbeginn ?? ''}'.trim(),
          farbe: AppColors.primary,
          icon: Icons.flag,
        ),
      );
    }
    final hatEndPunkt = punkte.any((p) => p.icon == Icons.sports_score);
    if (!hatEndPunkt && g?.endLat != null && g?.endLng != null) {
      punkte.add(
        _TagesPunkt(
          zeitMin: minutenAusHhmm(g?.arbeitsende) ?? 1439,
          pos: LatLng(g!.endLat!, g.endLng!),
          label: 'Feierabend ${g.arbeitsende ?? ''}'.trim(),
          farbe: AppColors.info,
          icon: Icons.sports_score,
        ),
      );
    }

    punkte.sort((a, b) => a.zeitMin.compareTo(b.zeitMin));
    final koordinaten = punkte.map((p) => p.pos).toList();

    final df = DateFormat('EE, d. MMM yyyy', 'de_CH');
    return Scaffold(
      appBar: AppBar(title: Text('Tour ${df.format(widget.datum)}')),
      body: punkte.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Keine Daten mit Standort an diesem Tag.\n'
                  'Besuche brauchen Betriebs-Koordinaten, Wegpunkte werden '
                  'seit 31.07.2026 erfasst.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          : Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCameraFit: koordinaten.length >= 2
                        ? CameraFit.coordinates(
                            coordinates: koordinaten,
                            padding: const EdgeInsets.all(48),
                          )
                        : CameraFit.coordinates(
                            coordinates: [
                              koordinaten.isEmpty
                                  ? _schweiz
                                  : koordinaten.first,
                            ],
                            maxZoom: 14,
                            padding: const EdgeInsets.all(48),
                          ),
                  ),
                  children: [
                    TileLayer(
                      key: ValueKey(_basemap),
                      urlTemplate: basemapUrl(_basemap),
                      userAgentPackageName: 'ch.sbsprojer.app',
                    ),
                    if (koordinaten.length >= 2)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: koordinaten,
                            strokeWidth: 3,
                            color: AppColors.primary.withAlpha(150),
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        for (final p in punkte)
                          Marker(
                            point: p.pos,
                            width: 34,
                            height: 34,
                            child: GestureDetector(
                              onTap: () => ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  SnackBar(content: Text(p.label)),
                                ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: p.farbe,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      blurRadius: 3,
                                      color: Colors.black38,
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: p.nummer != null
                                    ? Text(
                                        '${p.nummer}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      )
                                    : Icon(
                                        p.icon ?? Icons.place,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                              ),
                            ),
                          ),
                      ],
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
                // Quellenangabe ist bei beiden Diensten Pflicht.
                Positioned(
                  bottom: 4,
                  left: 8,
                  child: Text(
                    basemapQuelle(_basemap),
                    style: const TextStyle(fontSize: 10, color: Colors.black54),
                  ),
                ),
              ],
            ),
    );
  }
}

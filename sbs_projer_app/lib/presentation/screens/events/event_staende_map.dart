import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/stand_position.dart';
import 'package:sbs_projer_app/core/util/swisstopo.dart';
import 'package:sbs_projer_app/data/local/event_geraet_local_export.dart';
import 'package:sbs_projer_app/data/local/event_stand_local_export.dart';
import 'package:sbs_projer_app/data/models/event_geraet.dart';
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
/// Georeferenzierter Lageplan fürs Karten-Overlay (Ecken aus
/// `core/util/georeferenz.dart`).
typedef LageplanOverlay = ({
  String url,
  LatLng topLeft,
  LatLng bottomLeft,
  LatLng bottomRight,
});

/// **Marker-Farben** (Feldfeedback Churerfest 14.08.2026 — ersetzt die alte
/// gemessen/geplant-Rot/Blau-Unterscheidung, die stand für Datenqualität, nicht
/// für den Baufortschritt): Orange = gerade zum Platzieren ausgewählt, Grün =
/// [standStatus].komplett (voll in Betrieb), Rot = noch nicht komplett UND hat
/// mindestens ein Hollandbuffet-Gerät (Vorlauf 2–4 h zum Runterkühlen — hat
/// beim Aufbau Priorität), Blau = noch nicht komplett, kein Hollandbuffet.
/// Ohne Eintrag in [standStatus] (Default `{}`) bleibt ein Stand Blau.
class EventStaendeMap extends StatefulWidget {
  final List<EventStandLocal> staende;
  final void Function(EventStandLocal) onStandTap;

  /// Technik-Geräte (Anstiche/Kühler) mit Standort — rein informativ, ohne
  /// Bearbeitung von der Karte aus (die lebt im Technik-Tab). Optional, damit
  /// die Karte auch ohne Geräte-Daten aufrufbar bleibt.
  final List<EventGeraetLocal> geraete;

  /// Position eines Stands auf der Karte setzen (Planung). Fehlt der Callback,
  /// ist die Karte reine Anzeige.
  final Future<void> Function(EventStandLocal stand, LatLng punkt)?
      onPositionSetzen;

  /// Referenzierter Lageplan — liegt halbtransparent über dem Luftbild und
  /// ist per Ebenen-Knopf ausblendbar.
  final LageplanOverlay? lageplan;

  /// Inbetriebnahme-Status je Stand (Schlüssel = `serverId`) für die
  /// Marker-Farbe. Fehlt ein Eintrag, gilt der Stand als offen/blau.
  final Map<String, ({bool komplett, bool hatHollandbuffet})> standStatus;

  /// Punkt, auf den die Karte zentriert werden soll (Sprung «Auf Karte
  /// zeigen» aus der Liste). [fokusToken] muss bei jedem Sprung erhöht
  /// werden — auch beim erneuten Anspringen desselben Stands soll die Karte
  /// wieder zentrieren, ein reiner Wertevergleich von [fokus] würde das bei
  /// unveränderten Koordinaten unterschlagen.
  final LatLng? fokus;
  final String? fokusStandId;
  final int fokusToken;

  const EventStaendeMap({
    super.key,
    required this.staende,
    required this.onStandTap,
    this.geraete = const [],
    this.onPositionSetzen,
    this.lageplan,
    this.standStatus = const {},
    this.fokus,
    this.fokusStandId,
    this.fokusToken = 0,
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

  /// Kartenebenen einzeln ein-/ausblendbar (Feldfeedback Churerfest
  /// 14.08.2026, absorbiert den alten reinen Lageplan-Knopf von v0.83).
  /// Bewusst reiner Session-Zustand pro Karten-Mount, nicht persistiert:
  /// bei jedem Neuaufbau der Karte (z. B. Liste<->Karte-Umschalter) starten
  /// alle vier wieder auf «sichtbar».
  bool _zeigeLageplan = true;
  bool _zeigeStaende = true;
  bool _zeigeAnstiche = true;
  bool _zeigeKuehler = true;
  bool _ebenenPanelOffen = false;

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
      setState(() {
        _platziert = offen.isEmpty ? null : offen.first;
        // Positionier-Modus braucht zwingend die Stände-Ebene — sonst sieht
        // man nicht, wohin man gerade tippt.
        if (_platziert != null) _zeigeStaende = true;
      });
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
      setState(() {
        _platziert = gewaehlt;
        // Siehe _kartenTap: Positionier-Modus ohne sichtbare Stände wäre
        // blind.
        _zeigeStaende = true;
      });
    }
  }

  /// Marker für ein Technik-Gerät (Anstich oder Kühler) — gemeinsamer
  /// Aufbau für beide Ebenen (Feldfeedback Churerfest 14.08.2026), nur die
  /// Sichtbarkeit (Anstiche-/Kühler-Ebene) unterscheidet sich.
  Marker _geraetMarker(EventGeraetLocal g) {
    return Marker(
      point: LatLng(g.latitude!, g.longitude!),
      width: 30,
      height: 30,
      child: GestureDetector(
        // Im Positionier-Modus muss der Kartentap durch den Marker hindurch
        // beim MapOptions.onTap ankommen — ein gesetzter onTap-Handler würde
        // die Geste sonst gewinnen und eine tote Zone fürs Platzieren
        // erzeugen. null registriert keinen Recognizer.
        onTap: _platziert != null
            ? null
            : () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${g.bezeichnung} · ${EventGeraet.typLabel(g.typ)}',
                    ),
                  ),
                ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.deepPurple,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 3),
            ],
          ),
          child: Icon(
            EventGeraet.istAnstich(g.typ) ? Icons.propane_tank : Icons.ac_unit,
            color: Colors.white,
            size: 16,
          ),
        ),
      ),
    );
  }

  /// Marker-Farbe je Stand — siehe Klassendoku für die Semantik.
  Color _standFarbe(EventStandLocal s) {
    if (s.serverId == _platziert?.serverId) return Colors.orange;
    final status = s.serverId == null ? null : widget.standStatus[s.serverId!];
    if (status?.komplett == true) return AppColors.success;
    if (status?.hatHollandbuffet == true) return AppColors.error;
    return AppColors.info;
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

  @override
  void didUpdateWidget(covariant EventStaendeMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // «Auf Karte zeigen» aus der Liste: Sprung nur bei neuem Token ausführen
    // (siehe Doku bei EventStaendeMap.fokusToken), sonst würde jeder
    // Neuaufbau der Karte (z. B. Basemap-Wechsel) versehentlich erneut
    // zentrieren.
    if (widget.fokus != null && widget.fokusToken != oldWidget.fokusToken) {
      // Ein Fokus-Sprung ohne sichtbare Stände-Ebene wäre ein Ring um
      // nichts — Ebene notfalls wieder einschalten.
      _zeigeStaende = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _controller.move(widget.fokus!, 18);
      });
    }
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
            // widget.fokus (Sprung «Auf Karte zeigen» aus der Liste) muss
            // schon HIER greifen, nicht erst über didUpdateWidget: Der
            // Liste-/Karte-Umschalter in _StaendeTabState baut bei jedem
            // Wechsel einen komplett neuen EventStaendeMap-Zweig auf, das
            // ist ein Remount (neues State-Objekt) statt eines Rebuilds —
            // didUpdateWidget läuft dabei nie. initialCameraFit würde sonst
            // die Gesamt-Übersicht erzwingen und den Fokus überschreiben.
            initialCameraFit: widget.fokus != null || punkte.isEmpty
                ? null
                : CameraFit.coordinates(
                    coordinates: punkte,
                    padding: const EdgeInsets.all(48),
                    maxZoom: 18,
                  ),
            initialCenter:
                widget.fokus ?? (punkte.isEmpty ? schweiz : punkte.first),
            initialZoom: widget.fokus != null ? 18 : (punkte.isEmpty ? 7.5 : 13),
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
            // Lageplan unter den Markern, über den Kacheln — so bleiben die
            // Stand-Pins sichtbar und der Plan dient als Zeichenunterlage.
            if (widget.lageplan != null && _zeigeLageplan)
              OverlayImageLayer(overlayImages: [
                RotatedOverlayImage(
                  imageProvider: NetworkImage(widget.lageplan!.url),
                  topLeftCorner: widget.lageplan!.topLeft,
                  bottomLeftCorner: widget.lageplan!.bottomLeft,
                  bottomRightCorner: widget.lageplan!.bottomRight,
                  opacity: 0.65,
                ),
              ]),
            // Geräte-Marker UNTER den Stand-Markern (nächste Layer) — die
            // Stände bleiben die prominente Ebene, Technik ist Zusatzinfo.
            // Anstiche und Kühler sind zwei getrennte Ebenen (Feldfeedback
            // Churerfest 14.08.2026: beim Aufbau will man mal nur die
            // Anstiche sehen, mal nur die Kühler).
            if (_zeigeAnstiche)
              MarkerLayer(
                markers: [
                  for (final g in widget.geraete)
                    if (g.latitude != null &&
                        g.longitude != null &&
                        EventGeraet.istAnstich(g.typ))
                      _geraetMarker(g),
                ],
              ),
            if (_zeigeKuehler)
              MarkerLayer(
                markers: [
                  for (final g in widget.geraete)
                    if (g.latitude != null &&
                        g.longitude != null &&
                        !EventGeraet.istAnstich(g.typ))
                      _geraetMarker(g),
                ],
              ),
            if (_zeigeStaende)
              MarkerLayer(
                markers: [
                  for (final s in mitGps)
                    Marker(
                      point: LatLng(s.latitude!, s.longitude!),
                      width: s.serverId == widget.fokusStandId ? 52 : 40,
                      height: s.serverId == widget.fokusStandId ? 52 : 40,
                      child: GestureDetector(
                        // Im Positionier-Modus wählt ein Marker-Tap den
                        // Stand zum Verschieben aus, statt ihn zu bearbeiten.
                        onTap: () => _platziert == null
                            ? widget.onStandTap(s)
                            : setState(() => _platziert = s),
                        child: s.serverId == widget.fokusStandId
                            // «Auf Karte zeigen» aus der Liste: Ring statt
                            // simpler Grössenänderung, damit der
                            // angesprungene Stand eindeutig erkennbar
                            // bleibt, auch wenn mehrere Marker nahe
                            // beieinander liegen.
                            ? Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.amberAccent,
                                    width: 3,
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.location_on,
                                    color: _standFarbe(s),
                                    size: 40,
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.location_on,
                                color: _standFarbe(s),
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
          left: 8,
          bottom: 8,
          child: _StandFarbenLegende(
            // Legende beschreibt nur, was auch sichtbar ist — sonst würde
            // sie nach dem Ausblenden einer Ebene falsche Erwartungen wecken.
            zeigeStaende: _zeigeStaende,
            zeigeTechnik: _zeigeAnstiche || _zeigeKuehler,
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
        // Ebenen-Panel: Lageplan/Stände/Anstiche/Kühler einzeln schaltbar
        // (Feldfeedback Churerfest 14.08.2026, absorbiert den alten reinen
        // Lageplan-Ein/Aus-Knopf von v0.83). Barriere zuerst im Stack, damit
        // sie über allen bisherigen Kindern liegt und ein Tap ausserhalb
        // das Panel schliesst — der Ebenen-Knopf selbst kommt als
        // allerletztes Kind, damit er dabei anklickbar bleibt.
        if (_ebenenPanelOffen)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _ebenenPanelOffen = false),
              child: Container(color: Colors.transparent),
            ),
          ),
        if (_ebenenPanelOffen)
          Positioned(
            right: 8,
            bottom: 130,
            child: _EbenenPanel(
              hatLageplan: widget.lageplan != null,
              zeigeLageplan: _zeigeLageplan,
              zeigeStaende: _zeigeStaende,
              zeigeAnstiche: _zeigeAnstiche,
              zeigeKuehler: _zeigeKuehler,
              onToggleLageplan: () =>
                  setState(() => _zeigeLageplan = !_zeigeLageplan),
              onToggleStaende: () =>
                  setState(() => _zeigeStaende = !_zeigeStaende),
              onToggleAnstiche: () =>
                  setState(() => _zeigeAnstiche = !_zeigeAnstiche),
              onToggleKuehler: () =>
                  setState(() => _zeigeKuehler = !_zeigeKuehler),
            ),
          ),
        Positioned(
          right: 8,
          bottom: 84,
          child: FloatingActionButton.small(
            heroTag: 'event_ebenen_toggle',
            backgroundColor: Colors.white,
            foregroundColor: AppColors.primary,
            tooltip: 'Kartenebenen',
            onPressed: () =>
                setState(() => _ebenenPanelOffen = !_ebenenPanelOffen),
            child: const Icon(Icons.layers),
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

/// Legende zu den Marker-Farben, halbtransparent unten links über der
/// Kachel-Attribution. Reines Container/Row/Text — CanvasKit-sicher.
///
/// Zeigt nur Einträge zu tatsächlich sichtbaren Ebenen (Feldfeedback
/// Churerfest 14.08.2026, Ebenen-Panel): eine Legende, die Farben für
/// ausgeblendete Marker erklärt, würde in die Irre führen.
class _StandFarbenLegende extends StatelessWidget {
  final bool zeigeStaende;
  final bool zeigeTechnik;

  const _StandFarbenLegende({
    required this.zeigeStaende,
    required this.zeigeTechnik,
  });

  static const _standEintraege = [
    (farbe: AppColors.success, label: 'In Betrieb'),
    (farbe: AppColors.error, label: 'Hollandbuffet zuerst'),
    (farbe: AppColors.info, label: 'Offen'),
  ];
  static const _technikEintrag = (farbe: Colors.deepPurple, label: 'Technik');

  @override
  Widget build(BuildContext context) {
    final eintraege = [
      if (zeigeStaende) ..._standEintraege,
      if (zeigeTechnik) _technikEintrag,
    ];
    if (eintraege.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final e in eintraege)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: e.farbe,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    e.label,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Panel zum Ein-/Ausblenden einzelner Kartenebenen (Feldfeedback
/// Churerfest 14.08.2026) — reine InkWell-Zeilen mit Häkchen-Icon statt
/// ExpansionTile/Checkbox: dieselbe CanvasKit-Vorsicht wie überall sonst
/// in dieser Datei (Material-Komfort-Widgets rendern auf Daniels Geräten
/// nicht immer zuverlässig).
class _EbenenPanel extends StatelessWidget {
  final bool hatLageplan;
  final bool zeigeLageplan;
  final bool zeigeStaende;
  final bool zeigeAnstiche;
  final bool zeigeKuehler;
  final VoidCallback onToggleLageplan;
  final VoidCallback onToggleStaende;
  final VoidCallback onToggleAnstiche;
  final VoidCallback onToggleKuehler;

  const _EbenenPanel({
    required this.hatLageplan,
    required this.zeigeLageplan,
    required this.zeigeStaende,
    required this.zeigeAnstiche,
    required this.zeigeKuehler,
    required this.onToggleLageplan,
    required this.onToggleStaende,
    required this.onToggleAnstiche,
    required this.onToggleKuehler,
  });

  @override
  Widget build(BuildContext context) {
    // Material-Wrapper nur fürs InkWell-Ripple — die Zeilen selbst bleiben
    // reine Row/Icon/Text-Kombinationen.
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 172,
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hatLageplan)
              _EbenenZeile(
                label: 'Lageplan',
                aktiv: zeigeLageplan,
                onTap: onToggleLageplan,
              ),
            _EbenenZeile(
              label: 'Stände',
              aktiv: zeigeStaende,
              onTap: onToggleStaende,
            ),
            _EbenenZeile(
              label: 'Anstiche',
              aktiv: zeigeAnstiche,
              onTap: onToggleAnstiche,
            ),
            _EbenenZeile(
              label: 'Kühler',
              aktiv: zeigeKuehler,
              onTap: onToggleKuehler,
            ),
          ],
        ),
      ),
    );
  }
}

/// Eine Zeile im Ebenen-Panel: Häkchen-Icon + Label, ganze Zeile tappbar.
class _EbenenZeile extends StatelessWidget {
  final String label;
  final bool aktiv;
  final VoidCallback onTap;

  const _EbenenZeile({
    required this.label,
    required this.aktiv,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              aktiv ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 18,
              color: aktiv ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

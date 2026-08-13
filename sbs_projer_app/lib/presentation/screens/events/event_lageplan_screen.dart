import 'dart:convert';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/georeferenz.dart';
import 'package:sbs_projer_app/core/util/swisstopo.dart';
import 'package:sbs_projer_app/data/local/event_local_export.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/data/repositories/event_repository.dart';
import 'package:sbs_projer_app/presentation/providers/event_providers.dart';
import 'package:sbs_projer_app/services/storage/event_dokument_storage.dart';

/// Lageplan georeferenzieren (Daniel 13.08.2026, Fall Openair Gampel):
/// Ein JPG/PNG des Festgeländes wird über 2–5 Passpunkte auf die Karte
/// gelegt. Ablauf pro Punkt: zuerst den Ort auf dem PLAN antippen, dann
/// denselben Ort auf der KARTE (Luftbild). Ab zwei Punkten liegt der Plan
/// live als Overlay über der Karte, und die Abweichung pro Punkt (Meter)
/// zeigt, ob ein Passpunkt daneben sitzt.
///
/// Gespeichert werden nur Bild-Pfad, Bildmasse und Passpunkte
/// (`events.lageplan_*`) — die Transformation rechnet
/// `core/util/georeferenz.dart` bei jeder Anzeige frisch.
class EventLageplanScreen extends ConsumerStatefulWidget {
  final String eventId;

  const EventLageplanScreen({super.key, required this.eventId});

  @override
  ConsumerState<EventLageplanScreen> createState() =>
      _EventLageplanScreenState();
}

/// Farbpalette der Passpunkt-Paare — gleiche Ziffer + Farbe auf Plan und
/// Karte, damit die Zuordnung ohne Nachdenken sichtbar ist.
const _punktFarben = [
  Color(0xFFE53935), // rot
  Color(0xFF1E88E5), // blau
  Color(0xFF43A047), // grün
  Color(0xFF8E24AA), // violett
  Color(0xFFFB8C00), // orange
];

class _EventLageplanScreenState extends ConsumerState<EventLageplanScreen> {
  EventLocal? _event;
  bool _laedt = true;
  String? _bildUrl;
  double? _bildBreite;
  double? _bildHoehe;
  final List<Passpunkt> _punkte = [];

  /// Plan wurde getippt, Karten-Tap steht aus.
  ({double px, double py})? _offenerBildPunkt;

  LatLng _kartenStart = const LatLng(46.8, 8.23);
  double _kartenZoom = 7.5;
  bool _speichert = false;

  @override
  void initState() {
    super.initState();
    _laden();
  }

  Future<void> _laden() async {
    try {
      final event = await EventRepository.getById(widget.eventId);
      if (event == null) {
        if (mounted) setState(() => _laedt = false);
        return;
      }

      // Karten-Start: Betriebskoordinaten des Veranstaltungs-Betriebs.
      final betrieb = await BetriebRepository.getByServerId(event.betriebId);
      if (betrieb?.latitude != null && betrieb?.longitude != null) {
        _kartenStart = LatLng(betrieb!.latitude!, betrieb.longitude!);
        _kartenZoom = 16;
      }

      // Bestehende Referenzierung laden.
      if (event.lageplanPunkteJson != null) {
        final m = jsonDecode(event.lageplanPunkteJson!) as Map<String, dynamic>;
        _bildBreite = (m['bildBreite'] as num?)?.toDouble();
        _bildHoehe = (m['bildHoehe'] as num?)?.toDouble();
        _punkte.addAll(passpunkteAusJson(m['punkte'] as List? ?? []));
        if (_punkte.isNotEmpty) {
          _kartenStart = LatLng(_punkte.first.lat, _punkte.first.lng);
          _kartenZoom = 17;
        }
      }
      String? url;
      if (event.lageplanPfad != null) {
        url = await EventDokumentStorage.getSignedUrl(event.lageplanPfad!);
      }
      if (mounted) {
        setState(() {
          _event = event;
          _bildUrl = url;
          _laedt = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _laedt = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler beim Laden: $e')));
      }
    }
  }

  /// JPG/PNG wählen, Bildmasse bestimmen, hochladen, am Event speichern.
  Future<void> _bildHochladen() async {
    final messenger = ScaffoldMessenger.of(context);
    Uint8List? bytes;
    String endung = 'jpg';
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
      if (picked == null || picked.files.single.bytes == null) return;
      bytes = picked.files.single.bytes!;
      final name = picked.files.single.name.toLowerCase();
      endung = name.split('.').last;
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Datei konnte nicht gewählt werden: $e')));
      return;
    }

    messenger.showSnackBar(
        const SnackBar(content: Text('Lageplan wird hochgeladen …')));
    try {
      // Bildmasse bestimmen — Grundlage der Pixel↔Karte-Abbildung.
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final breite = frame.image.width.toDouble();
      final hoehe = frame.image.height.toDouble();

      final pfad = await EventDokumentStorage.uploadBild(
          _event!.serverId!, bytes, endung);
      final event = _event!;
      event.lageplanPfad = pfad;
      // Neues Bild = neue Geometrie: alte Passpunkte verwerfen.
      event.lageplanPunkteJson = jsonEncode({
        'bildBreite': breite,
        'bildHoehe': hoehe,
        'punkte': <Map<String, double>>[],
      });
      await EventRepository.save(event);
      ref.invalidate(eventByIdProvider(widget.eventId));

      final url = await EventDokumentStorage.getSignedUrl(pfad);
      if (mounted) {
        setState(() {
          _bildUrl = url;
          _bildBreite = breite;
          _bildHoehe = hoehe;
          _punkte.clear();
          _offenerBildPunkt = null;
        });
      }
    } catch (e) {
      messenger
          .showSnackBar(SnackBar(content: Text('Hochladen fehlgeschlagen: $e')));
    }
  }

  void _planTap(double px, double py) {
    if (_punkte.length >= 5 && _offenerBildPunkt == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Maximal 5 Passpunkte — einen bestehenden löschen.')));
      return;
    }
    setState(() => _offenerBildPunkt = (px: px, py: py));
  }

  void _kartenTap(LatLng punkt) {
    final offen = _offenerBildPunkt;
    if (offen == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Zuerst den Punkt auf dem Plan antippen.')));
      return;
    }
    setState(() {
      _punkte.add((
        px: offen.px,
        py: offen.py,
        lat: punkt.latitude,
        lng: punkt.longitude,
      ));
      _offenerBildPunkt = null;
    });
  }

  /// Lageplan samt Referenzierung vom Event lösen und die Datei aus dem
  /// Storage räumen (Wunsch Daniel 13.08.2026 — vorher gab es keinen Weg,
  /// einen falschen Plan wieder loszuwerden).
  Future<void> _lageplanEntfernen() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lageplan entfernen?'),
        content: const Text(
            'Bild und alle Passpunkte werden gelöscht. Die Stand-Positionen '
            'bleiben unverändert.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Entfernen')),
        ],
      ),
    );
    if (ok != true || _event == null) return;
    try {
      final pfad = _event!.lageplanPfad;
      _event!
        ..lageplanPfad = null
        ..lageplanPunkteJson = null;
      await EventRepository.save(_event!);
      // Storage erst nach dem Datensatz — ein Fehler dort lässt höchstens
      // eine Waisen-Datei zurück, nie einen kaputten Verweis.
      if (pfad != null) await EventDokumentStorage.delete(pfad);
      ref.invalidate(eventByIdProvider(widget.eventId));
      if (mounted) {
        setState(() {
          _bildUrl = null;
          _bildBreite = null;
          _bildHoehe = null;
          _punkte.clear();
          _offenerBildPunkt = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lageplan entfernt')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  Future<void> _speichern() async {
    if (_event == null || _bildBreite == null) return;
    setState(() => _speichert = true);
    try {
      final event = _event!;
      event.lageplanPunkteJson = jsonEncode({
        'bildBreite': _bildBreite,
        'bildHoehe': _bildHoehe,
        'punkte': passpunkteZuJson(_punkte),
      });
      await EventRepository.save(event);
      ref.invalidate(eventByIdProvider(widget.eventId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lageplan-Referenzierung gespeichert')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    } finally {
      if (mounted) setState(() => _speichert = false);
    }
  }

  Georeferenz? get _geo =>
      _punkte.length >= 2 ? Georeferenz.berechne(_punkte) : null;

  @override
  Widget build(BuildContext context) {
    if (_laedt) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_event == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lageplan')),
        body: const Center(child: Text('Event nicht gefunden.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lageplan referenzieren'),
        actions: [
          if (_bildUrl != null)
            IconButton(
              tooltip: 'Anderes Bild hochladen',
              icon: const Icon(Icons.upload_file),
              onPressed: _bildHochladen,
            ),
          if (_bildUrl != null)
            IconButton(
              tooltip: 'Lageplan entfernen',
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              onPressed: _lageplanEntfernen,
            ),
          if (_bildUrl != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              // GestureDetector statt FilledButton: Material-Buttons rendern
              // auf manchen CanvasKit-Screens nicht zuverlässig (Vorfall
              // 20.06.2026; erneut 13.08.2026 — genau dieser Speichern-Knopf
              // reagierte am PC nicht).
              child: _SpeichernKnopf(
                aktiv: !_speichert && _punkte.length >= 2,
                laeuft: _speichert,
                onTap: _speichern,
              ),
            ),
        ],
      ),
      body: _bildUrl == null ? _buildUploadAufforderung() : _buildReferenzieren(),
    );
  }

  Widget _buildUploadAufforderung() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined,
              size: 64, color: AppColors.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Lageplan als Bild (JPG/PNG) hochladen und danach mit 2–5 '
              'Punkten auf die Karte legen.\nEin PDF vorher als Bild '
              'exportieren (Screenshot genügt).',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.upload_file),
            label: const Text('Bild wählen'),
            onPressed: _bildHochladen,
          ),
        ],
      ),
    );
  }

  Widget _buildReferenzieren() {
    final g = _geo;
    return Column(
      children: [
        _buildStatusleiste(g),
        // Oben der Plan, unten die Karte — auf PC wie Handy dieselbe
        // Reihenfolge wie der Arbeitsschritt («erst Plan, dann Karte»).
        Expanded(flex: 5, child: _buildPlanPanel()),
        const Divider(height: 1),
        Expanded(flex: 6, child: _buildKartenPanel(g)),
      ],
    );
  }

  Widget _buildStatusleiste(Georeferenz? g) {
    final naechste = _punkte.length + 1;
    final String anweisung;
    final Color farbe;
    if (_offenerBildPunkt != null) {
      anweisung = 'Punkt $naechste: jetzt denselben Ort auf der KARTE antippen';
      farbe = AppColors.info;
    } else if (_punkte.length < 2) {
      anweisung = 'Punkt $naechste: markanten Ort auf dem PLAN antippen '
          '(Gebäudeecke, Kreuzung …)';
      farbe = Colors.orange;
    } else {
      anweisung = 'Referenziert — weitere Punkte verbessern die Genauigkeit';
      farbe = AppColors.success;
    }

    return Container(
      width: double.infinity,
      color: farbe.withValues(alpha: 0.10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                  _offenerBildPunkt != null
                      ? Icons.touch_app
                      : (g != null ? Icons.check_circle : Icons.touch_app),
                  size: 15,
                  color: farbe),
              const SizedBox(width: 6),
              Expanded(
                child: Text(anweisung,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: farbe)),
              ),
              if (_offenerBildPunkt != null)
                GestureDetector(
                  onTap: () => setState(() => _offenerBildPunkt = null),
                  child: const Icon(Icons.close, size: 16),
                ),
              if (g != null)
                Text('Ø ${g.rmsMeter.toStringAsFixed(1)} m',
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700)),
            ],
          ),
          if (_punkte.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (var i = 0; i < _punkte.length; i++)
                    _PunktChip(
                      index: i,
                      residuum: g != null && i < g.residuenMeter.length
                          ? g.residuenMeter[i]
                          : null,
                      onLoeschen: () => setState(() => _punkte.removeAt(i)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlanPanel() {
    final b = _bildBreite, h = _bildHoehe;
    if (b == null || h == null) {
      return const Center(child: Text('Bildmasse fehlen — Bild neu hochladen.'));
    }
    return LayoutBuilder(builder: (context, c) {
      // Anzeige auf Panelbreite eingepasst; Zoomen/Verschieben übernimmt der
      // InteractiveViewer. Tap-Koordinaten kommen im Child-Raum an und werden
      // über die Skala zurück in Bildpixel gerechnet.
      final skala = c.maxWidth / b;
      final anzeigeB = c.maxWidth;
      final anzeigeH = h * skala;
      return InteractiveViewer(
        constrained: false,
        minScale: 0.3,
        maxScale: 12,
        boundaryMargin: const EdgeInsets.all(300),
        child: GestureDetector(
          onTapUp: (d) =>
              _planTap(d.localPosition.dx / skala, d.localPosition.dy / skala),
          child: SizedBox(
            width: anzeigeB,
            height: anzeigeH,
            child: Stack(
              children: [
                Image.network(_bildUrl!,
                    width: anzeigeB, height: anzeigeH, fit: BoxFit.fill),
                for (var i = 0; i < _punkte.length; i++)
                  _planMarker(
                      _punkte[i].px * skala, _punkte[i].py * skala, i, false),
                if (_offenerBildPunkt != null)
                  _planMarker(_offenerBildPunkt!.px * skala,
                      _offenerBildPunkt!.py * skala, _punkte.length, true),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _planMarker(double x, double y, int index, bool offen) {
    final farbe = _punktFarben[index % _punktFarben.length];
    return Positioned(
      left: x - 11,
      top: y - 11,
      child: IgnorePointer(
        child: _PunktScheibe(index: index, farbe: farbe, offen: offen),
      ),
    );
  }

  Widget _buildKartenPanel(Georeferenz? g) {
    final ecken = (g != null && _bildBreite != null && _bildHoehe != null)
        ? g.ecken(_bildBreite!, _bildHoehe!)
        : null;
    return FlutterMap(
      options: MapOptions(
        initialCenter: _kartenStart,
        initialZoom: _kartenZoom,
        onTap: (_, punkt) => _kartenTap(punkt),
      ),
      children: [
        TileLayer(
          urlTemplate: basemapUrl(Basemap.luftbild),
          userAgentPackageName: 'ch.sbsprojer.app',
          maxZoom: 19,
        ),
        // Live-Vorschau: der referenzierte Plan über dem Luftbild.
        if (ecken != null)
          OverlayImageLayer(overlayImages: [
            RotatedOverlayImage(
              imageProvider: NetworkImage(_bildUrl!),
              topLeftCorner:
                  LatLng(ecken.topLeft.lat, ecken.topLeft.lng),
              bottomLeftCorner:
                  LatLng(ecken.bottomLeft.lat, ecken.bottomLeft.lng),
              bottomRightCorner:
                  LatLng(ecken.bottomRight.lat, ecken.bottomRight.lng),
              opacity: 0.65,
            ),
          ]),
        MarkerLayer(markers: [
          for (var i = 0; i < _punkte.length; i++)
            Marker(
              point: LatLng(_punkte[i].lat, _punkte[i].lng),
              width: 22,
              height: 22,
              child: _PunktScheibe(
                  index: i,
                  farbe: _punktFarben[i % _punktFarben.length],
                  offen: false),
            ),
        ]),
        RichAttributionWidget(attributions: [
          TextSourceAttribution(basemapQuelle(Basemap.luftbild)),
        ]),
      ],
    );
  }
}

/// Nummerierte Punktscheibe — identisch auf Plan und Karte, damit das Paar
/// optisch zusammenfindet. [offen] = Plan-Hälfte gesetzt, Karten-Tap fehlt.
class _PunktScheibe extends StatelessWidget {
  final int index;
  final Color farbe;
  final bool offen;

  const _PunktScheibe(
      {required this.index, required this.farbe, required this.offen});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: offen ? Colors.white : farbe,
        shape: BoxShape.circle,
        border: Border.all(color: offen ? farbe : Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3)],
      ),
      alignment: Alignment.center,
      child: Text(
        '${index + 1}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: offen ? farbe : Colors.white,
        ),
      ),
    );
  }
}

/// Chip eines gesetzten Passpunkts: Nummer, Abweichung in Metern, Löschen.
class _PunktChip extends StatelessWidget {
  final int index;
  final double? residuum;
  final VoidCallback onLoeschen;

  const _PunktChip(
      {required this.index, required this.residuum, required this.onLoeschen});

  @override
  Widget build(BuildContext context) {
    final farbe = _punktFarben[index % _punktFarben.length];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: farbe),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${index + 1}',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800, color: farbe)),
          if (residuum != null) ...[
            const SizedBox(width: 4),
            Text('${residuum!.toStringAsFixed(1)} m',
                style:
                    const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onLoeschen,
            child: const Icon(Icons.close, size: 13),
          ),
        ],
      ),
    );
  }
}

/// Speichern-Knopf als GestureDetector+Container — Material-Buttons sind auf
/// manchen CanvasKit-Screens tot (Vorfall 20.06.2026, erneut 13.08.2026).
class _SpeichernKnopf extends StatelessWidget {
  final bool aktiv;
  final bool laeuft;
  final VoidCallback onTap;

  const _SpeichernKnopf(
      {required this.aktiv, required this.laeuft, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: aktiv ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: aktiv || laeuft
              ? AppColors.primary
              : AppColors.textSecondary.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (laeuft)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
              ),
            Text(
              laeuft ? 'Speichert …' : 'Speichern',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

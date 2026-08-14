import 'dart:convert';
import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/kuehler_monitoring.dart';
import 'package:sbs_projer_app/data/local/event_kuehler_messung_local_export.dart';
import 'package:sbs_projer_app/data/repositories/event_kuehler_messung_repository.dart';
import 'package:sbs_projer_app/presentation/providers/event_providers.dart';
import 'package:sbs_projer_app/services/events/typenschild_service.dart';
import 'package:sbs_projer_app/services/spesen/beleg_bild_service.dart';
import 'package:sbs_projer_app/services/storage/event_dokument_storage.dart';

/// V2-6: Durchlaufkühler-Details (Typenschild-Fotos → KI → Felder, Soll-
/// Temperaturbereich) und Temperatur-Monitoring (Erfassen, Warnfarbe,
/// Verlaufsgrafik). Ausgelagert aus event_technik_tab.dart (dort bereits
/// ~1400 Zeilen) — von dort eingebettet in _GeraetFormSheet bzw. _GeraetCard.
///
/// CanvasKit-Regel gilt auch hier: kein ExpansionTile, Speichern-Knopf aus
/// InkWell+Container statt FilledButton (siehe event_technik_tab.dart).

// ─── Kühler-Felder im Formular ───

/// Ergebnis-Snapshot der Kühler-Felder für den Aufrufer beim Speichern.
class KuehlerFelderWerte {
  final String? kuehlerTyp;
  final String? pumpeTyp;
  final String? typenschildKuehlerPfad;
  final String? typenschildPumpePfad;
  final String? typenschildErkennungJson;
  final double? sollMinCelsius;
  final double? sollMaxCelsius;

  const KuehlerFelderWerte({
    this.kuehlerTyp,
    this.pumpeTyp,
    this.typenschildKuehlerPfad,
    this.typenschildPumpePfad,
    this.typenschildErkennungJson,
    this.sollMinCelsius,
    this.sollMaxCelsius,
  });
}

/// Textfelder + Kamera-Erfassung für Kühler-/Pumpen-Typenschild plus
/// Soll-Temperaturbereich. Der Aufrufer liest die Werte beim Speichern über
/// den State (`GlobalKey<KuehlerFelderState>`) aus — bei sieben Feldern ist
/// das übersichtlicher als ein Callback je Feld.
class KuehlerFelder extends StatefulWidget {
  /// serverId des Geräts. Bei neuen Geräten vom Aufrufer vorab erzeugt
  /// (das Repository setzt sie beim Speichern ohnehin auf denselben Wert
  /// nach) — nur so hat ein Foto, das VOR dem ersten Speichern aufgenommen
  /// wird, schon einen stabilen, dem Gerät zuordenbaren Pfad.
  final String geraetServerId;
  final String? initialKuehlerTyp;
  final String? initialPumpeTyp;
  final String? initialTypenschildKuehlerPfad;
  final String? initialTypenschildPumpePfad;
  final String? initialErkennungJson;
  final double? initialSollMin;
  final double? initialSollMax;

  const KuehlerFelder({
    super.key,
    required this.geraetServerId,
    this.initialKuehlerTyp,
    this.initialPumpeTyp,
    this.initialTypenschildKuehlerPfad,
    this.initialTypenschildPumpePfad,
    this.initialErkennungJson,
    this.initialSollMin,
    this.initialSollMax,
  });

  @override
  State<KuehlerFelder> createState() => KuehlerFelderState();
}

class KuehlerFelderState extends State<KuehlerFelder> {
  late final TextEditingController _kuehlerTyp;
  late final TextEditingController _pumpeTyp;
  late final TextEditingController _sollMin;
  late final TextEditingController _sollMax;

  String? _typenschildKuehlerPfad;
  String? _typenschildPumpePfad;
  late Map<String, dynamic> _erkennung;

  // Re-Entry-Riegel je Feld — ein zweiter Tap während der laufenden KI-
  // Analyse darf keinen zweiten Request auslösen (gleiches Muster wie
  // _schaltet/_ortet in _GeraetCardState).
  bool _liestKuehler = false;
  bool _liestPumpe = false;

  @override
  void initState() {
    super.initState();
    _kuehlerTyp = TextEditingController(text: widget.initialKuehlerTyp ?? '');
    _pumpeTyp = TextEditingController(text: widget.initialPumpeTyp ?? '');
    _sollMin = TextEditingController(
      text: widget.initialSollMin == null ? '' : _formatZahl(widget.initialSollMin!),
    );
    _sollMax = TextEditingController(
      text: widget.initialSollMax == null ? '' : _formatZahl(widget.initialSollMax!),
    );
    _typenschildKuehlerPfad = widget.initialTypenschildKuehlerPfad;
    _typenschildPumpePfad = widget.initialTypenschildPumpePfad;
    _erkennung = _erkennungAusJson(widget.initialErkennungJson);
  }

  /// Defekter/nicht lesbarer Alt-Inhalt darf das Öffnen des Formulars nie
  /// verhindern — sonst wird ein Gerät mit kaputtem JSON für immer
  /// unbearbeitbar. Fallback: leere Erkennung, Felder bleiben bearbeitbar.
  static Map<String, dynamic> _erkennungAusJson(String? json) {
    if (json == null) return <String, dynamic>{};
    try {
      return Map<String, dynamic>.from(jsonDecode(json) as Map);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  @override
  void dispose() {
    _kuehlerTyp.dispose();
    _pumpeTyp.dispose();
    _sollMin.dispose();
    _sollMax.dispose();
    super.dispose();
  }

  static String _formatZahl(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  double? _parseKomma(String text) {
    final t = text.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  List<String> _unsicherBei(String teil) {
    final liste = (_erkennung[teil] as Map?)?['unsicher_bei'] as List?;
    return List<String>.from(liste?.whereType<String>() ?? const []);
  }

  /// Prüft den Soll-Bereich; gibt eine Fehlermeldung zurück, wenn beide
  /// Grenzen gesetzt sind und die untere über der oberen liegt — sonst null.
  String? validate() {
    final min = _parseKomma(_sollMin.text);
    final max = _parseKomma(_sollMax.text);
    if (min != null && max != null && min > max) {
      return 'Soll von darf nicht grösser sein als Soll bis';
    }
    return null;
  }

  /// Aktuelle Werte für den Aufrufer beim Speichern — [validate] vorher
  /// aufrufen und bei Fehler nicht speichern, hier wird nicht mehr geprüft.
  KuehlerFelderWerte werte() => KuehlerFelderWerte(
        kuehlerTyp: _kuehlerTyp.text.trim().isEmpty ? null : _kuehlerTyp.text.trim(),
        pumpeTyp: _pumpeTyp.text.trim().isEmpty ? null : _pumpeTyp.text.trim(),
        typenschildKuehlerPfad: _typenschildKuehlerPfad,
        typenschildPumpePfad: _typenschildPumpePfad,
        typenschildErkennungJson: _erkennung.isEmpty ? null : jsonEncode(_erkennung),
        sollMinCelsius: _parseKomma(_sollMin.text),
        sollMaxCelsius: _parseKomma(_sollMax.text),
      );

  Future<void> _fotografieren(bool istKuehler) async {
    if (istKuehler ? _liestKuehler : _liestPumpe) return; // Riegel vor dem ersten await
    setState(() {
      if (istKuehler) {
        _liestKuehler = true;
      } else {
        _liestPumpe = true;
      }
    });
    try {
      final bild = await ImagePicker().pickImage(
        source: ImageSource.camera,
        // Die Edge Function lehnt >5 MB decodiert ab (Review-Fund #8) — fürs
        // Typenschild reicht deutlich weniger Auflösung als beim
        // Spesenbeleg mit Kleingedrucktem (dort 2000/Q88).
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (bild == null) {
        if (mounted) {
          setState(() {
            if (istKuehler) {
              _liestKuehler = false;
            } else {
              _liestPumpe = false;
            }
          });
        }
        return;
      }
      final rohBytes = await bild.readAsBytes();
      final ext = bild.name.split('.').last.toLowerCase();
      final dateityp = ext == 'png' ? 'png' : 'jpg';
      final mediaType = ext == 'png' ? 'image/png' : 'image/jpeg';
      // EXIF-Ausrichtung in die Pixel backen — gleicher Grund wie beim
      // Spesenscanner: quer aufgenommene Fotos landen sonst liegend im
      // Archiv (Regel Daniel 26.07.2026).
      final bytes = Uint8List.fromList(
        BelegBildService.autoAusrichten(rohBytes, dateityp: dateityp),
      );

      // Upload ZUERST, dann KI — schlägt der Upload fehl, ist das Foto weg
      // und die KI-Analyse wäre verschwendet. Schlägt umgekehrt nur die KI
      // fehl, bleibt das schon hochgeladene Foto als Dokumentation stehen
      // (Review-Fund: vorher ging bei einem KI-Fehler auch das Foto verloren).
      final pfad = await EventDokumentStorage.uploadTechnikFoto(
        widget.geraetServerId,
        bytes,
        istKuehler ? 'kuehler' : 'pumpe',
      );
      if (!mounted) return;
      setState(() {
        if (istKuehler) {
          _typenschildKuehlerPfad = pfad;
        } else {
          _typenschildPumpePfad = pfad;
        }
      });

      try {
        final ergebnis =
            await TypenschildService.lesen(bytes, mediaType: mediaType);
        if (!mounted) return;
        setState(() {
          final vorschlag = ergebnis.vorschlagTyp();
          if (vorschlag != null) {
            (istKuehler ? _kuehlerTyp : _pumpeTyp).text = vorschlag;
          }
          _erkennung[istKuehler ? 'kuehler' : 'pumpe'] = ergebnis.toJson();
          if (istKuehler) {
            _liestKuehler = false;
          } else {
            _liestPumpe = false;
          }
        });
      } catch (e) {
        // Nur die KI-Auswertung ist gescheitert — der Pfad oben bleibt
        // gesetzt, das Foto ist nicht verloren.
        if (mounted) {
          setState(() {
            if (istKuehler) {
              _liestKuehler = false;
            } else {
              _liestPumpe = false;
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Foto gespeichert, KI-Auswertung fehlgeschlagen: $e'),
            ),
          );
        }
      }
    } catch (e) {
      // Kamera/Ausrichtung/Upload fehlgeschlagen — hier gibt es noch nichts
      // zu erhalten, kompletter Abbruch mit Fehlermeldung.
      if (mounted) {
        setState(() {
          if (istKuehler) {
            _liestKuehler = false;
          } else {
            _liestPumpe = false;
          }
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  Widget _typFeld({
    required bool istKuehler,
    required TextEditingController controller,
    required String label,
  }) {
    final laeuft = istKuehler ? _liestKuehler : _liestPumpe;
    final pfad = istKuehler ? _typenschildKuehlerPfad : _typenschildPumpePfad;
    final unsicher = _unsicherBei(istKuehler ? 'kuehler' : 'pumpe');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(labelText: label),
              ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 40,
              height: 40,
              child: laeuft
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: Icon(
                        Icons.photo_camera,
                        color: pfad != null ? AppColors.success : null,
                      ),
                      tooltip: 'Typenschild fotografieren',
                      onPressed: () => _fotografieren(istKuehler),
                    ),
            ),
          ],
        ),
        if (unsicher.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(
              'KI unsicher bei: ${unsicher.join(', ')}',
              style: const TextStyle(fontSize: 11.5, color: AppColors.warning),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _typFeld(istKuehler: true, controller: _kuehlerTyp, label: 'Typ Kühler'),
        const SizedBox(height: 4),
        _typFeld(istKuehler: false, controller: _pumpeTyp, label: 'Typ Pumpe'),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _sollMin,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: const InputDecoration(labelText: 'Soll von (°C)'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _sollMax,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: const InputDecoration(labelText: 'Soll bis (°C)'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Temperatur-Erfassung + Verlaufsgrafik in der Kühler-Karte ───

class _TemperaturEingabe {
  final double temperatur;
  final String? notiz;
  const _TemperaturEingabe(this.temperatur, this.notiz);
}

/// Kleiner Erfassungsdialog: Zahl (komma-tolerant) + optionale Notiz.
class _TemperaturDialog extends StatefulWidget {
  const _TemperaturDialog();

  @override
  State<_TemperaturDialog> createState() => _TemperaturDialogState();
}

class _TemperaturDialogState extends State<_TemperaturDialog> {
  final _wert = TextEditingController();
  final _notiz = TextEditingController();
  String? _fehler;

  @override
  void dispose() {
    _wert.dispose();
    _notiz.dispose();
    super.dispose();
  }

  void _speichern() {
    final text = _wert.text.trim().replaceAll(',', '.');
    final temperatur = double.tryParse(text);
    if (temperatur == null) {
      setState(() => _fehler = 'Bitte eine Zahl eingeben');
      return;
    }
    Navigator.pop(
      context,
      _TemperaturEingabe(
        temperatur,
        _notiz.text.trim().isEmpty ? null : _notiz.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Temperatur erfassen'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _wert,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: InputDecoration(
              labelText: 'Temperatur (°C)',
              errorText: _fehler,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notiz,
            decoration: const InputDecoration(labelText: 'Notiz (optional)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        TextButton(onPressed: _speichern, child: const Text('Speichern')),
      ],
    );
  }
}

/// Erfassungs-Knopf + Verlaufsgrafik für einen Durchlaufkühler — eingebettet
/// im aufgeklappten Bereich von _GeraetCard.
class KuehlerTemperaturBereich extends ConsumerStatefulWidget {
  final String geraetServerId;
  final double? sollMin;
  final double? sollMax;

  const KuehlerTemperaturBereich({
    super.key,
    required this.geraetServerId,
    this.sollMin,
    this.sollMax,
  });

  @override
  ConsumerState<KuehlerTemperaturBereich> createState() =>
      _KuehlerTemperaturBereichState();
}

class _KuehlerTemperaturBereichState
    extends ConsumerState<KuehlerTemperaturBereich> {
  // Riegel gegen doppeltes Speichern, falls der Dialog-Speichern-Knopf
  // während des laufenden Requests erneut auslöst (gleiches Muster wie
  // _schaltet/_ortet in _GeraetCardState).
  bool _erfasst = false;

  Future<void> _erfassen() async {
    if (_erfasst) return;
    final eingabe = await showDialog<_TemperaturEingabe>(
      context: context,
      builder: (ctx) => const _TemperaturDialog(),
    );
    if (eingabe == null || !mounted) return;
    setState(() => _erfasst = true);
    try {
      final m = EventKuehlerMessungLocal()
        ..geraetId = widget.geraetServerId
        ..gemessenAm = DateTime.now()
        ..temperatur = eingabe.temperatur
        ..notiz = eingabe.notiz;
      await EventKuehlerMessungRepository.save(m);
      ref.invalidate(eventKuehlerMessungenProvider(widget.geraetServerId));
      if (mounted) {
        setState(() => _erfasst = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('🌡️ ${eingabe.temperatur.toStringAsFixed(1)} °C erfasst'),
          ),
        );
      }
    } catch (e) {
      // Kein stiller Fehlschlag — der Riegel geht so oder so wieder auf.
      if (mounted) {
        setState(() => _erfasst = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messungen = ref
            .watch(eventKuehlerMessungenProvider(widget.geraetServerId))
            .valueOrNull ??
        const <EventKuehlerMessungLocal>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton.icon(
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            alignment: Alignment.centerLeft,
          ),
          icon: const Icon(Icons.thermostat, size: 18),
          label: Text(_erfasst ? 'Speichert …' : 'Temperatur erfassen'),
          onPressed: _erfasst ? null : _erfassen,
        ),
        if (messungen.length >= 2)
          SizedBox(
            height: 160,
            child: KuehlerVerlaufChart(
              messungen: messungen,
              sollMin: widget.sollMin,
              sollMax: widget.sollMax,
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 4),
            child: Text(
              'Noch keine Messreihe.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }
}

/// Einfache Verlaufsgrafik der Temperatur-Messungen — keine Touch-
/// Interaktion, nur Linie + Punkte + gestricheltes Soll-Band.
/// [messungen] muss aufsteigend nach gemessenAm sortiert sein (die
/// Repository-Abfrage liefert das bereits so, nativ wie auf Web).
class KuehlerVerlaufChart extends StatelessWidget {
  final List<EventKuehlerMessungLocal> messungen;
  final double? sollMin;
  final double? sollMax;

  const KuehlerVerlaufChart({
    super.key,
    required this.messungen,
    this.sollMin,
    this.sollMax,
  });

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (final m in messungen)
        FlSpot(m.gemessenAm.millisecondsSinceEpoch.toDouble(), m.temperatur),
    ];
    final xMin = spots.first.x;
    final xMax = spots.last.x;
    final mehrereTage = messungen.last.gemessenAm
            .difference(messungen.first.gemessenAm)
            .inHours >=
        24;

    return LineChart(
      LineChartData(
        minX: xMin,
        maxX: xMax,
        lineTouchData: const LineTouchData(enabled: false),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (value, meta) => Text(
                '${value.toStringAsFixed(0)}°',
                style:
                    const TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: xMax > xMin ? (xMax - xMin) / 3 : 1,
              getTitlesWidget: (value, meta) {
                final zeit = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                final text = mehrereTage
                    ? '${_zwei(zeit.day)}.${_zwei(zeit.month)} ${_zwei(zeit.hour)}:${_zwei(zeit.minute)}'
                    : '${_zwei(zeit.hour)}:${_zwei(zeit.minute)}';
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    text,
                    style: const TextStyle(
                        fontSize: 9, color: AppColors.textSecondary),
                  ),
                );
              },
            ),
          ),
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            if (sollMin != null)
              HorizontalLine(
                y: sollMin!,
                color: AppColors.warning,
                strokeWidth: 1,
                dashArray: const [4, 4],
              ),
            if (sollMax != null)
              HorizontalLine(
                y: sollMax!,
                color: AppColors.warning,
                strokeWidth: 1,
                dashArray: const [4, 4],
              ),
          ],
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: AppColors.primary,
            barWidth: 2,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) {
                final ausserhalb = istAusserhalbSollbereich(
                  temperatur: spot.y,
                  sollMin: sollMin,
                  sollMax: sollMax,
                );
                return FlDotCirclePainter(
                  radius: 3,
                  color: ausserhalb ? AppColors.error : AppColors.primary,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _zwei(int n) => n.toString().padLeft(2, '0');
}

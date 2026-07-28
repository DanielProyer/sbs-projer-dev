import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/beleg_korrektur.dart';
import 'package:sbs_projer_app/data/models/beleg_scan_result.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/presentation/providers/buchung_providers.dart';
import 'package:sbs_projer_app/services/spesen/beleg_bild_service.dart';
import 'package:sbs_projer_app/services/spesen/beleg_scan_service.dart';
import 'package:sbs_projer_app/services/spesen/spesen_import_service.dart';

class SpesenScannerScreen extends ConsumerStatefulWidget {
  const SpesenScannerScreen({super.key});

  @override
  ConsumerState<SpesenScannerScreen> createState() =>
      _SpesenScannerScreenState();
}

class _SpesenScannerScreenState extends ConsumerState<SpesenScannerScreen> {
  int _step = 0; // 0 = Kamera, 1 = Prüfen, 2 = Erfolg
  bool _isLoading = false;
  String? _error;

  // Beleg-Daten
  Uint8List? _belegBytes;
  String _dateiname = '';
  String _dateityp = '';
  String _mediaType = '';

  // OCR-Ergebnis
  BelegScanResult? _scanResult;

  // Buchungs-Optionen
  Zahlungsweg _zahlungsweg = Zahlungsweg.bar;

  // Korrigierbarer Entwurf (aus dem Scan vorbefüllt)
  final _geschaeftCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();
  DateTime _datum = DateTime.now();
  final List<_PosEntwurf> _positionen = [];
  bool _dreheLaeuft = false;

  static const _mwstSaetze = [8.1, 3.8, 2.6, 0.0];
  static const _kategorien = [
    'essen',
    'benzin',
    'material',
    'berufskleider',
    'parkgebuehren',
    'entsorgung',
    'privat',
  ];

  // Ergebnis
  List<Buchung> _erstellteBuchungen = [];

  @override
  void dispose() {
    _geschaeftCtrl.dispose();
    _totalCtrl.dispose();
    for (final p in _positionen) {
      p.dispose();
    }
    super.dispose();
  }

  /// Scan-Ergebnis in den editierbaren Entwurf übernehmen.
  void _uebernehmeScan(BelegScanResult result) {
    _geschaeftCtrl.text = result.geschaeft;
    _totalCtrl.text = result.totalBrutto.toStringAsFixed(2);
    _datum = result.datum;
    for (final p in _positionen) {
      p.dispose();
    }
    _positionen
      ..clear()
      ..addAll(result.positionen.map(_PosEntwurf.ausPosition));
  }

  /// Entwurf zurück in ein BelegScanResult — das ist, was gebucht wird.
  BelegScanResult _scanAusEntwurf() {
    return BelegScanResult(
      geschaeft: _geschaeftCtrl.text.trim().isEmpty
          ? 'Unbekannt'
          : _geschaeftCtrl.text.trim(),
      datum: _datum,
      positionen: _positionen.map((p) => p.zuPosition()).toList(),
      totalBrutto: _total(),
      konfidenz: _scanResult?.konfidenz ?? 1.0,
      zahlungsmethode: _scanResult?.zahlungsmethode,
    );
  }

  double _total() => double.tryParse(_totalCtrl.text.replaceAll(',', '.')) ?? 0;

  List<double> _positionsBetraege() =>
      _positionen.map((p) => p.betragWert).toList();

  double _barRundung() =>
      double.parse((runde5Rappen(_total()) - _total()).toStringAsFixed(2));

  Future<void> _datumWaehlen() async {
    final gewaehlt = await showDatePicker(
      context: context,
      initialDate: _datum,
      firstDate: DateTime(_datum.year - 2),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (gewaehlt != null) setState(() => _datum = gewaehlt);
  }

  void _posHinzufuegen() {
    setState(() => _positionen.add(_PosEntwurf.leer()));
  }

  void _posEntfernen(int index) {
    setState(() => _positionen.removeAt(index).dispose());
  }

  /// Beleg drehen — wirkt auf die Datei, die im Storage landet.
  Future<void> _drehen(int grad) async {
    final bytes = _belegBytes;
    if (bytes == null) return;
    setState(() => _dreheLaeuft = true);
    try {
      final gedreht =
          BelegBildService.drehen(bytes, grad, dateityp: _dateityp);
      if (!mounted) return;
      setState(() {
        _belegBytes = gedreht;
        _dreheLaeuft = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Drehen fehlgeschlagen: $e';
        _dreheLaeuft = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openCamera());
  }

  Future<void> _openCamera() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      await Future.delayed(Duration.zero);

      final picker = ImagePicker();
      // Auflösung/Qualität hoch genug fürs Kleingedruckte (Regel Daniel
      // 26.07.2026): Mit 1024 px / Q60 war auf Thermo-Kassenzetteln nur der
      // fett gedruckte Totalbetrag sicher lesbar — Datum, MwSt-Tabelle und
      // Zahlungsart (alles klein) wurden regelmässig falsch erkannt.
      // 2000 px / Q88 liefert scharfe Ziffern und bleibt beim Base64-Versand
      // an die Edge-Function unter ~1.5 MB.
      final image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 88,
      );
      if (image == null) {
        if (mounted) context.pop();
        return;
      }

      final bytes = await image.readAsBytes();
      final ext = image.name.split('.').last.toLowerCase();

      _belegBytes = bytes;
      _dateiname = image.name;
      _dateityp = ext == 'png' ? 'png' : 'jpg';
      _mediaType = ext == 'png' ? 'image/png' : 'image/jpeg';

      await _analyzeBeleg();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Fehler beim Laden: $e';
      });
    }
  }

  Future<void> _analyzeBeleg() async {
    if (_belegBytes == null) return;

    try {
      final result = await BelegScanService.parseBeleg(
        bytes: _belegBytes!,
        mediaType: _mediaType,
      );

      // Zahlungsweg automatisch vorauswählen basierend auf OCR
      Zahlungsweg autoZahlungsweg = Zahlungsweg.bar;
      if (result.zahlungsmethode == 'twint') {
        autoZahlungsweg = Zahlungsweg.privat;
      } else if (result.zahlungsmethode == 'karte') {
        autoZahlungsweg = Zahlungsweg.bank;
      }

      setState(() {
        _scanResult = result;
        _uebernehmeScan(result);
        _zahlungsweg = autoZahlungsweg;
        _step = 1;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _buchen() async {
    if (_scanResult == null || _belegBytes == null) return;
    if (_positionen.isEmpty) {
      setState(() => _error = 'Keine Positionen erfasst.');
      return;
    }

    final entwurf = _scanAusEntwurf();
    if (!await _dublettePruefen(entwurf)) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final buchungen = await SpesenImportService.importSpesen(
        scanResult: entwurf,
        zahlungsweg: _zahlungsweg,
        belegBytes: _belegBytes!,
        dateiname: _dateiname,
        dateityp: _dateityp,
      );

      // Provider invalidieren damit Journal/Kontoauszug sofort aktuell sind
      ref.invalidate(buchungenStreamProvider);

      setState(() {
        _erstellteBuchungen = buchungen;
        _step = 2;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Buchung fehlgeschlagen: $e';
        _isLoading = false;
      });
    }
  }

  /// Warnt, wenn derselbe Beleg an diesem Tag schon gebucht wurde.
  /// Bewusst keine Sperre — zweimal am selben Tag bei derselben Tankstelle
  /// zu tanken ist ein echter Fall. Gibt true zurück, wenn gebucht werden soll.
  Future<bool> _dublettePruefen(BelegScanResult entwurf) async {
    List<DublettenKandidat> kandidaten;
    try {
      kandidaten = await BuchungRepository.spesenAmDatum(entwurf.datum);
    } catch (_) {
      return true; // Prüfung darf das Buchen nie blockieren
    }
    final summe =
        _positionsBetraege().fold<double>(0, (s, b) => s + b);
    if (!dublettenTreffer(kandidaten, entwurf.geschaeft, summe)) return true;
    if (!mounted) return false;

    final trotzdem = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Beleg schon gebucht?'),
        content: Text(
          '${entwurf.geschaeft} vom ${_formatDate(entwurf.datum)} über '
          '${summe.toStringAsFixed(2)} CHF ist bereits gebucht.\n\n'
          'Trotzdem nochmal buchen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Trotzdem buchen'),
          ),
        ],
      ),
    );
    return trotzdem == true;
  }

  void _reset() {
    setState(() {
      _step = 0;
      _isLoading = false;
      _error = null;
      _belegBytes = null;
      _dateiname = '';
      _dateityp = '';
      _mediaType = '';
      _scanResult = null;
      _zahlungsweg = Zahlungsweg.bar;
      _erstellteBuchungen = [];
    });
    _openCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Spesen Scanner')),
      body: SafeArea(child: _isLoading ? _buildLoading() : _buildStep()),
      // Aktions-Buttons FIX am unteren Rand (Vorfall 26.07.2026: bei einem
      // Beleg mit 6 Positionen war der Buchen-Button am Listenende nicht
      // mehr erreichbar). So hängt er nie am Scrollen und liegt nicht hinter
      // der System-Navigationsleiste.
      bottomNavigationBar: (!_isLoading && (_step == 1 || _step == 2))
          ? _buildAktionsLeiste()
          : null,
    );
  }

  /// Untere Aktionsleiste: im Prüf-Schritt buchen bzw. nochmal scannen,
  /// nach dem Buchen weiter scannen bzw. fertig. Immer fix am unteren
  /// Rand, damit sie nie am Scrollen hängt.
  Widget _buildAktionsLeiste() {
    if (_step == 2) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              TextButton(
                onPressed: () => context.go('/'),
                child: const Text('Fertig'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.document_scanner),
                  label: const Text('Weiteren Beleg scannen'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final scan = _scanResult;
    if (scan == null) return const SizedBox.shrink();
    final unsicher = scan.konfidenz < 0.85;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            TextButton(
              onPressed: _reset,
              child: Text(unsicher ? 'Abbrechen' : 'Neuer Beleg'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: unsicher
                  ? FilledButton.icon(
                      onPressed: _reset,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Nochmal scannen'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    )
                  : FilledButton.icon(
                      onPressed: _buchen,
                      icon: const Icon(Icons.check),
                      label: Text(
                        scan.istMischkauf
                            ? '${scan.positionen.length} Buchungen erstellen'
                            : 'Buchen',
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    final text = _step == 0
        ? 'Beleg wird analysiert...'
        : 'Buchung wird erstellt...';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(text, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _buildFehler();
      case 1:
        return _buildPruefen();
      case 2:
        return _buildErfolg();
      default:
        return const SizedBox();
    }
  }

  // === Step 0: Fehler / Retry ===
  Widget _buildFehler() {
    if (_error == null) return const SizedBox();
    // Scrollbar, damit auch lange Fehlermeldungen die Knöpfe nicht
    // aus dem Bild schieben (gleiche Falle wie im Erfolgs-Schritt).
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Column(
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.error, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _openCamera,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Nochmal versuchen'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Abbrechen'),
            ),
          ],
        ),
      ],
    );
  }

  // === Step 1: Prüfen & korrigieren ===
  //
  // Alle erkannten Werte sind editierbar (Entscheid Daniel 28.07.2026):
  // Datum, Geschäft, Total, jede Position (Text, Betrag, MwSt-Satz,
  // Kategorie) sowie Positionen löschen/hinzufügen. Stimmt die Summe der
  // Positionen nicht zum Total, wird nur gewarnt — buchen bleibt möglich
  // (z.B. Gutschein oder Rabatt, den der Scan nicht als Position führt).
  Widget _buildPruefen() {
    final scan = _scanResult!;
    final differenz = differenzZumTotal(_positionsBetraege(), _total());

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildBelegBild(scan),
        const SizedBox(height: 12),
        _buildAngaben(),
        const SizedBox(height: 12),
        _buildPositionen(),
        if (differenz != null) ...[
          const SizedBox(height: 8),
          _buildDifferenzHinweis(differenz),
        ],
        const SizedBox(height: 16),
        _buildZahlungsweg(),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _error!,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        ],
        if (scan.konfidenz < 0.85) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.warning.withAlpha(80)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.warning, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Erkennung unsicher (${(scan.konfidenz * 100).round()}%) — '
                    'bitte Beträge prüfen oder nochmal scannen.',
                    style: TextStyle(
                      color: AppColors.warning.withAlpha(200),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  /// Beleg-Vorschau mit Drehen-Knöpfen. Die Drehung wirkt auf die Datei,
  /// die im Storage landet (Belege wurden mehrfach quer gespeichert).
  Widget _buildBelegBild(BelegScanResult scan) {
    final bytes = _belegBytes;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (bytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.memory(
                  bytes,
                  height: 160,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _dreheLaeuft ? null : () => _drehen(270),
                  icon: const Icon(Icons.rotate_left),
                  tooltip: 'Nach links drehen',
                ),
                if (_dreheLaeuft)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Text('Beleg drehen',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                IconButton(
                  onPressed: _dreheLaeuft ? null : () => _drehen(90),
                  icon: const Icon(Icons.rotate_right),
                  tooltip: 'Nach rechts drehen',
                ),
                const Spacer(),
                _KonfidenzBadge(konfidenz: scan.konfidenz),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAngaben() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _geschaeftCtrl,
              decoration: const InputDecoration(
                labelText: 'Geschäft',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _datumWaehlen,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Datum',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatDate(_datum)),
                          const Icon(Icons.calendar_today, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _totalCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Total CHF',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            if (_zahlungsweg == Zahlungsweg.bar && _barRundung() != 0) ...[
              const SizedBox(height: 8),
              Text(
                'Bar gerundet auf 5 Rappen: '
                '${runde5Rappen(_total()).toStringAsFixed(2)} CHF '
                '(${_barRundung() > 0 ? '+' : ''}'
                '${_barRundung().toStringAsFixed(2)})',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPositionen() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.list_alt, size: 18, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  _positionen.length == 1
                      ? '1 Position'
                      : '${_positionen.length} Positionen',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  '${_positionsBetraege().fold<double>(0, (s, b) => s + b).toStringAsFixed(2)} CHF',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const Divider(height: 20),
            for (var i = 0; i < _positionen.length; i++) _posKarte(i),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _posHinzufuegen,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Position hinzufügen'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _posKarte(int index) {
    final pos = _positionen[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_katIcon(pos.kategorie),
                  size: 18, color: _katFarbe(pos.kategorie)),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: pos.beschreibung,
                  decoration: const InputDecoration(
                    labelText: 'Beschreibung',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _posEntfernen(index),
                icon: const Icon(Icons.delete_outline, size: 20),
                color: AppColors.error,
                tooltip: 'Position entfernen',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 96,
                child: TextField(
                  controller: pos.betrag,
                  decoration: const InputDecoration(
                    labelText: 'CHF',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 92,
                child: DropdownButtonFormField<double>(
                  initialValue: pos.mwstSatz,
                  decoration: const InputDecoration(
                    labelText: 'MwSt',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: _mwstSaetze
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text('$s%', style: const TextStyle(fontSize: 13)),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => pos.mwstSatz = v ?? pos.mwstSatz),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: pos.kategorie,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Konto',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: _kategorien
                      .map((k) => DropdownMenuItem(
                            value: k,
                            child: Text(_katLabel(k),
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => pos.kategorie = v ?? pos.kategorie),
                ),
              ),
            ],
          ),
          if (pos.kategorie == 'privat')
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _zahlungsweg == Zahlungsweg.privat
                    ? 'Privatkauf — wird nicht gebucht'
                    : 'Privatkauf — Bezug ab '
                        '${_zahlungsweg == Zahlungsweg.bar ? 'Kasse' : 'Bank'}, '
                        'kein Vorsteuerabzug',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDifferenzHinweis(double differenz) {
    final zuWenig = differenz > 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withAlpha(80)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Positionen ergeben ${differenz.abs().toStringAsFixed(2)} CHF '
              '${zuWenig ? 'weniger' : 'mehr'} als das Total. '
              'Gebucht werden die Positionen.',
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZahlungsweg() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Zahlungsweg',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ChoiceChipButton(
                icon: Icons.payments,
                label: 'Bar',
                subtitle: 'Konto 1000',
                isSelected: _zahlungsweg == Zahlungsweg.bar,
                color: AppColors.success,
                onTap: () => setState(() => _zahlungsweg = Zahlungsweg.bar),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ChoiceChipButton(
                icon: Icons.account_balance,
                label: 'Bank',
                subtitle: 'Konto 1020',
                isSelected: _zahlungsweg == Zahlungsweg.bank,
                color: AppColors.info,
                onTap: () => setState(() => _zahlungsweg = Zahlungsweg.bank),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ChoiceChipButton(
                icon: Icons.person,
                label: 'Privat',
                subtitle: 'Konto 2260',
                isSelected: _zahlungsweg == Zahlungsweg.privat,
                color: AppColors.warning,
                onTap: () => setState(() => _zahlungsweg = Zahlungsweg.privat),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // === Step 2: Erfolg ===
  Widget _buildErfolg() {
    // ListView statt Column: Bei mehreren Buchungen (Mischkauf) lief der
    // Inhalt sonst unten aus dem Bild UND liess sich nicht scrollen —
    // die Knöpfe waren unerreichbar (Vorfall 26.07.2026). Die Knöpfe
    // sitzen jetzt zusätzlich in der fixen Aktionsleiste unten.
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Column(
          children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 72),
            const SizedBox(height: 16),
            Text(
              _erstellteBuchungen.length == 1
                  ? 'Buchung erstellt!'
                  : '${_erstellteBuchungen.length} Buchungen erstellt!',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),

            // Buchungs-Details
            ...(_erstellteBuchungen.map(
              (b) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.success.withAlpha(25),
                    child: const Icon(
                      Icons.swap_horiz,
                      color: AppColors.success,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    b.beschreibung,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    '${b.sollKonto} → ${b.habenKonto} · ${b.mwstSatz}% MwSt',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Text(
                    '${b.betragBrutto.toStringAsFixed(2)} CHF',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () => context.push('/buchhaltung/buchungen/${b.id}'),
                ),
              ),
            )),
          ],
        ),
      ],
    );
  }

  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

}

// === Hilfs-Widgets ===

class _ChoiceChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _ChoiceChipButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: isSelected ? color.withAlpha(25) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: color, width: 2)
            : BorderSide(color: AppColors.divider),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? color : AppColors.textSecondary,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: isSelected ? color : null,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Eine korrigierbare Beleg-Position im Prüf-Schritt.
class _PosEntwurf {
  final TextEditingController beschreibung;
  final TextEditingController betrag;
  double mwstSatz;
  String kategorie;

  _PosEntwurf({
    required String text,
    required double betragWert,
    required this.mwstSatz,
    required this.kategorie,
  })  : beschreibung = TextEditingController(text: text),
        betrag = TextEditingController(text: betragWert.toStringAsFixed(2));

  factory _PosEntwurf.ausPosition(BelegPosition p) => _PosEntwurf(
        text: p.beschreibung,
        betragWert: p.betragBrutto,
        mwstSatz: p.mwstSatz,
        kategorie: p.kategorie,
      );

  factory _PosEntwurf.leer() => _PosEntwurf(
        text: '',
        betragWert: 0,
        mwstSatz: 8.1,
        kategorie: 'essen',
      );

  double get betragWert =>
      double.tryParse(betrag.text.replaceAll(',', '.')) ?? 0;

  BelegPosition zuPosition() => BelegPosition(
        mwstSatz: mwstSatz,
        betragBrutto: betragWert,
        beschreibung: beschreibung.text.trim(),
        kategorie: kategorie,
      );

  void dispose() {
    beschreibung.dispose();
    betrag.dispose();
  }
}

/// Anzeige-Mapping der OCR-Kategorien (Konten wie in SpesenImportService).
IconData _katIcon(String kategorie) {
  switch (kategorie) {
    case 'privat':
      return Icons.person_outline;
    case 'benzin':
      return Icons.local_gas_station;
    case 'material':
      return Icons.handyman;
    case 'berufskleider':
      return Icons.checkroom;
    case 'parkgebuehren':
      return Icons.local_parking;
    case 'entsorgung':
      return Icons.delete_outline;
    default:
      return Icons.restaurant;
  }
}

Color _katFarbe(String kategorie) {
  switch (kategorie) {
    case 'privat':
      return AppColors.textSecondary;
    case 'benzin':
      return AppColors.info;
    case 'material':
    case 'berufskleider':
    case 'entsorgung':
      return AppColors.primary;
    case 'parkgebuehren':
      return AppColors.info;
    default:
      return AppColors.warning;
  }
}

String _katLabel(String kategorie) {
  switch (kategorie) {
    case 'privat':
      return 'Privat · 2260';
    case 'benzin':
      return 'Benzin · 6200';
    case 'material':
      return 'Material · 4004';
    case 'berufskleider':
      return 'Berufskleider · 5850';
    case 'parkgebuehren':
      return 'Parkgebühren · 6270';
    case 'entsorgung':
      return 'Entsorgung · 6460';
    default:
      return 'Essen · 5820';
  }
}

class _KonfidenzBadge extends StatelessWidget {
  final double konfidenz;

  const _KonfidenzBadge({required this.konfidenz});

  @override
  Widget build(BuildContext context) {
    final pct = (konfidenz * 100).round();
    final color = konfidenz >= 0.8
        ? AppColors.success
        : konfidenz >= 0.5
        ? AppColors.warning
        : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$pct%',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

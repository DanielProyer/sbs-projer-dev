import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/beleg_scan_result.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/presentation/providers/buchung_providers.dart';
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

  // Ergebnis
  List<Buchung> _erstellteBuchungen = [];

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

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final buchungen = await SpesenImportService.importSpesen(
        scanResult: _scanResult!,
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

  // === Step 1: Prüfen ===
  Widget _buildPruefen() {
    final scan = _scanResult!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // OCR-Ergebnis Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        scan.geschaeft,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _KonfidenzBadge(konfidenz: scan.konfidenz),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Datum: ${_formatDate(scan.datum)}',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const Divider(height: 24),

                // Positionen
                ...scan.positionen.map(
                  (pos) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          _katIcon(pos.kategorie),
                          size: 18,
                          color: _katFarbe(pos.kategorie),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      pos.beschreibung,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _katFarbe(
                                        pos.kategorie,
                                      ).withAlpha(25),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _katLabel(pos.kategorie),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: _katFarbe(pos.kategorie),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                pos.kategorie == 'privat'
                                    ? (_zahlungsweg == Zahlungsweg.privat
                                          ? 'Privatkauf — wird nicht gebucht'
                                          : 'Privatkauf — Bezug ab '
                                                '${_zahlungsweg == Zahlungsweg.bar ? 'Kasse' : 'Bank'}, '
                                                'kein Vorsteuerabzug')
                                    : 'Netto ${pos.betragNetto.toStringAsFixed(2)} + ${pos.mwstSatz}% MwSt ${pos.mwstBetrag.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${pos.betragBrutto.toStringAsFixed(2)} CHF',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${scan.totalBrutto.toStringAsFixed(2)} CHF',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                // 5-Rappen-Rundung bei Barzahlung anzeigen
                if (_zahlungsweg == Zahlungsweg.bar &&
                    _gerundeterTotal(scan) != scan.totalBrutto) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Bar gerundet (5 Rp.)',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '${_gerundeterTotal(scan).toStringAsFixed(2)} CHF',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),

        // Mischkauf-Info
        if (scan.positionen.length > 1) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.info.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.info.withAlpha(50)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.info, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Mischkauf: ${scan.positionen.length} separate Buchungen (Konten automatisch erkannt)',
                    style: const TextStyle(color: AppColors.info, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Zahlungsweg
        Text(
          'Zahlungsweg',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
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

        const SizedBox(height: 16),

        // Niedrige Konfidenz → Warnung (der Knopf dazu sitzt in der
        // fixen Aktionsleiste unten).
        if (scan.konfidenz < 0.85)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.warning.withAlpha(80)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.warning,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Erkennung unsicher (${(scan.konfidenz * 100).round()}%) — Beträge könnten falsch sein. Bitte nochmal scannen.',
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

  static double _runden5Rappen(double betrag) =>
      (betrag * 20).roundToDouble() / 20;

  static double _gerundeterTotal(BelegScanResult scan) {
    double total = 0;
    for (final pos in scan.positionen) {
      total += _runden5Rappen(pos.betragBrutto);
    }
    return total;
  }
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

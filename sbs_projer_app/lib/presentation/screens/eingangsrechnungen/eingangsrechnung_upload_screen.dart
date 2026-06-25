import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/rechnung_scan_result.dart';
import 'package:sbs_projer_app/data/repositories/eingangsrechnung_repository.dart';
import 'package:sbs_projer_app/presentation/providers/eingangsrechnung_providers.dart';
import 'package:sbs_projer_app/services/eingangsrechnung/rechnung_scan_service.dart';

/// Upload-/Erkennungs-Screen für Eingangsrechnungen (Kreditoren, TP-1).
///
/// Ablauf: PDF auswählen → KI-Analyse (Edge Function `parse-rechnung`) →
/// Eingangsrechnung anlegen (Status `erkannt`) → Beleg in Storage ablegen →
/// erkannte Felder als Vorschau zeigen. "Prüfen & Buchen" folgt im Detail
/// (TP-2).
class EingangsrechnungUploadScreen extends ConsumerStatefulWidget {
  const EingangsrechnungUploadScreen({super.key});

  @override
  ConsumerState<EingangsrechnungUploadScreen> createState() =>
      _EingangsrechnungUploadScreenState();
}

class _EingangsrechnungUploadScreenState
    extends ConsumerState<EingangsrechnungUploadScreen> {
  bool _busy = false;
  String _statusText = '';
  RechnungScanResult? _result;
  String? _dateiname;

  Future<void> _pickAndScanPdf() async {
    if (_busy) return;

    Uint8List? bytes;
    String? name;
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (picked == null || picked.files.single.bytes == null) return;
      bytes = picked.files.single.bytes!;
      name = picked.files.single.name;
    } catch (e) {
      _showError('Datei konnte nicht ausgewählt werden: $e');
      return;
    }

    await _scanAndCreate(bytes: bytes, name: name, mediaType: 'application/pdf');
  }

  Future<void> _scanAndCreate({
    required Uint8List bytes,
    required String name,
    required String mediaType,
  }) async {
    setState(() {
      _busy = true;
      _result = null;
      _dateiname = name;
      _statusText = 'Rechnung wird analysiert …';
    });

    try {
      // 1) KI-Analyse via Edge Function
      final r = await RechnungScanService.scan(bytes: bytes, mediaType: mediaType);

      // 2) Eingangsrechnung anlegen (Status erkannt)
      setState(() => _statusText = 'Eingangsrechnung wird gespeichert …');
      final created = await EingangsrechnungRepository.create({
        'aussteller_name': r.ausstellerName,
        'aussteller_uid': r.ausstellerUid,
        'lieferant_iban': r.empfaengerIban,
        'qr_referenz': r.referenz,
        'referenz_typ': r.referenzTyp,
        'betrag_brutto': r.betragZahlbar,
        'mwst_satz': r.mwstSatz,
        'mwst_pflichtig': r.mwstPflichtig,
        'rechnungsnummer': r.rechnungsnummer,
        'rechnungsdatum': _dateOnly(r.rechnungsdatum),
        'faelligkeit': _dateOnly(r.faelligkeit),
        'dok_typ': r.dokTyp,
        'ist_nur_info': r.istNurInfo,
        'konfidenz': r.konfidenz,
        'status': 'erkannt',
      });

      // 3) Beleg in Storage ablegen + Pfad nachtragen
      setState(() => _statusText = 'Beleg wird hochgeladen …');
      final pfad = await EingangsrechnungRepository.uploadBeleg(
        eingangsrechnungId: created.id,
        dateiname: name,
        dateityp: 'pdf',
        bytes: bytes,
      );
      await EingangsrechnungRepository.update(created.id, {
        'beleg_pfad': pfad,
        'beleg_dateiname': name,
      });

      // Liste invalidieren, damit die neue Rechnung erscheint
      ref.invalidate(eingangsrechnungenProvider);

      if (!mounted) return;
      setState(() {
        _result = r;
        _statusText = '';
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _statusText = '';
      });
      _showError('Analyse/Upload fehlgeschlagen: $e');
    }
  }

  /// Wandelt ein DateTime in einen reinen Datums-String (YYYY-MM-DD) oder null.
  static String? _dateOnly(DateTime? d) {
    if (d == null) return null;
    return d.toIso8601String().substring(0, 10);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _fertig() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/buchhaltung/eingangsrechnungen');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rechnung hochladen')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'PDF einer Lieferanten-/Eingangsrechnung hochladen. '
              'Die Felder werden automatisch per KI erkannt.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 20),

            // PDF auswählen (GestureDetector — Material-Buttons rendern in
            // CanvasKit teils nicht zuverlässig).
            _primaryButton(
              label: 'PDF auswählen',
              icon: Icons.picture_as_pdf,
              onTap: _busy ? null : _pickAndScanPdf,
            ),

            if (_busy) ...[
              const SizedBox(height: 28),
              Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(
                      _statusText.isEmpty ? 'Bitte warten …' : _statusText,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],

            if (_result != null) ...[
              const SizedBox(height: 24),
              _ergebnisKarte(_result!),
              const SizedBox(height: 24),
              _primaryButton(
                label: 'Fertig',
                icon: Icons.check,
                onTap: _fertig,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _ergebnisKarte(RechnungScanResult r) {
    final niedrigeKonfidenz = r.konfidenz < 0.85;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                r.istRechnung ? Icons.check_circle : Icons.info_outline,
                color: r.istRechnung ? AppColors.success : AppColors.warning,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _dateiname ?? 'Erkanntes Dokument',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          if (r.istNurInfo)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: AppColors.warning),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Nur-Info-Beleg (keine Zahlung nötig).',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          _zeile('Aussteller', r.ausstellerName),
          _zeile('UID', r.ausstellerUid),
          _zeile('Dokument-Typ', r.dokTyp),
          _zeile(
            'Betrag',
            '${(r.waehrung ?? 'CHF')} ${r.betragZahlbar.toStringAsFixed(2)}',
          ),
          _zeile('IBAN', r.empfaengerIban),
          _zeile(
            'Referenz',
            r.referenz == null
                ? null
                : '${r.referenz} (${r.referenzTyp ?? 'NON'})',
          ),
          _zeile('Rechnungsnummer', r.rechnungsnummer),
          _zeile('Rechnungsdatum', _dateOnly(r.rechnungsdatum)),
          _zeile('Fälligkeit', _dateOnly(r.faelligkeit)),
          _zeile(
            'MwSt',
            '${r.mwstSatz.toStringAsFixed(1)}% '
                '(${r.mwstPflichtig ? 'pflichtig' : 'nicht pflichtig'})',
          ),

          const SizedBox(height: 8),
          Row(
            children: [
              Text('Konfidenz: ',
                  style: TextStyle(color: AppColors.textSecondary)),
              Text(
                '${(r.konfidenz * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: niedrigeKonfidenz
                      ? AppColors.error
                      : AppColors.success,
                ),
              ),
              if (niedrigeKonfidenz) ...[
                const SizedBox(width: 8),
                Icon(Icons.warning_amber_rounded,
                    size: 16, color: AppColors.error),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'bitte prüfen',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.error),
                  ),
                ),
              ],
            ],
          ),

          const Divider(height: 24),
          Text(
            'Prüfen & Buchen folgt im Detail (TP-2).',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _zeile(String label, String? wert) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              (wert == null || wert.isEmpty) ? '—' : wert,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primary
              : AppColors.primary.withAlpha(120),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

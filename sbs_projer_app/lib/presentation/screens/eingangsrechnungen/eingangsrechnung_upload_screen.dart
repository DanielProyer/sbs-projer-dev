import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/kreditor_regel.dart';
import 'package:sbs_projer_app/data/models/rechnung_scan_result.dart';
import 'package:sbs_projer_app/data/repositories/eingangsrechnung_repository.dart';
import 'package:sbs_projer_app/data/repositories/kreditor_regel_repository.dart';
import 'package:sbs_projer_app/presentation/providers/eingangsrechnung_providers.dart';
import 'package:sbs_projer_app/services/eingangsrechnung/kreditor_matcher.dart';
import 'package:sbs_projer_app/services/eingangsrechnung/rechnung_scan_service.dart';
import 'package:sbs_projer_app/services/eingangsrechnung/swiss_qr_data.dart';
import 'package:sbs_projer_app/services/eingangsrechnung/swiss_qr_service.dart';

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
  SwissQrData? _qr;
  String? _abweichungen;
  String? _dateiname;
  String? _belegPfad;
  KreditorRegel? _kreditorTreffer;

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
      _qr = null;
      _abweichungen = null;
      _kreditorTreffer = null;
      _dateiname = name;
      _statusText = 'Rechnung wird analysiert …';
    });

    try {
      // 1) KI-Analyse via Edge Function
      final r = await RechnungScanService.scan(bytes: bytes, mediaType: mediaType);

      // 1b) Swiss-QR-Code dekodieren (exakte IBAN/Referenz/Betrag) + abgleichen.
      //     QR gilt als Wahrheit; KI wird dagegengehalten.
      setState(() => _statusText = 'QR-Code wird gelesen …');
      final qr = await SwissQrService.decode(bytes: bytes, mediaType: mediaType);
      final abw = qr == null
          ? null
          : qrAbweichungen(
              qrIban: qr.iban,
              kiIban: r.empfaengerIban,
              qrRef: qr.referenz,
              kiRef: r.referenz,
              qrBetrag: qr.betrag,
              kiBetrag: r.betragZahlbar,
            );

      final effIban = qr?.iban ?? r.empfaengerIban;
      final effRef = qr?.referenz ?? r.referenz;
      final effRefTyp = qr?.referenzTyp ?? r.referenzTyp;
      final effBetrag =
          (qr?.betrag != null && qr!.betrag! > 0) ? qr.betrag! : r.betragZahlbar;

      // 1c) Lieferanten-Lernregel suchen → Konto/MwSt/Geschäftsfall vorbelegen.
      KreditorRegel? treffer;
      try {
        final regeln = await KreditorRegelRepository.getAllActive();
        treffer = matchKreditorRegel(
          regeln,
          ausstellerName: r.ausstellerName,
          iban: effIban,
          referenz: effRef,
        );
      } catch (_) {
        // Lernregeln dürfen den Upload nicht blockieren.
      }

      // 2) Eingangsrechnung anlegen (Status erkannt) — QR-Werte für IBAN/Ref/Betrag
      setState(() => _statusText = 'Eingangsrechnung wird gespeichert …');
      final created = await EingangsrechnungRepository.create({
        'aussteller_name': r.ausstellerName,
        'aussteller_uid': r.ausstellerUid,
        if (qr != null) 'aussteller_strasse': qr.cdtrStrasse,
        if (qr != null) 'aussteller_hausnr': qr.cdtrHausnr,
        if (qr != null) 'aussteller_plz': qr.cdtrPlz,
        if (qr != null) 'aussteller_ort': qr.cdtrOrt,
        if (qr != null) 'aussteller_land': qr.cdtrLand ?? 'CH',
        'lieferant_iban': effIban,
        'qr_referenz': effRef,
        'referenz_typ': effRefTyp,
        'betrag_brutto': effBetrag,
        'mwst_satz': treffer?.mwstSatzPercent ?? r.mwstSatz,
        'mwst_pflichtig': treffer?.mwstPflichtig ?? r.mwstPflichtig,
        'rechnungsnummer': r.rechnungsnummer,
        'rechnungsdatum': _dateOnly(r.rechnungsdatum),
        'faelligkeit': _dateOnly(r.faelligkeit),
        'dok_typ': r.dokTyp,
        'ist_nur_info': r.istNurInfo,
        'konfidenz': r.konfidenz,
        'qr_gelesen': qr != null,
        'qr_abweichungen': abw,
        'status': 'erkannt',
        if (treffer != null) 'aufwandskonto': treffer.aufwandskonto,
        if (treffer != null) 'vorsteuer_konto': treffer.vorsteuerKonto,
        if (treffer != null) 'geschaeftsfall_id': treffer.geschaeftsfallId,
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
        _qr = qr;
        _abweichungen = abw;
        _belegPfad = pfad;
        _kreditorTreffer = treffer;
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

  /// Öffnet das hochgeladene PDF über eine signierte Storage-URL (neuer Tab).
  Future<void> _pdfAnsehen() async {
    if (_belegPfad == null) return;
    try {
      final url = await EingangsrechnungRepository.signedBelegUrl(_belegPfad!);
      if (!await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication)) {
        _showError('PDF konnte nicht geöffnet werden');
      }
    } catch (e) {
      _showError('Fehler beim Öffnen: $e');
    }
  }

  Widget _outlineButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled ? AppColors.primary : AppColors.divider,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
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
              if (_belegPfad != null) ...[
                const SizedBox(height: 16),
                _outlineButton(
                  label: 'PDF ansehen',
                  icon: Icons.picture_as_pdf,
                  onTap: _busy ? null : _pdfAnsehen,
                ),
              ],
              const SizedBox(height: 14),
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
    final effIban = _qr?.iban ?? r.empfaengerIban;
    final effRef = _qr?.referenz ?? r.referenz;
    final effRefTyp = _qr?.referenzTyp ?? r.referenzTyp;
    final effBetrag =
        (_qr?.betrag != null && _qr!.betrag! > 0) ? _qr!.betrag! : r.betragZahlbar;

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

          _qrBanner(),

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
            'CHF ${effBetrag.toStringAsFixed(2)}'
                '${_qr?.betrag != null ? ' (QR)' : ''}',
          ),
          _zeile(
            'IBAN',
            effIban == null ? null : '$effIban${_qr != null ? ' (QR)' : ''}',
          ),
          _zeile(
            'Referenz',
            effRef == null
                ? null
                : '$effRef (${effRefTyp ?? 'NON'})'
                    '${_qr?.referenz != null ? ' · QR' : ''}',
          ),
          _zeile('Rechnungsnummer', r.rechnungsnummer),
          _zeile('Rechnungsdatum', _dateOnly(r.rechnungsdatum)),
          _zeile('Fälligkeit', _dateOnly(r.faelligkeit)),
          _zeile(
            'MwSt',
            '${r.mwstSatz.toStringAsFixed(1)}% '
                '(${r.mwstPflichtig ? 'pflichtig' : 'nicht pflichtig'})',
          ),
          if (_kreditorTreffer != null)
            _zeile(
              'Konto-Vorschlag',
              '${_kreditorTreffer!.aufwandskonto} (gelernt)',
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

  Widget _qrBanner() {
    final IconData icon;
    final Color color;
    final String text;
    if (_qr == null) {
      icon = Icons.warning_amber_rounded;
      color = AppColors.warning;
      text = 'Kein QR-Code gelesen – IBAN/Referenz stammen aus der '
          'Texterkennung. Bitte sorgfältig prüfen.';
    } else if (_abweichungen != null) {
      icon = Icons.error_outline;
      color = AppColors.error;
      text = 'QR ↔ Texterkennung weichen ab: $_abweichungen. '
          'Es gelten die QR-Werte (prüfziffer-gesichert).';
    } else {
      icon = Icons.verified_outlined;
      color = AppColors.success;
      text = 'QR-Code gelesen – IBAN/Referenz/Betrag stimmen mit der '
          'Texterkennung überein.';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
          ],
        ),
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

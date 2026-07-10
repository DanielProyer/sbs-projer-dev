import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/swiss_qr_bill.dart';
import 'package:sbs_projer_app/data/models/geschaeft_einstellungen.dart';
import 'package:sbs_projer_app/presentation/widgets/swiss_qr_ansicht.dart';

/// Dialog: Swiss-QR aufs Firmenkonto zum Scannen (Betrag editierbar).
class ReinigungQrDialog extends StatefulWidget {
  final GeschaeftEinstellungen firma;
  final String betriebName;
  final DateTime datum;
  final double? initialBetrag;

  const ReinigungQrDialog({
    super.key,
    required this.firma,
    required this.betriebName,
    required this.datum,
    this.initialBetrag,
  });

  @override
  State<ReinigungQrDialog> createState() => _ReinigungQrDialogState();
}

class _ReinigungQrDialogState extends State<ReinigungQrDialog> {
  late final TextEditingController _betragCtrl;

  @override
  void initState() {
    super.initState();
    final b = widget.initialBetrag;
    _betragCtrl = TextEditingController(
        text: (b != null && b > 0) ? b.toStringAsFixed(2) : '');
  }

  @override
  void dispose() {
    _betragCtrl.dispose();
    super.dispose();
  }

  // "Via Rezia 8" -> ("Via Rezia", "8")
  (String, String) _splitStrasse(String s) {
    final i = s.trimRight().lastIndexOf(' ');
    if (i <= 0) return (s.trim(), '');
    return (s.substring(0, i).trim(), s.substring(i + 1).trim());
  }

  // "7013 Domat/Ems" -> ("7013", "Domat/Ems")
  (String, String) _splitPlzOrt(String s) {
    final i = s.trim().indexOf(' ');
    if (i <= 0) return ('', s.trim());
    return (s.substring(0, i).trim(), s.substring(i + 1).trim());
  }

  @override
  Widget build(BuildContext context) {
    final iban = (widget.firma.firmenIban ?? '').replaceAll(' ', '');
    final betrag = double.tryParse(_betragCtrl.text.replaceAll(',', '.'));
    final (strasse, nr) = _splitStrasse(widget.firma.adresseStrasse);
    final (plz, ort) = _splitPlzOrt(widget.firma.adressePlzOrt);
    final datumStr =
        '${widget.datum.day.toString().padLeft(2, '0')}.${widget.datum.month.toString().padLeft(2, '0')}.${widget.datum.year}';

    final payload = iban.isEmpty
        ? null
        : swissQrPayload(
            iban: iban,
            creditorName: widget.firma.firma,
            creditorStreet: strasse,
            creditorNr: nr,
            creditorPlz: plz,
            creditorOrt: ort,
            betrag: betrag,
            mitteilung: 'Reinigung · ${widget.betriebName} · $datumStr',
          );

    return AlertDialog(
      title: const Text('QR-Zahlung'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iban.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Keine Firmen-IBAN hinterlegt.\nBitte in den Einstellungen eintragen.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.error),
                ),
              )
            else ...[
              SwissQrAnsicht(payload: payload!),
              const SizedBox(height: 12),
              TextField(
                controller: _betragCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Betrag (CHF, leer = offen)',
                  isDense: true,
                  prefixIcon: Icon(Icons.payments_outlined, size: 18),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${widget.firma.firma}\n${widget.firma.firmenIban}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Schliessen')),
      ],
    );
  }
}

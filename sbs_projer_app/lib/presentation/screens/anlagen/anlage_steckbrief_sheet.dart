import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/config/mail_config.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/services/mail/bericht_mail_service.dart';

/// Bottom-Sheet: Steckbrief-PDF an den RSL senden (Adresse vorausgefüllt + editierbar).
class AnlageSteckbriefSheet extends StatefulWidget {
  final String betriebName;
  final String anlageBezeichnung;
  final String? rslMail; // aus Heineken-Zuweisung 'rsl'
  final String betreff;
  final String dateiname;
  final Uint8List pdf;

  const AnlageSteckbriefSheet({
    super.key,
    required this.betriebName,
    required this.anlageBezeichnung,
    required this.rslMail,
    required this.betreff,
    required this.dateiname,
    required this.pdf,
  });

  @override
  State<AnlageSteckbriefSheet> createState() => _AnlageSteckbriefSheetState();
}

class _AnlageSteckbriefSheetState extends State<AnlageSteckbriefSheet> {
  late final _mailController = TextEditingController(text: widget.rslMail ?? '');
  bool _sending = false;

  bool get _scharf => MailConfig.istScharf('anlage');

  @override
  void dispose() {
    _mailController.dispose();
    super.dispose();
  }

  Future<void> _senden() async {
    final ziel = MailConfig.bereinige(_mailController.text);
    if (_scharf && !ziel.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte eine gültige RSL-Adresse eingeben.')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      final to = _scharf ? ziel : MailConfig.testEmpfaenger;
      await BerichtMailService.send(
        to: to,
        subject: widget.betreff,
        bodyText: 'Guten Tag\n\n'
            'Im Anhang der Anlagen-Steckbrief zu «${widget.betriebName}» '
            '(${widget.anlageBezeichnung}).\n\n'
            'Freundliche Grüsse\nSBS Projer GmbH',
        filename: widget.dateiname,
        pdf: widget.pdf,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_scharf
              ? 'Steckbrief an RSL gesendet'
              : 'Steckbrief gesendet (Testmodus → an dich)')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Senden: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Steckbrief an RSL senden',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('${widget.betriebName} — ${widget.anlageBezeichnung}',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          if (!_scharf)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AppColors.surface, borderRadius: BorderRadius.circular(6)),
              child: Text('Testmodus – Versand geht an dich (${MailConfig.testEmpfaenger}).',
                  style: const TextStyle(fontSize: 12)),
            ),
          if (widget.rslMail == null || widget.rslMail!.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Kein RSL hinterlegt — in „Heineken-Zuweisungen" festlegen oder unten eintragen.',
                  style: TextStyle(fontSize: 12, color: AppColors.error)),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _mailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'RSL E-Mail',
              isDense: true,
              prefixIcon: Icon(Icons.alternate_email, size: 18),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _sending ? null : _senden,
              icon: _sending
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
              label: Text(_sending ? 'Sende …' : 'Senden'),
            ),
          ),
        ],
      ),
    );
  }
}

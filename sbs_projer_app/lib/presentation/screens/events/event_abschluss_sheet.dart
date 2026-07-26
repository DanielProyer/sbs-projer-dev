import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/config/mail_config.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/event_mail_empfaenger.dart';
import 'package:sbs_projer_app/data/models/event_kontakt.dart';
import 'package:sbs_projer_app/services/mail/bericht_mail_service.dart';
import 'package:sbs_projer_app/services/pdf/pdf_tab_oeffner_export.dart';

/// Bottom-Sheet zum Versand der Abschluss-Mail: Empfänger wählen + senden.
class EventAbschlussSheet extends StatefulWidget {
  final String eventName; // Betriebsname ohne Jahr
  final int jahr;
  final List<EmpfaengerVorschlag> vorschlaege; // Eventverantwortlicher + RSL
  final List<({String name, String email})> weitereKontakte; // andere mit E-Mail
  final Uint8List pdf;

  const EventAbschlussSheet({
    super.key,
    required this.eventName,
    required this.jahr,
    required this.vorschlaege,
    required this.weitereKontakte,
    required this.pdf,
  });

  @override
  State<EventAbschlussSheet> createState() => _EventAbschlussSheetState();
}

class _EventAbschlussSheetState extends State<EventAbschlussSheet> {
  final _gewaehlt = <String>{}; // ausgewählte E-Mails
  final _manuell = <String>[];
  final _mailController = TextEditingController();
  bool _sending = false;

  bool get _scharf => MailConfig.istScharf('event');

  @override
  void initState() {
    super.initState();
    for (final v in widget.vorschlaege) {
      if (v.email != null && v.email!.trim().isNotEmpty) _gewaehlt.add(v.email!.trim());
    }
  }

  @override
  void dispose() {
    _mailController.dispose();
    super.dispose();
  }

  void _manuellHinzufuegen() {
    final e = _mailController.text.trim();
    if (e.contains('@')) {
      setState(() {
        _manuell.add(e);
        _gewaehlt.add(e);
        _mailController.clear();
      });
    }
  }

  Future<void> _vorschau() async {
    // Neuer Tab statt Druckdialog (Regel Daniel 26.07.2026).
    await oeffnePdfImNeuenTab(
        widget.pdf, abschlussDateiname(widget.eventName, widget.jahr));
  }

  Future<void> _senden() async {
    final adressen = _gewaehlt.map(MailConfig.bereinige).where((e) => e.contains('@')).toList();
    if (adressen.isEmpty && _scharf) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte mindestens einen Empfänger wählen.')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      final to = _scharf ? adressen.join(', ') : MailConfig.testEmpfaenger;
      await BerichtMailService.send(
        to: to,
        subject: abschlussBetreff(widget.eventName, widget.jahr),
        bodyText: 'Guten Tag\n\n'
            'Im Anhang der Abschlussbericht zum Event «${widget.eventName}».\n\n'
            'Freundliche Grüsse\nSBS Projer GmbH',
        filename: abschlussDateiname(widget.eventName, widget.jahr),
        pdf: widget.pdf,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_scharf
              ? 'Abschlussbericht gesendet'
              : 'Abschlussbericht gesendet (Testmodus → an dich)')),
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

  Widget _checkbox(String label, String? email, {String? subtitle}) {
    final hasMail = email != null && email.trim().isNotEmpty;
    return CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      value: hasMail && _gewaehlt.contains(email.trim()),
      onChanged: hasMail
          ? (v) => setState(() {
                if (v == true) {
                  _gewaehlt.add(email.trim());
                } else {
                  _gewaehlt.remove(email.trim());
                }
              })
          : null,
      title: Text(label, style: TextStyle(color: hasMail ? null : AppColors.textSecondary)),
      subtitle: Text(hasMail ? email.trim() : (subtitle ?? 'keine E-Mail'),
          style: const TextStyle(fontSize: 12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Abschluss-Mail senden',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('PDF-Bericht zu «${widget.eventName} ${widget.jahr}»',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            if (!_scharf)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Testmodus – Versand geht an dich (${MailConfig.testEmpfaenger}).',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            const SizedBox(height: 8),
            if (widget.vorschlaege.isNotEmpty) ...[
              const Text('Vorgeschlagen', style: TextStyle(fontWeight: FontWeight.w600)),
              ...widget.vorschlaege.map((v) =>
                  _checkbox('${v.name} (${EventKontakt.rolleLabel(v.rolle)})', v.email)),
            ],
            if (widget.weitereKontakte.isNotEmpty) ...[
              const SizedBox(height: 4),
              const Text('Weitere Kontakte', style: TextStyle(fontWeight: FontWeight.w600)),
              ...widget.weitereKontakte.map((k) => _checkbox(k.name, k.email)),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Weitere E-Mail',
                      isDense: true,
                      prefixIcon: Icon(Icons.alternate_email, size: 18),
                    ),
                    onSubmitted: (_) => _manuellHinzufuegen(),
                  ),
                ),
                TextButton(onPressed: _manuellHinzufuegen, child: const Text('Hinzufügen')),
              ],
            ),
            if (_manuell.isNotEmpty)
              Wrap(
                spacing: 6,
                children: _manuell
                    .map((e) => Chip(
                          label: Text(e, style: const TextStyle(fontSize: 12)),
                          onDeleted: () => setState(() {
                            _manuell.remove(e);
                            _gewaehlt.remove(e);
                          }),
                        ))
                    .toList(),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _sending ? null : _vorschau,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('PDF-Vorschau'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _sending ? null : _senden,
                icon: _sending
                    ? const SizedBox(
                        height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
                label: Text(_sending ? 'Sende …' : 'Senden'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/config/mail_config.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/models/rechnungs_position.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/data/repositories/kontakt_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnungs_position_repository.dart';
import 'package:sbs_projer_app/presentation/providers/buchung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/heineken_providers.dart';
import 'package:sbs_projer_app/services/buchhaltung/heineken_buchung_service.dart';
import 'package:sbs_projer_app/services/rechnung/heineken_rechnung_service.dart';
import 'package:sbs_projer_app/services/pdf/rechnung_pdf_storage.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';
import 'package:url_launcher/url_launcher.dart';

class HeinekenRechnungDetailScreen extends ConsumerStatefulWidget {
  final String rechnungId;
  const HeinekenRechnungDetailScreen({super.key, required this.rechnungId});

  @override
  ConsumerState<HeinekenRechnungDetailScreen> createState() =>
      _HeinekenRechnungDetailScreenState();
}

class _HeinekenRechnungDetailScreenState
    extends ConsumerState<HeinekenRechnungDetailScreen> {
  Rechnung? _rechnung;
  List<RechnungsPosition> _positionen = [];
  bool _loading = true;

  static final _monatFormat = DateFormat('MMMM yyyy', 'de_CH');
  static final _dateFormat = DateFormat('dd.MM.yyyy');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rechnung = await RechnungRepository.getById(widget.rechnungId);
      List<RechnungsPosition> pos = [];
      if (rechnung != null) {
        pos = await RechnungsPositionRepository.getByRechnung(rechnung.id);
      }
      setState(() {
        _rechnung = rechnung;
        _positionen = pos;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _openPdf() async {
    if (_rechnung?.pdfUrl == null) {
      // PDF neu generieren / URL erneuern
      try {
        final url =
            await RechnungPdfStorage.getSignedUrl(widget.rechnungId);
        await RechnungRepository.update(widget.rechnungId, {'pdf_url': url});
        if (url.isNotEmpty) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('PDF nicht verfügbar: $e')),
          );
        }
      }
      return;
    }
    await launchUrl(Uri.parse(_rechnung!.pdfUrl!),
        mode: LaunchMode.externalApplication);
  }

  Future<void> _sendMail() async {
    if (_rechnung == null) return;
    setState(() => _loading = true);
    try {
      final kontakt =
          await KontaktRepository.getHeinekenZuweisung('monatsrechnung');
      final empfaenger =
          MailConfig.empfaenger(kontakt?.email, bereich: 'heineken');
      debugPrint('[Heineken-Mail] Kontakt: ${kontakt?.email}, Empfänger: $empfaenger');
      final monatLabel = _monatFormat.format(_rechnung!.heinekenMonat!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Heineken-Mail → $empfaenger (Kontakt: ${kontakt?.email ?? "KEIN KONTAKT"})'),
            duration: const Duration(seconds: 6),
          ),
        );
      }

      await SupabaseService.client.functions.invoke('send-rechnung-mail',
          body: {
            'to': empfaenger,
            'subject': 'Monatsrechnung $monatLabel SBS Projer GmbH',
            'bodyText':
                'Hallo${kontakt?.vorname != null ? ' ${kontakt!.vorname}' : ''}\n\n'
                'Im Anhang sende ich Dir die Monatsrechnung für den $monatLabel.\n\n'
                'Gruass Dani',
            'rechnungId': _rechnung!.id,
            'userId': SupabaseService.dataUserId,
          });

      await RechnungRepository.update(widget.rechnungId, {
        'zahlungsstatus': 'gesendet',
        'versendet_am': DateTime.now().toIso8601String().split('T').first,
      });

      ref.invalidate(heinekenRechnungenProvider);
      _load();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mail versendet')),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Mail-Versand fehlgeschlagen: $e',
                style: const TextStyle(color: Colors.white)),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    await RechnungRepository.update(widget.rechnungId, {
      'zahlungsstatus': newStatus,
      if (newStatus == 'bezahlt')
        'zahlung_eingegangen_am':
            DateTime.now().toIso8601String().split('T').first,
    });

    // Buchung (Debitoren/Ertrag) beim Wechsel auf 'freigegeben' erstellen
    if (newStatus == 'freigegeben' && _rechnung != null) {
      try {
        final buchung =
            await HeinekenBuchungService.createFromRechnung(_rechnung!);
        if (buchung != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Buchung erstellt (Debitoren/Ertrag)')),
          );
        }
        ref.invalidate(buchungenStreamProvider);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Buchung fehlgeschlagen: $e')),
          );
        }
      }
    }

    // Zahlungseingang bei Bezahlt erstellen
    if (newStatus == 'bezahlt' && _rechnung != null) {
      try {
        final aktuell = await RechnungRepository.getById(widget.rechnungId);
        if (aktuell != null) {
          final buchung =
              await HeinekenBuchungService.createZahlungseingang(aktuell);
          if (buchung != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Zahlungseingang gebucht')),
            );
          }
          ref.invalidate(buchungenStreamProvider);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Zahlungseingang-Buchung fehlgeschlagen: $e')),
          );
        }
      }
    }

    ref.invalidate(heinekenRechnungenProvider);
    _load();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechnung löschen?'),
        content: const Text(
            'Die Heineken-Rechnung wird unwiderruflich gelöscht.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Löschen', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      // Abgerechnet-Flags für den Monat zurücksetzen
      if (_rechnung != null) {
        try {
          await HeinekenRechnungService.resetAbrechnung(
              _rechnung!.rechnungsdatum);
        } catch (_) {}
      }

      // Zugehörige Buchungen löschen
      try {
        final buchungen =
            await BuchungRepository.getByBeleg(widget.rechnungId);
        for (final b in buchungen) {
          await BuchungRepository.delete(b.id);
        }
        if (buchungen.isNotEmpty) {
          ref.invalidate(buchungenStreamProvider);
        }
      } catch (_) {}

      await RechnungRepository.delete(widget.rechnungId);
      ref.invalidate(heinekenRechnungenProvider);
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Heineken-Rechnung')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final r = _rechnung;
    if (r == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Heineken-Rechnung')),
        body: const Center(child: Text('Rechnung nicht gefunden')),
      );
    }

    final monat = r.heinekenMonat;
    final monatsName = monat != null
        ? _monatFormat.format(monat)
        : 'Unbekannt';

    return Scaffold(
      appBar: AppBar(
        title: Text('Heineken $monatsName'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'offen':
                case 'gesendet':
                case 'freigegeben':
                case 'bezahlt':
                  _updateStatus(value);
                  break;
                case 'delete':
                  _delete();
                  break;
              }
            },
            itemBuilder: (context) => [
              // Status-Flow: offen → gesendet → freigegeben → bezahlt
              if (r.zahlungsstatus == 'gesendet') ...[
                const PopupMenuItem(
                    value: 'freigegeben',
                    child: Text('Als freigegeben markieren')),
                const PopupMenuItem(
                    value: 'offen', child: Text('Auf offen zurücksetzen')),
              ],
              if (r.zahlungsstatus == 'freigegeben') ...[
                const PopupMenuItem(
                    value: 'bezahlt', child: Text('Als bezahlt markieren')),
                const PopupMenuItem(
                    value: 'gesendet',
                    child: Text('Auf gesendet zurücksetzen')),
              ],
              if (r.zahlungsstatus == 'bezahlt')
                const PopupMenuItem(
                    value: 'freigegeben',
                    child: Text('Auf freigegeben zurücksetzen')),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Löschen', style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status-Banner
          _StatusBanner(status: r.zahlungsstatus),
          const SizedBox(height: 16),

          // Info-Karte
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rechnungsperiode $monatsName',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _InfoRow('Datum', _dateFormat.format(r.rechnungsdatum)),
                  _InfoRow('RG Nr.', r.rechnungsnummer ?? '-'),
                  _InfoRow('PO Nummer', r.heinekenPoNummer ?? '-'),
                  _InfoRow('Fällig bis',
                      _dateFormat.format(r.faelligkeitsdatum)),
                  _InfoRow('Status', _statusLabel(r.zahlungsstatus)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Positionen (Kategorien)
          Text(
            'Positionen',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ..._positionen.map((p) => Card(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(child: Text(p.beschreibung)),
                      Text(
                        '${p.betragNetto.toStringAsFixed(2)} CHF',
                        style:
                            const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              )),

          const SizedBox(height: 8),
          const Divider(),
          _TotalRow(label: 'Total Netto', value: r.betragNetto),
          _TotalRow(label: 'MwSt (8.1%)', value: r.mwstBetrag),
          _TotalRow(
            label: 'Gesamttotal inkl. MwSt',
            value: r.betragBrutto,
            bold: true,
          ),

          const SizedBox(height: 24),

          // PDF Button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _openPdf,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('PDF anzeigen'),
            ),
          ),

          // Mail-Button (nur bei Status offen)
          if (r.zahlungsstatus == 'offen') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _sendMail,
                icon: const Icon(Icons.send),
                label: const Text('Mail an Heineken senden'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'offen': return 'Offen';
      case 'gesendet': return 'Gesendet';
      case 'freigegeben': return 'Freigegeben';
      case 'bezahlt': return 'Bezahlt';
      case 'erinnert': return 'Erinnert';
      case 'mahnung_1': return 'Mahnung 1';
      case 'mahnung_2': return 'Mahnung 2';
      case 'abgeschrieben': return 'Abgeschrieben';
      default: return status;
    }
  }
}

class _StatusBanner extends StatelessWidget {
  final String status;
  const _StatusBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String text;
    switch (status) {
      case 'bezahlt':
        color = AppColors.success;
        icon = Icons.check_circle;
        text = 'Bezahlt';
        break;
      case 'gesendet':
        color = AppColors.info;
        icon = Icons.send;
        text = 'Gesendet';
        break;
      case 'freigegeben':
        color = AppColors.primary;
        icon = Icons.task_alt;
        text = 'Freigegeben';
        break;
      case 'erinnert':
        color = const Color(0xFFE65100);
        icon = Icons.notifications;
        text = 'Erinnert';
        break;
      case 'mahnung_1':
        color = AppColors.error;
        icon = Icons.warning;
        text = 'Mahnung 1';
        break;
      case 'mahnung_2':
        color = const Color(0xFF8B0000);
        icon = Icons.gavel;
        text = 'Mahnung 2';
        break;
      case 'abgeschrieben':
        color = AppColors.inaktiv;
        icon = Icons.block;
        text = 'Abgeschrieben';
        break;
      default:
        color = AppColors.warning;
        icon = Icons.hourglass_empty;
        text = 'Offen';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(text,
              style: TextStyle(color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(color: AppColors.textSecondary)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double value;
  final bool bold;

  const _TotalRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: bold ? 16 : 14,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('${value.toStringAsFixed(2)} CHF', style: style),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/models/rechnungs_position.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnungs_position_repository.dart';
import 'package:sbs_projer_app/presentation/providers/heineken_providers.dart';
import 'package:sbs_projer_app/services/pdf/rechnung_pdf_storage.dart';
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

  Future<void> _updateStatus(String newStatus) async {
    await RechnungRepository.update(widget.rechnungId, {
      'zahlungsstatus': newStatus,
      if (newStatus == 'bezahlt')
        'zahlung_eingegangen_am':
            DateTime.now().toIso8601String().split('T').first,
    });
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
                case 'versendet':
                case 'bezahlt':
                  _updateStatus(value);
                  break;
                case 'delete':
                  _delete();
                  break;
              }
            },
            itemBuilder: (context) => [
              if (r.zahlungsstatus != 'versendet')
                const PopupMenuItem(
                    value: 'versendet', child: Text('Als versendet markieren')),
              if (r.zahlungsstatus != 'bezahlt')
                const PopupMenuItem(
                    value: 'bezahlt', child: Text('Als bezahlt markieren')),
              if (r.zahlungsstatus == 'versendet' ||
                  r.zahlungsstatus == 'bezahlt')
                const PopupMenuItem(
                    value: 'offen', child: Text('Auf offen zurücksetzen')),
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
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'entwurf': return 'Entwurf';
      case 'offen': return 'Offen';
      case 'versendet': return 'Versendet';
      case 'bezahlt': return 'Bezahlt';
      case 'ueberfaellig': return 'Überfällig';
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
      case 'versendet':
        color = AppColors.info;
        icon = Icons.send;
        text = 'Versendet — warte auf Zahlung';
        break;
      case 'ueberfaellig':
        color = AppColors.error;
        icon = Icons.warning;
        text = 'Überfällig';
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

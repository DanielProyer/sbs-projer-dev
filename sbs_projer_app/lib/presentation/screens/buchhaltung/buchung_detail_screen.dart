import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/presentation/providers/buchung_providers.dart';

class BuchungDetailScreen extends ConsumerStatefulWidget {
  final String buchungId;

  const BuchungDetailScreen({super.key, required this.buchungId});

  @override
  ConsumerState<BuchungDetailScreen> createState() =>
      _BuchungDetailScreenState();
}

class _BuchungDetailScreenState extends ConsumerState<BuchungDetailScreen> {
  Buchung? _buchung;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final b = await BuchungRepository.getById(widget.buchungId);
    if (mounted) setState(() { _buchung = b; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Buchung')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final b = _buchung;
    if (b == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Buchung')),
        body: const Center(child: Text('Buchung nicht gefunden')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(b.belegnummer ?? 'Buchung'),
        actions: [
          if (!b.istStorniert)
            IconButton(
              icon: const Icon(Icons.cancel_outlined),
              tooltip: 'Stornieren',
              onPressed: () => _stornieren(b),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (b.istStorniert)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cancel, color: AppColors.error, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Diese Buchung wurde storniert',
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          // Beträge
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _DetailRow('Betrag Netto', '${b.betragNetto.toStringAsFixed(2)} CHF'),
                  if (b.mwstSatz > 0) ...[
                    _DetailRow('MwSt (${b.mwstSatz.toStringAsFixed(1)}%)', '${b.mwstBetrag.toStringAsFixed(2)} CHF'),
                  ],
                  const Divider(),
                  _DetailRow(
                    'Betrag Brutto',
                    '${b.betragBrutto.toStringAsFixed(2)} CHF',
                    bold: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Konten
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Konten',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  _DetailRow('Soll', b.sollKonto.toString()),
                  _DetailRow('Haben', b.habenKonto.toString()),
                  if (b.mwstKonto != null)
                    _DetailRow('MwSt-Konto', b.mwstKonto.toString()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Details
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Details',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  _DetailRow('Datum', _formatDate(b.datum)),
                  _DetailRow('Beschreibung', b.beschreibung),
                  if (b.belegnummer != null)
                    _DetailRow('Belegnummer', b.belegnummer!),
                  if (b.zahlungsweg != null)
                    _DetailRow('Zahlungsweg', b.zahlungsweg!),
                  if (b.belegordner != null)
                    _DetailRow('Belegordner', b.belegordner!),
                  if (b.belegTyp != null) _DetailRow('Beleg-Typ', b.belegTyp!),
                  _DetailRow('Geschäftsjahr', b.geschaeftsjahr.toString()),
                  if (b.monat != null)
                    _DetailRow('Monat', b.monat.toString()),
                  if (b.quartal != null)
                    _DetailRow('Quartal', 'Q${b.quartal}'),
                  if (b.notizen != null && b.notizen!.isNotEmpty)
                    _DetailRow('Notizen', b.notizen!),
                ],
              ),
            ),
          ),

          // Verknüpfter Beleg
          if (b.belegId != null) ...[
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.link, color: AppColors.info),
                title: const Text('Verknüpfter Beleg'),
                subtitle: Text(b.belegTyp ?? 'Beleg'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  if (b.belegTyp == 'rechnung') {
                    context.push('/rechnungen/${b.belegId}');
                  }
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _stornieren(Buchung b) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buchung stornieren?'),
        content: Text(
          'Die Buchung "${b.beschreibung}" über ${b.betragBrutto.toStringAsFixed(2)} CHF wird storniert. '
          'Es wird eine Gegenbuchung erstellt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Stornieren'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await BuchungRepository.stornieren(b.id);
        ref.invalidate(buchungenStreamProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Buchung storniert')),
          );
          _load(); // Reload
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler: $e')),
          );
        }
      }
    }
  }

  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _DetailRow(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

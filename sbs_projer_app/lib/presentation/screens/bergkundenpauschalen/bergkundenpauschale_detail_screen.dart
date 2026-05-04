import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/local/bergkundenpauschale_local_export.dart';
import 'package:sbs_projer_app/data/repositories/bergkundenpauschale_repository.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/presentation/providers/bergkundenpauschale_providers.dart';

class BergkundenpauschaleDetailScreen extends ConsumerStatefulWidget {
  final String pauschaleId;

  const BergkundenpauschaleDetailScreen(
      {super.key, required this.pauschaleId});

  @override
  ConsumerState<BergkundenpauschaleDetailScreen> createState() =>
      _BergkundenpauschaleDetailScreenState();
}

class _BergkundenpauschaleDetailScreenState
    extends ConsumerState<BergkundenpauschaleDetailScreen> {
  BergkundenpauschaleLocal? _pauschale;
  String? _betriebName;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await BergkundenpauschaleRepository.getById(widget.pauschaleId);
    String? betriebName;
    if (p != null) {
      final betrieb = await BetriebRepository.getByServerId(p.betriebId);
      betriebName = betrieb?.name;
    }
    if (mounted) {
      setState(() {
        _pauschale = p;
        _betriebName = betriebName;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final p = _pauschale;
    if (p == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nicht gefunden')),
        body: const Center(child: Text('Pauschale nicht gefunden')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bergkundenpauschale'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Löschen',
            onPressed: () => _delete(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Status',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: p.abgerechnet
                          ? AppColors.success.withAlpha(25)
                          : AppColors.warning.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      p.abgerechnet ? 'Abgerechnet' : 'Offen',
                      style: TextStyle(
                        color:
                            p.abgerechnet ? AppColors.success : AppColors.warning,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
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
                children: [
                  _InfoRow('Betrieb', _betriebName ?? 'Unbekannt'),
                  const Divider(height: 16),
                  _InfoRow('Datum', _formatDate(p.datum)),
                  const Divider(height: 16),
                  _InfoRow('Betrag', '${p.betrag.toStringAsFixed(2)} CHF'),
                  if (p.notizen != null && p.notizen!.isNotEmpty) ...[
                    const Divider(height: 16),
                    _InfoRow('Notizen', p.notizen!),
                  ],
                  if (p.abrechnungsMonat != null) ...[
                    const Divider(height: 16),
                    _InfoRow('Abrechnungsmonat',
                        '${p.abrechnungsMonat!.month.toString().padLeft(2, '0')}/${p.abrechnungsMonat!.year}'),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Verknüpfung
          if (p.reinigungId != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.cleaning_services),
                title: const Text('Verknüpfte Reinigung'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    context.push('/reinigungen/${p.reinigungId}'),
              ),
            ),

          if (_betriebName != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.store),
                title: Text(_betriebName!),
                subtitle: const Text('Zum Betrieb'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    context.push('/betriebe/${p.betriebId}'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pauschale löschen?'),
        content:
            const Text('Soll diese Bergkundenpauschale wirklich gelöscht werden?'),
        actions: [
          TextButton(
              onPressed: () => ctx.pop(false), child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => ctx.pop(true), child: const Text('Löschen')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await BergkundenpauschaleRepository.delete(widget.pauschaleId);
      ref.invalidate(bergkundenpauschaleStreamProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500)),
        const SizedBox(width: 16),
        Flexible(
          child: Text(value, textAlign: TextAlign.end),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/presentation/providers/rechnung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';

class RechnungenListScreen extends ConsumerStatefulWidget {
  const RechnungenListScreen({super.key});

  @override
  ConsumerState<RechnungenListScreen> createState() =>
      _RechnungenListScreenState();
}

class _RechnungenListScreenState extends ConsumerState<RechnungenListScreen> {
  String _searchQuery = '';
  String _statusFilter = 'alle';

  @override
  Widget build(BuildContext context) {
    final rechnungen = ref.watch(rechnungenProvider);
    final betriebe = ref.watch(betriebeProvider);

    // Betrieb-Name Lookup
    final betriebNames = <String, String>{};
    for (final b in betriebe) {
      if (b.serverId != null) {
        betriebNames[b.serverId!] = b.name;
      }
    }

    // Filter
    final filtered = rechnungen.where((r) {
      if (_statusFilter != 'alle' && r.zahlungsstatus != _statusFilter) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final betriebName =
            (r.betriebId != null ? betriebNames[r.betriebId] : null)
                    ?.toLowerCase() ??
                '';
        return betriebName.contains(query) ||
            (r.rechnungsnummer?.toLowerCase().contains(query) ?? false);
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rechnungen'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter',
            onSelected: (value) => setState(() => _statusFilter = value),
            itemBuilder: (context) => [
              _filterItem('alle', 'Alle'),
              _filterItem('offen', 'Offen'),
              _filterItem('bezahlt', 'Bezahlt'),
              _filterItem('ueberfaellig', 'Überfällig'),
              _filterItem('storniert', 'Storniert'),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              hintText: 'Rechnung suchen...',
              leading: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.search, size: 20),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          if (_statusFilter != 'alle')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Chip(
                    label: Text(_statusFilter == 'ueberfaellig'
                        ? 'Überfällig'
                        : _statusFilter),
                    onDeleted: () =>
                        setState(() => _statusFilter = 'alle'),
                    deleteIcon: const Icon(Icons.close, size: 16),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${filtered.length} Rechnungen',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? _buildEmpty()
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final rechnung = filtered[index];
                      return _RechnungListItem(
                        rechnung: rechnung,
                        betriebName: rechnung.betriebId != null
                            ? betriebNames[rechnung.betriebId]
                            : null,
                        onTap: () =>
                            context.push('/rechnungen/${rechnung.id}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _filterItem(String value, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (_statusFilter == value)
            const Icon(Icons.check, size: 18)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long,
              size: 64, color: AppColors.textSecondary.withAlpha(100)),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'Keine Ergebnisse'
                : 'Noch keine Rechnungen',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Versuche einen anderen Suchbegriff'
                : 'Rechnungen werden automatisch bei Reinigungsabschluss erstellt',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _RechnungListItem extends StatelessWidget {
  final Rechnung rechnung;
  final String? betriebName;
  final VoidCallback onTap;

  const _RechnungListItem({
    required this.rechnung,
    this.betriebName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _statusColor.withAlpha(25),
          child: Icon(Icons.receipt_long, color: _statusColor, size: 20),
        ),
        title: Text(
          rechnung.rechnungsnummer ?? 'Entwurf',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(_buildSubtitle()),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatusChip(status: rechnung.zahlungsstatus),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  String _buildSubtitle() {
    final parts = <String>[];
    if (betriebName != null) parts.add(betriebName!);
    parts.add(_formatDate(rechnung.rechnungsdatum));
    final brutto = (rechnung.betragBrutto * 20).roundToDouble() / 20;
    parts.add('CHF ${brutto.toStringAsFixed(2)}');
    return parts.join(' · ');
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  Color get _statusColor {
    switch (rechnung.zahlungsstatus) {
      case 'offen':
        return AppColors.warning;
      case 'bezahlt':
        return AppColors.success;
      case 'ueberfaellig':
        return AppColors.error;
      case 'storniert':
        return AppColors.inaktiv;
      case 'teilbezahlt':
        return AppColors.info;
      default:
        return AppColors.textSecondary;
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: _color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  String get _label {
    switch (status) {
      case 'offen':
        return 'Offen';
      case 'bezahlt':
        return 'Bezahlt';
      case 'ueberfaellig':
        return 'Überfällig';
      case 'storniert':
        return 'Storniert';
      case 'teilbezahlt':
        return 'Teilbezahlt';
      case 'entwurf':
        return 'Entwurf';
      default:
        return status;
    }
  }

  Color get _color {
    switch (status) {
      case 'offen':
        return AppColors.warning;
      case 'bezahlt':
        return AppColors.success;
      case 'ueberfaellig':
        return AppColors.error;
      case 'storniert':
        return AppColors.inaktiv;
      case 'teilbezahlt':
        return AppColors.info;
      default:
        return AppColors.textSecondary;
    }
  }
}

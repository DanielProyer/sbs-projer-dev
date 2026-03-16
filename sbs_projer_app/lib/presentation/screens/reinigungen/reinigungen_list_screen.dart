import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/presentation/providers/reinigung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';

class ReinigungenListScreen extends ConsumerStatefulWidget {
  const ReinigungenListScreen({super.key});

  @override
  ConsumerState<ReinigungenListScreen> createState() =>
      _ReinigungenListScreenState();
}

class _ReinigungenListScreenState
    extends ConsumerState<ReinigungenListScreen> {
  String _searchQuery = '';
  String _statusFilter = 'alle';

  @override
  Widget build(BuildContext context) {
    final reinigungen = ref.watch(reinigungenProvider);
    final betriebe = ref.watch(betriebeProvider);

    // Betrieb-Name Lookup
    final betriebNames = <String, String>{};
    for (final b in betriebe) {
      if (b.serverId != null) {
        betriebNames[b.serverId!] = b.name;
      }
    }

    // Sortieren nach Datum (neueste zuerst)
    final sorted = List<ReinigungLocal>.from(reinigungen)
      ..sort((a, b) => b.datum.compareTo(a.datum));

    // Filter
    final filtered = sorted.where((r) {
      if (_statusFilter != 'alle' && r.status != _statusFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final betriebName = betriebNames[r.betriebId]?.toLowerCase() ?? '';
        return betriebName.contains(query) ||
            (r.notizen?.toLowerCase().contains(query) ?? false);
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reinigungen'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter',
            onSelected: (value) => setState(() => _statusFilter = value),
            itemBuilder: (context) => [
              _filterItem('alle', 'Alle'),
              _filterItem('offen', 'Offen'),
              _filterItem('abgeschlossen', 'Abgeschlossen'),
              _filterItem('abgebrochen', 'Abgebrochen'),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              hintText: 'Reinigung suchen...',
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
                    label: Text(_statusFilter),
                    onDeleted: () =>
                        setState(() => _statusFilter = 'alle'),
                    deleteIcon: const Icon(Icons.close, size: 16),
                  ),
                ],
              ),
            ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${filtered.length} Reinigungen',
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
                      final reinigung = filtered[index];
                      return _ReinigungListItem(
                        reinigung: reinigung,
                        betriebName: betriebNames[reinigung.betriebId],
                        onTap: () =>
                            context.push('/reinigungen/${reinigung.routeId}'),
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
          Icon(Icons.cleaning_services,
              size: 64, color: AppColors.textSecondary.withAlpha(100)),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'Keine Ergebnisse'
                : 'Noch keine Reinigungen',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Versuche einen anderen Suchbegriff'
                : 'Starte eine Reinigung über die Anlage-Detailseite',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _ReinigungListItem extends StatelessWidget {
  final ReinigungLocal reinigung;
  final String? betriebName;
  final VoidCallback onTap;

  const _ReinigungListItem({
    required this.reinigung,
    this.betriebName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _statusColor.withAlpha(25),
          child:
              Icon(Icons.cleaning_services, color: _statusColor, size: 20),
        ),
        title: Text(
          betriebName ?? 'Unbekannter Betrieb',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(_buildSubtitle()),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!reinigung.isSynced)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.cloud_upload_outlined,
                  size: 16,
                  color: AppColors.warning,
                ),
              ),
            if (reinigung.status == 'abgeschlossen')
              const Icon(Icons.check_circle,
                  size: 16, color: AppColors.success),
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
    parts.add(_formatDate(reinigung.datum));
    if (reinigung.uhrzeitStart != null) {
      parts.add(reinigung.uhrzeitStart!);
    }
    final checked = _checkedCount;
    parts.add('$checked/16 Punkte');
    if (reinigung.preisBrutto != null) {
      final brutto = (reinigung.preisBrutto! * 20).roundToDouble() / 20;
      parts.add('${brutto.toStringAsFixed(2)} CHF');
    }
    return parts.join(' · ');
  }

  int get _checkedCount {
    var count = 0;
    if (reinigung.begleitkuehlungKontrolliert) count++;
    if (reinigung.installationAllgemeinKontrolliert) count++;
    if (reinigung.aligalAnschluesseKontrolliert) count++;
    if (reinigung.durchlaufkuehlerAusgeblasen) count++;
    if (reinigung.wasserstandKontrolliert) count++;
    if (reinigung.wasserGewechselt) count++;
    if (reinigung.leitungWasserVorgespuelt) count++;
    if (reinigung.leitungsreinigungReinigungsmittel) count++;
    if (reinigung.foerderdruckKontrolliert) count++;
    if (reinigung.zapfhahnZerlegtGereinigt) count++;
    if (reinigung.zapfkopfZerlegtGereinigt) count++;
    if (reinigung.servicekarteAusgefuellt) count++;
    if (reinigung.hatDurchlaufkuehler) count++;
    if (reinigung.hatBuffetanstich) count++;
    if (reinigung.hatKuehlkeller) count++;
    if (reinigung.hatFasskuehler) count++;
    return count;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  Color get _statusColor {
    switch (reinigung.status) {
      case 'offen':
        return AppColors.warning;
      case 'abgeschlossen':
        return AppColors.success;
      case 'abgebrochen':
        return AppColors.inaktiv;
      default:
        return AppColors.textSecondary;
    }
  }
}

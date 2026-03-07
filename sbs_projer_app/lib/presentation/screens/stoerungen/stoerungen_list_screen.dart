import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/local/stoerung_local.dart';
import 'package:sbs_projer_app/presentation/providers/stoerung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';

class StoerungenListScreen extends ConsumerStatefulWidget {
  const StoerungenListScreen({super.key});

  @override
  ConsumerState<StoerungenListScreen> createState() =>
      _StoerungenListScreenState();
}

class _StoerungenListScreenState
    extends ConsumerState<StoerungenListScreen> {
  String _searchQuery = '';
  String _statusFilter = 'alle';

  @override
  Widget build(BuildContext context) {
    final stoerungen = ref.watch(stoerungenProvider);
    final betriebe = ref.watch(betriebeProvider);

    // Betrieb-Name Lookup
    final betriebNames = <String, String>{};
    for (final b in betriebe) {
      if (b.serverId != null) {
        betriebNames[b.serverId!] = b.name;
      }
    }

    // Sortieren nach Datum (neueste zuerst)
    final sorted = List<StoerungLocal>.from(stoerungen)
      ..sort((a, b) => b.datum.compareTo(a.datum));

    // Filter
    final filtered = sorted.where((s) {
      if (_statusFilter != 'alle' && s.status != _statusFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final betriebName = betriebNames[s.betriebId]?.toLowerCase() ?? '';
        return betriebName.contains(query) ||
            s.stoerungsnummer.toLowerCase().contains(query) ||
            s.problemBeschreibung.toLowerCase().contains(query) ||
            (s.notizen?.toLowerCase().contains(query) ?? false);
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Störungen'),
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
              hintText: 'Störung suchen...',
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
                '${filtered.length} Störungen',
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
                      final stoerung = filtered[index];
                      return _StoerungListItem(
                        stoerung: stoerung,
                        betriebName: betriebNames[stoerung.betriebId],
                        onTap: () =>
                            context.push('/stoerungen/${stoerung.id}'),
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
          Icon(Icons.warning_amber,
              size: 64, color: AppColors.textSecondary.withAlpha(100)),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'Keine Ergebnisse'
                : 'Noch keine Störungen',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Versuche einen anderen Suchbegriff'
                : 'Erfasse eine Störung über die Anlage-Detailseite',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _StoerungListItem extends StatelessWidget {
  final StoerungLocal stoerung;
  final String? betriebName;
  final VoidCallback onTap;

  const _StoerungListItem({
    required this.stoerung,
    this.betriebName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _statusColor.withAlpha(25),
          child: Icon(Icons.warning_amber, color: _statusColor, size: 20),
        ),
        title: Text(
          stoerung.stoerungsnummer,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(_buildSubtitle()),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!stoerung.isSynced)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.cloud_upload_outlined,
                  size: 16,
                  color: AppColors.warning,
                ),
              ),
            if (stoerung.status == 'abgeschlossen')
              const Icon(Icons.check_circle,
                  size: 16, color: AppColors.success),
            if (stoerung.istPikettEinsatz)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.nightlight_round,
                    size: 16, color: AppColors.info),
              ),
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
    parts.add(_formatDate(stoerung.datum));
    if (stoerung.stoerungBereich != null) {
      parts.add('Bereich ${stoerung.stoerungBereich}');
    }
    if (stoerung.preisBrutto != null) {
      parts.add('${stoerung.preisBrutto!.toStringAsFixed(2)} CHF');
    }
    return parts.join(' · ');
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  Color get _statusColor {
    switch (stoerung.status) {
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

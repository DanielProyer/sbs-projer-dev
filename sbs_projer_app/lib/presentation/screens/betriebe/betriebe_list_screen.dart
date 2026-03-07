import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/local/betrieb_local.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';

class BetriebeListScreen extends ConsumerStatefulWidget {
  const BetriebeListScreen({super.key});

  @override
  ConsumerState<BetriebeListScreen> createState() => _BetriebeListScreenState();
}

class _BetriebeListScreenState extends ConsumerState<BetriebeListScreen> {
  String _searchQuery = '';
  String _statusFilter = 'alle';

  @override
  Widget build(BuildContext context) {
    final betriebe = ref.watch(betriebeProvider);

    // Filter anwenden
    final filtered = betriebe.where((b) {
      if (_statusFilter != 'alle' && b.status != _statusFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return b.name.toLowerCase().contains(query) ||
            (b.ort?.toLowerCase().contains(query) ?? false) ||
            (b.heinekenNr?.toLowerCase().contains(query) ?? false);
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Betriebe'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter',
            onSelected: (value) => setState(() => _statusFilter = value),
            itemBuilder: (context) => [
              _filterItem('alle', 'Alle'),
              _filterItem('aktiv', 'Aktiv'),
              _filterItem('inaktiv', 'Inaktiv'),
              _filterItem('saisonpause', 'Saisonpause'),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Suchleiste
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              hintText: 'Betrieb suchen...',
              leading: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.search, size: 20),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Status-Chips
          if (_statusFilter != 'alle')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Chip(
                    label: Text(_statusFilter),
                    onDeleted: () => setState(() => _statusFilter = 'alle'),
                    deleteIcon: const Icon(Icons.close, size: 16),
                  ),
                ],
              ),
            ),

          // Anzahl
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${filtered.length} Betriebe',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ),
          ),

          // Liste
          Expanded(
            child: filtered.isEmpty
                ? _buildEmpty()
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      return _BetriebListItem(
                        betrieb: filtered[index],
                        onTap: () => context.push(
                          '/betriebe/${filtered[index].id}',
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/betriebe/neu'),
        tooltip: 'Neuer Betrieb',
        child: const Icon(Icons.add),
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
          Icon(Icons.store_outlined, size: 64, color: AppColors.textSecondary.withAlpha(100)),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'Keine Ergebnisse' : 'Noch keine Betriebe',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Versuche einen anderen Suchbegriff'
                : 'Erstelle deinen ersten Betrieb mit +',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _BetriebListItem extends StatelessWidget {
  final BetriebLocal betrieb;
  final VoidCallback onTap;

  const _BetriebListItem({required this.betrieb, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _statusColor.withAlpha(25),
          child: Icon(Icons.store, color: _statusColor, size: 20),
        ),
        title: Text(
          betrieb.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: _buildSubtitle(),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!betrieb.isSynced)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.cloud_upload_outlined,
                  size: 16,
                  color: AppColors.warning,
                ),
              ),
            if (betrieb.istBergkunde)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(Icons.terrain, size: 16, color: AppColors.info),
              ),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Widget? _buildSubtitle() {
    final parts = <String>[];
    if (betrieb.ort != null) parts.add(betrieb.ort!);
    if (betrieb.heinekenNr != null) parts.add('H-Nr: ${betrieb.heinekenNr}');
    if (parts.isEmpty) return null;
    return Text(parts.join(' · '));
  }

  Color get _statusColor {
    switch (betrieb.status) {
      case 'aktiv':
        return AppColors.aktiv;
      case 'inaktiv':
        return AppColors.inaktiv;
      case 'saisonpause':
        return AppColors.saisonpause;
      default:
        return AppColors.textSecondary;
    }
  }
}

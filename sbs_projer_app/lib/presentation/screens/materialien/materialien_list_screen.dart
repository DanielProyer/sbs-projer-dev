import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/lager.dart';
import 'package:sbs_projer_app/presentation/providers/material_providers.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class MaterialienListScreen extends ConsumerStatefulWidget {
  const MaterialienListScreen({super.key});

  @override
  ConsumerState<MaterialienListScreen> createState() =>
      _MaterialienListScreenState();
}

class _MaterialienListScreenState
    extends ConsumerState<MaterialienListScreen> {
  String _searchQuery = '';
  String _kategorieFilter = 'alle';
  bool _nurNiedrig = false;

  @override
  Widget build(BuildContext context) {
    final materialien = ref.watch(materialienProvider);
    final kategorienAsync = ref.watch(kategorienProvider);
    final kategorien = kategorienAsync.valueOrNull ?? [];

    // Kategorie-Name Lookup
    final kategorieNames = <String, String>{};
    for (final k in kategorien) {
      kategorieNames[k.id] = k.name;
    }

    // Filter
    final filtered = materialien.where((l) {
      if (_nurNiedrig && l.bestandNiedrig != true) return false;
      if (_kategorieFilter != 'alle' && l.kategorieId != _kategorieFilter) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return l.name.toLowerCase().contains(query) ||
            (l.dboNr?.toLowerCase().contains(query) ?? false) ||
            (l.beschreibung?.toLowerCase().contains(query) ?? false) ||
            (l.notizen?.toLowerCase().contains(query) ?? false) ||
            (l.lieferant?.toLowerCase().contains(query) ?? false);
      }
      return true;
    }).toList()
      ..sort((a, b) {
        final aDbo = a.dboNr ?? '';
        final bDbo = b.dboNr ?? '';
        if (aDbo.isEmpty && bDbo.isEmpty) return a.name.compareTo(b.name);
        if (aDbo.isEmpty) return 1;
        if (bDbo.isEmpty) return -1;
        return aDbo.compareTo(bDbo);
      });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Material'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            tooltip: 'Materialbestellung',
            onPressed: () => context.push('/materialien/bestellen'),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Kategorie',
            onSelected: (value) =>
                setState(() => _kategorieFilter = value),
            itemBuilder: (context) {
              final usedIds = materialien
                  .map((m) => m.kategorieId)
                  .whereType<String>()
                  .toSet();
              final used = kategorien
                  .where((k) => usedIds.contains(k.id))
                  .toList();
              return [
                _filterItem('alle', 'Alle Kategorien'),
                const PopupMenuDivider(),
                ...used.map((k) => _filterItem(k.id, k.name)),
              ];
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              hintText: 'Material suchen...',
              leading: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.search, size: 20),
              ),
              onChanged: (value) =>
                  setState(() => _searchQuery = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Nur niedrig'),
                  selected: _nurNiedrig,
                  onSelected: (v) => setState(() => _nurNiedrig = v),
                ),
                if (_kategorieFilter != 'alle') ...[
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(
                        kategorieNames[_kategorieFilter] ?? 'Kategorie'),
                    onDeleted: () =>
                        setState(() => _kategorieFilter = 'alle'),
                    deleteIcon: const Icon(Icons.close, size: 16),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${filtered.length} Materialien',
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
                      final lager = filtered[index];
                      return _MaterialListItem(
                        lager: lager,
                        kategorieName: lager.kategorieId != null
                            ? kategorieNames[lager.kategorieId]
                            : null,
                        onTap: () =>
                            context.push('/materialien/${lager.id}'),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: SupabaseService.isGuest
          ? null
          : FloatingActionButton(
              onPressed: () => context.push('/materialien/neu'),
              child: const Icon(Icons.add),
            ),
    );
  }

  PopupMenuItem<String> _filterItem(String value, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (_kategorieFilter == value)
            const Icon(Icons.check, size: 18)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2,
              size: 64, color: AppColors.textSecondary.withAlpha(100)),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty || _nurNiedrig
                ? 'Keine Ergebnisse'
                : 'Noch keine Materialien',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _MaterialListItem extends StatelessWidget {
  final Lager lager;
  final String? kategorieName;
  final VoidCallback onTap;

  const _MaterialListItem({
    required this.lager,
    this.kategorieName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isNiedrig = lager.bestandNiedrig == true;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              (isNiedrig ? AppColors.error : AppColors.success).withAlpha(25),
          child: Icon(
            isNiedrig ? Icons.warning : Icons.inventory_2,
            color: isNiedrig ? AppColors.error : AppColors.success,
            size: 20,
          ),
        ),
        title: Text(
          lager.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          _buildSubtitle(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (lager.vorgemerkt)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.bookmark, size: 16, color: Colors.orange),
              ),
            Text(
              '${lager.bestandAktuell.toStringAsFixed(0)}/${lager.bestandOptimal.toStringAsFixed(0)}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isNiedrig ? AppColors.error : AppColors.success,
                fontSize: 13,
              ),
            ),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  String _buildSubtitle() {
    final parts = <String>[];
    if (lager.dboNr != null) parts.add('DBO ${lager.dboNr}');
    if (kategorieName != null) parts.add(kategorieName!);
    return parts.join(' · ');
  }
}

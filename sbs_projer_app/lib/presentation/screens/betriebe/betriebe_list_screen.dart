import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/region_local_export.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

class BetriebeListScreen extends ConsumerStatefulWidget {
  const BetriebeListScreen({super.key});

  @override
  ConsumerState<BetriebeListScreen> createState() => _BetriebeListScreenState();
}

class _BetriebeListScreenState extends ConsumerState<BetriebeListScreen> {
  String _searchQuery = '';
  String _statusFilter = 'aktiv';
  String _kundenFilter = 'meine'; // 'alle', 'meine', 'fremde'
  Set<String> _selectedZapfsysteme = {};
  Set<String> _selectedRegionIds = {};

  @override
  Widget build(BuildContext context) {
    final betriebe = ref.watch(betriebeProvider);
    final regionen = ref.watch(regionenProvider);

    // Filter anwenden
    final filtered = betriebe.where((b) {
      if (_kundenFilter == 'meine' && !b.istMeinKunde) return false;
      if (_kundenFilter == 'fremde' && b.istMeinKunde) return false;
      if (_statusFilter != 'alle' && b.status != _statusFilter) return false;
      if (_selectedZapfsysteme.isNotEmpty &&
          !_selectedZapfsysteme.any((z) => b.zapfsysteme.contains(z))) {
        return false;
      }
      if (_selectedRegionIds.isNotEmpty &&
          (b.regionId == null || !_selectedRegionIds.contains(b.regionId))) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return b.name.toLowerCase().contains(query) ||
            (b.ort?.toLowerCase().contains(query) ?? false) ||
            (b.betriebNr?.toLowerCase().contains(query) ?? false);
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Betriebe'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter',
            onPressed: () => _showFilterSheet(regionen),
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

          // Aktive Filter-Chips
          if (_hasActiveFilters(regionen))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    ..._selectedRegionIds.map((id) {
                      final name = regionen
                          .where((r) => r.serverId == id)
                          .map((r) => r.name)
                          .firstOrNull ?? id;
                      return Chip(
                        label: Text(name),
                        onDeleted: () => setState(() {
                          _selectedRegionIds = {..._selectedRegionIds}..remove(id);
                        }),
                        deleteIcon: const Icon(Icons.close, size: 16),
                      );
                    }),
                  ],
                ),
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
                          '/betriebe/${filtered[index].routeId}',
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

  bool _hasActiveFilters(List<RegionLocal> regionen) {
    return _selectedRegionIds.isNotEmpty;
  }

  void _showFilterSheet(List<RegionLocal> regionen) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _FilterSheet(
        statusFilter: _statusFilter,
        kundenFilter: _kundenFilter,
        selectedZapfsysteme: _selectedZapfsysteme,
        selectedRegionIds: _selectedRegionIds,
        regionen: regionen,
        onApply: (status, kundenFilter, zapfsysteme, regionIds) {
          setState(() {
            _statusFilter = status;
            _kundenFilter = kundenFilter;
            _selectedZapfsysteme = zapfsysteme;
            _selectedRegionIds = regionIds;
          });
        },
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

// ─── Filter BottomSheet ───

class _FilterSheet extends StatefulWidget {
  final String statusFilter;
  final String kundenFilter;
  final Set<String> selectedZapfsysteme;
  final Set<String> selectedRegionIds;
  final List<RegionLocal> regionen;
  final void Function(String status, String kundenFilter, Set<String> zapfsysteme, Set<String> regionIds) onApply;

  const _FilterSheet({
    required this.statusFilter,
    required this.kundenFilter,
    required this.selectedZapfsysteme,
    required this.selectedRegionIds,
    required this.regionen,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String _status;
  late String _kundenFilter;
  late Set<String> _zapfsysteme;
  late Set<String> _regionIds;

  @override
  void initState() {
    super.initState();
    _status = widget.statusFilter;
    _kundenFilter = widget.kundenFilter;
    _zapfsysteme = {...widget.selectedZapfsysteme};
    _regionIds = {...widget.selectedRegionIds};
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withAlpha(50),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Kunden
            Wrap(
              spacing: 8,
              children: [
                _kundenChip('alle', 'Alle Kunden'),
                _kundenChip('meine', 'Meine Kunden'),
                _kundenChip('fremde', 'Fremde Kunden'),
              ],
            ),

            const Divider(height: 12),

            // Status
            Wrap(
              spacing: 8,
              children: [
                _statusChip('alle', 'Alle'),
                _statusChip('aktiv', 'Aktiv'),
                _statusChip('inaktiv', 'Inaktiv'),
              ],
            ),

            const Divider(height: 12),

            // Zapfsysteme
            Text('Zapfsysteme', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: ['David', 'Konventionell', 'Higenie', 'Orion', 'Veranstaltungen'].map((system) {
                final selected = _zapfsysteme.contains(system);
                return FilterChip(
                  label: Text(system),
                  selected: selected,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _zapfsysteme.add(system);
                      } else {
                        _zapfsysteme.remove(system);
                      }
                    });
                  },
                );
              }).toList(),
            ),

            if (widget.regionen.isNotEmpty) ...[
              const Divider(height: 12),

              // Regionen als 2-Spalten Grid
              LayoutBuilder(
                builder: (context, constraints) {
                  final colWidth = constraints.maxWidth / 2;
                  return Wrap(
                    children: widget.regionen.map((r) {
                      final selected = _regionIds.contains(r.serverId);
                      return SizedBox(
                        width: colWidth,
                        height: 32,
                        child: InkWell(
                          onTap: () => setState(() {
                            if (selected) {
                              _regionIds.remove(r.serverId);
                            } else if (r.serverId != null) {
                              _regionIds.add(r.serverId!);
                            }
                          }),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: selected,
                                  onChanged: (v) => setState(() {
                                    if (v == true && r.serverId != null) {
                                      _regionIds.add(r.serverId!);
                                    } else {
                                      _regionIds.remove(r.serverId);
                                    }
                                  }),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  r.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],

            const SizedBox(height: 8),

            // Anwenden
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  widget.onApply(_status, _kundenFilter, _zapfsysteme, _regionIds);
                  Navigator.pop(context);
                },
                child: const Text('Filter anwenden'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String value, String label) {
    final selected = _status == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (s) {
        if (s) setState(() => _status = value);
      },
    );
  }

  Widget _kundenChip(String value, String label) {
    final selected = _kundenFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (s) {
        if (s) setState(() => _kundenFilter = value);
      },
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
    if (betrieb.betriebNr != null) parts.add('Nr: ${betrieb.betriebNr}');
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

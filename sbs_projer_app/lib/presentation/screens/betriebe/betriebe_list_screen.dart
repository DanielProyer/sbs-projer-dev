import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/betrieb_faelligkeit.dart';
import 'package:sbs_projer_app/core/util/google_maps_route.dart';
import 'package:sbs_projer_app/data/local/anlage_local_export.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/region_local_export.dart';
import 'package:sbs_projer_app/presentation/providers/anlage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';
import 'package:sbs_projer_app/presentation/screens/betriebe/betriebe_map.dart';
import 'package:url_launcher/url_launcher.dart';

class BetriebeListScreen extends ConsumerStatefulWidget {
  const BetriebeListScreen({super.key});

  @override
  ConsumerState<BetriebeListScreen> createState() => _BetriebeListScreenState();
}

class _BetriebeListScreenState extends ConsumerState<BetriebeListScreen> {
  String _searchQuery = '';
  String _statusFilter = 'aktiv';
  String _kundenFilter = 'alle'; // 'alle', 'meine', 'fremde'
  Set<String> _selectedZapfsysteme = {};
  Set<String> _selectedRegionIds = {};

  // Karten-Ansicht
  bool _karteAktiv = false;
  bool _karteNurMeine = false;
  bool _karteNurFaellig = false;
  bool _karteZeigeInaktiv = false;
  String? _karteRegionId; // null = alle Regionen

  @override
  Widget build(BuildContext context) {
    final betriebe = ref.watch(betriebeProvider);
    final regionen = ref.watch(regionenProvider);

    // Fälligkeit je Betrieb aus allen Anlagen aggregieren
    final anlagen = ref.watch(anlagenProvider);
    final anlagenNachBetrieb = <String, List<AnlageLocal>>{};
    for (final a in anlagen) {
      (anlagenNachBetrieb[a.betriebId] ??= []).add(a);
    }
    final jetzt = DateTime.now();
    FaelligkeitsStatus statusFuer(BetriebLocal b) {
      // Inaktive/geschlossene Betriebe werden nicht mehr serviciert -> nie fällig.
      if (b.status != 'aktiv') return FaelligkeitsStatus.nichtFaellig;
      final sid = b.serverId;
      final list = sid == null
          ? const <AnlageLocal>[]
          : (anlagenNachBetrieb[sid] ?? const []);
      return betriebFaelligkeit(
        // Nur aktive Anlagen zählen (analog Touren-Logik).
        list
            .where((a) => a.status == 'aktiv')
            .map((a) => getFaelligkeit(a, jetzt, betrieb: b))
            .toList(),
      );
    }

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
          // Umschalter Liste ↔ Karte
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                    value: false,
                    icon: Icon(Icons.list),
                    label: Text('Liste')),
                ButtonSegment(
                    value: true,
                    icon: Icon(Icons.map),
                    label: Text('Karte')),
              ],
              selected: {_karteAktiv},
              onSelectionChanged: (s) =>
                  setState(() => _karteAktiv = s.first),
            ),
          ),

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

          // Liste bzw. Karte
          Expanded(
            child: _karteAktiv
                ? _buildKarte(statusFuer)
                : (filtered.isEmpty
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
                      )),
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

  // ─── Karten-Ansicht ───

  Widget _buildKarte(FaelligkeitsStatus Function(BetriebLocal) statusFuer) {
    final alle = ref.read(betriebeProvider);
    final regionen = ref.read(regionenProvider);

    bool istFaellig(FaelligkeitsStatus s) =>
        s == FaelligkeitsStatus.ueberfaellig ||
        s == FaelligkeitsStatus.faellig ||
        s == FaelligkeitsStatus.baldFaellig;

    final gefiltert = alle.where((b) {
      if (!_karteZeigeInaktiv &&
          b.status != 'aktiv' &&
          b.status != 'saisonpause') {
        return false;
      }
      if (_karteNurMeine && !b.istMeinKunde) return false;
      if (_karteRegionId != null && b.regionId != _karteRegionId) return false;
      if (_karteNurFaellig && !istFaellig(statusFuer(b))) return false;
      return true;
    }).toList();

    final mitKoord = gefiltert
        .where((b) => b.latitude != null && b.longitude != null)
        .map((b) => BetriebMarkerData(b, statusFuer(b)))
        .toList();
    final ohneKoord = gefiltert
        .where((b) => b.latitude == null || b.longitude == null)
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              FilterChip(
                label: const Text('Meine Kunden'),
                selected: _karteNurMeine,
                onSelected: (v) => setState(() => _karteNurMeine = v),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Nur fällige'),
                selected: _karteNurFaellig,
                onSelected: (v) => setState(() => _karteNurFaellig = v),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Inaktive/geschl.'),
                selected: _karteZeigeInaktiv,
                onSelected: (v) => setState(() => _karteZeigeInaktiv = v),
              ),
              const SizedBox(width: 8),
              if (regionen.isNotEmpty)
                DropdownButton<String?>(
                  value: _karteRegionId,
                  hint: const Text('Region'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('Alle Regionen')),
                    for (final r in regionen)
                      if (r.serverId != null)
                        DropdownMenuItem(
                            value: r.serverId, child: Text(r.name)),
                  ],
                  onChanged: (v) => setState(() => _karteRegionId = v),
                ),
            ],
          ),
        ),
        Expanded(
          child: BetriebeMap(
            eintraege: mitKoord,
            onOeffnen: (b) => context.push('/betriebe/${b.routeId}'),
            onRoute: (b) => _oeffneRoute(b),
          ),
        ),
        if (ohneKoord.isNotEmpty)
          TextButton.icon(
            onPressed: () => _zeigeOhneStandort(ohneKoord),
            icon: const Icon(Icons.wrong_location_outlined, size: 18),
            label: Text('${ohneKoord.length} Betriebe ohne Standort'),
          ),
      ],
    );
  }

  void _zeigeOhneStandort(List<BetriebLocal> ohne) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Betriebe ohne Standort',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            for (final b in ohne)
              ListTile(
                title: Text(b.name),
                subtitle: b.ort != null ? Text(b.ort!) : null,
                trailing: const Icon(Icons.edit_location_alt),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/betriebe/${b.routeId}/bearbeiten');
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _oeffneRoute(BetriebLocal b) async {
    final url = googleMapsRouteUrl(
      latitude: b.latitude,
      longitude: b.longitude,
      adresse: [b.strasse, b.nr, b.plz, b.ort]
          .where((s) => s != null && s.isNotEmpty)
          .join(' '),
    );
    if (url == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Keine Adresse/Koordinaten für Route.')),
        );
      }
      return;
    }
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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
                _statusChip('geschlossen', 'Geschlossen'),
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
          backgroundColor: _zapfSystemColor.withAlpha(25),
          child: Icon(Icons.store, color: _zapfSystemColor, size: 20),
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
    if (betrieb.ort == null) return null;
    return Text(betrieb.ort!);
  }

  Color get _zapfSystemColor {
    final sys = betrieb.zapfsysteme.isNotEmpty
        ? betrieb.zapfsysteme.first.toLowerCase()
        : '';
    switch (sys) {
      case 'konventionell':
      case 'orion':
        return AppColors.success;
      case 'higenie':
        return AppColors.info;
      case 'david':
        return AppColors.textSecondary;
      case 'veranstaltungen':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }
}

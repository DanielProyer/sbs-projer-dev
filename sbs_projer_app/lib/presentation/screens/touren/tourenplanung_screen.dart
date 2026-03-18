import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/local/anlage_local_export.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/presentation/providers/anlage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/reinigung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

class TourenplanungScreen extends ConsumerStatefulWidget {
  const TourenplanungScreen({super.key});

  @override
  ConsumerState<TourenplanungScreen> createState() =>
      _TourenplanungScreenState();
}

class _TourenplanungScreenState extends ConsumerState<TourenplanungScreen>
    with SingleTickerProviderStateMixin {
  late DateTime _selectedDate;
  String? _selectedRegionId;
  String? _selectedTyp;
  late TabController _tabController;
  List<String>? _vorschlagOrder; // anlageId order for drag & drop

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  DateTime get _weekStart {
    final d = _selectedDate;
    return d.subtract(Duration(days: d.weekday - 1));
  }

  void _changeWeek(int delta) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: 7 * delta));
      _vorschlagOrder = null;
    });
  }

  void _selectDay(DateTime day) {
    setState(() {
      _selectedDate = day;
      _vorschlagOrder = null;
    });
  }

  int _weekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final days = date.difference(firstDayOfYear).inDays;
    return ((days + firstDayOfYear.weekday - 1) / 7).ceil() + 1;
  }

  @override
  Widget build(BuildContext context) {
    final betriebe = ref.watch(betriebeProvider);
    final regionen = ref.watch(regionenProvider);
    final vorschlagReinigungen = ref.watch(tourVorschlagProvider(_selectedDate));
    final faelligeAnlagen = ref.watch(faelligeAnlagenProvider(_selectedDate));
    final alleAnlagen = ref.watch(anlagenProvider);

    // Lookup maps
    final betriebMap = <String, BetriebLocal>{};
    for (final b in betriebe) {
      betriebMap[b.routeId] = b;
      if (b.serverId != null) betriebMap[b.serverId!] = b;
    }
    final anlageMap = <String, AnlageLocal>{};
    for (final a in alleAnlagen) {
      anlageMap[a.routeId] = a;
      if (a.serverId != null) anlageMap[a.serverId!] = a;
    }

    // Vorschlag: Reinigungen → Anlagen (dedupliziert)
    final vorschlagAnlagen = <AnlageLocal>[];
    final seenIds = <String>{};
    for (final r in vorschlagReinigungen) {
      final anlage = anlageMap[r.anlageId];
      if (anlage != null && anlage.status == 'aktiv' && seenIds.add(anlage.routeId)) {
        final betrieb = betriebMap[anlage.betriebId];
        if (betrieb == null || isBetriebOffen(betrieb, _selectedDate)) {
          vorschlagAnlagen.add(anlage);
        }
      }
    }

    // Apply filters to both lists
    final filteredVorschlag = _applyFilters(vorschlagAnlagen, betriebMap);
    final filteredFaellig = _applyFilters(faelligeAnlagen, betriebMap);

    // Manage drag & drop order for Vorschlag tab
    _vorschlagOrder ??= filteredVorschlag.map((a) => a.routeId).toList();
    final orderedVorschlag = <AnlageLocal>[];
    for (final id in _vorschlagOrder!) {
      final a = filteredVorschlag.firstWhere(
        (a) => a.routeId == id,
        orElse: () => filteredVorschlag.first,
      );
      if (filteredVorschlag.contains(a) && !orderedVorschlag.contains(a)) {
        orderedVorschlag.add(a);
      }
    }
    // Add any new items not in the order list
    for (final a in filteredVorschlag) {
      if (!orderedVorschlag.contains(a)) {
        orderedVorschlag.add(a);
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Tourenplanung')),
      body: Column(
        children: [
          // ─── Wochen-Navigation ───
          _WeekNavigator(
            weekStart: _weekStart,
            weekNumber: _weekNumber(_selectedDate),
            onPrevious: () => _changeWeek(-1),
            onNext: () => _changeWeek(1),
          ),

          // ─── Tages-Chips ───
          _DayChips(
            weekStart: _weekStart,
            selectedDate: _selectedDate,
            onSelect: _selectDay,
            vorschlagCounts: _buildDayCounts(vorschlagReinigungen, alleAnlagen, betriebMap),
          ),

          const Divider(height: 1),

          // ─── Filter ───
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedRegionId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Region',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Alle Regionen')),
                      ...regionen.map((r) => DropdownMenuItem(
                          value: r.routeId, child: Text(r.name))),
                    ],
                    onChanged: (v) => setState(() {
                      _selectedRegionId = v;
                      _vorschlagOrder = null;
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedTyp,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Anlagentyp',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Alle Typen')),
                      DropdownMenuItem(
                          value: 'Warmanstich', child: Text('Warmanstich')),
                      DropdownMenuItem(
                          value: 'Kaltanstich', child: Text('Kaltanstich')),
                      DropdownMenuItem(
                          value: 'Buffetanstich',
                          child: Text('Buffetanstich')),
                      DropdownMenuItem(value: 'Orion', child: Text('Orion')),
                    ],
                    onChanged: (v) => setState(() {
                      _selectedTyp = v;
                      _vorschlagOrder = null;
                    }),
                  ),
                ),
              ],
            ),
          ),

          // ─── TabBar ───
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: 'Vorschlag (${orderedVorschlag.length})'),
              Tab(text: 'Fällig (${filteredFaellig.length})'),
            ],
          ),

          // ─── Tab Content ───
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Vorschlag Tab (mit Drag & Drop)
                orderedVorschlag.isEmpty
                    ? _buildEmpty(
                        'Kein Vorschlag',
                        'Vor 4 Wochen wurden am ${_formatDate(_selectedDate.subtract(const Duration(days: 28)))} keine Reinigungen durchgeführt.',
                      )
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: orderedVorschlag.length,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) newIndex--;
                            final item = _vorschlagOrder!.removeAt(oldIndex);
                            _vorschlagOrder!.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (context, index) {
                          final anlage = orderedVorschlag[index];
                          final betrieb = betriebMap[anlage.betriebId];
                          return _AnlageListItem(
                            key: ValueKey(anlage.routeId),
                            anlage: anlage,
                            betrieb: betrieb,
                            selectedDate: _selectedDate,
                            position: index + 1,
                            showDragHandle: true,
                            onTap: () => context
                                .push('/anlagen/${anlage.routeId}'),
                          );
                        },
                      ),

                // Fällig Tab
                filteredFaellig.isEmpty
                    ? _buildEmpty(
                        'Keine fälligen Anlagen',
                        'Zum ${_formatDate(_selectedDate)} sind keine Reinigungen fällig.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: filteredFaellig.length,
                        itemBuilder: (context, index) {
                          final anlage = filteredFaellig[index];
                          final betrieb = betriebMap[anlage.betriebId];
                          return _AnlageListItem(
                            key: ValueKey(anlage.routeId),
                            anlage: anlage,
                            betrieb: betrieb,
                            selectedDate: _selectedDate,
                            onTap: () => context
                                .push('/anlagen/${anlage.routeId}'),
                          );
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<AnlageLocal> _applyFilters(
      List<AnlageLocal> anlagen, Map<String, BetriebLocal> betriebMap) {
    return anlagen.where((a) {
      // Typ-Filter
      if (_selectedTyp != null && a.typAnlage != _selectedTyp) return false;
      // Region-Filter
      if (_selectedRegionId != null) {
        final betrieb = betriebMap[a.betriebId];
        if (betrieb == null || betrieb.regionId != _selectedRegionId) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  /// Zählt pro Wochentag (Mo-Sa) wie viele Vorschlag-Anlagen es gibt.
  List<int> _buildDayCounts(
    List<ReinigungLocal> vorschlagReinigungen,
    List<AnlageLocal> alleAnlagen,
    Map<String, BetriebLocal> betriebMap,
  ) {
    final counts = List<int>.filled(6, 0); // Mo-Sa
    for (int i = 0; i < 6; i++) {
      final day = _weekStart.add(Duration(days: i));
      final referenz = day.subtract(const Duration(days: 28));
      final von = referenz.subtract(const Duration(days: 2));
      final bis = referenz.add(const Duration(days: 2));
      final reinigungen = ref.read(reinigungenProvider);
      final seen = <String>{};
      for (final r in reinigungen) {
        if (r.datum.isAfter(von) && r.datum.isBefore(bis)) {
          if (seen.add(r.anlageId)) counts[i]++;
        }
      }
    }
    return counts;
  }

  Widget _buildEmpty(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.route,
                size: 64, color: AppColors.textSecondary.withAlpha(100)),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}

// ─── Wochen-Navigation Widget ───

class _WeekNavigator extends StatelessWidget {
  final DateTime weekStart;
  final int weekNumber;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _WeekNavigator({
    required this.weekStart,
    required this.weekNumber,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final weekEnd = weekStart.add(const Duration(days: 5));
    final df = DateFormat('d.');
    final mf = DateFormat('d. MMM yyyy', 'de_CH');

    final label = weekStart.month == weekEnd.month
        ? '${df.format(weekStart)}–${mf.format(weekEnd)}'
        : '${df.format(weekStart)} ${DateFormat('MMM', 'de_CH').format(weekStart)} – ${mf.format(weekEnd)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: AppColors.primary.withAlpha(15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrevious,
            tooltip: 'Vorherige Woche',
          ),
          Text(
            'KW $weekNumber · $label',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
            tooltip: 'Nächste Woche',
          ),
        ],
      ),
    );
  }
}

// ─── Tages-Chips Widget ───

class _DayChips extends StatelessWidget {
  final DateTime weekStart;
  final DateTime selectedDate;
  final void Function(DateTime) onSelect;
  final List<int> vorschlagCounts;

  const _DayChips({
    required this.weekStart,
    required this.selectedDate,
    required this.onSelect,
    required this.vorschlagCounts,
  });

  static const _dayLabels = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa'];

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(6, (i) {
          final day = weekStart.add(Duration(days: i));
          final isSelected = day.year == selectedDate.year &&
              day.month == selectedDate.month &&
              day.day == selectedDate.day;
          final isToday = day.year == todayDate.year &&
              day.month == todayDate.month &&
              day.day == todayDate.day;
          final count = vorschlagCounts[i];

          return GestureDetector(
            onTap: () => onSelect(day),
            child: Container(
              width: 52,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : isToday
                        ? AppColors.primary.withAlpha(25)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: isToday && !isSelected
                    ? Border.all(color: AppColors.primary, width: 1.5)
                    : null,
              ),
              child: Column(
                children: [
                  Text(
                    _dayLabels[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withAlpha(50)
                            : AppColors.info.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : AppColors.info,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Anlage List Item ───

class _AnlageListItem extends StatelessWidget {
  final AnlageLocal anlage;
  final BetriebLocal? betrieb;
  final DateTime selectedDate;
  final int? position;
  final bool showDragHandle;
  final VoidCallback onTap;

  const _AnlageListItem({
    super.key,
    required this.anlage,
    this.betrieb,
    required this.selectedDate,
    this.position,
    this.showDragHandle = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final faelligkeit = getFaelligkeit(anlage, selectedDate);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: ListTile(
        leading: showDragHandle
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ReorderableDragStartListener(
                    index: (position ?? 1) - 1,
                    child: const Icon(Icons.drag_handle,
                        color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 4),
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: _faelligkeitsColor(faelligkeit).withAlpha(25),
                    child: Text(
                      '${position ?? ''}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _faelligkeitsColor(faelligkeit),
                      ),
                    ),
                  ),
                ],
              )
            : CircleAvatar(
                backgroundColor: _faelligkeitsColor(faelligkeit).withAlpha(25),
                child: Icon(
                  _faelligkeitsIcon(faelligkeit),
                  color: _faelligkeitsColor(faelligkeit),
                  size: 20,
                ),
              ),
        title: Text(
          betrieb?.name ?? 'Unbekannter Betrieb',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_buildSubtitle()),
            Text(
              anlage.letzteReinigung != null
                  ? 'Letzte Reinigung: ${anlage.letzteReinigung!.day.toString().padLeft(2, '0')}.${anlage.letzteReinigung!.month.toString().padLeft(2, '0')}.${anlage.letzteReinigung!.year}'
                  : 'Noch nie gereinigt',
              style: TextStyle(
                fontSize: 12,
                color: anlage.letzteReinigung != null
                    ? AppColors.textSecondary
                    : AppColors.error,
              ),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (faelligkeit == FaelligkeitsStatus.ueberfaellig)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'überfällig',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
              )
            else if (faelligkeit == FaelligkeitsStatus.faellig)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warning.withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'fällig',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                  ),
                ),
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
    if (anlage.bezeichnung != null && anlage.bezeichnung!.isNotEmpty) {
      parts.add(anlage.bezeichnung!);
    }
    if (betrieb?.ort != null) parts.add(betrieb!.ort!);
    parts.add(anlage.typAnlage);
    return parts.join(' · ');
  }

  Color _faelligkeitsColor(FaelligkeitsStatus status) {
    switch (status) {
      case FaelligkeitsStatus.ueberfaellig:
        return AppColors.error;
      case FaelligkeitsStatus.faellig:
        return AppColors.warning;
      case FaelligkeitsStatus.baldFaellig:
        return AppColors.success;
      case FaelligkeitsStatus.nichtFaellig:
        return AppColors.info;
    }
  }

  IconData _faelligkeitsIcon(FaelligkeitsStatus status) {
    switch (status) {
      case FaelligkeitsStatus.ueberfaellig:
        return Icons.warning;
      case FaelligkeitsStatus.faellig:
        return Icons.schedule;
      case FaelligkeitsStatus.baldFaellig:
        return Icons.upcoming;
      case FaelligkeitsStatus.nichtFaellig:
        return Icons.check_circle_outline;
    }
  }
}

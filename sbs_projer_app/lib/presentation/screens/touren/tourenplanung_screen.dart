import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
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
  late TabController _tabController;
  DateTime? _loadedForDate;

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
      _loadedForDate = null;
    });
  }

  void _selectDay(DateTime day) {
    setState(() {
      _selectedDate = day;
      _loadedForDate = null;
    });
  }

  int _weekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final days = date.difference(firstDayOfYear).inDays;
    return ((days + firstDayOfYear.weekday - 1) / 7).ceil() + 1;
  }

  @override
  Widget build(BuildContext context) {
    ref.read(aktiverTagesplanTagProvider.notifier).state = _selectedDate;

    final regionen = ref.watch(regionenProvider);
    final selectedRegionen = ref.watch(selectedRegionenProvider);
    final selectedFaelligkeit = ref.watch(selectedFaelligkeitProvider);
    final tagesplan = ref.watch(tagesplanProvider);
    final dayCounts = ref.watch(tagesCountsProvider(_weekStart));
    final faelligeEintraege =
        ref.watch(faelligeEintraegeProvider(_selectedDate));

    // Reaktives Laden: gespeicherter Plan hat Vorrang vor Vorschlag
    final gespeichertAsync =
        ref.watch(gespeicherterTagesplanProvider(_selectedDate));
    if (_loadedForDate != _selectedDate) {
      gespeichertAsync.when(
        data: (gespeichert) {
          if (_loadedForDate != _selectedDate) {
            _loadedForDate = _selectedDate;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              if (gespeichert != null) {
                ref
                    .read(tagesplanProvider.notifier)
                    .setFromGespeichert(gespeichert);
              } else {
                final vorschlag =
                    ref.read(tourVorschlagErweitertProvider(_selectedDate));
                ref
                    .read(tagesplanProvider.notifier)
                    .setFromVorschlag(vorschlag);
              }
            });
          }
        },
        loading: () {},
        error: (_, _) {
          _loadedForDate = _selectedDate;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final vorschlag =
                ref.read(tourVorschlagErweitertProvider(_selectedDate));
            ref.read(tagesplanProvider.notifier).setFromVorschlag(vorschlag);
          });
        },
      );
    }

    // Filter-Funktion (Region + Fälligkeit)
    bool passesFilter(TourEintrag e) {
      // Region-Filter
      if (selectedRegionen.isNotEmpty &&
          e.regionId != null &&
          !selectedRegionen.contains(e.regionId)) {
        return false;
      }
      // Fälligkeits-Filter (nur auf Reinigungen anwenden;
      // Störungen/Montagen immer durchlassen)
      if (selectedFaelligkeit.isNotEmpty &&
          e.typ == TourEintragTyp.reinigung) {
        if (e.faelligkeit == null ||
            !selectedFaelligkeit.contains(e.faelligkeit)) {
          return false;
        }
      }
      return true;
    }

    final angezeigtTagesplan = tagesplan.where(passesFilter).toList();
    final angezeigtFaellig = faelligeEintraege.where(passesFilter).toList();

    final bereitsImPlan = tagesplan.map((e) => e.id).toSet();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tourenplanung'),
        actions: [
          // Regionen-Filter Button
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                tooltip: 'Filter',
                onPressed: () => _showFilterPicker(context, regionen,
                    selectedRegionen, selectedFaelligkeit),
              ),
              if (selectedRegionen.isNotEmpty ||
                  selectedFaelligkeit.isNotEmpty)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${selectedRegionen.length + selectedFaelligkeit.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Wochen-Navigation
          _WeekNavigator(
            weekStart: _weekStart,
            weekNumber: _weekNumber(_selectedDate),
            onPrevious: () => _changeWeek(-1),
            onNext: () => _changeWeek(1),
          ),

          // Tages-Chips
          _DayChips(
            weekStart: _weekStart,
            selectedDate: _selectedDate,
            onSelect: _selectDay,
            counts: dayCounts,
          ),

          const Divider(height: 1),

          // TabBar
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: 'Tagesplan (${angezeigtTagesplan.length})'),
              Tab(text: 'Fällig (${angezeigtFaellig.length})'),
            ],
          ),

          // Filter-Chips (Fälligkeit + Regionen)
          if (selectedFaelligkeit.isNotEmpty || selectedRegionen.isNotEmpty)
            _FilterChips(
              selectedFaelligkeit: selectedFaelligkeit,
              selectedRegionen: selectedRegionen,
              regionen: regionen,
              onFaelligkeitChanged: (updated) {
                ref.read(selectedFaelligkeitProvider.notifier).state =
                    updated;
              },
              onRegionenChanged: (updated) {
                ref.read(selectedRegionenProvider.notifier).state =
                    updated;
              },
            ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // === Tab 1: Tagesplan ===
                Column(
                  children: [
                    _TagesplanHeader(
                      datum: _selectedDate,
                      istGespeichert: ref.read(tagesplanProvider.notifier).gespeichert,
                      onLeeren: () =>
                          ref.read(tagesplanProvider.notifier).leeren(),
                      onAusFaelligBefuellen: () {
                        final faellige = ref
                            .read(faelligeEintraegeProvider(_selectedDate));
                        ref
                            .read(tagesplanProvider.notifier)
                            .befuellenAusFaellig(faellige);
                      },
                      onSpeichern: () async {
                        try {
                          await tagesplanSpeichern(
                              _selectedDate, tagesplan);
                          ref.read(tagesplanProvider.notifier).markGespeichert();
                          ref.invalidate(gespeicherterTagesplanProvider);
                          if (mounted) {
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Tagesplan gespeichert')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Fehler: $e')),
                            );
                          }
                        }
                      },
                    ),
                    Expanded(
                      child: angezeigtTagesplan.isEmpty
                          ? _buildEmpty(
                              'Kein Tagesplan',
                              'Wechsle zum Tab "Fällig" um Einträge\nzum Tagesplan hinzuzufügen.',
                            )
                          : _TagesplanListe(
                              eintraege: angezeigtTagesplan,
                              onReorder: (old, neu) => ref
                                  .read(tagesplanProvider.notifier)
                                  .reorder(old, neu),
                              onDismiss: (id) => ref
                                  .read(tagesplanProvider.notifier)
                                  .entfernen(id),
                              onTap: _navigateToDetail,
                            ),
                    ),
                  ],
                ),

                // === Tab 2: Fällig ===
                angezeigtFaellig.isEmpty
                    ? _buildEmpty(
                        'Keine fälligen Einträge',
                        'Zum ${_formatDate(_selectedDate)} sind keine\nReinigungen, Störungen oder Montagen fällig.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: angezeigtFaellig.length,
                        itemBuilder: (_, i) {
                          final e = angezeigtFaellig[i];
                          final imPlan = bereitsImPlan.contains(e.id);
                          return _FaelligEintragKarte(
                            eintrag: e,
                            imPlan: imPlan,
                            onAdd: () {
                              ref
                                  .read(tagesplanProvider.notifier)
                                  .hinzufuegen(e);
                            },
                            onTap: () => _navigateToDetail(e),
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

  void _navigateToDetail(TourEintrag eintrag) {
    switch (eintrag.typ) {
      case TourEintragTyp.reinigung:
        if (eintrag.anlageId != null) {
          context.push('/anlagen/${eintrag.anlageId}');
        }
        break;
      case TourEintragTyp.stoerung:
        final id = eintrag.id.substring(2);
        context.push('/stoerungen/$id');
        break;
      case TourEintragTyp.montage:
      case TourEintragTyp.heigenie:
        final id = eintrag.id.substring(2);
        context.push('/montagen/$id');
        break;
    }
  }

  void _showFilterPicker(
    BuildContext context,
    List<dynamic> regionen,
    Set<String> selectedRegionen,
    Set<FaelligkeitsStatus> selectedFaelligkeit,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          final currentRegionen = ref.read(selectedRegionenProvider);
          final currentFaelligkeit = ref.read(selectedFaelligkeitProvider);
          final hasAnyFilter =
              currentRegionen.isNotEmpty || currentFaelligkeit.isNotEmpty;

          return DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.3,
            maxChildSize: 0.85,
            expand: false,
            builder: (_, scrollController) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Text('Filter',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        if (hasAnyFilter)
                          TextButton(
                            onPressed: () {
                              ref
                                  .read(selectedRegionenProvider.notifier)
                                  .state = {};
                              ref
                                  .read(
                                      selectedFaelligkeitProvider.notifier)
                                  .state = {};
                              Navigator.pop(ctx);
                            },
                            child: const Text('Alle zurücksetzen'),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        // ─── Fälligkeit ───
                        const Padding(
                          padding:
                              EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Text('Fälligkeit',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary)),
                        ),
                        ..._faelligkeitsOptionen.map((opt) {
                          final isChecked =
                              currentFaelligkeit.contains(opt.status);
                          return CheckboxListTile(
                            title: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  margin:
                                      const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: opt.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Text(opt.label),
                              ],
                            ),
                            value: isChecked,
                            dense: true,
                            onChanged: (checked) {
                              final updated =
                                  Set<FaelligkeitsStatus>.from(
                                      currentFaelligkeit);
                              if (checked == true) {
                                updated.add(opt.status);
                              } else {
                                updated.remove(opt.status);
                              }
                              ref
                                  .read(
                                      selectedFaelligkeitProvider.notifier)
                                  .state = updated;
                              setModalState(() {});
                            },
                          );
                        }),
                        const Divider(height: 16),
                        // ─── Regionen ───
                        const Padding(
                          padding:
                              EdgeInsets.fromLTRB(16, 4, 16, 4),
                          child: Text('Regionen',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary)),
                        ),
                        ...regionen.map((r) {
                          final isChecked =
                              currentRegionen.contains(r.routeId);
                          return CheckboxListTile(
                            title: Text(r.name),
                            value: isChecked,
                            dense: true,
                            onChanged: (checked) {
                              final updated =
                                  Set<String>.from(currentRegionen);
                              if (checked == true) {
                                updated.add(r.routeId);
                              } else {
                                updated.remove(r.routeId);
                              }
                              ref
                                  .read(selectedRegionenProvider.notifier)
                                  .state = updated;
                              setModalState(() {});
                            },
                          );
                        }),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        });
      },
    );
  }

  static const _faelligkeitsOptionen = [
    _FaelligkeitsOption(
      status: FaelligkeitsStatus.ueberfaellig,
      label: 'Überfällig',
      color: AppColors.error,
    ),
    _FaelligkeitsOption(
      status: FaelligkeitsStatus.faellig,
      label: 'Fällig',
      color: AppColors.warning,
    ),
    _FaelligkeitsOption(
      status: FaelligkeitsStatus.baldFaellig,
      label: 'Bald fällig',
      color: AppColors.success,
    ),
    _FaelligkeitsOption(
      status: FaelligkeitsStatus.endreinigungFaellig,
      label: 'Endreinigung',
      color: Color(0xFFEA580C),
    ),
    _FaelligkeitsOption(
      status: FaelligkeitsStatus.eroeffnungFaellig,
      label: 'Eröffnung',
      color: AppColors.info,
    ),
  ];
}

// ─── Wochen-Navigation ───

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

// ─── Tages-Chips ───

class _DayChips extends StatelessWidget {
  final DateTime weekStart;
  final DateTime selectedDate;
  final void Function(DateTime) onSelect;
  final List<int> counts;

  const _DayChips({
    required this.weekStart,
    required this.selectedDate,
    required this.onSelect,
    required this.counts,
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
          final count = counts[i];

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
                      color:
                          isSelected ? Colors.white : AppColors.textSecondary,
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

// ─── Tagesplan-Header ───

class _TagesplanHeader extends StatelessWidget {
  final DateTime datum;
  final bool istGespeichert;
  final VoidCallback onLeeren;
  final VoidCallback onAusFaelligBefuellen;
  final VoidCallback onSpeichern;

  const _TagesplanHeader({
    required this.datum,
    required this.istGespeichert,
    required this.onLeeren,
    required this.onAusFaelligBefuellen,
    required this.onSpeichern,
  });

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('EE, d. MMM', 'de_CH');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 2),
      child: Row(
        children: [
          Text(
            df.format(datum),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          if (istGespeichert)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.cloud_done, size: 16, color: AppColors.success),
            ),
          const Spacer(),
          IconButton(
            onPressed: onSpeichern,
            icon: Icon(
              istGespeichert ? Icons.save : Icons.save_outlined,
              size: 20,
              color: istGespeichert ? AppColors.success : AppColors.primary,
            ),
            tooltip: 'Tagesplan speichern',
            visualDensity: VisualDensity.compact,
          ),
          TextButton.icon(
            onPressed: onAusFaelligBefuellen,
            icon: const Icon(Icons.playlist_add, size: 18),
            label: const Text('Fällige', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
          TextButton.icon(
            onPressed: onLeeren,
            icon: const Icon(Icons.clear_all, size: 18),
            label: const Text('Leeren', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: AppColors.error,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tagesplan-Liste (ReorderableListView) ───

class _TagesplanListe extends StatelessWidget {
  final List<TourEintrag> eintraege;
  final void Function(int, int) onReorder;
  final void Function(String) onDismiss;
  final void Function(TourEintrag) onTap;

  const _TagesplanListe({
    required this.eintraege,
    required this.onReorder,
    required this.onDismiss,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      itemCount: eintraege.length,
      onReorder: onReorder,
      proxyDecorator: (child, index, animation) {
        return Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final eintrag = eintraege[index];

        return Dismissible(
          key: ValueKey(eintrag.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: AppColors.error.withAlpha(30),
            child: const Icon(Icons.delete_outline, color: AppColors.error),
          ),
          onDismissed: (_) => onDismiss(eintrag.id),
          child: _TourEintragKarte(
            eintrag: eintrag,
            position: index + 1,
            onTap: () => onTap(eintrag),
          ),
        );
      },
    );
  }
}

// ─── Tour-Eintrag Karte ───

class _TourEintragKarte extends StatelessWidget {
  final TourEintrag eintrag;
  final int position;
  final VoidCallback onTap;

  const _TourEintragKarte({
    required this.eintrag,
    required this.position,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _typColor(eintrag.typ);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Farbbalken links
              Container(width: 5, color: color),
              // Inhalt
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      // Position
                      SizedBox(
                        width: 24,
                        child: Text(
                          '$position',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                      // Icon
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: color.withAlpha(25),
                        child: Icon(_typIcon(eintrag.typ),
                            color: color, size: 16),
                      ),
                      const SizedBox(width: 10),
                      // Text
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    eintrag.betriebName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (eintrag.betriebOrt != null)
                                  Text(
                                    eintrag.betriebOrt!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    eintrag.beschreibung,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                _StatusBadge(eintrag: eintrag),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Drag Handle
                      ReorderableDragStartListener(
                        index: position - 1,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.drag_handle,
                              color: AppColors.textSecondary, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _typColor(TourEintragTyp typ) {
    switch (typ) {
      case TourEintragTyp.reinigung:
        return AppColors.success;
      case TourEintragTyp.stoerung:
        return AppColors.error;
      case TourEintragTyp.montage:
        return AppColors.info;
      case TourEintragTyp.heigenie:
        return AppColors.warning;
    }
  }

  static IconData _typIcon(TourEintragTyp typ) {
    switch (typ) {
      case TourEintragTyp.reinigung:
        return Icons.cleaning_services;
      case TourEintragTyp.stoerung:
        return Icons.warning_amber;
      case TourEintragTyp.montage:
        return Icons.construction;
      case TourEintragTyp.heigenie:
        return Icons.build;
    }
  }
}

// ─── Status-Badge ───

class _StatusBadge extends StatelessWidget {
  final TourEintrag eintrag;

  const _StatusBadge({required this.eintrag});

  @override
  Widget build(BuildContext context) {
    String? label;
    Color? color;

    if (eintrag.faelligkeit == FaelligkeitsStatus.ueberfaellig) {
      label = 'überfällig';
      color = AppColors.error;
    } else if (eintrag.faelligkeit == FaelligkeitsStatus.faellig) {
      label = 'fällig';
      color = AppColors.warning;
    } else if (eintrag.faelligkeit == FaelligkeitsStatus.baldFaellig) {
      label = 'bald fällig';
      color = AppColors.success;
    } else if (eintrag.faelligkeit == FaelligkeitsStatus.endreinigungFaellig) {
      label = 'Endreinigung';
      color = const Color(0xFFEA580C); // deep orange
    } else if (eintrag.faelligkeit == FaelligkeitsStatus.eroeffnungFaellig) {
      label = 'Eröffnung';
      color = AppColors.info;
    } else if (eintrag.typ == TourEintragTyp.stoerung) {
      label = 'offen';
      color = AppColors.error;
    } else if (eintrag.typ == TourEintragTyp.montage ||
        eintrag.typ == TourEintragTyp.heigenie) {
      label = 'geplant';
      color = AppColors.info;
    }

    if (label == null || color == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ─── Fällig-Eintrag Karte (im Fällig-Tab) ───

class _FaelligEintragKarte extends StatelessWidget {
  final TourEintrag eintrag;
  final bool imPlan;
  final VoidCallback onAdd;
  final VoidCallback onTap;

  const _FaelligEintragKarte({
    required this.eintrag,
    required this.imPlan,
    required this.onAdd,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _TourEintragKarte._typColor(eintrag.typ);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 4, color: color),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: color.withAlpha(25),
                        child: Icon(_TourEintragKarte._typIcon(eintrag.typ),
                            color: color, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    eintrag.betriebName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (eintrag.betriebOrt != null)
                                  Text(
                                    eintrag.betriebOrt!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              eintrag.beschreibung,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      _StatusBadge(eintrag: eintrag),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(
                          imPlan
                              ? Icons.check_circle
                              : Icons.add_circle_outline,
                          color:
                              imPlan ? AppColors.success : AppColors.primary,
                        ),
                        onPressed: imPlan ? null : onAdd,
                        tooltip:
                            imPlan ? 'Bereits im Plan' : 'Zum Tagesplan',
                        iconSize: 24,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Fälligkeits-Option (für Filter-Picker) ───

class _FaelligkeitsOption {
  final FaelligkeitsStatus status;
  final String label;
  final Color color;

  const _FaelligkeitsOption({
    required this.status,
    required this.label,
    required this.color,
  });
}

// ─── Filter-Chips (Fälligkeit + Regionen) ───

class _FilterChips extends StatelessWidget {
  final Set<FaelligkeitsStatus> selectedFaelligkeit;
  final Set<String> selectedRegionen;
  final List<dynamic> regionen;
  final void Function(Set<FaelligkeitsStatus>) onFaelligkeitChanged;
  final void Function(Set<String>) onRegionenChanged;

  const _FilterChips({
    required this.selectedFaelligkeit,
    required this.selectedRegionen,
    required this.regionen,
    required this.onFaelligkeitChanged,
    required this.onRegionenChanged,
  });

  static const _labels = {
    FaelligkeitsStatus.ueberfaellig: ('Überfällig', AppColors.error),
    FaelligkeitsStatus.faellig: ('Fällig', AppColors.warning),
    FaelligkeitsStatus.baldFaellig: ('Bald fällig', AppColors.success),
    FaelligkeitsStatus.endreinigungFaellig:
        ('Endreinigung', Color(0xFFEA580C)),
    FaelligkeitsStatus.eroeffnungFaellig: ('Eröffnung', AppColors.info),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: AppColors.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ActionChip(
                avatar: const Icon(Icons.close, size: 14),
                label: const Text('Filter',
                    style: TextStyle(fontSize: 12)),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize:
                    MaterialTapTargetSize.shrinkWrap,
                onPressed: () {
                  onFaelligkeitChanged({});
                  onRegionenChanged({});
                },
              ),
            ),
            ...selectedFaelligkeit.map((s) {
              final (label, color) = _labels[s]!;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Chip(
                  label: Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          color: color,
                          fontWeight: FontWeight.w600)),
                  backgroundColor: color.withAlpha(20),
                  side: BorderSide(color: color.withAlpha(60)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize:
                      MaterialTapTargetSize.shrinkWrap,
                  deleteIcon: Icon(Icons.close, size: 14, color: color),
                  onDeleted: () {
                    final updated =
                        Set<FaelligkeitsStatus>.from(selectedFaelligkeit);
                    updated.remove(s);
                    onFaelligkeitChanged(updated);
                  },
                ),
              );
            }),
            ...selectedRegionen.map((regionId) {
              final region = regionen.cast<dynamic>().where(
                  (r) => r.routeId == regionId).toList();
              final name = region.isNotEmpty ? region.first.name : regionId;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Chip(
                  avatar: const Icon(Icons.map, size: 14, color: AppColors.primary),
                  label: Text(name,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
                  backgroundColor: AppColors.primary.withAlpha(20),
                  side: BorderSide(color: AppColors.primary.withAlpha(60)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize:
                      MaterialTapTargetSize.shrinkWrap,
                  deleteIcon: const Icon(Icons.close, size: 14,
                      color: AppColors.primary),
                  onDeleted: () {
                    final updated = Set<String>.from(selectedRegionen);
                    updated.remove(regionId);
                    onRegionenChanged(updated);
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/touren_anzeige.dart';
import 'package:sbs_projer_app/presentation/widgets/filter/app_filter_bar.dart';
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
    final autoTermine = ref.watch(autoTermineProvider(_selectedDate));

    // Reaktives Laden: gespeicherter Plan hat Vorrang vor Vorschlag.
    final gespeichertAsync =
        ref.watch(gespeicherterTagesplanProvider(_selectedDate));
    if (_loadedForDate != _selectedDate) {
      final tag = _selectedDate;
      void anwenden(List<TourEintrag>? gespeichert) {
        _loadedForDate = tag;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final notifier = ref.read(tagesplanProvider.notifier);
          // Race-Schutz: hat der User diesen Tag inzwischen bereits bearbeitet,
          // seinen Stand NICHT mit dem (evtl. älteren) Lade-Fetch überschreiben.
          if (notifier.datum == tag) return;
          if (gespeichert != null) {
            notifier.setFromGespeichert(tag, gespeichert);
          } else {
            notifier.resetLeer(tag);
          }
        });
      }

      gespeichertAsync.when(
        data: (gespeichert) {
          if (_loadedForDate != tag) anwenden(gespeichert);
        },
        loading: () {},
        error: (_, _) {
          if (_loadedForDate != tag) anwenden(null);
        },
      );
    }

    // Region-Filter (gilt für beide Ansichten).
    bool passesRegion(TourEintrag e) {
      return !(selectedRegionen.isNotEmpty &&
          e.regionId != null &&
          !selectedRegionen.contains(e.regionId));
    }

    // Region + Fälligkeit — für die „Fällig"-Liste.
    bool passesFilter(TourEintrag e) {
      if (!passesRegion(e)) return false;
      // Fälligkeits-Filter nur auf Reinigungen; Störungen/Montagen durchlassen.
      if (selectedFaelligkeit.isNotEmpty &&
          e.typ == TourEintragTyp.reinigung) {
        if (e.faelligkeit == null ||
            !selectedFaelligkeit.contains(e.faelligkeit)) {
          return false;
        }
      }
      return true;
    }

    // Tagesplan: NUR Region-Filter — die committeten Einträge bleiben sichtbar,
    // unabhängig vom Fälligkeits-Filter (der triagiert nur die Fällig-Liste).
    final angezeigtTagesplan = tagesplan.where(passesRegion).toList();
    final angezeigtFaellig = faelligeEintraege.where(passesFilter).toList();

    final bereitsImPlan = tagesplan.map((e) => e.id).toSet();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tourenplanung'),
        actions: [
          // Region-Filter oben rechts (kompakter Mehrfach-Dropdown)
          if (regionen.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: AppFilterMultiDropdown<String>(
                label: 'Regionen',
                options: [
                  for (final r in regionen) (r.routeId, r.name),
                ],
                selected: selectedRegionen,
                onChanged: (updated) {
                  ref.read(selectedRegionenProvider.notifier).state = updated;
                },
              ).build(context),
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

          // Inline-Filter Fälligkeit (einzeilig, ohne Label — Region: AppBar)
          _InlineFilterLeiste(
            selectedFaelligkeit: selectedFaelligkeit,
            onFaelligkeitChanged: (updated) {
              ref.read(selectedFaelligkeitProvider.notifier).state = updated;
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
                      onLeeren: () =>
                          ref.read(tagesplanProvider.notifier).leeren(),
                      onAusFaelligBefuellen: () {
                        ref
                            .read(tagesplanProvider.notifier)
                            .befuellenAusFaellig(angezeigtFaellig);
                      },
                    ),
                    if (autoTermine.isNotEmpty)
                      _AutoTermineSektion(
                        eintraege: autoTermine,
                        onUebernehmen: (e) => ref
                            .read(tagesplanProvider.notifier)
                            .hinzufuegen(e.alsPlanEintrag()),
                        onAlleUebernehmen: () {
                          final notifier =
                              ref.read(tagesplanProvider.notifier);
                          for (final e in autoTermine) {
                            notifier.hinzufuegen(e.alsPlanEintrag());
                          }
                        },
                        onTap: _navigateToDetail,
                      ),
                    Expanded(
                      child: angezeigtTagesplan.isEmpty
                          ? _buildEmpty(
                              'Kein Tagesplan',
                              'Wechsle zum Tab "Fällig" um Einträge\nzum Tagesplan hinzuzufügen.',
                            )
                          : _TagesplanListe(
                              datum: _selectedDate,
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
                            datum: _selectedDate,
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
  final VoidCallback onLeeren;
  final VoidCallback onAusFaelligBefuellen;

  const _TagesplanHeader({
    required this.datum,
    required this.onLeeren,
    required this.onAusFaelligBefuellen,
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
          const Spacer(),
          TextButton.icon(
            onPressed: onAusFaelligBefuellen,
            icon: const Icon(Icons.playlist_add, size: 18),
            label: const Text('Fällige übernehmen',
                style: TextStyle(fontSize: 12)),
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
  final DateTime datum;
  final List<TourEintrag> eintraege;
  final void Function(int, int) onReorder;
  final void Function(String) onDismiss;
  final void Function(TourEintrag) onTap;

  const _TagesplanListe({
    required this.datum,
    required this.eintraege,
    required this.onReorder,
    required this.onDismiss,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      buildDefaultDragHandles: false,
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
            datum: datum,
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
  final DateTime datum;
  final TourEintrag eintrag;
  final int position;
  final VoidCallback onTap;

  const _TourEintragKarte({
    required this.datum,
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
                            _TourInfoZeile(datum: datum, eintrag: eintrag),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Grosser Greif-Griff (leicht zu treffen)
                      ReorderableDragStartListener(
                        index: position - 1,
                        child: Container(
                          width: 48,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.textSecondary.withAlpha(15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.drag_indicator,
                              color: AppColors.textSecondary, size: 28),
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

// ─── Automatische Termine (Saison) ───

class _AutoTermineSektion extends StatelessWidget {
  final List<TourEintrag> eintraege;
  final void Function(TourEintrag) onUebernehmen;
  final VoidCallback onAlleUebernehmen;
  final void Function(TourEintrag) onTap;

  const _AutoTermineSektion({
    required this.eintraege,
    required this.onUebernehmen,
    required this.onAlleUebernehmen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      decoration: BoxDecoration(
        color: AppColors.info.withAlpha(12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.info.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 2),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, size: 16, color: AppColors.info),
                const SizedBox(width: 6),
                Text('Automatische Termine (${eintraege.length})',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.info)),
                const Spacer(),
                TextButton(
                  onPressed: onAlleUebernehmen,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('Alle übernehmen',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          ...eintraege.map((e) => _AutoTerminKarte(
                eintrag: e,
                onUebernehmen: () => onUebernehmen(e),
                onTap: () => onTap(e),
              )),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _AutoTerminKarte extends StatelessWidget {
  final TourEintrag eintrag;
  final VoidCallback onUebernehmen;
  final VoidCallback onTap;

  const _AutoTerminKarte({
    required this.eintrag,
    required this.onUebernehmen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = eintrag.faelligkeit != null
        ? faelligkeitFarbe(eintrag.faelligkeit!)
        : AppColors.info;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(eintrag.betriebName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                  Text(eintrag.beschreibung,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline,
                  color: AppColors.primary),
              onPressed: onUebernehmen,
              tooltip: 'Zum Tagesplan',
              iconSize: 22,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Info-Zeile: Ruhetage / Servicezeiten / Ruhetag-Warnung ───

class _TourInfoZeile extends StatelessWidget {
  final DateTime datum;
  final TourEintrag eintrag;

  const _TourInfoZeile({required this.datum, required this.eintrag});

  @override
  Widget build(BuildContext context) {
    final heuteRuhetag = istRuhetag(eintrag.ruhetage, datum);
    final ruheTxt = ruhetageText(eintrag.ruhetage);
    final zeitTxt = eintrag.servicezeit;

    // Nichts anzuzeigen
    if (!heuteRuhetag && ruheTxt.isEmpty && (zeitTxt == null)) {
      return const SizedBox.shrink();
    }

    final children = <Widget>[];

    if (heuteRuhetag) {
      children.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.block, size: 13, color: AppColors.error),
          SizedBox(width: 3),
          Text('Heute Ruhetag',
              style: TextStyle(
                  fontSize: 11,
                  color: AppColors.error,
                  fontWeight: FontWeight.w700)),
        ],
      ));
    } else if (ruheTxt.isNotEmpty) {
      children.add(_infoChip(Icons.event_busy, 'Ruhetag: $ruheTxt'));
    }

    if (zeitTxt != null) {
      children.add(_infoChip(Icons.schedule, zeitTxt));
    }

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Wrap(
        spacing: 10,
        runSpacing: 2,
        children: children,
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textSecondary),
        const SizedBox(width: 3),
        Text(text,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
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
  final DateTime datum;
  final TourEintrag eintrag;
  final bool imPlan;
  final VoidCallback onAdd;
  final VoidCallback onTap;

  const _FaelligEintragKarte({
    required this.datum,
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
                            _TourInfoZeile(datum: datum, eintrag: eintrag),
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

// ─── Inline-Filter-Leiste (Fälligkeit — einzeilig, farbige Chips) ───

class _InlineFilterLeiste extends StatelessWidget {
  final Set<FaelligkeitsStatus> selectedFaelligkeit;
  final void Function(Set<FaelligkeitsStatus>) onFaelligkeitChanged;

  const _InlineFilterLeiste({
    required this.selectedFaelligkeit,
    required this.onFaelligkeitChanged,
  });

  static const _faelligStatuses = [
    FaelligkeitsStatus.ueberfaellig,
    FaelligkeitsStatus.faellig,
    FaelligkeitsStatus.baldFaellig,
    FaelligkeitsStatus.endreinigungFaellig,
    FaelligkeitsStatus.eroeffnungFaellig,
  ];

  // Kurz-Label nur für die Filter-Chips (global bleibt faelligkeitLabel).
  static String _kurz(FaelligkeitsStatus s) =>
      s == FaelligkeitsStatus.baldFaellig ? 'Bald' : faelligkeitLabel(s);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: AppMultiToggleChips<FaelligkeitsStatus>(
        spacing: 4,
        alignment: WrapAlignment.spaceBetween,
        options: [
          for (final s in _faelligStatuses)
            AppMultiOption(s, _kurz(s), color: faelligkeitFarbe(s)),
        ],
        selected: selectedFaelligkeit,
        onChanged: onFaelligkeitChanged,
      ),
    );
  }
}

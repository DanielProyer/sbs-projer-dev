import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/local/termin_local_export.dart';
import 'package:sbs_projer_app/data/local/pikett_dienst_local_export.dart';
import 'package:sbs_projer_app/data/repositories/termin_repository.dart';
import 'package:sbs_projer_app/presentation/providers/termin_providers.dart';
import 'package:sbs_projer_app/presentation/providers/pikett_providers.dart';
import 'package:sbs_projer_app/utils/schweizer_feiertage.dart';

class TermineKalenderScreen extends ConsumerStatefulWidget {
  const TermineKalenderScreen({super.key});

  @override
  ConsumerState<TermineKalenderScreen> createState() =>
      _TermineKalenderScreenState();
}

class _TermineKalenderScreenState
    extends ConsumerState<TermineKalenderScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _isGenerating = false;

  // Feiertage-Cache für sichtbare Jahre
  final Map<int, List<Feiertag>> _feiertagCache = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _cacheYear(_focusedDay.year);
  }

  void _cacheYear(int year) {
    if (!_feiertagCache.containsKey(year)) {
      _feiertagCache[year] = SchweizerFeiertage.feiertage(year);
    }
    // Auch Nachbarjahre cachen (Kalender zeigt oft Tage aus Vormonat/Nachmonat)
    if (!_feiertagCache.containsKey(year - 1)) {
      _feiertagCache[year - 1] = SchweizerFeiertage.feiertage(year - 1);
    }
    if (!_feiertagCache.containsKey(year + 1)) {
      _feiertagCache[year + 1] = SchweizerFeiertage.feiertage(year + 1);
    }
  }

  Feiertag? _getFeiertag(DateTime day) {
    final normDay = DateTime(day.year, day.month, day.day);
    final jahresFeiertage = _feiertagCache[day.year];
    if (jahresFeiertage == null) return null;
    for (final f in jahresFeiertage) {
      if (DateTime(f.datum.year, f.datum.month, f.datum.day) == normDay) {
        return f;
      }
    }
    return null;
  }

  List<TerminLocal> _getTermineForDay(
      DateTime day, List<TerminLocal> allTermine) {
    return allTermine.where((t) {
      final td = DateTime(t.datum.year, t.datum.month, t.datum.day);
      return td == DateTime(day.year, day.month, day.day);
    }).toList();
  }

  List<PikettDienstLocal> _getPikettForDay(
      DateTime day, List<PikettDienstLocal> allPikett) {
    final normDay = DateTime(day.year, day.month, day.day);
    return allPikett.where((p) {
      final start = DateTime(p.datumStart.year, p.datumStart.month, p.datumStart.day);
      final ende = DateTime(p.datumEnde.year, p.datumEnde.month, p.datumEnde.day);
      return !normDay.isBefore(start) && !normDay.isAfter(ende);
    }).toList();
  }

  Color _getTypColor(String typ) {
    switch (typ) {
      case 'eroeffnungsreinigung':
        return AppColors.success;
      case 'endreinigung':
        return AppColors.error;
      default:
        return AppColors.info;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'vorgeschlagen':
        return AppColors.warning;
      case 'geplant':
        return AppColors.info;
      case 'erledigt':
        return AppColors.success;
      case 'abgesagt':
        return AppColors.textSecondary;
      default:
        return AppColors.textSecondary;
    }
  }

  String _getTypLabel(String typ) {
    switch (typ) {
      case 'eroeffnungsreinigung':
        return 'Eröffnung';
      case 'endreinigung':
        return 'Endreinigung';
      default:
        return 'Sonstiges';
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'vorgeschlagen':
        return 'Vorgeschlagen';
      case 'geplant':
        return 'Geplant';
      case 'erledigt':
        return 'Erledigt';
      case 'abgesagt':
        return 'Abgesagt';
      default:
        return status;
    }
  }

  IconData _getTypIcon(String typ) {
    switch (typ) {
      case 'eroeffnungsreinigung':
        return Icons.play_circle_outline;
      case 'endreinigung':
        return Icons.stop_circle_outlined;
      default:
        return Icons.event;
    }
  }

  Future<void> _generiereVorschlaege() async {
    setState(() => _isGenerating = true);
    try {
      final vorschlaege = await TerminRepository.generiereVorschlaege();
      if (!mounted) return;
      ref.invalidate(termineStreamProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(vorschlaege.isEmpty
              ? 'Kalender aktualisiert — keine neuen Termine'
              : '${vorschlaege.length} neue Termin-Vorschläge erstellt'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final termine = ref.watch(termineProvider);
    final pikett = ref.watch(pikettDiensteProvider);
    final selectedDayTermine =
        _selectedDay != null ? _getTermineForDay(_selectedDay!, termine) : <TerminLocal>[];
    final selectedDayPikett =
        _selectedDay != null ? _getPikettForDay(_selectedDay!, pikett) : <PikettDienstLocal>[];
    final selectedDayFeiertag =
        _selectedDay != null ? _getFeiertag(_selectedDay!) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kalender'),
        actions: [
          IconButton(
            icon: _isGenerating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_fix_high),
            tooltip: 'Termine vorschlagen',
            onPressed: _isGenerating ? null : _generiereVorschlaege,
          ),
        ],
      ),
      body: Column(
        children: [
          TableCalendar<TerminLocal>(
            firstDay: DateTime(2024, 1, 1),
            lastDay: DateTime(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            locale: 'de_DE',
            startingDayOfWeek: StartingDayOfWeek.monday,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: (day) => _getTermineForDay(day, termine),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              setState(() => _calendarFormat = format);
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
              _cacheYear(focusedDay.year);
            },
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: AppColors.primary.withAlpha(75),
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(
                color: AppColors.info,
                shape: BoxShape.circle,
              ),
              markersMaxCount: 4,
              markerSize: 6,
            ),
            calendarBuilders: CalendarBuilders(
              // Feiertage + Pikett: farbig hervorheben
              defaultBuilder: (context, day, focusedDay) {
                final feiertag = _getFeiertag(day);
                final hatPikett = _getPikettForDay(day, pikett).isNotEmpty;

                if (feiertag == null && !hatPikett) return null;

                // Pikett + Feiertag: gesplitteter Hintergrund
                final bgColor = hatPikett && feiertag != null
                    ? const Color(0xFF7B1FA2) // Dunkel-Lila bei Kombination
                    : hatPikett
                        ? const Color(0xFF9C27B0) // Lila für Pikett
                        : AppColors.error; // Rot für Feiertag

                return Center(
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: bgColor.withAlpha(hatPikett ? 40 : 20),
                      shape: BoxShape.circle,
                      border: hatPikett
                          ? Border.all(color: const Color(0xFF9C27B0), width: 2)
                          : null,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            color: feiertag != null
                                ? AppColors.error
                                : const Color(0xFF7B1FA2),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        // "P"-Badge oben rechts bei Pikett
                        if (hatPikett)
                          Positioned(
                            top: 1,
                            right: 1,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: Color(0xFF9C27B0),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Text(
                                  'P',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 7,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
              // Marker: Termine (farbig nach Typ)
              markerBuilder: (context, day, events) {
                if (events.isEmpty) return null;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: events.take(3).map((t) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _getTypColor(t.typ),
                        shape: BoxShape.circle,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            headerStyle: const HeaderStyle(
              formatButtonShowsNext: false,
              titleCentered: true,
            ),
          ),
          const Divider(height: 1),
          // Detail-Liste für ausgewählten Tag
          Expanded(
            child: _buildDayDetailList(
              selectedDayFeiertag,
              selectedDayPikett,
              selectedDayTermine,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final datumParam = _selectedDay != null
              ? '?datum=${_selectedDay!.toIso8601String().split('T').first}'
              : '';
          context.push('/termine/neu$datumParam');
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildDayDetailList(
    Feiertag? feiertag,
    List<PikettDienstLocal> pikettList,
    List<TerminLocal> terminList,
  ) {
    final hasContent = feiertag != null || pikettList.isNotEmpty || terminList.isNotEmpty;

    if (!hasContent) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 8),
            Text(
              _selectedDay != null
                  ? 'Keine Einträge am ${DateFormat('d. MMMM yyyy', 'de_DE').format(_selectedDay!)}'
                  : 'Tag auswählen',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // Feiertag
        if (feiertag != null)
          _FeiertagCard(feiertag: feiertag),

        // Pikett-Dienste
        for (final p in pikettList)
          _PikettCard(
            pikett: p,
            onTap: () => context.push('/pikett/${p.routeId}'),
          ),

        // Termine
        for (final termin in terminList)
          _TerminCard(
            termin: termin,
            typColor: _getTypColor(termin.typ),
            statusColor: _getStatusColor(termin.status),
            typLabel: _getTypLabel(termin.typ),
            statusLabel: _getStatusLabel(termin.status),
            typIcon: _getTypIcon(termin.typ),
            onTap: () => context.push('/termine/${termin.routeId}/bearbeiten'),
          ),
      ],
    );
  }
}

// ─── Feiertag-Card ───

class _FeiertagCard extends StatelessWidget {
  final Feiertag feiertag;
  const _FeiertagCard({required this.feiertag});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.error.withAlpha(15),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.flag, color: AppColors.error, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feiertag.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    feiertag.istBeweglich ? 'Beweglicher Feiertag' : 'Feiertag',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Pikett-Card ───

class _PikettCard extends StatelessWidget {
  final PikettDienstLocal pikett;
  final VoidCallback onTap;
  const _PikettCard({required this.pikett, required this.onTap});

  static int _isoKw(DateTime date) {
    final d = DateTime.utc(date.year, date.month, date.day);
    final thursday = d.add(Duration(days: DateTime.thursday - d.weekday));
    final jan1 = DateTime.utc(thursday.year, 1, 1);
    return (thursday.difference(jan1).inDays / 7).floor() + 1;
  }

  @override
  Widget build(BuildContext context) {
    final kw = _isoKw(pikett.datumStart);
    final betrag = pikett.pauschaleGesamt ?? pikett.pauschale ?? 80.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF9C27B0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.nightlight_round,
                  color: Color(0xFF9C27B0), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pikett-Dienst KW $kw',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF9C27B0).withAlpha(25),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Pikett',
                            style: TextStyle(
                              color: Color(0xFF9C27B0),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${betrag.toStringAsFixed(2)} CHF',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Termin-Card ───

class _TerminCard extends StatelessWidget {
  final TerminLocal termin;
  final Color typColor;
  final Color statusColor;
  final String typLabel;
  final String statusLabel;
  final IconData typIcon;
  final VoidCallback onTap;

  const _TerminCard({
    required this.termin,
    required this.typColor,
    required this.statusColor,
    required this.typLabel,
    required this.statusLabel,
    required this.typIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final zeitStr = [
      if (termin.uhrzeitVon != null) termin.uhrzeitVon,
      if (termin.uhrzeitBis != null) '– ${termin.uhrzeitBis}',
    ].join(' ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: typColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Icon(typIcon, color: typColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            termin.titel,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (termin.erinnerungAktiv)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.notifications_active,
                                size: 14, color: Colors.orange),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(25),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          typLabel,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        if (zeitStr.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            zeitStr,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

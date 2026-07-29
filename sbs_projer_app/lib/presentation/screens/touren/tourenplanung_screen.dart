import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/besuch_buendelung.dart';
import 'package:sbs_projer_app/core/util/besuch_dauer.dart';
import 'package:sbs_projer_app/core/util/fahrzeit.dart';
import 'package:sbs_projer_app/core/util/tour_filter.dart';
import 'package:sbs_projer_app/core/util/touren_anzeige.dart';
import 'package:sbs_projer_app/core/util/touren_saison.dart';
import 'package:sbs_projer_app/core/util/zeitplan.dart';
import 'package:sbs_projer_app/data/local/anlage_local_export.dart';
import 'package:sbs_projer_app/data/repositories/fahrzeit_repository.dart';
import 'package:sbs_projer_app/presentation/providers/anlage_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/filter/app_filter_bar.dart';
import 'package:sbs_projer_app/presentation/widgets/filter/tour_filter_leiste.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/zeitplan_leiste.dart';

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
    final faelligeEintraege = ref.watch(
      faelligeEintraegeProvider(_selectedDate),
    );
    final autoTermine = ref.watch(autoTermineProvider(_selectedDate));

    // Reaktives Laden: gespeicherter Plan hat Vorrang vor Vorschlag.
    final gespeichertAsync = ref.watch(
      gespeicherterTagesplanProvider(_selectedDate),
    );
    if (_loadedForDate != _selectedDate) {
      final tag = _selectedDate;
      void anwenden(GespeicherterTagesplan? gespeichert) {
        _loadedForDate = tag;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          // Arbeitstag-Rahmen übernehmen: liegt eine Zeile vor, ist sie für
          // Ende und km-Stand massgebend (auch leer — sonst käme ein gerade
          // gelöschter Wert beim nächsten Öffnen wieder). Nur beim Beginn
          // bleibt der Standard 06:00 stehen, wenn nichts gepflegt ist.
          if (gespeichert != null) {
            final aktuell = ref.read(arbeitstagProvider(tag));
            ref.read(arbeitstagProvider(tag).notifier).state = (
              beginn: gespeichert.arbeitsbeginn ?? aktuell.beginn,
              ende: gespeichert.arbeitsende,
              km: gespeichert.kmStand,
            );
          }
          final notifier = ref.read(tagesplanProvider.notifier);
          // Race-Schutz: hat der User diesen Tag inzwischen bereits bearbeitet,
          // seinen Stand NICHT mit dem (evtl. älteren) Lade-Fetch überschreiben.
          if (notifier.datum == tag) return;
          if (gespeichert != null) {
            notifier.setFromGespeichert(tag, gespeichert.eintraege);
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

    // Filter (Region + Fälligkeit) — nur für die „Fällig"-Liste (Auswahl,
    // was in den Plan übernommen wird).
    bool passesFilter(TourEintrag e) {
      // Region-Filter
      if (selectedRegionen.isNotEmpty &&
          e.regionId != null &&
          !selectedRegionen.contains(e.regionId)) {
        return false;
      }
      // Fälligkeits-Filter nur auf Reinigungen; Störungen/Montagen durchlassen.
      if (selectedFaelligkeit.isNotEmpty && e.typ == TourEintragTyp.reinigung) {
        if (e.faelligkeit == null ||
            !sichtbarImTourfilter(e.faelligkeit!, selectedFaelligkeit)) {
          return false;
        }
      }
      return true;
    }

    // Tagesplan: KEIN Filter — zeigt den vollständigen Plan in EXAKT der
    // Eingabe-/manuellen Reihenfolge. Ein Filter würde die Anzeige-Indizes
    // gegenüber dem State verschieben → Drag-Reorder träfe die falschen
    // Einträge und die Reihenfolge ginge kaputt.
    final angezeigtTagesplan = tagesplan;
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
                options: [for (final r in regionen) (r.routeId, r.name)],
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
          TourFilterLeiste(
            ausgewaehlt: selectedFaelligkeit,
            onChanged: (updated) {
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
                      onPlanUebernehmen: _planVonDatumUebernehmen,
                    ),
                    _ArbeitstagZeile(datum: _selectedDate),
                    if (autoTermine.isNotEmpty)
                      _AutoTermineSektion(
                        eintraege: autoTermine,
                        onUebernehmen: (e) => ref
                            .read(tagesplanProvider.notifier)
                            .hinzufuegen(e.alsPlanEintrag()),
                        onAlleUebernehmen: () {
                          final notifier = ref.read(tagesplanProvider.notifier);
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
                          : _TagesplanZeitachse(
                              datum: _selectedDate,
                              eintraege: angezeigtTagesplan,
                              onReorder: (old, neu) => ref
                                  .read(tagesplanProvider.notifier)
                                  .reorder(old, neu),
                              onDismiss: (id) => ref
                                  .read(tagesplanProvider.notifier)
                                  .entfernen(id),
                            ),
                    ),
                  ],
                ),

                // === Tab 2: Fällig ===
                Column(
                  children: [
                    _warnungSaisonAnker(),
                    Expanded(
                      child: angezeigtFaellig.isEmpty
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
                                  onAdd: () => _faelligEintragUebernehmen(e),
                                  onTap: () => _navigateToDetail(e),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _warnungSaisonAnker() {
    final fehlt = ref.watch(saisonAnkerFehltProvider);
    if (fehlt.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: InkWell(
        onTap: () => showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('${fehlt.length} Betriebe ohne Saisonstart'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Text(
                  '${fehlt.map((b) => b.ort != null && b.ort!.isNotEmpty ? '${b.name} ${b.ort}' : b.name).join('\n')}\n\n'
                  'Endreinigung erledigt, aber kein künftiger Saisonstart/'
                  'Ferien-Ende gepflegt — die Fälligkeits-Uhr kann nicht starten. '
                  'Bitte Saisondaten im Betrieb ergänzen.',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.warning.withAlpha(30),
            border: Border.all(color: AppColors.warning.withAlpha(100)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.event_busy, color: AppColors.warning, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${fehlt.length} Betriebe: Endreinigung ohne Saisonstart — Uhr kann nicht starten',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.warning,
                size: 18,
              ),
            ],
          ),
        ),
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
            Icon(
              Icons.route,
              size: 64,
              color: AppColors.textSecondary.withAlpha(100),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  /// Fällig-Tab „in den Plan"-Aktion: bündelt Reinigungen beim selben
  /// Betrieb statt einen zweiten Besuchs-Block anzulegen (Spec §1). Die
  /// heute fälligen Geschwister-Anlagen des Betriebs kommen bewusst aus
  /// `faelligeAnlagenProvider`, NICHT aus der (evtl. gefilterten)
  /// Fällig-Eintragsliste: seit v0.54.17 lässt der «Alle»-Filter dort auch
  /// nicht fällige Anlagen durch — Spec §1 verlangt aber ausdrücklich nur
  /// die heute FÄLLIGEN Geschwister (Review 29.07.2026).
  void _faelligEintragUebernehmen(TourEintrag eintrag) {
    final notifier = ref.read(tagesplanProvider.notifier);
    final planVorher = ref.read(tagesplanProvider);
    final betriebId = eintrag.betriebId;
    final faelligeGeschwister = betriebId == null
        ? const <String>[]
        : faelligeAnlagenRouteIdsFuerBetrieb(
            ref.read(faelligeAnlagenProvider(_selectedDate)),
            betriebId,
          );

    final neuerPlan = buendleInPlan(
      plan: planVorher,
      neu: eintrag,
      faelligeAnlagenDesBetriebs: faelligeGeschwister,
    );
    // Gleiche Länge wie vorher = in bestehenden Besuch gebündelt (kein neuer
    // Eintrag angehängt) — das ist der Fall, der ohne Hinweis unbemerkt
    // bliebe (der neue Block wäre ja sonst sichtbar im Tagesplan-Tab).
    final wurdeGebuendelt = neuerPlan.length == planVorher.length;
    notifier.setzePlan(neuerPlan);

    if (wurdeGebuendelt && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text('Anlage zu ${eintrag.betriebName} hinzugefügt'),
        ),
      );
    }
  }

  /// Menüpunkt „Plan von Datum übernehmen" (Spec §6): Einträge eines anderen
  /// Tages in identischer Reihenfolge an den aktuellen Plan anhängen.
  /// Betriebe, die im Zielplan schon einen Reinigungs-Besuch haben, werden
  /// nicht dupliziert; Besuche, deren Betrieb heute keine fällige Anlage
  /// hat, kommen als `uebernommen = true` (graue Darstellung) mit.
  Future<void> _planVonDatumUebernehmen() async {
    final heuteReal = DateTime.now();
    final heuteDatum = DateTime(heuteReal.year, heuteReal.month, heuteReal.day);
    final gewaehlt = await showDatePicker(
      context: context,
      initialDate: heuteDatum.subtract(const Duration(days: 1)),
      firstDate: DateTime(2025, 1, 1),
      lastDate: heuteDatum.add(const Duration(days: 365)),
      helpText: 'Plan von welchem Tag übernehmen?',
    );
    if (gewaehlt == null || !mounted) return;
    final quelltag = DateTime(gewaehlt.year, gewaehlt.month, gewaehlt.day);

    final quelle = await ref.read(
      gespeicherterTagesplanProvider(quelltag).future,
    );
    if (!mounted) return;
    if (quelle == null || quelle.eintraege.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kein gespeicherter Plan am ${_formatDate(quelltag)}'),
        ),
      );
      return;
    }

    // Heute fällige Betriebe — massgebend für die „uebernommen"-Markierung.
    // Bewusst `faelligeAnlagenProvider`, NICHT `faelligeEintraegeProvider`:
    // letzterer folgt intern dem UI-Fällig-Filter — bei aktivem «Alle»-
    // Filter (seit v0.54.17) gälten dann ALLE Betriebe als „fällig" und kein
    // übernommener Besuch würde je grau markiert (Review 29.07.2026).
    final faelligeBetriebe = faelligeBetriebIds(
      ref.read(faelligeAnlagenProvider(_selectedDate)),
    );

    final planVorher = ref.read(tagesplanProvider);
    final vorhandeneBetriebe = {
      for (final e in planVorher)
        if (e.typ == TourEintragTyp.reinigung && e.betriebId != null)
          e.betriebId!,
    };
    final vorhandeneIds = planVorher.map((e) => e.id).toSet();

    final uebernahme = <TourEintrag>[];
    for (final original in quelle.eintraege) {
      final istReinigung = original.typ == TourEintragTyp.reinigung;
      if (istReinigung &&
          original.betriebId != null &&
          vorhandeneBetriebe.contains(original.betriebId)) {
        continue; // Betrieb hat im Zielplan schon einen Besuch
      }

      var eintrag = original.alsPlanEintrag();
      if (istReinigung) {
        final heuteFaellig =
            eintrag.betriebId != null &&
            faelligeBetriebe.contains(eintrag.betriebId);
        eintrag = eintrag.copyWith(uebernommen: !heuteFaellig);
      }
      // ID-Kollision (z.B. zweimalige Übernahme desselben Quelltags):
      // NUR dann umbenennen, wenn die ID im Zielplan bereits existiert —
      // sonst bleibt die Original-ID stehen, damit z.B. „Reinigung starten"
      // weiter auf denselben Eintrag verweist wie am Quelltag.
      if (vorhandeneIds.contains(eintrag.id)) {
        eintrag = eintrag.mitId(
          'u_${eintrag.id}_${quelltag.millisecondsSinceEpoch}',
        );
      }
      vorhandeneIds.add(eintrag.id);
      if (istReinigung && eintrag.betriebId != null) {
        vorhandeneBetriebe.add(eintrag.betriebId!);
      }
      uebernahme.add(eintrag);
    }

    ref.read(tagesplanProvider.notifier).setzePlan([
      ...planVorher,
      ...uebernahme,
    ]);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${uebernahme.length} Einträge übernommen')),
    );
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
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
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
          final isSelected =
              day.year == selectedDate.year &&
              day.month == selectedDate.month &&
              day.day == selectedDate.day;
          final isToday =
              day.year == todayDate.year &&
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
                      color: isSelected
                          ? Colors.white
                          : AppColors.textSecondary,
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
                        horizontal: 5,
                        vertical: 1,
                      ),
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
  final VoidCallback onPlanUebernehmen;

  const _TagesplanHeader({
    required this.datum,
    required this.onLeeren,
    required this.onAusFaelligBefuellen,
    required this.onPlanUebernehmen,
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
          IconButton(
            onPressed: onPlanUebernehmen,
            icon: const Icon(Icons.history, size: 20),
            tooltip: 'Plan von Datum übernehmen',
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          TextButton.icon(
            onPressed: onAusFaelligBefuellen,
            icon: const Icon(Icons.playlist_add, size: 18),
            label: const Text(
              'Fällige übernehmen',
              style: TextStyle(fontSize: 12),
            ),
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

// ─── Typ-Farben/-Symbole (geteilt von Fällig-Liste und Zeitachse) ───

Color _typColor(TourEintragTyp typ) {
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

IconData _typIcon(TourEintragTyp typ) {
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

// ─── Zeitachse: Dauer- und Fahrzeit-Helfer ───

/// Anlagen dieses Besuchs. `anlageIds` ist fachlich führend; Alt-Einträge
/// tragen nur das einzelne `anlageId`.
List<String> _besuchsAnlagen(TourEintrag e) => e.anlageIds.isNotEmpty
    ? e.anlageIds
    : [if (e.anlageId != null) e.anlageId!];

/// Wirksame Dauer eines Plan-Eintrags: manuelle Übersteuerung hat Vorrang,
/// sonst die Median-Schätzung aus der Betriebs-Historie (Reinigung) bzw. der
/// Standardwert für Störung/Montage (Spec 2026-07-29 §2).
int _dauerFuer(TourEintrag e, Map<String, List<BesuchHistorie>> historie) {
  final manuell = e.dauerMinuten;
  if (manuell != null) return manuell;
  if (e.typ != TourEintragTyp.reinigung) return kDauerDefaultMinuten;
  final hist = e.betriebId != null
      ? (historie[e.betriebId!] ?? const <BesuchHistorie>[])
      : const <BesuchHistorie>[];
  final anlagen = _besuchsAnlagen(e).length;
  return geschaetzteDauer(
    historie: hist,
    anlagenZahl: anlagen == 0 ? 1 : anlagen,
  );
}

/// Fahrzeit, wenn zu mindestens einem der beiden Betriebe die Koordinaten
/// fehlen: nicht 0 (das würde eine Fahrt verschlucken) und nicht die
/// Heuristik (ohne GPS nicht berechenbar) — ein neutraler Ansatz, den die
/// erste beobachtete Fahrt später ersetzt.
const int _kFahrzeitOhneGps = 15;

// ─── Tagesplan als Zeitachse ───

class _TagesplanZeitachse extends ConsumerStatefulWidget {
  final DateTime datum;
  final List<TourEintrag> eintraege;
  final void Function(int, int) onReorder;
  final void Function(String) onDismiss;

  const _TagesplanZeitachse({
    required this.datum,
    required this.eintraege,
    required this.onReorder,
    required this.onDismiss,
  });

  @override
  ConsumerState<_TagesplanZeitachse> createState() =>
      _TagesplanZeitachseState();
}

class _TagesplanZeitachseState extends ConsumerState<_TagesplanZeitachse> {
  /// Bereits bei der Edge-Function angefragte Strecken — verhindert, dass
  /// jeder Rebuild dieselbe Route erneut anfordert.
  final Set<String> _routeAngefragt = {};

  @override
  Widget build(BuildContext context) {
    final lookup = ref.watch(betriebLookupProvider);
    final historie = ref.watch(besuchHistorieProvider);
    final fahrzeiten =
        ref.watch(fahrzeitenMapProvider).valueOrNull ??
        const <String, FahrzeitEintrag>{};
    final arbeitstag = ref.watch(arbeitstagProvider(widget.datum));
    final anlagen = ref.watch(anlagenProvider);

    final eintraege = widget.eintraege;
    final byId = {for (final e in eintraege) e.id: e};

    // Nenner des Chips «n von m Anlagen»: aktive Anlagen je Betrieb.
    final anlagenJeBetrieb = <String, int>{};
    for (final a in anlagen) {
      if (a.status != 'aktiv') continue;
      final key = lookup[a.betriebId]?.routeId ?? a.betriebId;
      anlagenJeBetrieb[key] = (anlagenJeBetrieb[key] ?? 0) + 1;
    }

    // Quelle je Fahrt (für den Punkt an der Fahrt-Zeile) und die Paare ohne
    // gelernten/gerouteten Wert. Beides fällt beim Durchlaufen der Kaskade an,
    // die `berechneZeitplan` genau einmal je Übergang aufruft.
    final fahrtQuellen = <String, String>{};
    final fehlendePaare = <({String von, String nach})>[];

    int fahrzeitZwischen(String vonBlockId, String nachBlockId) {
      final vonBetrieb = byId[vonBlockId]?.betriebId;
      final nachBetrieb = byId[nachBlockId]?.betriebId;
      if (vonBetrieb == null || nachBetrieb == null) {
        fahrtQuellen[nachBlockId] = 'heuristik';
        return _kFahrzeitOhneGps;
      }
      // Zwei Einträge beim selben Betrieb (z.B. Reinigung + Störung): keine
      // Fahrt dazwischen.
      if (vonBetrieb == nachBetrieb) return 0;

      final gelernt = FahrzeitRepository.ausMap(
        fahrzeiten,
        vonBetrieb,
        nachBetrieb,
      );
      if (gelernt != null) {
        fahrtQuellen[nachBlockId] = gelernt.quelle;
        return gelernt.minuten;
      }

      fehlendePaare.add((von: vonBetrieb, nach: nachBetrieb));
      fahrtQuellen[nachBlockId] = 'heuristik';
      final bv = lookup[vonBetrieb];
      final bn = lookup[nachBetrieb];
      if (bv?.latitude != null &&
          bv?.longitude != null &&
          bn?.latitude != null &&
          bn?.longitude != null) {
        return heuristikMinuten(
          luftlinieKm: haversineKm(
            bv!.latitude!,
            bv.longitude!,
            bn!.latitude!,
            bn.longitude!,
          ),
        );
      }
      return _kFahrzeitOhneGps;
    }

    final segmente = berechneZeitplan(
      bloecke: [
        for (final e in eintraege)
          PlanBlock(
            id: e.id,
            dauerMinuten: _dauerFuer(e, historie),
            ankerZeit: e.ankerZeit,
          ),
      ],
      arbeitsbeginn: arbeitstag.beginn,
      // Startort (Zuhause) kommt in Task 8 aus den Geschäftseinstellungen —
      // null heisst hier: keine Anfahrt-/Heimweg-Segmente zeichnen.
      anfahrtMinuten: null,
      heimwegMinuten: null,
      fahrzeitZwischen: fahrzeitZwischen,
    );

    final besuchSeg = <String, ZeitSegment>{};
    final fahrtSeg = <String, ZeitSegment>{};
    final warteSeg = <String, ZeitSegment>{};
    ZeitSegment? anfahrt;
    ZeitSegment? heimweg;
    for (final s in segmente) {
      switch (s.art) {
        case SegmentArt.anfahrt:
          anfahrt = s;
        case SegmentArt.heimweg:
          heimweg = s;
        case SegmentArt.besuch:
          if (s.blockId != null) besuchSeg[s.blockId!] = s;
        case SegmentArt.fahrt:
          if (s.blockId != null) fahrtSeg[s.blockId!] = s;
        case SegmentArt.wartezeit:
          if (s.blockId != null) warteSeg[s.blockId!] = s;
      }
    }

    if (fehlendePaare.isNotEmpty) {
      // Nach dem Frame, nie während des Builds (Provider-Invalidierung).
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _routenAnfordern(fehlendePaare),
      );
    }

    return Column(
      children: [
        if (anfahrt != null)
          RandSegmentZeile(segment: anfahrt, label: 'Anfahrt'),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.only(top: 4, bottom: 24),
            buildDefaultDragHandles: false,
            itemCount: eintraege.length,
            onReorder: widget.onReorder,
            proxyDecorator: (child, index, animation) =>
                Material(elevation: 4, color: Colors.transparent, child: child),
            itemBuilder: (context, index) {
              final eintrag = eintraege[index];
              final segment = besuchSeg[eintrag.id];
              // Sicherheitsnetz: ohne Segment (dürfte nicht vorkommen) bleibt
              // die Zeile leer, statt die ganze Liste scheitern zu lassen.
              if (segment == null) {
                return SizedBox.shrink(key: ValueKey(eintrag.id));
              }

              final betrieb = eintrag.betriebId == null
                  ? null
                  : lookup[eintrag.betriebId!];
              final ruhetagKonflikt =
                  betrieb != null && !istOffenerTag(betrieb, widget.datum);
              // Spec §4: der ganze Besuch (Ankunft bis Ende) muss ins
              // Servicefenster passen, nicht nur die Ankunft.
              final servicezeitKonflikt =
                  betrieb != null &&
                  besuchAusserhalbServicezeit(
                    segment.startMin,
                    segment.endMin,
                    betrieb.servicezeitMorgenAb,
                    betrieb.servicezeitMorgenBis,
                    betrieb.servicezeitNachmittagAb,
                    betrieb.servicezeitNachmittagBis,
                  );
              // Vorschlag nur, wenn nach der Ankunft noch ein Fenster beginnt.
              final vorschlagMin = servicezeitKonflikt
                  ? naechsterFensterStart(
                      segment.startMin,
                      betrieb.servicezeitMorgenAb,
                      betrieb.servicezeitMorgenBis,
                      betrieb.servicezeitNachmittagAb,
                      betrieb.servicezeitNachmittagBis,
                    )
                  : null;

              final betriebKey = betrieb?.routeId ?? eintrag.betriebId;
              final gesamt = betriebKey != null
                  ? (anlagenJeBetrieb[betriebKey] ?? 0)
                  : 0;

              return Dismissible(
                key: ValueKey(eintrag.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: AppColors.error.withAlpha(30),
                  child: const Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                  ),
                ),
                onDismissed: (_) => widget.onDismiss(eintrag.id),
                child: ZeitplanZeile(
                  segment: segment,
                  fahrtDavor: fahrtSeg[eintrag.id],
                  wartezeitDavor: warteSeg[eintrag.id],
                  eintrag: eintrag,
                  anlagenGesamt: gesamt,
                  dauerGeschaetzt: eintrag.dauerMinuten == null,
                  ruhetagKonflikt: ruhetagKonflikt,
                  servicezeitKonflikt: servicezeitKonflikt,
                  fahrtQuelle: fahrtQuellen[eintrag.id],
                  ankerVorschlag: vorschlagMin != null
                      ? hhmmAusMinuten(vorschlagMin)
                      : null,
                  onAnkerVorschlag: vorschlagMin != null
                      ? () => ref
                            .read(tagesplanProvider.notifier)
                            .ersetze(
                              eintrag.id,
                              eintrag.copyWith(
                                ankerZeit: hhmmAusMinuten(vorschlagMin),
                              ),
                            )
                      : null,
                  dragHandle: ReorderableDragStartListener(
                    index: index,
                    child: Container(
                      width: 44,
                      alignment: Alignment.center,
                      color: AppColors.textSecondary.withAlpha(12),
                      child: const Icon(
                        Icons.drag_indicator,
                        color: AppColors.textSecondary,
                        size: 26,
                      ),
                    ),
                  ),
                  onTap: () => _oeffneBlockSheet(eintrag),
                ),
              );
            },
          ),
        ),
        if (heimweg != null)
          RandSegmentZeile(segment: heimweg, label: 'Heimweg'),
      ],
    );
  }

  /// Fehlende Strecken einmalig bei der Edge-Function anfragen (fire and
  /// forget). Kommt ein Wert zurück, wird die Fahrzeit-Map neu geladen und
  /// die Zeitachse rechnet mit dem gerouteten statt dem geschätzten Wert.
  Future<void> _routenAnfordern(List<({String von, String nach})> paare) async {
    var erfolg = false;
    for (final p in paare) {
      final key = '${p.von}>${p.nach}';
      if (!_routeAngefragt.add(key)) continue;
      final res = await FahrzeitRepository.routeAnfordern(p.von, p.nach);
      if (res != null) erfolg = true;
    }
    if (erfolg && mounted) ref.invalidate(fahrzeitenMapProvider);
  }

  void _oeffneBlockSheet(TourEintrag eintrag) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BlockSheet(eintragId: eintrag.id),
    );
  }
}

// ─── Block-Sheet: Anlagen, Dauer, Anker, Entfernen ───

class _BlockSheet extends ConsumerWidget {
  final String eintragId;

  const _BlockSheet({required this.eintragId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(tagesplanProvider);
    final treffer = plan.where((e) => e.id == eintragId);
    // Eintrag inzwischen entfernt (z.B. per Swipe) → Sheet leeren statt
    // auf einem verwaisten Stand weiterzuarbeiten.
    if (treffer.isEmpty) return const SizedBox.shrink();
    final eintrag = treffer.first;

    final lookup = ref.watch(betriebLookupProvider);
    final historie = ref.watch(besuchHistorieProvider);
    final betrieb = eintrag.betriebId == null
        ? null
        : lookup[eintrag.betriebId!];
    final gewaehlt = _besuchsAnlagen(eintrag);
    final dauer = _dauerFuer(eintrag, historie);

    // Aktive Anlagen des Betriebs. `AnlageLocal.betriebId` und
    // `TourEintrag.betriebId` tragen dieselbe Id-Konvention (Server-Id); der
    // Vergleich läuft trotzdem über den aufgelösten Betrieb, damit ein
    // Eintrag mit routeId statt serverId nicht durchfällt.
    final anlagen = <AnlageLocal>[
      if (betrieb != null)
        for (final a in ref.watch(anlagenProvider))
          if (a.status == 'aktiv' &&
              lookup[a.betriebId]?.routeId == betrieb.routeId)
            a,
    ];

    void ersetze(TourEintrag neu) =>
        ref.read(tagesplanProvider.notifier).ersetze(eintragId, neu);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Griff
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Row(
                  children: [
                    Icon(
                      _typIcon(eintrag.typ),
                      size: 18,
                      color: _typColor(eintrag.typ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        eintrag.betriebOrt != null &&
                                eintrag.betriebOrt!.isNotEmpty
                            ? '${eintrag.betriebName} - ${eintrag.betriebOrt}'
                            : eintrag.betriebName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ─── Anlagen (nur Reinigung) ───
              if (eintrag.typ == TourEintragTyp.reinigung) ...[
                const _SheetTitel('Anlagen dieses Besuchs'),
                if (anlagen.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      'Keine aktiven Anlagen gefunden.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                for (final a in anlagen)
                  _AnlageZeile(
                    anlage: a,
                    gewaehlt: gewaehlt.contains(a.routeId),
                    onTap: () {
                      final neu = List<String>.of(gewaehlt);
                      final abwahl = neu.contains(a.routeId);
                      // Ein Besuch ohne Anlage ergibt fachlich nichts: die
                      // Dauer-Schätzung fiele auf «1 Anlage» zurück und
                      // «Reinigung starten» hätte kein Ziel mehr. Wer den
                      // Besuch loswerden will, entfernt ihn unten ganz.
                      if (abwahl && neu.length <= 1) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            duration: Duration(seconds: 3),
                            content: Text(
                              'Letzte Anlage — zum Entfernen des Besuchs '
                              'unten «Aus Plan entfernen»',
                            ),
                          ),
                        );
                        return;
                      }
                      if (abwahl) {
                        neu.remove(a.routeId);
                      } else {
                        neu.add(a.routeId);
                      }
                      // `dauerMinuten` bleibt unangetastet: ist nichts manuell
                      // gesetzt, folgt die Schätzung automatisch der neuen
                      // Anlagenzahl. `anlageId` (erste Anlage) bleibt als
                      // Kompatibilitäts-Feld für «Reinigung starten» erhalten.
                      ersetze(
                        eintrag.copyWith(anlageIds: neu, anlageId: neu.first),
                      );
                    },
                  ),
              ],

              // ─── Dauer ───
              const _SheetTitel('Dauer'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    _RundKnopf(
                      icon: Icons.remove,
                      onTap: () => ersetze(
                        eintrag.copyWith(
                          dauerMinuten: dauer - 5 < 10 ? 10 : dauer - 5,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '${eintrag.dauerMinuten == null ? '~' : ''}$dauer min',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    _RundKnopf(
                      icon: Icons.add,
                      onTap: () =>
                          ersetze(eintrag.copyWith(dauerMinuten: dauer + 5)),
                    ),
                  ],
                ),
              ),
              if (eintrag.dauerMinuten != null)
                _SheetAktion(
                  icon: Icons.restart_alt,
                  text: 'auf Schätzung zurücksetzen',
                  onTap: () => ersetze(eintrag.copyWith(dauerMinuten: null)),
                ),

              // ─── Termin-Anker ───
              const _SheetTitel('Termin-Anker (frühestens ab)'),
              Row(
                children: [
                  Expanded(
                    child: _SheetAktion(
                      icon: Icons.push_pin_outlined,
                      text: eintrag.ankerZeit ?? '—',
                      onTap: () async {
                        final jetzt =
                            minutenAusHhmm(eintrag.ankerZeit) ?? 8 * 60;
                        final gewaehltZeit = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(
                            hour: jetzt ~/ 60,
                            minute: jetzt % 60,
                          ),
                        );
                        if (gewaehltZeit == null) return;
                        ersetze(
                          eintrag.copyWith(
                            ankerZeit: hhmmAusMinuten(
                              gewaehltZeit.hour * 60 + gewaehltZeit.minute,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (eintrag.ankerZeit != null)
                    GestureDetector(
                      onTap: () => ersetze(eintrag.copyWith(ankerZeit: null)),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(right: 16),
                        child: const Icon(
                          Icons.close,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),

              const Divider(height: 20),
              _SheetAktion(
                icon: Icons.delete_outline,
                text: 'Aus Plan entfernen',
                farbe: AppColors.error,
                onTap: () {
                  ref.read(tagesplanProvider.notifier).entfernen(eintragId);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetTitel extends StatelessWidget {
  final String text;

  const _SheetTitel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// Tippbare Zeile im Sheet — bewusst GestureDetector + Container statt eines
/// Material-Buttons (CanvasKit-Regel: Material-Buttons in Sheets werden auf
/// Web nicht zuverlässig gezeichnet).
class _SheetAktion extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color farbe;
  final VoidCallback onTap;

  const _SheetAktion({
    required this.icon,
    required this.text,
    required this.onTap,
    this.farbe = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: farbe),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: farbe,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RundKnopf extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RundKnopf({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
    );
  }
}

class _AnlageZeile extends StatelessWidget {
  final AnlageLocal anlage;
  final bool gewaehlt;
  final VoidCallback onTap;

  const _AnlageZeile({
    required this.anlage,
    required this.gewaehlt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(
              gewaehlt ? Icons.check_box : Icons.check_box_outline_blank,
              size: 22,
              color: gewaehlt ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${anlage.bezeichnung ?? anlage.typAnlage} · '
                '${anlage.anzahlHaehne} Hähne',
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Arbeitstag: Start / Ende + km ───

class _ArbeitstagZeile extends ConsumerWidget {
  final DateTime datum;

  const _ArbeitstagZeile({required this.datum});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final at = ref.watch(arbeitstagProvider(datum));

    Future<void> speichern(Arbeitstag neu) async {
      ref.read(arbeitstagProvider(datum).notifier).state = neu;
      // Datum-Guard: gehört der In-Memory-Plan inzwischen einem anderen Tag
      // (Tagwechsel während des Dialogs), würde der Fallback-Pfad die Einträge
      // des Vortags auf diesen Tag schreiben. Dann lieber gar nicht speichern.
      if (ref.read(tagesplanProvider.notifier).datum != datum) return;
      try {
        await arbeitstagFelderSpeichern(
          datum,
          ref.read(tagesplanProvider),
          arbeitsbeginn: neu.beginn,
          arbeitsende: neu.ende,
          kmStand: neu.km,
        );
        ref.invalidate(gespeicherterTagesplanProvider(datum));
      } catch (e) {
        debugPrint('[Arbeitstag] Speichern fehlgeschlagen: $e');
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Row(
        children: [
          _TippFeld(
            icon: Icons.schedule,
            text: 'Start ${at.beginn}',
            onTap: () async {
              final start = minutenAusHhmm(at.beginn) ?? 6 * 60;
              final gewaehlt = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(hour: start ~/ 60, minute: start % 60),
              );
              if (gewaehlt == null) return;
              await speichern((
                beginn: hhmmAusMinuten(gewaehlt.hour * 60 + gewaehlt.minute),
                ende: at.ende,
                km: at.km,
              ));
            },
          ),
          const Spacer(),
          _TippFeld(
            icon: Icons.flag_outlined,
            text:
                'Ende ${at.ende ?? '—'} · ${at.km != null ? '${at.km} km' : '— km'}',
            onTap: () async {
              final ergebnis = await showModalBottomSheet<Arbeitstag>(
                context: context,
                isScrollControlled: true,
                builder: (_) => _ArbeitstagSheet(aktuell: at),
              );
              if (ergebnis == null) return;
              await speichern(ergebnis);
            },
          ),
        ],
      ),
    );
  }
}

class _TippFeld extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _TippFeld({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppColors.primary),
            const SizedBox(width: 5),
            Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Abend-Erfassung: Arbeitsende und km-Stand.
class _ArbeitstagSheet extends StatefulWidget {
  final Arbeitstag aktuell;

  const _ArbeitstagSheet({required this.aktuell});

  @override
  State<_ArbeitstagSheet> createState() => _ArbeitstagSheetState();
}

class _ArbeitstagSheetState extends State<_ArbeitstagSheet> {
  late final TextEditingController _ende = TextEditingController(
    text: widget.aktuell.ende ?? '',
  );
  late final TextEditingController _km = TextEditingController(
    text: widget.aktuell.km?.toString() ?? '',
  );

  @override
  void dispose() {
    _ende.dispose();
    _km.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Arbeitstag abschliessen',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ende,
                keyboardType: TextInputType.datetime,
                decoration: const InputDecoration(
                  labelText: 'Arbeitsende (HH:mm)',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _km,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'km-Stand',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  // Leeres Feld heisst «löschen» (null), ein unbrauchbarer
                  // Wert («12:xx», «abc») heisst «unverändert lassen» — sonst
                  // liesse sich ein falsch erfasstes Arbeitsende nie mehr
                  // entfernen.
                  final endeText = _ende.text.trim();
                  final kmText = _km.text.trim();
                  final String? ende = endeText.isEmpty
                      ? null
                      : (minutenAusHhmm(endeText) != null
                            ? endeText
                            : widget.aktuell.ende);
                  final int? km = kmText.isEmpty
                      ? null
                      : (int.tryParse(kmText) ?? widget.aktuell.km);
                  Navigator.pop(context, (
                    beginn: widget.aktuell.beginn,
                    ende: ende,
                    km: km,
                  ));
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Speichern',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
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
                Text(
                  'Automatische Termine (${eintraege.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.info,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onAlleUebernehmen,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text(
                    'Alle übernehmen',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          ...eintraege.map(
            (e) => _AutoTerminKarte(
              eintrag: e,
              onUebernehmen: () => onUebernehmen(e),
              onTap: () => onTap(e),
            ),
          ),
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
                  Text(
                    eintrag.betriebName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    eintrag.beschreibung,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.add_circle_outline,
                color: AppColors.primary,
              ),
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

class _TourInfoZeile extends ConsumerWidget {
  final DateTime datum;
  final TourEintrag eintrag;

  const _TourInfoZeile({required this.datum, required this.eintrag});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ruhetage und Servicezeit immer frisch aus den Stammdaten — im
    // gespeicherten Tagesplan stehen sie nur als Kopie vom Speicherzeitpunkt.
    final betrieb = eintrag.betriebId == null
        ? null
        : ref.watch(betriebLookupProvider)[eintrag.betriebId!];
    final ruhetage = betrieb?.ruhetage ?? eintrag.ruhetage;
    final zeitTxt = betrieb != null
        ? servicezeitAus(betrieb)
        : eintrag.servicezeit;

    final heuteRuhetag = istRuhetag(ruhetage, datum);
    final ruheTxt = ruhetageText(ruhetage);
    // Fehlt die Servicezeit ganz, wird das benannt — sonst ist nicht
    // erkennbar, ob sie fehlt oder ob kein Service möglich ist.
    final zeitFehlt =
        zeitTxt == null && eintrag.typ == TourEintragTyp.reinigung;

    if (!heuteRuhetag && ruheTxt.isEmpty && zeitTxt == null && !zeitFehlt) {
      return const SizedBox.shrink();
    }

    final children = <Widget>[];

    if (heuteRuhetag) {
      children.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.block, size: 13, color: AppColors.error),
            SizedBox(width: 3),
            Text(
              'Heute Ruhetag',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    } else if (ruheTxt.isNotEmpty) {
      children.add(_infoChip(Icons.event_busy, 'Ruhetag: $ruheTxt'));
    }

    if (zeitTxt != null) {
      children.add(_infoChip(Icons.schedule, zeitTxt));
    } else if (zeitFehlt) {
      children.add(_infoChip(Icons.schedule, 'Servicezeit fehlt'));
    }

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Wrap(spacing: 10, runSpacing: 2, children: children),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textSecondary),
        const SizedBox(width: 3),
        Text(
          text,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
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
    final color = _typColor(eintrag.typ);

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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: color.withAlpha(25),
                        child: Icon(
                          _typIcon(eintrag.typ),
                          color: color,
                          size: 16,
                        ),
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
                                      fontSize: 13,
                                    ),
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
                                color: AppColors.textSecondary,
                              ),
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
                          color: imPlan ? AppColors.success : AppColors.primary,
                        ),
                        onPressed: imPlan ? null : onAdd,
                        tooltip: imPlan ? 'Bereits im Plan' : 'Zum Tagesplan',
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

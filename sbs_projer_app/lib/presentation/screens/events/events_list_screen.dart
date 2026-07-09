import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/event_status.dart';
import 'package:sbs_projer_app/data/local/event_local_export.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/event_providers.dart';

/// Liste aller Event-Jahre (z. B. «Lumnezia 2026»), sortiert nach Status.
class EventsListScreen extends ConsumerStatefulWidget {
  const EventsListScreen({super.key});

  @override
  ConsumerState<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends ConsumerState<EventsListScreen> {
  String _suchText = '';

  int _sortKey(EventStatus s) => switch (s) {
        EventStatus.laufend => 0,
        EventStatus.kommend => 1,
        EventStatus.offen => 2,
        EventStatus.vorbei => 3,
      };

  List<EventLocal> _filterAndSort(
    List<EventLocal> alle,
    Map<String, String> betriebNamen,
    Map<String, String> betriebOrte,
  ) {
    var result = [...alle];

    // Suche (Betriebsname / Ort / Jahr)
    if (_suchText.isNotEmpty) {
      final q = _suchText.toLowerCase();
      result = result.where((e) {
        final name = (betriebNamen[e.betriebId] ?? '').toLowerCase();
        final ort = (betriebOrte[e.betriebId] ?? '').toLowerCase();
        return name.contains(q) ||
            ort.contains(q) ||
            e.jahr.toString().contains(q);
      }).toList();
    }

    // Sortierung: laufend → kommend (terminVon aufsteigend)
    // → offen (jahr absteigend) → vorbei (jahr absteigend, terminVon absteigend)
    final heute = DateTime.now();
    result.sort((a, b) {
      final sa = eventStatus(a.terminVon, a.terminBis, heute);
      final sb = eventStatus(b.terminVon, b.terminBis, heute);
      final statusCmp = _sortKey(sa).compareTo(_sortKey(sb));
      if (statusCmp != 0) return statusCmp;
      switch (sa) {
        case EventStatus.laufend:
        case EventStatus.kommend:
          final ta = a.terminVon ?? a.terminBis;
          final tb = b.terminVon ?? b.terminBis;
          if (ta == null && tb == null) return 0;
          if (ta == null) return 1;
          if (tb == null) return -1;
          return ta.compareTo(tb);
        case EventStatus.offen:
          return b.jahr.compareTo(a.jahr);
        case EventStatus.vorbei:
          final jahrCmp = b.jahr.compareTo(a.jahr);
          if (jahrCmp != 0) return jahrCmp;
          final ta = a.terminVon;
          final tb = b.terminVon;
          if (ta == null && tb == null) return 0;
          if (ta == null) return 1;
          if (tb == null) return -1;
          return tb.compareTo(ta);
      }
    });

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsProvider);
    final betriebNamen = ref.watch(betriebNameMapProvider);
    final betriebOrte = ref.watch(betriebOrtMapProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Events')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/events/neu');
          ref.invalidate(eventsProvider);
        },
        child: const Icon(Icons.add),
      ),
      body: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (alleEvents) {
          final events = _filterAndSort(alleEvents, betriebNamen, betriebOrte);

          return Column(
            children: [
              // Suchfeld
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Suche nach Betrieb, Ort, Jahr...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (v) => setState(() => _suchText = v),
                ),
              ),

              // Liste
              Expanded(
                child: events.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.festival,
                                size: 64,
                                color: AppColors.textSecondary
                                    .withValues(alpha: 0.4)),
                            const SizedBox(height: 16),
                            const Text('Keine Events gefunden.',
                                style:
                                    TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                        itemCount: events.length,
                        itemBuilder: (ctx, i) {
                          final e = events[i];
                          final name = betriebNamen[e.betriebId] ??
                              'Unbekannter Betrieb';
                          final ort = betriebOrte[e.betriebId];
                          final termin = _terminText(e);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 4),
                            child: ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 2),
                              title: Text(
                                '$name ${e.jahr}',
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                ort != null && ort.isNotEmpty
                                    ? '$termin · $ort'
                                    : termin,
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: _StatusBadge(event: e),
                              onTap: () async {
                                await context.push('/events/${e.routeId}');
                                ref.invalidate(eventsProvider);
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Status-Badge: laufend (grün), «in X Tagen» (blau), Termin offen / vorbei (grau).
class _StatusBadge extends StatelessWidget {
  final EventLocal event;

  const _StatusBadge({required this.event});

  @override
  Widget build(BuildContext context) {
    final heute = DateTime.now();
    final status = eventStatus(event.terminVon, event.terminBis, heute);

    final String label;
    final Color color;
    switch (status) {
      case EventStatus.laufend:
        label = 'laufend';
        color = AppColors.success;
      case EventStatus.kommend:
        final start = event.terminVon ?? event.terminBis!;
        final tage = DateTime(start.year, start.month, start.day)
            .difference(DateTime(heute.year, heute.month, heute.day))
            .inDays;
        label = 'in $tage Tag${tage == 1 ? '' : 'en'}';
        color = AppColors.info;
      case EventStatus.offen:
        label = 'Termin offen';
        color = AppColors.textSecondary;
      case EventStatus.vorbei:
        label = 'vorbei';
        color = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// Termin als «dd.MM.–dd.MM.yyyy», eintägig «dd.MM.yyyy», sonst «Termin offen».
String _terminText(EventLocal e) {
  final von = e.terminVon;
  final bis = e.terminBis;
  if (von == null && bis == null) return 'Termin offen';
  final start = von ?? bis!;
  final ende = bis ?? von!;
  final eintaegig = start.year == ende.year &&
      start.month == ende.month &&
      start.day == ende.day;
  if (eintaegig) return _ddMMyyyy(start);
  return '${_ddMM(start)}–${_ddMMyyyy(ende)}';
}

String _zwei(int v) => v.toString().padLeft(2, '0');

String _ddMM(DateTime d) => '${_zwei(d.day)}.${_zwei(d.month)}.';

String _ddMMyyyy(DateTime d) => '${_zwei(d.day)}.${_zwei(d.month)}.${d.year}';

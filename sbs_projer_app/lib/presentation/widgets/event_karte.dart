import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/event_fenster.dart';
import 'package:sbs_projer_app/presentation/providers/event_providers.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

/// Anstehende Events oben auf Heute — sonst stehen Events nur unter
/// «Mehr» (v0.132.0). Eine Karte je Event im Fenster.
class EventKarten extends ConsumerWidget {
  const EventKarten({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jetzt = DateTime.now();
    final events = (ref.watch(eventsProvider).valueOrNull ?? const [])
        .where((e) => eventImFenster(e.terminVon, e.terminBis, jetzt))
        .toList();
    if (events.isEmpty) return const SizedBox.shrink();
    final betriebe = ref.watch(betriebLookupProvider);
    final fmt = DateFormat('dd.MM.');
    return Column(
      children: [
        for (final e in events)
          GestureDetector(
            onTap: () => context.push('/events/${e.routeId}'),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.info.withAlpha(60)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.festival, color: AppColors.info, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${betriebe[e.betriebId]?.name ?? 'Event'} · '
                      '${fmt.format(e.terminVon!)}'
                      '${e.terminBis != null ? '–${fmt.format(e.terminBis!)}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

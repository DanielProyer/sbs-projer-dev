import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/app_version.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/presentation/providers/aufgaben_providers.dart';
import 'package:sbs_projer_app/presentation/providers/connectivity_provider.dart';
import 'package:sbs_projer_app/presentation/providers/sync_provider.dart';
import 'package:sbs_projer_app/presentation/widgets/arbeitstag_karte.dart';
import 'package:sbs_projer_app/presentation/widgets/aufgaben_sheet.dart';
import 'package:sbs_projer_app/presentation/widgets/diktat_sheet.dart';
import 'package:sbs_projer_app/presentation/widgets/event_karte.dart';
import 'package:sbs_projer_app/presentation/widgets/heute_liste.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Version gleich im Titel: sonst ist im Web nicht feststellbar,
        // welcher Stand geladen ist (Cache-Diagnosen, Daniel 28.07.2026).
        title: const Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('SBS Projer'),
            SizedBox(width: 6),
            Text('(v$kAppVersion)', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          // Suche (v0.133.0): hier und oben auf Mehr — von jedem Screen in
          // zwei Tipps erreichbar, ohne 100 Kopfzeilen umzubauen.
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Suchen',
            onPressed: () => context.push('/suche'),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: _SyncIndicator(),
          ),
        ],
      ),
      // Seit v0.131.0 nur noch der Tag: Kacheln und «Weitere» rutschten mit
      // jedem Stopp des Tagesplans tiefer und waren am Handy kaum zu
      // erreichen. Sie stehen jetzt unter «Mehr» in der Leiste.
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        children: [
          const EventKarten(),
          const _AufgabenKarte(),
          // Arbeitstag direkt auf dem Startbildschirm erfassen (Beginn mit
          // GPS-Position, abends Ende + km) — Daniel 29.07.2026.
          const ArbeitstagKarte(),
          const HeuteListe(),
        ],
      ),
      // Diktieren als frei schwebender Knopf statt fester Leiste: Daniel
      // braucht ihn vor allem im Auto (einhändig, sofort da) — ein FAB
      // liegt IMMER über dem Inhalt, ohne den seit Task 10 (13.09.2026)
      // bewusst scrollenden Startbildschirm durch zusätzliche Leisten
      // zusätzlich zu verkleinern.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => zeigeDiktatSheet(context),
        icon: const Icon(Icons.mic),
        label: const Text('Diktieren'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _SyncIndicator extends ConsumerWidget {
  const _SyncIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    final isSyncing = ref.watch(isSyncingProvider);
    final hatFehler = ref.watch(syncHatFehlerProvider);

    if (isSyncing) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    // Ein fehlgeschlagener Sync darf nicht als grünes «cloud_done»
    // erscheinen — genau das liess fehlende Daten wie übertragene aussehen.
    if (hatFehler) {
      return Tooltip(
        message:
            'Letzter Sync unvollständig — «Sync erzwingen» in den Einstellungen',
        child: Icon(Icons.cloud_off, color: AppColors.offline, size: 20),
      );
    }
    return Icon(
      isOnline ? Icons.cloud_done : Icons.cloud_off,
      color: isOnline ? AppColors.online : AppColors.offline,
      size: 20,
    );
  }
}

class _AufgabenKarte extends ConsumerWidget {
  const _AufgabenKarte();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jetzt = ref.watch(aufgabenJetztProvider);
    if (jetzt.isEmpty) return const SizedBox.shrink();
    final titel = jetzt.map((a) => a.titel).take(3).toList();
    final dringend = jetzt.any((a) => a.dringend);
    final label = jetzt.length == 1
        ? '1 Aufgabe offen'
        : '${jetzt.length} Aufgaben offen';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: dringend
          ? AppColors.error.withValues(alpha: 0.08)
          : AppColors.warning.withValues(alpha: 0.08),
      child: InkWell(
        onTap: () => zeigeAufgabenSheet(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.notifications_active,
                    size: 18,
                    color: dringend ? AppColors.error : AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
              const SizedBox(height: 4),
              ...titel.map(
                (t) => Padding(
                  padding: const EdgeInsets.only(left: 26, top: 2),
                  child: Text(
                    '· $t',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

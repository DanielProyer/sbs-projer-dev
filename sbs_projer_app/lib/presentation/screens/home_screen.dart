import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/app_version.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/presentation/providers/aufgaben_providers.dart';
import 'package:sbs_projer_app/presentation/providers/connectivity_provider.dart';
import 'package:sbs_projer_app/presentation/providers/sync_provider.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/reinigung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/stoerung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/material_providers.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';
import 'package:sbs_projer_app/presentation/providers/eigenauftrag_providers.dart';
import 'package:sbs_projer_app/presentation/providers/eroeffnungsreinigung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/tagesuebersicht_provider.dart';
import 'package:sbs_projer_app/presentation/providers/buchung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/montage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/kontakt_providers.dart';
import 'package:sbs_projer_app/presentation/providers/event_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/arbeitstag_karte.dart';
import 'package:sbs_projer_app/presentation/widgets/aufgaben_sheet.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';
import 'package:sbs_projer_app/services/sync/sync_service_export.dart';

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
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: _SyncIndicator(),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Abmelden',
            onPressed: () async {
              if (!kIsWeb) SyncService.stopListening();
              await SupabaseService.client.auth.signOut();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const _AufgabenKarte(),
          // Arbeitstag direkt auf dem Startbildschirm erfassen (Beginn mit
          // GPS-Position, abends Ende + km) — Daniel 29.07.2026.
          const ArbeitstagKarte(),
          const _TagesUebersicht(),
          const SizedBox(height: 10),
          const _KachelGrid(),
          const SizedBox(height: 16),
          const _WeitereSection(),
        ],
      ),
    );
  }
}

class _KachelGrid extends ConsumerWidget {
  const _KachelGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final betriebCount = ref.watch(betriebCountProvider);
    // Werkstatt-/Reinigungs-Kacheln zeigen die Anzahl des AKTUELLEN JAHRES
    // (nicht die Gesamt-Historie) — analog Montage.
    final reinigungCount = ref.watch(reinigungCountAktuellesJahrProvider);
    final stoerungCount = ref.watch(stoerungCountAktuellesJahrProvider);
    final faelligeCount = ref.watch(faelligeAnlagenCountProvider);
    final eigenauftragCount = ref.watch(eigenauftragCountAktuellesJahrProvider);
    final eroeffnungsreinigungCount = ref.watch(
      eroeffnungsreinigungCountAktuellesJahrProvider,
    );
    final montageJahrCount = ref.watch(montageCountAktuellesJahrProvider);
    final kontaktCount = ref.watch(kontakteProvider).valueOrNull?.length ?? 0;
    final spesenCount =
        ref.watch(spesenBelegeCountAktuellesJahrProvider).valueOrNull ?? 0;
    final eventCount =
        ref
            .watch(eventsProvider)
            .valueOrNull
            ?.where((e) => e.jahr == DateTime.now().year)
            .length ??
        0;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.75,
      children: [
        _DashboardTile(
          icon: Icons.store,
          label: 'Betriebe',
          count: betriebCount > 0 ? '$betriebCount' : null,
          color: AppColors.primary,
          onTap: () => context.push('/betriebe'),
        ),
        _DashboardTile(
          icon: Icons.cleaning_services,
          label: 'Reinigungen',
          count: reinigungCount > 0 ? '$reinigungCount' : null,
          color: AppColors.success,
          onTap: () => context.push('/reinigungen'),
        ),
        _DashboardTile(
          icon: Icons.warning_amber,
          label: 'Störungen',
          count: stoerungCount > 0 ? '$stoerungCount' : null,
          color: AppColors.warning,
          onTap: () => context.push('/stoerungen'),
        ),
        _DashboardTile(
          icon: Icons.build,
          label: 'Montagen',
          count: montageJahrCount > 0 ? '$montageJahrCount' : null,
          color: AppColors.info,
          onTap: () => context.push('/montagen'),
        ),
        _DashboardTile(
          icon: Icons.build_circle_outlined,
          label: 'Eigenaufträge',
          count: eigenauftragCount > 0 ? '$eigenauftragCount' : null,
          color: const Color(0xFF7C3AED),
          onTap: () => context.push('/eigenauftraege'),
        ),
        _DashboardTile(
          icon: Icons.cleaning_services_outlined,
          label: 'Eröffnungen',
          count: eroeffnungsreinigungCount > 0
              ? '$eroeffnungsreinigungCount'
              : null,
          color: AppColors.primary,
          onTap: () => context.push('/eroeffnungsreinigungen'),
        ),
        _DashboardTile(
          icon: Icons.contacts,
          label: 'Kontakte',
          count: kontaktCount > 0 ? '$kontaktCount' : null,
          color: Colors.teal,
          onTap: () => context.push('/kontakte'),
        ),
        _DashboardTile(
          icon: Icons.festival,
          label: 'Events',
          count: eventCount > 0 ? '$eventCount' : null,
          color: Colors.deepPurple,
          onTap: () => context.push('/events'),
        ),
        _DashboardTile(
          icon: Icons.route,
          label: 'Tourenplanung',
          count: faelligeCount > 0 ? '$faelligeCount fällig' : null,
          color: AppColors.primary,
          onTap: () => context.push('/touren'),
        ),
        _DashboardTile(
          icon: Icons.receipt_long,
          label: 'Spesen',
          count: spesenCount > 0 ? '$spesenCount' : null,
          color: Colors.brown,
          onTap: () => context.push('/spesen'),
        ),
      ],
    );
  }
}

class _WeitereSection extends ConsumerWidget {
  const _WeitereSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buchungenCount = ref.watch(buchungenCountProvider);
    final niedrigCount = ref.watch(niedrigCountProvider);

    return Column(
      children: [
        // Buchhaltung für Gast (Heineken) ausgeblendet
        if (!SupabaseService.isGuest)
          _MenuListTile(
            icon: Icons.account_balance,
            label: 'Buchhaltung',
            count: buchungenCount > 0 ? '$buchungenCount' : null,
            onTap: () => context.push('/buchhaltung'),
          ),
        _MenuListTile(
          icon: Icons.inventory_2,
          label: 'Material',
          count: niedrigCount > 0 ? '$niedrigCount niedrig' : null,
          onTap: () => context.push('/materialien'),
        ),
        _MenuListTile(
          icon: Icons.nightlight_round,
          label: 'Pikett-Dienste',
          onTap: () => context.push('/pikett'),
        ),
        _MenuListTile(
          icon: Icons.propane_tank_outlined,
          label: 'Anlagen',
          onTap: () => context.push('/anlagen'),
        ),
        _MenuListTile(
          icon: Icons.landscape,
          label: 'Bergkundenpauschalen',
          onTap: () => context.push('/bergkundenpauschalen'),
        ),
        _MenuListTile(
          icon: Icons.settings,
          label: 'Einstellungen',
          onTap: () => context.push('/einstellungen'),
        ),
        if (!kIsWeb)
          _MenuListTile(
            icon: Icons.sync,
            label: 'Sync erzwingen',
            onTap: () {
              SyncService.syncAll();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Synchronisierung gestartet...')),
              );
            },
          ),
      ],
    );
  }
}

class _SyncIndicator extends ConsumerWidget {
  const _SyncIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    final isSyncing = ref.watch(isSyncingProvider);

    if (isSyncing) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return Icon(
      isOnline ? Icons.cloud_done : Icons.cloud_off,
      color: isOnline ? AppColors.online : AppColors.offline,
      size: 20,
    );
  }
}

const _wochentage = [
  'Montag',
  'Dienstag',
  'Mittwoch',
  'Donnerstag',
  'Freitag',
  'Samstag',
  'Sonntag',
];

class _TagesUebersicht extends ConsumerWidget {
  const _TagesUebersicht();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now();
    final data = ref.watch(tagesUebersichtProvider);
    final hR = data.reinigungen;
    final hS = data.stoerungen;
    final hM = data.montagen;
    final hE = data.eigenauftraege;
    final hER = data.eroeffnungen;
    final hBP = data.bergkundenpauschalen;
    final total = data.total;
    final totalCHF = data.totalCHF;

    final datumStr =
        '${_wochentage[today.weekday - 1]}, ${today.day.toString().padLeft(2, '0')}.${today.month.toString().padLeft(2, '0')}.${today.year}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.today, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    datumStr,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (data.monatsUmsatzCHF > 0)
                  Text(
                    '${data.monatsUmsatzCHF.toStringAsFixed(0)} CHF / Monat',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (total == 0)
              Text(
                'Keine Einsätze heute',
                style: TextStyle(color: AppColors.textSecondary),
              )
            else ...[
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  if (hR.isNotEmpty)
                    _CountChip(
                      '${hR.length} Reinigung${hR.length > 1 ? 'en' : ''}',
                      AppColors.success,
                    ),
                  if (hS.isNotEmpty)
                    _CountChip(
                      '${hS.length} Störung${hS.length > 1 ? 'en' : ''}',
                      AppColors.warning,
                    ),
                  if (hM.isNotEmpty)
                    _CountChip(
                      '${hM.length} Montage${hM.length > 1 ? 'n' : ''}',
                      AppColors.info,
                    ),
                  if (hE.isNotEmpty)
                    _CountChip(
                      '${hE.length} Eigenauftr${hE.length > 1 ? 'äge' : 'ag'}',
                      AppColors.textSecondary,
                    ),
                  if (hER.isNotEmpty)
                    _CountChip(
                      '${hER.length} Eröffnung${hER.length > 1 ? 'en' : ''}',
                      AppColors.primary,
                    ),
                  if (hBP.isNotEmpty)
                    _CountChip(
                      '${hBP.length} Bergkunde${hBP.length > 1 ? 'n' : ''}',
                      Colors.brown,
                    ),
                ],
              ),
              if (totalCHF > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Tagesumsatz: ${totalCHF.toStringAsFixed(2)} CHF',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final Color color;
  const _CountChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _DashboardTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? count;
  final Color color;
  final VoidCallback onTap;

  const _DashboardTile({
    required this.icon,
    required this.label,
    this.count,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: color.withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        count!,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuListTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? count;
  final VoidCallback onTap;

  const _MenuListTile({
    required this.icon,
    required this.label,
    this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (count != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  count!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _AufgabenKarte extends ConsumerWidget {
  const _AufgabenKarte();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stand = ref.watch(aufgabenProvider).valueOrNull;
    if (stand == null || stand.badge == 0) return const SizedBox.shrink();
    final titel = [
      ...stand.offene.map((a) => a.titel),
      ...stand.eigene.map((e) => e.aufgabe.titel),
    ].take(3).toList();
    final dringend =
        stand.offene.any((a) => a.dringend) ||
        stand.eigene.any((e) => e.aufgabe.dringend);
    final label = stand.badge == 1
        ? '1 Aufgabe offen'
        : '${stand.badge} Aufgaben offen';
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

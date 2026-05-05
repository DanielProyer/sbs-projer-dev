import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/presentation/providers/connectivity_provider.dart';
import 'package:sbs_projer_app/presentation/providers/sync_provider.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/anlage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/reinigung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/stoerung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/rechnung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/material_providers.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';
import 'package:sbs_projer_app/presentation/providers/eigenauftrag_providers.dart';
import 'package:sbs_projer_app/presentation/providers/eroeffnungsreinigung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/heineken_providers.dart';
import 'package:sbs_projer_app/presentation/providers/buchung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/montage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/pikett_providers.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';
import 'package:sbs_projer_app/services/sync/sync_service_export.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    final isSyncing = ref.watch(isSyncingProvider);
    final betriebCount = ref.watch(betriebCountProvider);
    final anlageCount = ref.watch(anlageCountProvider);
    final reinigungCount = ref.watch(reinigungCountProvider);
    final stoerungCount = ref.watch(stoerungCountProvider);
    final faelligeCount = ref.watch(faelligeAnlagenCountProvider);
    final offeneRechnungen = ref.watch(offeneRechnungenCountProvider);
    final niedrigCount = ref.watch(niedrigCountProvider);
    final eigenauftragCount = ref.watch(eigenauftragCountProvider);
    final eroeffnungsreinigungCount = ref.watch(eroeffnungsreinigungCountProvider);
    final heinekenCount = ref.watch(heinekenRechnungCountProvider);
    final buchungenCount = ref.watch(buchungenCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SBS Projer'),
        actions: [
          // Sync-Status Indicator
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _SyncIndicator(isOnline: isOnline, isSyncing: isSyncing),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Abmelden',
            onPressed: () async {
              if (!kIsWeb) SyncService.stopListening();
              await SupabaseService.client.auth.signOut();
              // GoRouter redirected automatisch via refreshListenable
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Tagesübersicht
          _TagesUebersicht(),
          const SizedBox(height: 24),

          // Schnellzugriff
          Text(
            'Schnellzugriff',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),

          // Tourenplanung Kachel (volle Breite)
          _DashboardTile(
            icon: Icons.route,
            label: 'Tourenplanung',
            count: faelligeCount > 0 ? '$faelligeCount fällig' : null,
            color: AppColors.primary,
            onTap: () => context.push('/touren'),
          ),
          const SizedBox(height: 12),

          // Dashboard-Kacheln
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _DashboardTile(
                icon: Icons.store,
                label: 'Betriebe',
                count: betriebCount.valueOrNull?.toString(),
                color: AppColors.primary,
                onTap: () => context.push('/betriebe'),
              ),
              _DashboardTile(
                icon: Icons.cleaning_services,
                label: 'Reinigungen',
                count: reinigungCount.valueOrNull?.toString(),
                color: AppColors.success,
                onTap: () => context.push('/reinigungen'),
              ),
              _DashboardTile(
                icon: Icons.warning_amber,
                label: 'Störungen',
                count: stoerungCount.valueOrNull?.toString(),
                color: AppColors.warning,
                onTap: () => context.push('/stoerungen'),
              ),
              _DashboardTile(
                icon: Icons.build,
                label: 'Montagen',
                color: AppColors.info,
                onTap: () => context.push('/montagen'),
              ),
              _DashboardTile(
                icon: Icons.build_circle_outlined,
                label: 'Eigenaufträge',
                count: eigenauftragCount.valueOrNull?.toString(),
                color: const Color(0xFF7C3AED),
                onTap: () => context.push('/eigenauftraege'),
              ),
              _DashboardTile(
                icon: Icons.cleaning_services_outlined,
                label: 'Eröffnungen',
                count: eroeffnungsreinigungCount.valueOrNull?.toString(),
                color: AppColors.primary,
                onTap: () => context.push('/eroeffnungsreinigungen'),
              ),
            ],
          ),

          const SizedBox(height: 24),
          Text(
            'Weitere',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),

          _MenuListTile(
            icon: Icons.precision_manufacturing,
            label: 'Anlagen',
            count: anlageCount.valueOrNull?.toString(),
            onTap: () => context.push('/anlagen'),
          ),
          _MenuListTile(
            icon: Icons.receipt_long,
            label: 'Rechnungen',
            count: offeneRechnungen.valueOrNull != null &&
                    offeneRechnungen.valueOrNull! > 0
                ? '${offeneRechnungen.valueOrNull} offen'
                : null,
            onTap: () => context.push('/rechnungen'),
          ),
          _MenuListTile(
            icon: Icons.receipt_long_outlined,
            label: 'Heineken Rechnungen',
            count: heinekenCount.valueOrNull?.toString(),
            onTap: () => context.push('/heineken'),
          ),
          _MenuListTile(
            icon: Icons.account_balance,
            label: 'Buchhaltung',
            count: buchungenCount.valueOrNull?.toString(),
            onTap: () => context.push('/buchhaltung'),
          ),
          _MenuListTile(
            icon: Icons.inventory_2,
            label: 'Material',
            count: niedrigCount.valueOrNull != null &&
                    niedrigCount.valueOrNull! > 0
                ? '${niedrigCount.valueOrNull} niedrig'
                : null,
            onTap: () => context.push('/materialien'),
          ),
          _MenuListTile(
            icon: Icons.nightlight_round,
            label: 'Pikett-Dienste',
            onTap: () => context.push('/pikett'),
          ),
          _MenuListTile(
            icon: Icons.contacts,
            label: 'Kontakte',
            onTap: () => context.push('/kontakte'),
          ),
          _MenuListTile(
            icon: Icons.landscape,
            label: 'Bergkundenpauschalen',
            onTap: () => context.push('/bergkundenpauschalen'),
          ),
          _MenuListTile(
            icon: Icons.calendar_month,
            label: 'Termine',
            onTap: () => context.push('/termine'),
          ),
          _MenuListTile(
            icon: Icons.receipt,
            label: 'Jahresrechnung',
            onTap: () => context.push('/jahresrechnung'),
          ),
          _MenuListTile(
            icon: Icons.receipt_long,
            label: 'Spesen erfassen',
            onTap: () => context.push('/spesen'),
          ),
          _MenuListTile(
            icon: Icons.search,
            label: 'Fehlersuche',
            onTap: () => context.push('/fehlersuche'),
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
      ),
    );
  }
}

class _SyncIndicator extends StatelessWidget {
  final bool isOnline;
  final bool isSyncing;

  const _SyncIndicator({required this.isOnline, required this.isSyncing});

  @override
  Widget build(BuildContext context) {
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
  'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag',
  'Freitag', 'Samstag', 'Sonntag',
];

class _TagesUebersicht extends ConsumerWidget {
  const _TagesUebersicht();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    final reinigungen = ref.watch(reinigungenProvider);
    final stoerungen = ref.watch(stoerungenProvider);
    final montagen = ref.watch(montagenProvider);
    final eigenauftraege = ref.watch(eigenauftraegeProvider);
    final eroeffnungen = ref.watch(eroeffnungsreinigungenProvider);

    bool _isToday(DateTime d) =>
        DateTime(d.year, d.month, d.day) == todayDate;

    final hR = reinigungen.where((r) => _isToday(r.datum)).toList();
    final hS = stoerungen.where((s) => _isToday(s.datum)).toList();
    final hM = montagen.where((m) => _isToday(m.datum)).toList();
    final hE = eigenauftraege.where((e) => _isToday(e.datum)).toList();
    final hER = eroeffnungen.where((e) => _isToday(e.datum)).toList();

    final total = hR.length + hS.length + hM.length + hE.length + hER.length;
    final totalCHF = hR.fold(0.0, (s, r) => s + (r.preisBrutto ?? 0)) +
        hS.fold(0.0, (s, r) => s + (r.preisNetto ?? 0)) +
        hM.fold(0.0, (s, r) => s + (r.kostenArbeit ?? 0)) +
        hE.fold(0.0, (s, r) => s + (r.pauschale ?? 0)) +
        hER.fold(0.0, (s, r) => s + (r.preis ?? 0));

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
                Text(datumStr,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 12),
            if (total == 0)
              Text('Keine Einsätze heute',
                  style: TextStyle(color: AppColors.textSecondary))
            else ...[
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  if (hR.isNotEmpty)
                    _CountChip(
                        '${hR.length} Reinigung${hR.length > 1 ? 'en' : ''}',
                        AppColors.success),
                  if (hS.isNotEmpty)
                    _CountChip(
                        '${hS.length} Störung${hS.length > 1 ? 'en' : ''}',
                        AppColors.warning),
                  if (hM.isNotEmpty)
                    _CountChip(
                        '${hM.length} Montage${hM.length > 1 ? 'n' : ''}',
                        AppColors.info),
                  if (hE.isNotEmpty)
                    _CountChip(
                        '${hE.length} Eigenauftr${hE.length > 1 ? 'äge' : 'ag'}',
                        AppColors.textSecondary),
                  if (hER.isNotEmpty)
                    _CountChip(
                        '${hER.length} Eröffnung${hER.length > 1 ? 'en' : ''}',
                        AppColors.primary),
                ],
              ),
              if (totalCHF > 0) ...[
                const SizedBox(height: 8),
                Text('Tagesumsatz: ${totalCHF.toStringAsFixed(2)} CHF',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
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
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w600, fontSize: 12)),
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (count != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        count!,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
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

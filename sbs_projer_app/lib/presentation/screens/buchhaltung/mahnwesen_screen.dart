import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/presentation/providers/rechnung_providers.dart';
import 'package:sbs_projer_app/services/rechnung/mahnwesen_service.dart';

final _df = DateFormat('dd.MM.yyyy');

String _aktionLabel(String aktion) {
  switch (aktion) {
    case 'erinnerung_faellig':
      return 'Erinnerung fällig';
    case 'mahnung_1_faellig':
      return '1. Mahnung fällig';
    case 'mahnung_2_faellig':
      return '2. Mahnung fällig';
    case 'eskalation':
      return 'Eskalation';
    default:
      return 'Warten';
  }
}

Color _aktionColor(String aktion) {
  switch (aktion) {
    case 'erinnerung_faellig':
      return AppColors.warning;
    case 'mahnung_1_faellig':
      return AppColors.error;
    case 'mahnung_2_faellig':
      return const Color(0xFF8B0000);
    case 'eskalation':
      return const Color(0xFF8B0000);
    default:
      return AppColors.textSecondary;
  }
}

int _mahnStufeAusAktion(String aktion) {
  switch (aktion) {
    case 'erinnerung_faellig':
      return 0;
    case 'mahnung_1_faellig':
      return 1;
    case 'mahnung_2_faellig':
      return 2;
    default:
      return -1;
  }
}

double _r5(double v) => (v * 20).roundToDouble() / 20;

class MahnwesenScreen extends ConsumerStatefulWidget {
  const MahnwesenScreen({super.key});

  @override
  ConsumerState<MahnwesenScreen> createState() => _MahnwesenScreenState();
}

class _MahnwesenScreenState extends ConsumerState<MahnwesenScreen> {
  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(mahnwesenDashboardProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mahnwesen')),
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (rechnungen) {
          if (rechnungen.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle,
                      size: 64, color: AppColors.success.withAlpha(100)),
                  const SizedBox(height: 16),
                  Text('Keine offenen Kundenrechnungen',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            );
          }

          final aktionNoetig = rechnungen
              .where((r) => r['empfohlene_aktion'] != 'warten')
              .toList();
          final wartend = rechnungen
              .where((r) => r['empfohlene_aktion'] == 'warten')
              .toList();

          double totalBetrag = 0;
          for (final r in rechnungen) {
            totalBetrag += _r5(_d(r['betrag_brutto']));
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(mahnwesenDashboardProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Summary Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${totalBetrag.toStringAsFixed(2)} CHF',
                                style: const TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.w700),
                              ),
                              Text('Offener Gesamtbetrag',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: aktionNoetig.isNotEmpty
                                ? AppColors.error.withAlpha(25)
                                : AppColors.success.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '${aktionNoetig.length}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: aktionNoetig.isNotEmpty
                                      ? AppColors.error
                                      : AppColors.success,
                                ),
                              ),
                              Text(
                                'Aktion nötig',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: aktionNoetig.isNotEmpty
                                      ? AppColors.error
                                      : AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Aktion erforderlich
                if (aktionNoetig.isNotEmpty) ...[
                  Text(
                    'Aktion erforderlich (${aktionNoetig.length})',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.error),
                  ),
                  const SizedBox(height: 8),
                  ...aktionNoetig.map((r) => _MahnItem(
                        rechnung: r,
                        onAktion: () => _eskalieren(r),
                        onTap: () => context.push('/rechnungen/${r['id']}'),
                      )),
                  const SizedBox(height: 16),
                ],

                // Wartend
                if (wartend.isNotEmpty) ...[
                  Text(
                    'Innerhalb Frist (${wartend.length})',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  ...wartend.map((r) => _MahnItem(
                        rechnung: r,
                        onTap: () => context.push('/rechnungen/${r['id']}'),
                      )),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _eskalieren(Map<String, dynamic> r) async {
    final aktion = r['empfohlene_aktion'] as String? ?? '';
    final mahnStufe = _mahnStufeAusAktion(aktion);
    final rechnungId = r['id'] as String;
    final rgNr = r['rechnungsnummer'] ?? '';
    final versandart = r['versandart'] as String? ?? '';
    final hatEmail = versandart == 'rechnung_mail';

    if (aktion == 'eskalation') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Rechnung abschreiben?'),
          content: Text(
            'Rechnung $rgNr wird als uneinbringlich abgeschrieben.\n'
            'Eine Buchung auf Konto 3805 (Debitorenverlust) wird erstellt.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Abschreiben'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      try {
        final rechnung = await RechnungRepository.getById(rechnungId);
        if (rechnung == null) return;
        await MahnwesenService.abschreiben(rechnung);
        ref.invalidate(mahnwesenDashboardProvider);
        ref.invalidate(rechnungenStreamProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$rgNr abgeschrieben')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler: $e')),
          );
        }
      }
      return;
    }

    if (mahnStufe < 0) return;

    final titel = MahnwesenService.titelFuerStufe(mahnStufe);

    bool? mailSenden = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        bool mail = hatEmail;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text('$titel erstellen?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rechnung $rgNr'),
                const SizedBox(height: 12),
                const Text('Ein PDF wird generiert und hochgeladen.'),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: mail,
                  onChanged: (v) =>
                      setDialogState(() => mail = v ?? false),
                  title: Text(
                    hatEmail ? 'Per E-Mail senden' : 'Per E-Mail senden (keine E-Mail hinterlegt)',
                    style: TextStyle(
                      fontSize: 14,
                      color: hatEmail ? null : AppColors.textSecondary,
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                onPressed: () {
                  mailSenden = mail;
                  Navigator.pop(ctx, true);
                },
                child: Text('$titel erstellen'),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;

    try {
      final rechnung = await RechnungRepository.getById(rechnungId);
      if (rechnung == null) return;
      await MahnwesenService.eskalieren(
        rechnung: rechnung,
        mahnStufe: mahnStufe,
        mailSenden: mailSenden ?? false,
      );
      ref.invalidate(mahnwesenDashboardProvider);
      ref.invalidate(rechnungenStreamProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '$titel für $rgNr erstellt${mailSenden == true ? ' & versendet' : ''}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  static double _d(dynamic v) =>
      double.tryParse(v?.toString() ?? '') ?? 0;
}

class _MahnItem extends StatelessWidget {
  final Map<String, dynamic> rechnung;
  final VoidCallback? onAktion;
  final VoidCallback onTap;

  const _MahnItem({
    required this.rechnung,
    this.onAktion,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final nummer = rechnung['rechnungsnummer'] ?? '';
    final betriebName = rechnung['betrieb_name'] ?? '';
    final betrag = _r5(_d(rechnung['betrag_brutto']));
    final tage = (rechnung['ueberfaellig_seit_tagen'] as int?) ?? 0;
    final status = rechnung['zahlungsstatus'] ?? 'offen';
    final aktion = rechnung['empfohlene_aktion'] as String? ?? 'warten';
    final hatAktion = aktion != 'warten';

    final faellig = rechnung['faelligkeitsdatum'] != null
        ? DateTime.tryParse(rechnung['faelligkeitsdatum'].toString())
        : null;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: hatAktion
              ? _aktionColor(aktion).withAlpha(25)
              : AppColors.warning.withAlpha(25),
          child: Icon(
            hatAktion ? Icons.priority_high : Icons.schedule,
            color: hatAktion ? _aktionColor(aktion) : AppColors.warning,
            size: 20,
          ),
        ),
        title: Text(
          nummer.toString(),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (betriebName.toString().isNotEmpty)
              Text(betriebName.toString(),
                  style: const TextStyle(fontSize: 12)),
            Row(
              children: [
                Text('${betrag.toStringAsFixed(2)} CHF',
                    style: const TextStyle(fontSize: 12)),
                if (tage > 0) ...[
                  const Text(' · ', style: TextStyle(fontSize: 12)),
                  Text('$tage Tage überfällig',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.error,
                          fontWeight: FontWeight.w600)),
                ] else if (faellig != null) ...[
                  const Text(' · ', style: TextStyle(fontSize: 12)),
                  Text('Fällig ${_df.format(faellig)}',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ],
            ),
            if (hatAktion)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _aktionColor(aktion).withAlpha(20),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _aktionLabel(aktion),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _aktionColor(aktion),
                    ),
                  ),
                ),
              ),
            if (!hatAktion) ...[
              _statusChip(status),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onAktion != null)
              IconButton(
                icon: Icon(
                  aktion == 'eskalation' ? Icons.block : Icons.send,
                  size: 20,
                ),
                tooltip: aktion == 'eskalation'
                    ? 'Abschreiben'
                    : _aktionLabel(aktion),
                onPressed: onAktion,
              ),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _statusChip(String status) {
    final label = {
          'offen': 'Offen',
          'erinnert': 'Erinnert',
          'mahnung_1': 'Mahnung 1',
          'mahnung_2': 'Mahnung 2',
        }[status] ??
        status;
    final color = {
          'offen': AppColors.warning,
          'erinnert': const Color(0xFFE65100),
          'mahnung_1': AppColors.error,
          'mahnung_2': const Color(0xFF8B0000),
        }[status] ??
        AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ),
    );
  }

  static double _d(dynamic v) =>
      double.tryParse(v?.toString() ?? '') ?? 0;
}

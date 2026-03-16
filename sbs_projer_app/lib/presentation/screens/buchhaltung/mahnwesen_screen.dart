import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/presentation/providers/buchhaltung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/rechnung_providers.dart';

class MahnwesenScreen extends ConsumerWidget {
  const MahnwesenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offeneAsync = ref.watch(offeneRechnungenViewProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mahnwesen')),
      body: offeneAsync.when(
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
                  Text(
                    'Keine offenen Rechnungen',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Alle Rechnungen sind bezahlt',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            );
          }

          // Sortieren: Überfällige zuerst (meiste Tage überfällig)
          final sorted = List<Map<String, dynamic>>.from(rechnungen)
            ..sort((a, b) {
              final aTage = (a['ueberfaellig_seit_tagen'] as int?) ?? 0;
              final bTage = (b['ueberfaellig_seit_tagen'] as int?) ?? 0;
              return bTage.compareTo(aTage);
            });

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Zusammenfassung
              _SummaryCard(rechnungen: sorted),
              const SizedBox(height: 16),

              Text(
                '${sorted.length} offene Rechnungen',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),

              ...sorted.map((r) => _MahnungItem(
                    rechnung: r,
                    onMahnen: () => _mahnen(context, ref, r),
                    onTap: () {
                      // Navigation zur Rechnung
                      final id = r['id'];
                      if (id != null) context.push('/rechnungen/$id');
                    },
                  )),
            ],
          );
        },
      ),
    );
  }

  Future<void> _mahnen(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> rechnung,
  ) async {
    final stufe = (rechnung['mahnung_stufe'] as int?) ?? 0;
    final neueStufe = stufe + 1;
    final rechnungsnummer = rechnung['rechnungsnummer'] ?? '';

    if (neueStufe > 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximale Mahnstufe erreicht (3)')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$neueStufe. Mahnung erstellen?'),
        content: Text(
          'Rechnung $rechnungsnummer wird auf Mahnstufe $neueStufe gesetzt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mahnung erstellen'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final id = rechnung['id'] as String?;
        if (id != null) {
          await RechnungRepository.update(id, {
            'mahnung_stufe': neueStufe,
            'letzte_mahnung_am':
                DateTime.now().toIso8601String().split('T').first,
            'zahlungsstatus': 'ueberfaellig',
          });
          ref.invalidate(offeneRechnungenViewProvider);
          ref.invalidate(rechnungenStreamProvider);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$neueStufe. Mahnung für $rechnungsnummer erstellt'),
              ),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler: $e')),
          );
        }
      }
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final List<Map<String, dynamic>> rechnungen;

  const _SummaryCard({required this.rechnungen});

  @override
  Widget build(BuildContext context) {
    double totalBetrag = 0;
    int ueberfaellig = 0;
    for (final r in rechnungen) {
      totalBetrag += _d(r['betrag_brutto']);
      final tage = (r['ueberfaellig_seit_tagen'] as int?) ?? 0;
      if (tage > 0) ueberfaellig++;
    }

    return Card(
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
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Offener Gesamtbetrag',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: ueberfaellig > 0
                    ? AppColors.error.withAlpha(25)
                    : AppColors.warning.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    '$ueberfaellig',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: ueberfaellig > 0
                          ? AppColors.error
                          : AppColors.warning,
                    ),
                  ),
                  Text(
                    'Überfällig',
                    style: TextStyle(
                      fontSize: 11,
                      color: ueberfaellig > 0
                          ? AppColors.error
                          : AppColors.warning,
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

  static double _d(dynamic v) =>
      double.tryParse(v?.toString() ?? '') ?? 0;
}

class _MahnungItem extends StatelessWidget {
  final Map<String, dynamic> rechnung;
  final VoidCallback onMahnen;
  final VoidCallback onTap;

  const _MahnungItem({
    required this.rechnung,
    required this.onMahnen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final nummer = rechnung['rechnungsnummer'] ?? '';
    final betriebName = rechnung['betrieb_name'] ?? '';
    final betrag = _d(rechnung['betrag_brutto']);
    final tageUeberfaellig = (rechnung['ueberfaellig_seit_tagen'] as int?) ?? 0;
    final stufe = (rechnung['mahnung_stufe'] as int?) ?? 0;
    final status = rechnung['zahlungsstatus'] ?? 'offen';

    final isUeberfaellig = tageUeberfaellig > 0;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isUeberfaellig
              ? AppColors.error.withAlpha(25)
              : AppColors.warning.withAlpha(25),
          child: Icon(
            isUeberfaellig ? Icons.warning_amber : Icons.schedule,
            color: isUeberfaellig ? AppColors.error : AppColors.warning,
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
              Text(betriebName.toString(), style: const TextStyle(fontSize: 12)),
            Row(
              children: [
                Text(
                  '${betrag.toStringAsFixed(2)} CHF',
                  style: const TextStyle(fontSize: 12),
                ),
                if (isUeberfaellig) ...[
                  const Text(' · ', style: TextStyle(fontSize: 12)),
                  Text(
                    '$tageUeberfaellig Tage überfällig',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (stufe > 0) ...[
                  const Text(' · ', style: TextStyle(fontSize: 12)),
                  Text(
                    '$stufe. Mahnung',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isUeberfaellig && stufe < 3)
              IconButton(
                icon: const Icon(Icons.mail_outline, size: 20),
                tooltip: 'Mahnung erstellen',
                onPressed: onMahnen,
              ),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  static double _d(dynamic v) =>
      double.tryParse(v?.toString() ?? '') ?? 0;
}

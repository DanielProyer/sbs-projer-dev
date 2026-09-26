import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/config/bereiche.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/presentation/providers/bereich_zaehler_provider.dart';
import 'package:sbs_projer_app/presentation/providers/buchung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/buchhaltung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/rechnung_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/bereich_gruppen_liste.dart';

class BuchhaltungDashboardScreen extends ConsumerWidget {
  const BuchhaltungDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final buchungen = ref.watch(buchungenProvider);
    final erfolgsrechnung = ref.watch(erfolgsrechnungProvider(now.year));
    final mwst = ref.watch(mwstAbrechnungProvider(now.year));
    // Server-Count; solange er lädt 0 — wie früher die leere Liste.
    final offeneCount = ref.watch(offeneRechnungenCountProvider).valueOrNull ?? 0;

    // Buchungen aktueller Monat
    final buchungenMonat = buchungen
        .where((b) => b.geschaeftsjahr == now.year && b.monat == now.month)
        .toList();

    // Umsatz aktueller Monat aus Erfolgsrechnung
    double umsatzMonat = 0;
    erfolgsrechnung.whenData((data) {
      for (final row in data) {
        if (row['monat'] == now.month) {
          umsatzMonat = _d(row['ertrag']);
          break;
        }
      }
    });

    // MwSt aktuelles Quartal
    double mwstSchuld = 0;
    final quartal = ((now.month - 1) ~/ 3) + 1;
    mwst.whenData((data) {
      for (final row in data) {
        if (row['quartal'] == quartal) {
          mwstSchuld = _d(row['netto_mwst_schuld']);
          break;
        }
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Buchhaltung')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // «Was ist offen?», camt-Erinnerung und Bank-Wächter stehen seit
          // v0.131.0 nicht mehr hier: die offenen Punkte als Zähler auf
          // «Mehr» und in der Glocke, Bank-Themen auf «Bank und Zahlungen».
          // Kennzahlen
          Row(
            children: [
              Expanded(
                child: _KennzahlCard(
                  label: 'Umsatz ${_monatName(now.month)}',
                  value: '${umsatzMonat.toStringAsFixed(2)} CHF',
                  icon: Icons.trending_up,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    await context.push('/rechnungen');
                    // Zurück aus der Liste frisch zählen — dort geänderte
                    // Status sollen hier sofort stimmen (früher über den
                    // gemeinsamen Rechnungs-Stream).
                    if (context.mounted) {
                      ref.invalidate(offeneRechnungenCountProvider);
                    }
                  },
                  child: _KennzahlCard(
                    label: 'Offene Rechnungen',
                    value: '$offeneCount',
                    icon: Icons.receipt_long,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _KennzahlCard(
                  label: 'MwSt Q$quartal',
                  value: '${mwstSchuld.toStringAsFixed(2)} CHF',
                  icon: Icons.account_balance,
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KennzahlCard(
                  label: 'Buchungen ${_monatName(now.month)}',
                  value: buchungenMonat.length.toString(),
                  icon: Icons.menu_book,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          BereichGruppenListe(
            gruppen: kBereichBuchhaltung.gruppen,
            zaehler: ref.watch(bereichZaehlerProvider),
            onTap: (ziel) => context.push(ziel),
          ),

          const SizedBox(height: 24),

          // Letzte Buchungen
          Text(
            'Letzte Buchungen',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (buchungen.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Noch keine Buchungen vorhanden',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
            )
          else
            ...(List.of(buchungen)..sort((a, b) {
                  final cmp = b.datum.compareTo(a.datum);
                  if (cmp != 0) return cmp;
                  final catA = a.createdAt ?? a.datum;
                  final catB = b.createdAt ?? b.datum;
                  return catB.compareTo(catA);
                }))
                .take(5)
                .map(
                  (b) => Card(
                    // CanvasKit: InkWell + Container + Row statt ListTile
                    // (CLAUDE.md).
                    child: InkWell(
                      onTap: () =>
                          context.push('/buchhaltung/buchungen/${b.id}'),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: b.istStorniert
                                    ? AppColors.error.withAlpha(25)
                                    : AppColors.primary.withAlpha(25),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                b.istStorniert
                                    ? Icons.cancel
                                    : Icons.swap_horiz,
                                size: 18,
                                color: b.istStorniert
                                    ? AppColors.error
                                    : AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    b.beschreibung,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                      decoration: b.istStorniert
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${_formatDateTime(b)} · ${b.sollKonto} → ${b.habenKonto}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${b.betragBrutto.toStringAsFixed(2)} CHF',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: b.istStorniert ? AppColors.error : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  static double _d(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;

  static String _monatName(int m) {
    const namen = [
      '',
      'Jan',
      'Feb',
      'Mär',
      'Apr',
      'Mai',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Okt',
      'Nov',
      'Dez',
    ];
    return namen[m];
  }

  static String _formatDateTime(Buchung b) {
    final d = b.datum;
    final date =
        '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    final c = b.createdAt;
    if (c != null) {
      final time =
          '${c.hour.toString().padLeft(2, '0')}:${c.minute.toString().padLeft(2, '0')}';
      return '$date $time';
    }
    return date;
  }
}

class _KennzahlCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KennzahlCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

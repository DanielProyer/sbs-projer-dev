import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/camt_pruefliste_eintrag.dart';
import 'package:sbs_projer_app/data/repositories/camt_pruefliste_repository.dart';
import 'package:sbs_projer_app/presentation/providers/camt_pruefliste_providers.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/camt_regeln_screen.dart';

/// camt-Prüfliste — persistente Liste der Transaktionen, die der Auto-Booker
/// nicht sicher verbuchen konnte.
///
/// Phase-1-Scope: Auflösung beschränkt sich auf das Markieren als "erledigt"
/// bzw. "ignoriert". Die eigentliche manuelle Verbuchung erfolgt im
/// bestehenden Buchungen-UI — hier wird KEIN geführter Re-Booking-Dialog gebaut.
class CamtPrueflisteScreen extends ConsumerWidget {
  const CamtPrueflisteScreen({super.key});

  static String _kategorieLabel(String kategorie) {
    switch (kategorie) {
      case 'kundenzahlung':
        return 'Kundenzahlung';
      case 'heinekenEingang':
        return 'Heineken';
      case 'bargeldEinzahlung':
        return 'Bargeld';
      case 'ausgabe':
        return 'Ausgabe';
      case 'unbekannt':
        return 'Unbekannt';
      default:
        return kategorie;
    }
  }

  Future<void> _setStatus(
    BuildContext context,
    WidgetRef ref,
    CamtPrueflisteEintrag e,
    String status,
  ) async {
    try {
      await CamtPrueflisteRepository.setStatus(e.id!, status);
      ref.invalidate(camtPrueflisteProvider);
    } catch (err) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $err')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(camtPrueflisteProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('camt-Prüfliste')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Fehler beim Laden: $err',
              style: const TextStyle(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (eintraege) {
          if (eintraege.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: AppColors.success.withAlpha(120),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Keine offenen Einträge',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: eintraege.length,
            itemBuilder: (context, index) {
              final e = eintraege[index];
              const regelKategorien = {
                'ausgabe',
                'bargeldEinzahlung',
                'unbekannt',
              };
              return _PrueflisteCard(
                eintrag: e,
                onErledigt: () => _setStatus(context, ref, e, 'erledigt'),
                onIgnorieren: () => _setStatus(context, ref, e, 'ignoriert'),
                onRegelAnlegen: regelKategorien.contains(e.kategorie)
                    ? () => showRegelDialog(
                          context,
                          ref,
                          vorausgefuelltMatchName: e.parteiName,
                        )
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}

class _PrueflisteCard extends StatelessWidget {
  final CamtPrueflisteEintrag eintrag;
  final VoidCallback onErledigt;
  final VoidCallback onIgnorieren;
  final VoidCallback? onRegelAnlegen;

  const _PrueflisteCard({
    required this.eintrag,
    required this.onErledigt,
    required this.onIgnorieren,
    this.onRegelAnlegen,
  });

  @override
  Widget build(BuildContext context) {
    final e = eintrag;
    final vorschlagBetrieb = e.vorschlag?['betrieb'];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.parteiName ?? 'Unbekannt',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${DateFormat('dd.MM.yyyy').format(e.bookingDatum)} · '
                        '${CamtPrueflisteScreen._kategorieLabel(e.kategorie)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${e.istGutschrift ? '+' : '-'} ${e.betrag.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: e.istGutschrift ? AppColors.success : AppColors.error,
                  ),
                ),
              ],
            ),

            // Referenz
            if (e.referenz != null) ...[
              const SizedBox(height: 6),
              Text(
                e.referenz!,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // Fehlertext
            if (e.fehlertext != null) ...[
              const SizedBox(height: 6),
              Text(
                e.fehlertext!,
                style: const TextStyle(fontSize: 11, color: AppColors.error),
              ),
            ],

            // Vorschlag-Chip
            if (vorschlagBetrieb != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        size: 12, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Vorschlag: $vorschlagBetrieb',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Aktionen
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onRegelAnlegen != null) ...[
                  TextButton.icon(
                    onPressed: onRegelAnlegen,
                    icon: const Icon(Icons.rule, size: 16),
                    label: const Text('Regel anlegen'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                TextButton.icon(
                  onPressed: onIgnorieren,
                  icon: const Icon(Icons.block, size: 16),
                  label: const Text('Ignorieren'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onErledigt,
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Erledigt'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/util/kalenderwoche.dart';
import 'package:sbs_projer_app/presentation/widgets/detail/detail_karte.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';
import 'package:sbs_projer_app/services/pdf/heineken_rapport_service.dart';
import 'package:sbs_projer_app/data/local/pikett_dienst_local_export.dart';
import 'package:sbs_projer_app/data/repositories/pikett_dienst_repository.dart';
import 'package:sbs_projer_app/presentation/providers/pikett_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';
import 'package:sbs_projer_app/core/util/anfrage_bloecke.dart';

class PikettDienstDetailScreen extends ConsumerWidget {
  final String pikettId;

  const PikettDienstDetailScreen({super.key, required this.pikettId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<PikettDienstLocal?>(
      future: PikettDienstRepository.getById(pikettId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final pikett = snapshot.data;
        if (pikett == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Nicht gefunden')),
            body: const Center(child: Text('Pikett-Dienst nicht gefunden')),
          );
        }

        return _PikettDetailContent(pikett: pikett);
      },
    );
  }
}

class _PikettDetailContent extends ConsumerWidget {
  final PikettDienstLocal pikett;

  const _PikettDetailContent({required this.pikett});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pikett KW ${kalenderwoche(pikett.datumStart)}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Rapport PDF',
            onPressed: () => _showRapportPdf(context),
          ),
          if (!SupabaseService.isGuest) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Bearbeiten',
              onPressed: () =>
                  context.push('/pikett/${pikett.routeId}/bearbeiten'),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Loeschen',
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Abrechnung-Chip
          if (pikett.abgerechnet)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Wrap(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.info.withAlpha(25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.info.withAlpha(50)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt, size: 14, color: AppColors.info),
                        SizedBox(width: 4),
                        Text(
                          'Abgerechnet',
                          style: TextStyle(
                            color: AppColors.info,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Einsatzzeiten
          DetailKarte(
            titel: 'Einsatzzeiten',
            icon: Icons.schedule,
            kinder: [
              InfoZeile('Kalenderwoche', 'KW ${kalenderwoche(pikett.datumStart)}'),
              InfoZeile(
                'Freitag',
                '${_formatDate(pikett.datumStart)}, 17:00 – 22:00',
              ),
              InfoZeile(
                'Samstag',
                '${_formatDate(pikett.datumEnde)}, 08:00 – 22:00',
              ),
            ],
          ),

          // Vergütung
          DetailKarte(
            titel: 'Vergütung',
            icon: Icons.attach_money,
            kinder: [
              InfoZeile(
                'Pauschale',
                '${(pikett.pauschale ?? 80).toStringAsFixed(2)} CHF',
              ),
              if (pikett.anzahlFeiertage > 0)
                InfoZeile('Feiertage', '${pikett.anzahlFeiertage}'),
              if (pikett.feiertagZuschlag != null &&
                  pikett.feiertagZuschlag! > 0)
                InfoZeile(
                  'Feiertag-Zuschlag',
                  '${pikett.feiertagZuschlag!.toStringAsFixed(2)} CHF',
                ),
              if (pikett.pauschaleGesamt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 130,
                        child: Text(
                          'Gesamt',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${pikett.pauschaleGesamt!.toStringAsFixed(2)} CHF',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          // Abrechnung
          if (pikett.abrechnungsMonat != null || pikett.abgerechnet)
            DetailKarte(
              titel: 'Abrechnung',
              icon: Icons.receipt_long,
              kinder: [
                if (pikett.abrechnungsMonat != null)
                  InfoZeile(
                    'Abrechnungsmonat',
                    '${pikett.abrechnungsMonat!.month.toString().padLeft(2, '0')}/${pikett.abrechnungsMonat!.year}',
                  ),
                InfoZeile(
                  'Status',
                  pikett.abgerechnet ? 'Abgerechnet' : 'Offen',
                ),
              ],
            ),

          // Sync-Info
          if (!pikett.isSynced)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warning.withAlpha(50)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    color: AppColors.warning,
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Noch nicht synchronisiert',
                    style: TextStyle(color: AppColors.warning),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Future<void> _showRapportPdf(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final kw = kalenderwoche(pikett.datumStart);
      final year = pikett.datumStart.year;

      final pdfBytes = await HeinekenRapportService.generatePikett(
        referenzNr: pikett.referenzNr ?? '${year}_$kw',
        datumStart: pikett.datumStart,
        datumEnde: pikett.datumEnde,
        kalenderwoche: kw,
        pauschale: pikett.pauschale,
        anzahlFeiertage: pikett.anzahlFeiertage,
        feiertagZuschlag: pikett.feiertagZuschlag,
        pauschaleGesamt: pikett.pauschaleGesamt,
      );

      if (context.mounted) {
        Navigator.of(context).pop();
        await Printing.layoutPdf(
          onLayout: (_) => pdfBytes,
          name: 'Rapport_Pikett_KW${kw}_$year',
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF-Fehler: ${kurzeFehlermeldung(e)}')),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pikett-Dienst loeschen'),
        content: const Text(
          'Diesen Pikett-Dienst wirklich loeschen?\n\nDiese Aktion kann nicht rueckgaengig gemacht werden.',
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(false),
            child: const Text('Abbrechen'),
          ),
          TapKnopf(text: 'Loeschen', gefahr: true, onTap: () => ctx.pop(true)),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await PikettDienstRepository.delete(pikett.routeId);
        ref.invalidate(pikettDiensteStreamProvider);
        if (context.mounted) context.pop();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Loeschen nur mit Internetverbindung moeglich'),
            ),
          );
        }
      }
    }
  }
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
}


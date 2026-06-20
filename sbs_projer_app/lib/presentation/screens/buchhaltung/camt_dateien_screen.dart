import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/camt_datei.dart';
import 'package:sbs_projer_app/data/repositories/camt_datei_repository.dart';
import 'package:sbs_projer_app/presentation/providers/camt_abgleich_providers.dart';

/// Übersicht der archivierten camt-Dateien: erfasste Zeiträume chronologisch,
/// Warnung bei Lücken (> 3 Tage zwischen zwei Dateien) und Download je Datei.
class CamtDateienScreen extends ConsumerWidget {
  const CamtDateienScreen({super.key});

  static final _dateFormat = DateFormat('dd.MM.yyyy');

  /// Formatiert ein Datum oder gibt einen Platzhalter zurück (null-sicher).
  static String _fmt(DateTime? d) => d == null ? '—' : _dateFormat.format(d);

  /// Lädt eine signierte URL und öffnet die Datei im externen Browser.
  Future<void> _download(BuildContext context, CamtDatei d) async {
    try {
      final url = await CamtDateiRepository.signedUrl(d.storagePfad);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download fehlgeschlagen: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(camtDateienProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('camt-Dateien')),
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
        data: (dateien) {
          if (dateien.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_open,
                    size: 64,
                    color: AppColors.primary.withAlpha(120),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Noch keine camt-Datei erfasst',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            );
          }

          final items = <Widget>[];
          // dateien ist nach zeitraum_von sortiert (Repository).
          for (int i = 0; i < dateien.length; i++) {
            final d = dateien[i];
            if (i > 0) {
              final prevBis = dateien[i - 1].zeitraumBis;
              if (prevBis != null &&
                  d.zeitraumVon != null &&
                  d.zeitraumVon!.difference(prevBis).inDays > 3) {
                items.add(_LueckeBanner(von: prevBis, bis: d.zeitraumVon!));
              }
            }
            items.add(_DateiCard(datei: d, onDownload: () => _download(context, d)));
          }

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: items,
          );
        },
      ),
    );
  }
}

/// Warn-Banner für eine Lücke zwischen zwei aufeinanderfolgenden Dateien.
class _LueckeBanner extends StatelessWidget {
  final DateTime von;
  final DateTime bis;

  const _LueckeBanner({required this.von, required this.bis});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.warning.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning.withAlpha(80)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, size: 18, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Lücke: ${CamtDateienScreen._fmt(von)} – ${CamtDateienScreen._fmt(bis)}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card pro camt-Datei: Zeitraum, Anzahl Gutschriften/Einträge, Download.
class _DateiCard extends StatelessWidget {
  final CamtDatei datei;
  final VoidCallback onDownload;

  const _DateiCard({required this.datei, required this.onDownload});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${CamtDateienScreen._fmt(datei.zeitraumVon)} – '
                    '${CamtDateienScreen._fmt(datei.zeitraumBis)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${datei.anzahlGutschriften} Gutschrift(en) · '
                    '${datei.anzahlEintraege} Eintrag/Einträge',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.download, size: 20),
              color: AppColors.primary,
              tooltip: 'Herunterladen',
              onPressed: onDownload,
            ),
          ],
        ),
      ),
    );
  }
}
